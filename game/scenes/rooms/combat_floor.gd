extends Node2D
## Reusable combat arena floor — instance under RunController and call apply_theme(stage_index).

const RUNTIME_MANIFEST_PATH := "res://assets/maps/runtime_scene_manifest.json"
const METADATA_PATH := "res://assets/maps/tileset_metadata.json"
const DEFAULT_THEME_ID := "qi_refining_verdant"
const RoomLayoutGenerator = preload("res://systems/world/room_layout_generator.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")
const WeatherOverlay = preload("res://scenes/visual/weather_overlay.gd")

const THUNDER_STRIKE_BASE_DAMAGE := 34.0
const THUNDER_STRIKE_BATCH_INTERVAL := 3.8

@onready var _background: Sprite2D = $Background
@onready var _tile_map: TileMap = $TileMap
@onready var _floor_layer: TileMapLayer = $TileMap/FloorLayer

var _metadata: Dictionary = {}
var _scene_manifest: Dictionary = {}
var _obstacle_root: Node2D
var _prop_root: Node2D
var _weather_ground_root: Node2D
var _weather_overlay: WeatherOverlay
var _thunder_strike_parent: Node2D
var _current_theme: Dictionary = {}
var _current_room: Dictionary = {}
var _active_arena: Dictionary = {}
var _texture_cache: Dictionary = {}
var _layout_blockers: Array = []
var _debug_overlay_visible := false
var _current_stage_index := 1
var _runtime_asset_warnings: Dictionary = {}
var _active_weather_id := "clear"
var _thunder_strike_timer := 0.0
var _thunder_strike_batch := 0


func _ready() -> void:
	_load_metadata()
	_obstacle_root = Node2D.new()
	_obstacle_root.name = "ObstacleRoot"
	_obstacle_root.z_index = 1
	add_child(_obstacle_root)
	_prop_root = Node2D.new()
	_prop_root.name = "PropRoot"
	_prop_root.z_index = 0
	add_child(_prop_root)
	_weather_ground_root = Node2D.new()
	_weather_ground_root.name = "WeatherGroundRoot"
	_weather_ground_root.z_index = -1
	add_child(_weather_ground_root)
	_weather_overlay = WeatherOverlay.new()
	_weather_overlay.name = "WeatherOverlay"
	add_child(_weather_overlay)
	_thunder_strike_parent = Node2D.new()
	_thunder_strike_parent.name = "ThunderStrikeRoot"
	add_child(_thunder_strike_parent)
	set_process(false)


func _process(delta: float) -> void:
	if _active_weather_id != "thunder":
		return
	_thunder_strike_timer -= delta
	if _thunder_strike_timer > 0.0:
		return
	_spawn_thunder_strike_batch()
	_thunder_strike_timer = THUNDER_STRIKE_BATCH_INTERVAL / maxf(WeatherSystem.get_weather_intensity(_active_weather_id), 0.1)


func apply_theme(stage_index: int = 1) -> void:
	_current_stage_index = stage_index
	var theme := _theme_for_stage(stage_index)
	if theme.is_empty():
		push_warning("CombatFloor: no theme for stage_index=%d" % stage_index)
		return
	_current_theme = theme
	_current_room = {}
	_active_arena = _scene_manifest.get("arena", {}).duplicate(true)
	_validate_theme_runtime_assets(theme)
	_swap_textures(theme)
	_fill_floor_tiles(theme)
	_spawn_scenery_props(theme)
	_apply_arena_manifest()
	queue_redraw()


func clear_layout() -> void:
	_current_room = {}
	_active_arena = _scene_manifest.get("arena", {}).duplicate(true)
	_clear_obstacles()
	_schedule_weather_strikes("clear")
	queue_redraw()


func apply_layout(room: Dictionary, rng: RandomNumberGenerator, weather_id: String = "clear") -> Dictionary:
	_clear_obstacles()
	_current_room = room
	_active_arena = _arena_for_room(room)
	_apply_arena_manifest()
	_fill_floor_tiles(_current_theme)
	_spawn_scenery_props(_current_theme)
	var layout_id := str(room.get("layout_id", "open_scatter"))
	var layout_profile := _layout_profile_for_current_theme(room)
	var layout: Dictionary = RoomLayoutGenerator.build_with_profile(layout_id, rng, layout_profile)
	room["layout"] = layout
	for obs in layout.get("obstacles", []):
		_spawn_obstacle(obs)
	TerrainSystem.setup_for_room(weather_id, layout, self, rng)
	_apply_weather_mood(weather_id)
	queue_redraw()
	return layout


func set_debug_overlay_visible(_show: bool) -> void:
	_debug_overlay_visible = false
	queue_redraw()


func is_debug_overlay_visible() -> bool:
	return _debug_overlay_visible


func get_spawn_zones() -> Array:
	return _current_room.get("spawn_zones", _current_theme.get("spawn_zones", []))


func get_no_spawn_zones() -> Array:
	return _current_room.get("no_spawn_zones", _current_theme.get("no_spawn_zones", []))


func get_safe_zones() -> Array:
	return _current_room.get("safe_zones", _current_theme.get("safe_zones", []))


func get_layout_blockers() -> Array:
	return _layout_blockers.duplicate(true)


func get_world_bounds() -> Dictionary:
	return _active_arena.get("world_bounds", _fallback_world_bounds())


func clamp_to_active_arena(pos: Vector2, body_radius: float = 12.0) -> Vector2:
	var bounds: Dictionary = get_world_bounds()
	var margin := body_radius + 2.0
	var min_x := float(bounds.get("x", -640.0)) + margin
	var min_y := float(bounds.get("y", -352.0)) + margin
	var max_x := min_x + float(bounds.get("width", 1280.0)) - margin * 2.0
	var max_y := min_y + float(bounds.get("height", 704.0)) - margin * 2.0
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))


func make_terrain_zone_visual(terrain_type: String, color: Color, radius: float, rng: RandomNumberGenerator) -> Node2D:
	var terrain_props := str(_current_theme.get("terrain_props", ""))
	if terrain_props.is_empty():
		return null
	var coords := _terrain_prop_coords(terrain_type, rng)
	var sprite := _make_atlas_sprite({
		"atlas_path": terrain_props,
		"atlas_coords": coords,
		"atlas_cell_size": _terrain_prop_cell_size(),
	})
	if sprite == null:
		return null
	var visual := Node2D.new()
	visual.name = "TerrainPropVisual"
	var diameter := radius * 2.0
	var cell_size := float(_terrain_prop_cell_size())
	var terrain_style := _terrain_visual_style(terrain_type, color)
	var base_scale := diameter / cell_size * float(terrain_style.get("size_mult", 1.0))
	var stretch: Vector2 = terrain_style.get("stretch", Vector2.ONE)
	sprite.scale = Vector2(
		base_scale * stretch.x * rng.randf_range(0.88, 1.24),
		base_scale * stretch.y * rng.randf_range(0.82, 1.18)
	)
	sprite.rotation = rng.randf_range(-PI, PI)
	sprite.modulate = terrain_style.get("modulate", Color.WHITE)
	sprite.z_index = 1
	visual.add_child(sprite)
	var aura_alpha := float(terrain_style.get("aura_alpha", 0.0))
	if aura_alpha > 0.001:
		var aura := _make_terrain_aura(color, radius, rng, aura_alpha)
		visual.add_child(aura)
		visual.move_child(aura, 0)
	return visual


func is_spawn_position_clear(pos: Vector2, radius: float = 18.0) -> bool:
	for zone in get_no_spawn_zones():
		if _point_in_zone(pos, zone, radius):
			return false
	for zone in get_safe_zones():
		if _point_in_zone(pos, zone, radius):
			return false
	for blocker in _layout_blockers:
		var blocker_pos: Vector2 = blocker.get("position", Vector2.ZERO)
		var blocker_size := Vector2(float(blocker.get("width", 48.0)), float(blocker.get("height", 48.0)))
		if _point_in_rect(pos, blocker_pos, blocker_size, radius):
			return false
	return true


func _spawn_obstacle(obs: Dictionary) -> void:
	var size := Vector2(float(obs.get("width", 48)), float(obs.get("height", 48)))
	var collision_size := Vector2(float(obs.get("collision_width", size.x)), float(obs.get("collision_height", size.y)))
	var pos: Vector2 = obs.get("position", Vector2.ZERO)
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = GameConstants.COLLISION_LAYER_OBSTACLE
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	if str(obs.get("shape", "rect")) == "circle":
		var circle := CircleShape2D.new()
		circle.radius = maxf(collision_size.x, collision_size.y) * 0.5
		shape.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = collision_size
		shape.shape = rect
	body.add_child(shape)
	body.add_child(_make_obstacle_shadow(size))
	var obstacle_sprite := _make_obstacle_sprite(size)
	if obstacle_sprite:
		body.add_child(obstacle_sprite)
	else:
		var visual := ColorRect.new()
		visual.size = size
		visual.position = -size * 0.5
		visual.color = Color(str(obs.get("color", "#5A5A6E")))
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(visual)
	body.add_child(_make_obstacle_edge_highlight(size))
	_obstacle_root.add_child(body)
	_layout_blockers.append({
		"position": pos,
		"width": collision_size.x,
		"height": collision_size.y,
		"shape": str(obs.get("shape", "rect")),
	})


func _clear_obstacles() -> void:
	if _obstacle_root == null:
		return
	for child in _obstacle_root.get_children():
		child.queue_free()
	_layout_blockers.clear()


func _clear_props() -> void:
	if _prop_root == null:
		return
	for child in _prop_root.get_children():
		child.queue_free()


func _spawn_scenery_props(theme: Dictionary) -> void:
	_clear_props()
	var room_scale := _room_scale_for_active_arena()
	var size_scale := minf(room_scale.x, room_scale.y)
	for prop in theme.get("scenery_props", []):
		var sprite := _make_atlas_sprite(prop)
		if sprite == null:
			continue
		var raw_pos: Array = prop.get("position", [0, 0])
		if raw_pos.size() >= 2:
			sprite.position = Vector2(float(raw_pos[0]) * room_scale.x, float(raw_pos[1]) * room_scale.y)
		var raw_size: Array = prop.get("size", [32, 32])
		if raw_size.size() >= 2:
			var cell_size := float(_atlas_cell_size(prop))
			sprite.scale = Vector2(float(raw_size[0]) * size_scale / cell_size, float(raw_size[1]) * size_scale / cell_size)
		var raw_modulate: Array = prop.get("modulate", [])
		if raw_modulate.size() >= 4:
			sprite.modulate = Color(float(raw_modulate[0]), float(raw_modulate[1]), float(raw_modulate[2]), float(raw_modulate[3]))
		_prop_root.add_child(sprite)


func _load_metadata() -> void:
	_load_runtime_manifest()
	if FileAccess.file_exists(METADATA_PATH):
		var file := FileAccess.open(METADATA_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_metadata = parsed
	else:
		push_warning("CombatFloor: missing %s" % METADATA_PATH)


func _load_runtime_manifest() -> void:
	if FileAccess.file_exists(RUNTIME_MANIFEST_PATH):
		var manifest_file := FileAccess.open(RUNTIME_MANIFEST_PATH, FileAccess.READ)
		var manifest: Variant = JSON.parse_string(manifest_file.get_as_text())
		if manifest is Dictionary:
			_scene_manifest = manifest
		else:
			push_warning("CombatFloor: failed to parse %s" % RUNTIME_MANIFEST_PATH)
	else:
		push_warning("CombatFloor: missing %s; falling back to %s" % [RUNTIME_MANIFEST_PATH, METADATA_PATH])


func _theme_for_stage(stage_index: int) -> Dictionary:
	for entry in _scene_manifest.get("stages", []):
		if int(entry.get("stage_index", -1)) == stage_index:
			return entry
	for entry in _metadata.get("themes", []):
		if int(entry.get("stage_index", -1)) == stage_index:
			return entry
	for entry in _scene_manifest.get("stages", []):
		if entry.get("theme_id", "") == DEFAULT_THEME_ID:
			return entry
	for entry in _metadata.get("themes", []):
		if entry.get("theme_id", "") == DEFAULT_THEME_ID:
			return entry
	return {}


func _swap_textures(theme: Dictionary) -> void:
	var bg_path: String = theme.get("room_background", "")
	var tile_path: String = theme.get("tileset", "")
	if bg_path.is_empty() or tile_path.is_empty():
		return
	if ResourceLoader.exists(bg_path):
		_background.texture = _load_cached_texture(bg_path)
	var tile_tex: Texture2D = _load_cached_texture(tile_path) if ResourceLoader.exists(tile_path) else null
	if tile_tex == null:
		return
	var tile_set := _tile_map.tile_set
	if tile_set == null or tile_set.get_source_count() == 0:
		return
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source:
		source.texture = tile_tex
		source.texture_region_size = Vector2i(_tile_size(), _tile_size())
	tile_set.tile_size = Vector2i(_tile_size(), _tile_size())


func _fill_floor_tiles(theme: Dictionary) -> void:
	_floor_layer.clear()
	# 与背景 room_background.png（1280×720 @ -640,-360）对齐
	var cells := _tilemap_cells()
	var cols := cells.x
	var rows := cells.y
	var origin := Vector2i(-cols / 2, -rows / 2)
	var floor_atlas := _atlas_coords_from_theme(theme, "floor_atlas_coords", Vector2i(0, 0))
	var floor_alt_atlas := _atlas_coords_from_theme(theme, "floor_alt_atlas_coords", Vector2i(1, 0))
	var decoration_atlas := _atlas_coords_from_theme(theme, "decoration_atlas_coords", Vector2i(3, 0))
	var decoration_lookup := _decoration_cell_lookup(theme)
	for y in range(rows):
		for x in range(cols):
			var coords := origin + Vector2i(x, y)
			var atlas := floor_alt_atlas if _uses_alt_floor(theme, x, y) else floor_atlas
			if decoration_lookup.has(coords):
				atlas = decoration_atlas
			_floor_layer.set_cell(coords, 0, atlas)


func _apply_arena_manifest() -> void:
	var arena: Dictionary = _active_arena if not _active_arena.is_empty() else _scene_manifest.get("arena", {})
	GameConstants.set_arena_bounds(arena.get("world_bounds", _fallback_world_bounds()))
	var camera_bounds: Dictionary = arena.get("camera_bounds", _fallback_camera_bounds())
	_background.centered = false
	_background.position = Vector2(
		float(camera_bounds.get("x", -640.0)),
		float(camera_bounds.get("y", -360.0))
	)
	var background_size := Vector2(
		float(camera_bounds.get("width", 1280.0)),
		float(camera_bounds.get("height", 720.0))
	)
	if _background.texture != null:
		var tex_size := Vector2(_background.texture.get_size())
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_background.scale = Vector2(background_size.x / tex_size.x, background_size.y / tex_size.y)


func _tilemap_cells() -> Vector2i:
	var arena: Dictionary = _active_arena if not _active_arena.is_empty() else _scene_manifest.get("arena", {})
	var cells: Array = arena.get("tilemap_cells", [])
	if cells.size() >= 2:
		return Vector2i(int(cells[0]), int(cells[1]))
	return Vector2i(40, 22)


func _tile_size() -> int:
	var arena: Dictionary = _active_arena if not _active_arena.is_empty() else _scene_manifest.get("arena", {})
	var manifest_tile_size := int(arena.get("tile_size", 0))
	if manifest_tile_size > 0:
		return manifest_tile_size
	var metadata_tile_size := int(_metadata.get("tile_size", 0))
	if metadata_tile_size > 0:
		return metadata_tile_size
	return 32


func _make_obstacle_sprite(size: Vector2) -> Sprite2D:
	var sprite := _make_atlas_sprite({"atlas_coords": _atlas_coords_from_theme(_current_theme, "obstacle_atlas_coords", Vector2i(2, 0))})
	if sprite == null:
		return null
	var tile_size := float(_tile_size())
	sprite.scale = Vector2(size.x / tile_size, size.y / tile_size)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.92)
	return sprite


func _make_obstacle_shadow(size: Vector2) -> Polygon2D:
	var shadow := Polygon2D.new()
	var half := size * 0.5
	var drop := Vector2(8.0, 10.0)
	shadow.polygon = PackedVector2Array([
		Vector2(-half.x, half.y - 5.0) + drop,
		Vector2(half.x, half.y - 5.0) + drop,
		Vector2(half.x - 8.0, half.y + 9.0) + drop,
		Vector2(-half.x + 8.0, half.y + 9.0) + drop,
	])
	shadow.color = Color(0.02, 0.018, 0.012, 0.34)
	shadow.z_index = -1
	return shadow


func _make_obstacle_edge_highlight(size: Vector2) -> Line2D:
	var half := size * 0.5
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = Color(0.96, 0.82, 0.46, 0.28)
	line.closed = true
	line.points = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	line.z_index = 2
	return line


func _make_atlas_sprite(entry: Dictionary) -> Sprite2D:
	var source_texture := _texture_for_atlas_entry(entry)
	if source_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	var coords: Variant = entry.get("atlas_coords", Vector2i(3, 0))
	var atlas_coords := Vector2i(3, 0)
	if coords is Vector2i:
		atlas_coords = coords
	elif coords is Array and coords.size() >= 2:
		atlas_coords = Vector2i(int(coords[0]), int(coords[1]))
	var cell_size := float(_atlas_cell_size(entry))
	atlas.region = Rect2(Vector2(atlas_coords) * cell_size, Vector2(cell_size, cell_size))
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


func _layout_profile_for_current_theme(room: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = _current_theme.get("layout_profile", {}).duplicate(true)
	if room.has("layout_profile"):
		profile.merge(room.get("layout_profile", {}), true)
	profile["safe_zones"] = room.get("safe_zones", _current_theme.get("safe_zones", []))
	profile["no_spawn_zones"] = room.get("no_spawn_zones", _current_theme.get("no_spawn_zones", []))
	profile["arena_bounds"] = _active_arena.get("world_bounds", _fallback_world_bounds())
	return profile


func _point_in_zone(pos: Vector2, zone: Dictionary, padding: float = 0.0) -> bool:
	var raw_center: Array = zone.get("center", [0, 0])
	var raw_size: Array = zone.get("size", [0, 0])
	if raw_center.size() < 2 or raw_size.size() < 2:
		return false
	var center := Vector2(float(raw_center[0]), float(raw_center[1]))
	var radius := Vector2(float(raw_size[0]) * 0.5 + padding, float(raw_size[1]) * 0.5 + padding)
	if radius.x <= 0.0 or radius.y <= 0.0:
		return false
	var local := pos - center
	return (local.x * local.x) / (radius.x * radius.x) + (local.y * local.y) / (radius.y * radius.y) <= 1.0


func _point_in_rect(pos: Vector2, rect_center: Vector2, rect_size: Vector2, padding: float = 0.0) -> bool:
	var half := rect_size * 0.5 + Vector2(padding, padding)
	var local := pos - rect_center
	return absf(local.x) <= half.x and absf(local.y) <= half.y


func _draw() -> void:
	_draw_debug_overlay()


func _draw_debug_overlay() -> void:
	if not _debug_overlay_visible:
		return
	var arena: Dictionary = _active_arena if not _active_arena.is_empty() else _scene_manifest.get("arena", {})
	var world_bounds: Dictionary = arena.get("world_bounds", _fallback_world_bounds())
	var bounds := Rect2(
		float(world_bounds.get("x", -640.0)),
		float(world_bounds.get("y", -352.0)),
		float(world_bounds.get("width", 1280.0)),
		float(world_bounds.get("height", 704.0))
	)
	draw_rect(bounds, Color(0.58, 0.78, 1.0, 0.08), false, 2.0)
	for zone in get_spawn_zones():
		_draw_debug_zone(zone, Color(0.22, 1.0, 0.42, 0.13), Color(0.22, 1.0, 0.42, 0.72))
	for zone in get_safe_zones():
		_draw_debug_zone(zone, Color(0.16, 0.9, 1.0, 0.12), Color(0.16, 0.9, 1.0, 0.72))
	for zone in get_no_spawn_zones():
		_draw_debug_zone(zone, Color(1.0, 0.2, 0.2, 0.11), Color(1.0, 0.2, 0.2, 0.72))
	for blocker in _layout_blockers:
		var center: Vector2 = blocker.get("position", Vector2.ZERO)
		var size := Vector2(float(blocker.get("width", 48.0)), float(blocker.get("height", 48.0)))
		var rect := Rect2(center - size * 0.5, size)
		draw_rect(rect, Color(1.0, 0.62, 0.14, 0.18), true)
		draw_rect(rect, Color(1.0, 0.62, 0.14, 0.9), false, 2.0)


func _draw_debug_zone(zone: Dictionary, fill: Color, stroke: Color) -> void:
	var raw_center: Array = zone.get("center", [0, 0])
	var raw_size: Array = zone.get("size", [0, 0])
	if raw_center.size() < 2 or raw_size.size() < 2:
		return
	var center := Vector2(float(raw_center[0]), float(raw_center[1]))
	var size := Vector2(float(raw_size[0]), float(raw_size[1]))
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect, fill, true)
	draw_rect(rect, stroke, false, 1.5)


func _atlas_coords_from_theme(theme: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	var raw: Array = theme.get(key, [])
	if raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return fallback


func _fallback_camera_bounds() -> Dictionary:
	return {"x": -640.0, "y": -360.0, "width": 1280.0, "height": 720.0}


func _fallback_world_bounds() -> Dictionary:
	return {"x": -640.0, "y": -352.0, "width": 1280.0, "height": 704.0}


func _arena_for_room(room: Dictionary) -> Dictionary:
	var arena: Dictionary = _scene_manifest.get("arena", {}).duplicate(true)
	if room.has("arena"):
		arena.merge(room.get("arena", {}), true)
	if not arena.has("world_bounds"):
		arena["world_bounds"] = _fallback_world_bounds()
	if not arena.has("camera_bounds"):
		arena["camera_bounds"] = _fallback_camera_bounds()
	return arena


func _room_scale_for_active_arena() -> Vector2:
	var raw: Variant = _active_arena.get("room_scale", [1.0, 1.0])
	if raw is Vector2:
		return raw
	if raw is Array and raw.size() >= 2:
		return Vector2(maxf(float(raw[0]), 0.5), maxf(float(raw[1]), 0.5))
	return Vector2.ONE


func _texture_for_atlas_entry(entry: Dictionary) -> Texture2D:
	var atlas_path := str(entry.get("atlas_path", ""))
	if not atlas_path.is_empty():
		return _load_cached_texture(atlas_path)
	var tile_set := _tile_map.tile_set
	if tile_set == null or tile_set.get_source_count() == 0:
		return null
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source == null:
		return null
	return source.texture


func _atlas_cell_size(entry: Dictionary) -> int:
	var explicit_size := int(entry.get("atlas_cell_size", 0))
	if explicit_size > 0:
		return explicit_size
	return _tile_size()


func _terrain_prop_cell_size() -> int:
	var arena: Dictionary = _scene_manifest.get("arena", {})
	var atlas: Dictionary = arena.get("terrain_prop_atlas", {})
	var cell_size := int(atlas.get("cell_size", 0))
	return cell_size if cell_size > 0 else 128


func _terrain_prop_coords(terrain_type: String, rng: RandomNumberGenerator) -> Vector2i:
	var choices: Array = []
	match terrain_type:
		"water", "wet":
			choices = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
		"swamp":
			choices = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)]
		"fire", "dry":
			choices = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
		"rock":
			choices = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
		"ice":
			choices = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
		_:
			choices = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	return choices[rng.randi_range(0, choices.size() - 1)]


func _terrain_visual_style(terrain_type: String, color: Color) -> Dictionary:
	match terrain_type:
		"rock":
			return {
				"modulate": Color(1.02, 1.02, 1.02, 0.95),
				"stretch": Vector2(0.92, 0.78),
				"size_mult": 0.86,
				"aura_alpha": 0.035,
			}
		"fire", "dry":
			return {
				"modulate": Color(1.0, 0.80, 0.56, 0.86),
				"stretch": Vector2(1.45, 0.76),
				"size_mult": 0.96,
				"aura_alpha": 0.18,
			}
		"swamp":
			return {
				"modulate": Color(0.70, 1.0, 0.68, 0.70),
				"stretch": Vector2(1.25, 0.82),
				"size_mult": 1.02,
				"aura_alpha": 0.14,
			}
		"ice":
			return {
				"modulate": Color(0.78, 0.94, 1.0, 0.78),
				"stretch": Vector2(1.36, 0.72),
				"size_mult": 1.04,
				"aura_alpha": 0.13,
			}
		"water", "wet":
			return {
				"modulate": Color(0.70, 0.90, 1.0, 0.76),
				"stretch": Vector2(1.42, 0.74),
				"size_mult": 1.06,
				"aura_alpha": 0.16,
			}
	return {
		"modulate": Color(color.r, color.g, color.b, 0.68),
		"stretch": Vector2(1.0, 1.0),
		"size_mult": 1.0,
		"aura_alpha": 0.10,
	}


func _make_terrain_aura(color: Color, radius: float, rng: RandomNumberGenerator, alpha_scale: float) -> Polygon2D:
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	var steps := rng.randi_range(13, 20)
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		var wobble := rng.randf_range(0.62, 1.12)
		points.append(Vector2(cos(angle), sin(angle)) * radius * wobble)
	poly.polygon = points
	poly.rotation = rng.randf_range(-PI, PI)
	poly.color = Color(color.r, color.g, color.b, alpha_scale)
	poly.z_index = 0
	return poly


func _apply_weather_mood(weather_id: String) -> void:
	var bg := Color.WHITE
	var floor := Color.WHITE
	match weather_id:
		"rain":
			bg = Color(0.78, 0.86, 1.0, 1.0)
			floor = Color(0.74, 0.88, 1.0, 1.0)
		"thunder":
			bg = Color(0.70, 0.76, 1.08, 1.0)
			floor = Color(0.72, 0.78, 1.05, 1.0)
		"fire":
			bg = Color(1.08, 0.82, 0.66, 1.0)
			floor = Color(1.10, 0.82, 0.68, 1.0)
		"wind":
			bg = Color(0.90, 1.04, 0.88, 1.0)
			floor = Color(0.88, 1.02, 0.86, 1.0)
		"fog":
			bg = Color(0.86, 0.90, 0.88, 1.0)
			floor = Color(0.86, 0.92, 0.90, 1.0)
		"snow":
			bg = Color(0.84, 0.94, 1.08, 1.0)
			floor = Color(0.84, 0.96, 1.10, 1.0)
		"sand":
			bg = Color(1.08, 0.96, 0.74, 1.0)
			floor = Color(1.08, 0.95, 0.72, 1.0)
	if _background:
		_background.modulate = bg
	if _floor_layer:
		_floor_layer.modulate = floor
	_apply_weather_ground_cover(weather_id)
	if _weather_overlay:
		_weather_overlay.set_weather(weather_id, _active_camera_rect(), WeatherSystem.get_weather_intensity(weather_id))
	_schedule_weather_strikes(weather_id)


func _active_camera_rect() -> Rect2:
	var arena: Dictionary = _active_arena if not _active_arena.is_empty() else _scene_manifest.get("arena", {})
	var camera_bounds: Dictionary = arena.get("camera_bounds", _fallback_camera_bounds())
	return Rect2(
		Vector2(float(camera_bounds.get("x", -640.0)), float(camera_bounds.get("y", -360.0))),
		Vector2(float(camera_bounds.get("width", 1280.0)), float(camera_bounds.get("height", 720.0)))
	)


func _apply_weather_ground_cover(weather_id: String) -> void:
	if _weather_ground_root == null:
		return
	for child in _weather_ground_root.get_children():
		child.queue_free()
	if weather_id == "clear" or weather_id == "wind":
		return
	var bounds := _active_camera_rect()
	var intensity := WeatherSystem.get_weather_intensity(weather_id)
	var area_scale := sqrt(maxf(bounds.size.x * bounds.size.y, 1.0) / (1280.0 * 720.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s_%s" % [weather_id, str(_current_stage_index), str(_current_room.get("layout_id", ""))])
	match weather_id:
		"snow":
			_spawn_ground_patches(bounds, rng, int(18 * area_scale * intensity), Color(0.86, 0.95, 1.0, 0.22), Vector2(54, 24))
		"rain", "thunder":
			_spawn_ground_patches(bounds, rng, int(14 * area_scale * intensity), Color(0.34, 0.58, 0.86, 0.18), Vector2(48, 18))
		"sand":
			_spawn_ground_patches(bounds, rng, int(20 * area_scale * intensity), Color(0.84, 0.67, 0.36, 0.16), Vector2(58, 16))
		"fog":
			_spawn_ground_patches(bounds, rng, int(10 * area_scale), Color(0.78, 0.84, 0.78, 0.10), Vector2(72, 28))
		"fire":
			_spawn_ground_patches(bounds, rng, int(12 * area_scale), Color(0.78, 0.30, 0.12, 0.11), Vector2(42, 14))


func _spawn_ground_patches(bounds: Rect2, rng: RandomNumberGenerator, count: int, color: Color, base_size: Vector2) -> void:
	for _i in range(maxi(count, 0)):
		var patch := Polygon2D.new()
		var center := Vector2(
			rng.randf_range(bounds.position.x + 30.0, bounds.end.x - 30.0),
			rng.randf_range(bounds.position.y + 36.0, bounds.end.y - 30.0)
		)
		var size := Vector2(base_size.x * rng.randf_range(0.72, 1.45), base_size.y * rng.randf_range(0.62, 1.28))
		var points := PackedVector2Array()
		var steps := 10
		for j in range(steps):
			var angle := TAU * float(j) / float(steps)
			var wobble := rng.randf_range(0.68, 1.08)
			points.append(Vector2(cos(angle) * size.x, sin(angle) * size.y) * 0.5 * wobble)
		patch.position = center
		patch.rotation = rng.randf_range(-0.35, 0.35)
		patch.polygon = points
		patch.color = color
		_weather_ground_root.add_child(patch)


func _load_cached_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


func _validate_theme_runtime_assets(theme: Dictionary) -> void:
	var theme_id := str(theme.get("theme_id", "stage_%d" % _current_stage_index))
	if _runtime_asset_warnings.has(theme_id):
		return
	_runtime_asset_warnings[theme_id] = true
	for key in ["room_background", "tileset"]:
		var path := str(theme.get(key, ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			push_warning("CombatFloor: manifest %s for %s is missing or not imported: %s" % [key, theme_id, path])
	var terrain_props := str(theme.get("terrain_props", ""))
	if not terrain_props.is_empty() and not ResourceLoader.exists(terrain_props):
		push_warning("CombatFloor: manifest terrain_props for %s is missing or not imported: %s" % [theme_id, terrain_props])


func _decoration_cell_lookup(theme: Dictionary) -> Dictionary:
	var lookup := {}
	for raw in theme.get("decoration_cells", []):
		if raw is Array and raw.size() >= 2:
			lookup[Vector2i(int(raw[0]), int(raw[1]))] = true
	return lookup


func _uses_alt_floor(theme: Dictionary, x: int, y: int) -> bool:
	var pattern := str(theme.get("floor_pattern", ""))
	match pattern:
		"meadow":
			return (x * 3 + y * 5) % 9 == 0
		"cavern":
			return (x + y * 2) % 6 == 0 or (x - y) % 11 == 0
		"demon":
			return abs(x) == abs(y) or (x + y) % 7 == 0
		"ruins":
			return x % 6 == 0 or y % 5 == 0
		"thunder":
			return (x * x + y * 3) % 10 == 0
		_:
			return (x + y) % 5 == 0


func _schedule_weather_strikes(weather_id: String) -> void:
	if _thunder_strike_parent == null:
		return
	_active_weather_id = weather_id
	set_process(weather_id == "thunder")
	for child in _thunder_strike_parent.get_children():
		child.queue_free()
	if weather_id != "thunder":
		_thunder_strike_timer = 0.0
		return
	_thunder_strike_batch = 0
	_spawn_thunder_strike_batch()
	_thunder_strike_timer = THUNDER_STRIKE_BATCH_INTERVAL / maxf(WeatherSystem.get_weather_intensity(weather_id), 0.1)


func _spawn_thunder_strike_batch() -> void:
	if _thunder_strike_parent == null:
		return
	var intensity := WeatherSystem.get_weather_intensity("thunder")
	var count := clampi(int(round(1.0 + intensity * 2.2)), 2, 4)
	var bounds := _active_camera_rect()
	var rng := RunRng.make("weather_thunder_%d_%s_%d" % [_current_stage_index, str(_current_room.get("layout_id", "open")), _thunder_strike_batch])
	_thunder_strike_batch += 1
	for i in range(count):
		var strike := ThunderStrikeMarker.new()
		strike.name = "ThunderStrikeMarker_%d_%d" % [_thunder_strike_batch, i]
		strike.setup(
			Vector2(
				rng.randf_range(bounds.position.x + 70.0, bounds.end.x - 70.0),
				rng.randf_range(bounds.position.y + 70.0, bounds.end.y - 70.0)
			),
			rng.randf_range(0.55, 1.05),
			rng.randf_range(0.45, 0.65),
			rng.randf_range(60.0, 86.0),
			THUNDER_STRIKE_BASE_DAMAGE * intensity * rng.randf_range(0.75, 1.0)
		)
		_thunder_strike_parent.add_child(strike)


class ThunderStrikeMarker:
	extends Node2D

	var _radius := 72.0
	var _warning_time := 0.7
	var _impact_time := 0.55
	var _damage := 64.0
	var _life := 0.0
	var _done := false
	var _color := Color(0.78, 0.88, 1.0, 0.9)

	func setup(pos: Vector2, warning_time: float, impact_time: float, radius: float, damage: float) -> void:
		global_position = pos
		_warning_time = warning_time
		_impact_time = impact_time
		_radius = radius
		_damage = damage
		z_index = 90
		set_process(true)

	func _ready() -> void:
		queue_redraw()

	func _process(delta: float) -> void:
		_life += delta
		if not _done and _life >= _warning_time:
			_done = true
			_strike()
		if _life >= _warning_time + _impact_time:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _life < _warning_time:
			var t := clampf(_life / maxf(_warning_time, 0.01), 0.0, 1.0)
			var pulse := 0.4 + 0.6 * sin(t * PI)
			var warn_color := Color(0.95, 0.92, 0.38, 0.25 + pulse * 0.35)
			draw_circle(Vector2.ZERO, _radius, Color(0.95, 0.76, 0.16, 0.08 + pulse * 0.06))
			draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, warn_color, 4.0, true)
			draw_arc(Vector2.ZERO, _radius * 0.55, 0.0, TAU, 48, Color(1.0, 0.78, 0.18, 0.18 + pulse * 0.2), 2.0, true)
		else:
			var impact_t := clampf((_life - _warning_time) / maxf(_impact_time, 0.01), 0.0, 1.0)
			var alpha := 0.5 * (1.0 - impact_t)
			var bolt_alpha := 0.86 * (1.0 - impact_t)
			var top := Vector2(-18.0, -420.0)
			var bolt := PackedVector2Array([
				top,
				Vector2(10.0, -300.0),
				Vector2(-14.0, -184.0),
				Vector2(18.0, -78.0),
				Vector2.ZERO,
			])
			draw_polyline(bolt, Color(0.78, 0.92, 1.0, bolt_alpha), 7.0, true)
			draw_polyline(bolt, Color(1.0, 0.98, 0.68, bolt_alpha), 2.5, true)
			draw_circle(Vector2.ZERO, _radius * (1.0 + impact_t * 0.35), Color(1.0, 0.92, 0.62, alpha))
			draw_arc(Vector2.ZERO, _radius * (0.72 + impact_t * 0.45), 0.0, TAU, 64, Color(0.72, 0.88, 1.0, alpha), 3.0, true)

	func _strike() -> void:
		if get_tree() == null:
			return
		var player := get_tree().get_first_node_in_group("player")
		if _can_damage_target(player):
			player.receive_terrain_damage(_damage, "thunder")
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if _can_damage_target(enemy):
				enemy.receive_terrain_damage(_damage, "thunder")

	func _can_damage_target(target: Variant) -> bool:
		return (
			target != null
			and is_instance_valid(target)
			and target.has_method("receive_terrain_damage")
			and target is Node2D
			and (target as Node2D).global_position.distance_to(global_position) <= _radius
		)
