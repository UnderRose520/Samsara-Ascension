class_name StageGenerator

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const RoomLayoutGenerator = preload("res://systems/world/room_layout_generator.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")
const EventSelector = preload("res://systems/world/event_selector.gd")

const RUNTIME_MANIFEST_PATH := "res://assets/maps/runtime_scene_manifest.json"
const BASE_VIEWPORT_SIZE := Vector2(1280, 720)
const BASE_WORLD_SIZE := Vector2(1280, 704)
const MIN_VIEWPORT_SIZE := Vector2(960, 540)

static var _stage_rows: Array = []
static var _room_templates: Dictionary = {}
static var _runtime_stage_by_index: Dictionary = {}
static var _runtime_arena: Dictionary = {}
static var _loaded := false


static func generate(dao_heart: int = 1, events_seen: Dictionary = {}) -> Array:
	_ensure_loaded()
	var plan: Array = []
	var heart_demon_assigned := false
	for row in _stage_rows:
		var stage_index: int = int(row.get("stage_index", 1))
		var runtime_stage := _runtime_stage_for(stage_index)
		var combat_count: int = int(row.get("combat_rooms", 2))
		var weather_id := str(runtime_stage.get("weather_id", row.get("weather_id", "clear")))
		var rooms: Array = []
		var room_index := 0
		for i in combat_count:
			var hard := i == combat_count - 1 and stage_index >= 2
			var template_id := "combat_hard" if hard else "combat"
			rooms.append(_make_room(template_id, stage_index, row, room_index))
			room_index += 1
		var event_room := _make_room("event", stage_index, row, room_index)
		var event_rng := RunRng.stage_room(stage_index, room_index, "event")
		var event_id := EventSelector.pick_event_id(
			weather_id,
			dao_heart,
			event_rng,
			events_seen,
			heart_demon_assigned
		)
		if event_id == "M01":
			heart_demon_assigned = true
		event_room["event_id"] = event_id
		room_index += 1
		rooms.append(event_room)
		rooms.append(_make_room("boss", stage_index, row, room_index))
		var stage_def := {
			"stage_index": stage_index,
			"name": str(runtime_stage.get("stage_name", row.get("name", ""))),
			"weather_id": weather_id,
			"rooms": rooms,
		}
		stage_def.merge(_runtime_stage_surface(runtime_stage), true)
		plan.append(stage_def)
	return plan


static func _make_room(
	template_id: String,
	stage_index: int,
	stage_row: Dictionary,
	room_index: int,
) -> Dictionary:
	var rng := RunRng.stage_room(stage_index, room_index, template_id)
	var tpl: Dictionary = _room_templates.get(template_id, {})
	var runtime_stage := _runtime_stage_for(stage_index)
	var enemy_count: int = int(tpl.get("enemy_count", 3))
	if template_id == "combat":
		enemy_count = mini(4 + stage_index * 2, GameConstants.MAX_ROOM_ENEMIES)
	elif template_id == "combat_hard":
		enemy_count = maxi(
			int(tpl.get("enemy_count", 8)),
			mini(6 + stage_index * 2, GameConstants.MAX_ROOM_ENEMIES)
		)
	var room := {
		"type": template_id,
		"label": str(tpl.get("label", template_id)),
		"enemy_count": enemy_count,
		"hp_mult": float(tpl.get("hp_mult", 1.0)),
		"is_boss": template_id == "boss",
		"stage_index": stage_index,
		"room_index": room_index,
	}
	room.merge(_runtime_stage_surface(runtime_stage), true)
	if template_id == "boss":
		var boss_name := str(stage_row.get("boss_name", "关底守将"))
		room["boss_name"] = boss_name
		room["label"] = boss_name
	if template_id in ["combat", "combat_hard", "boss"]:
		room["layout_id"] = RoomLayoutGenerator.pick_layout_id(template_id, stage_index, rng)
		room.merge(_build_room_runtime_map(runtime_stage, stage_index, room_index, template_id, rng), true)
	return room


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/stages/stages.csv"):
		_stage_rows.append(row)
	for row in CsvLoader.load_rows("res://data/rooms/room_templates.csv"):
		_room_templates[str(row.get("room_type", ""))] = row
	_load_runtime_manifest()
	_loaded = true


static func _load_runtime_manifest() -> void:
	_runtime_stage_by_index.clear()
	if not FileAccess.file_exists(RUNTIME_MANIFEST_PATH):
		return
	var file := FileAccess.open(RUNTIME_MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("StageGenerator: failed to parse %s" % RUNTIME_MANIFEST_PATH)
		return
	_runtime_arena = parsed.get("arena", {})
	for stage in parsed.get("stages", []):
		if not (stage is Dictionary):
			continue
		var stage_index := int(stage.get("stage_index", 0))
		if stage_index <= 0:
			continue
		_runtime_stage_by_index[stage_index] = stage


static func _runtime_stage_for(stage_index: int) -> Dictionary:
	return _runtime_stage_by_index.get(stage_index, {})


static func _runtime_stage_surface(runtime_stage: Dictionary) -> Dictionary:
	if runtime_stage.is_empty():
		return {}
	var surface := {
		"theme_id": str(runtime_stage.get("theme_id", "")),
		"theme_label": str(runtime_stage.get("theme_label", "")),
		"tileset": str(runtime_stage.get("tileset", "")),
		"room_background": str(runtime_stage.get("room_background", "")),
	}
	if runtime_stage.has("terrain_props"):
		surface["terrain_props"] = str(runtime_stage.get("terrain_props", ""))
	if runtime_stage.has("qa_preview"):
		surface["qa_preview"] = str(runtime_stage.get("qa_preview", ""))
	if runtime_stage.has("prompt_files"):
		surface["prompt_files"] = runtime_stage.get("prompt_files", {})
	return surface


static func _build_room_runtime_map(
	runtime_stage: Dictionary,
	stage_index: int,
	room_index: int,
	template_id: String,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var scale := _room_scale(stage_index, template_id, rng)
	var viewport_size := _runtime_viewport_size()
	var base_expand := Vector2(
		maxf(viewport_size.x / BASE_VIEWPORT_SIZE.x, 1.0),
		maxf(viewport_size.y / BASE_VIEWPORT_SIZE.y, 1.0)
	)
	var world_size := _rounded_to_tile(Vector2(BASE_WORLD_SIZE.x * scale.x * base_expand.x, BASE_WORLD_SIZE.y * scale.y * base_expand.y))
	var camera_size := _rounded_to_tile(Vector2(viewport_size.x * scale.x, viewport_size.y * scale.y))
	var tile_size := int(_manifest_arena().get("tile_size", 32))
	var tilemap_cells := [
		int(round(world_size.x / float(tile_size))),
		int(round(world_size.y / float(tile_size))),
	]
	var arena := {
		"viewport_size": [int(viewport_size.x), int(viewport_size.y)],
		"tile_size": tile_size,
		"tilemap_cells": tilemap_cells,
		"world_bounds": _bounds(Vector2(-world_size.x * 0.5, -world_size.y * 0.5), world_size),
		"camera_bounds": _bounds(Vector2(-camera_size.x * 0.5, -camera_size.y * 0.5), camera_size),
		"player_spawn": [0, 120],
		"room_scale": [scale.x, scale.y],
	}
	var scale_vec := Vector2(scale.x, scale.y)
	var output := {
		"arena": arena,
		"spawn_zones": _scaled_zones(runtime_stage.get("spawn_zones", []), scale_vec),
		"no_spawn_zones": _scaled_zones(runtime_stage.get("no_spawn_zones", []), scale_vec),
		"safe_zones": _scaled_zones(runtime_stage.get("safe_zones", []), scale_vec),
		"map_variant": {
			"seed_context": "stage_room_%d_%d_%s" % [stage_index, room_index, template_id],
			"scale": [scale.x, scale.y],
			"size_px": [int(world_size.x), int(world_size.y)],
			"tilemap_cells": tilemap_cells,
		},
	}
	var profile: Dictionary = runtime_stage.get("layout_profile", {}).duplicate(true)
	profile["obstacle_count_bias"] = int(profile.get("obstacle_count_bias", 0)) + rng.randi_range(0, 2)
	profile["min_spacing_bias"] = float(profile.get("min_spacing_bias", 0.0)) + rng.randf_range(-6.0, 14.0)
	profile["room_scale"] = [scale.x, scale.y]
	output["layout_profile"] = profile
	return output


static func _room_scale(stage_index: int, template_id: String, rng: RandomNumberGenerator) -> Vector2:
	var base := 1.08 + float(stage_index - 1) * 0.08
	if template_id == "combat_hard":
		base += 0.08
	elif template_id == "boss":
		base += 0.14
	return Vector2(
		clampf(base + rng.randf_range(-0.04, 0.16), 1.04, 1.62),
		clampf(base + rng.randf_range(-0.05, 0.12), 1.02, 1.48)
	)


static func _rounded_to_tile(size: Vector2) -> Vector2:
	return Vector2(round(size.x / 32.0) * 32.0, round(size.y / 32.0) * 32.0)


static func _runtime_viewport_size() -> Vector2:
	var size := BASE_VIEWPORT_SIZE
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree := loop as SceneTree
		if tree.root:
			var visible_size := tree.root.get_visible_rect().size
			if visible_size.x > 0.0 and visible_size.y > 0.0:
				size = visible_size
	size.x = maxf(size.x, MIN_VIEWPORT_SIZE.x)
	size.y = maxf(size.y, MIN_VIEWPORT_SIZE.y)
	return size


static func _bounds(pos: Vector2, size: Vector2 = Vector2.ZERO) -> Dictionary:
	var resolved_size := size if size != Vector2.ZERO else BASE_WORLD_SIZE
	return {
		"x": int(round(pos.x)),
		"y": int(round(pos.y)),
		"width": int(round(resolved_size.x)),
		"height": int(round(resolved_size.y)),
	}


static func _scaled_zones(zones: Array, scale: Vector2) -> Array:
	var result: Array = []
	for raw_zone in zones:
		if not (raw_zone is Dictionary):
			continue
		var zone: Dictionary = raw_zone.duplicate(true)
		var center: Array = zone.get("center", [0, 0])
		var size: Array = zone.get("size", [0, 0])
		if center.size() >= 2:
			zone["center"] = [int(round(float(center[0]) * scale.x)), int(round(float(center[1]) * scale.y))]
		if size.size() >= 2:
			zone["size"] = [int(round(float(size[0]) * scale.x)), int(round(float(size[1]) * scale.y))]
		result.append(zone)
	return result


static func _manifest_arena() -> Dictionary:
	return _runtime_arena
