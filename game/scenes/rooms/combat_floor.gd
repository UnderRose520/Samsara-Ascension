extends Node2D
## Reusable combat arena floor — instance under RunController and call apply_theme(stage_index).

const METADATA_PATH := "res://assets/maps/tileset_metadata.json"
const DEFAULT_THEME_ID := "qi_refining_verdant"
const RoomLayoutGenerator = preload("res://systems/world/room_layout_generator.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")

@onready var _background: Sprite2D = $Background
@onready var _tile_map: TileMap = $TileMap
@onready var _floor_layer: TileMapLayer = $TileMap/FloorLayer

var _metadata: Dictionary = {}
var _obstacle_root: Node2D


func _ready() -> void:
	_load_metadata()
	_obstacle_root = Node2D.new()
	_obstacle_root.name = "ObstacleRoot"
	_obstacle_root.z_index = 1
	add_child(_obstacle_root)


func apply_theme(stage_index: int = 1) -> void:
	var theme := _theme_for_stage(stage_index)
	if theme.is_empty():
		push_warning("CombatFloor: no theme for stage_index=%d" % stage_index)
		return
	_swap_textures(theme)
	_fill_floor_tiles()


func clear_layout() -> void:
	_clear_obstacles()


func apply_layout(room: Dictionary, rng: RandomNumberGenerator, weather_id: String = "clear") -> Dictionary:
	_clear_obstacles()
	var layout_id := str(room.get("layout_id", "open_scatter"))
	var layout: Dictionary = RoomLayoutGenerator.build(layout_id, rng)
	room["layout"] = layout
	for obs in layout.get("obstacles", []):
		_spawn_obstacle(obs)
	TerrainSystem.setup_for_room(weather_id, layout, self, rng)
	return layout


func _spawn_obstacle(obs: Dictionary) -> void:
	var size := Vector2(float(obs.get("width", 48)), float(obs.get("height", 48)))
	var pos: Vector2 = obs.get("position", Vector2.ZERO)
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = GameConstants.COLLISION_LAYER_OBSTACLE
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size * 0.5
	visual.color = Color(str(obs.get("color", "#5A5A6E")))
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(visual)
	_obstacle_root.add_child(body)


func _clear_obstacles() -> void:
	if _obstacle_root == null:
		return
	for child in _obstacle_root.get_children():
		child.queue_free()


func _load_metadata() -> void:
	if not FileAccess.file_exists(METADATA_PATH):
		push_warning("CombatFloor: missing %s" % METADATA_PATH)
		return
	var file := FileAccess.open(METADATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_metadata = parsed


func _theme_for_stage(stage_index: int) -> Dictionary:
	for entry in _metadata.get("themes", []):
		if int(entry.get("stage_index", -1)) == stage_index:
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
		_background.texture = load(bg_path)
	var tile_tex: Texture2D = load(tile_path) if ResourceLoader.exists(tile_path) else null
	if tile_tex == null:
		return
	var tile_set := _tile_map.tile_set
	if tile_set == null or tile_set.get_source_count() == 0:
		return
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source:
		source.texture = tile_tex


func _fill_floor_tiles() -> void:
	_floor_layer.clear()
	# 与背景 room_background.png（1280×720 @ -640,-360）对齐
	var cols := 40
	var rows := 22
	var origin := Vector2i(-cols / 2, -rows / 2)
	for y in range(rows):
		for x in range(cols):
			var coords := origin + Vector2i(x, y)
			var atlas := Vector2i(1, 0) if (x + y) % 5 == 0 else Vector2i(0, 0)
			_floor_layer.set_cell(coords, 0, atlas)
