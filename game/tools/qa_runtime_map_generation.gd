extends Node

const StageGenerator = preload("res://systems/world/stage_generator.gd")
const RoomLayoutGenerator = preload("res://systems/world/room_layout_generator.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")

const SAMPLE_SEEDS := [
	104729,
	130363,
	196613,
	262147,
	524309,
	786433,
	999983,
	1234577,
]

const COMBAT_ROOM_TYPES := {"combat": true, "combat_hard": true, "boss": true}
const EXPECTED_STAGE_COUNT := 5
const MIN_TERRAIN_FEATURES := 5
const MAX_TERRAIN_FEATURES := 11
const MAX_OBSTACLE_AREA_RATIO := 0.12
const MAX_ROCK_AREA_RATIO := 0.09
const MAX_TOTAL_TERRAIN_AREA_RATIO := 0.30
const PLAYER_SAFE := Vector2(0, 120)
const REPORT_PATH := "res://tools/runtime_map_generation_qa_report.txt"

const WEATHER_TERRAIN_BOOSTS := {
	"rain": {"water": 2, "wet": 1, "swamp": 1},
	"thunder": {"thunder": 3, "water": 1, "rock": 1},
	"fire": {"fire": 3, "dry": 1},
	"wind": {"dry": 1, "rock": 1},
	"fog": {"swamp": 1, "wet": 1},
	"snow": {"ice": 3, "water": 1},
	"sand": {"dry": 2, "rock": 2},
}

const THEME_REQUIRED_TERRAIN := {
	"qi_refining_verdant": ["water", "swamp"],
	"foundation_cavern": ["water", "rock"],
	"golden_core_demon": ["fire"],
	"nascent_soul_ruins": ["rock"],
	"tribulation_thunder": ["thunder"],
}

var _failures: Array = []
var _rooms_checked := 0
var _stage_terrain_seen := {}
var _weather_terrain_seen := {}
var _weather_seen := {}
var _run_context: Node = null
var _report_lines: Array[String] = []


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := _run()
	get_tree().quit(code)


func _run() -> int:
	_report("Runtime map generation QA")
	_report("=========================")
	_run_context = get_node_or_null("/root/RunContext")
	if _run_context == null:
		_fail("RunContext autoload is not available")
		_write_report(1)
		return 1
	for seed in SAMPLE_SEEDS:
		_check_seed(int(seed))
	_check_aggregate_coverage()
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		_write_report(1)
		return 1
	_report("Checked seeds: %d" % SAMPLE_SEEDS.size())
	_report("Checked combat rooms: %d" % _rooms_checked)
	_report("Weather ids seen: %s" % str(_weather_seen.keys()))
	_report("Runtime map generation QA passed")
	_write_report(0)
	return 0


func _check_seed(seed: int) -> void:
	_run_context.set("seed_value", seed)
	_run_context.set("training_mode", false)
	var plan: Array = StageGenerator.generate(1, {})
	if plan.size() != EXPECTED_STAGE_COUNT:
		_fail("seed %d expected %d stages, found %d" % [seed, EXPECTED_STAGE_COUNT, plan.size()])
	for stage in plan:
		if not (stage is Dictionary):
			_fail("seed %d stage entry is not a Dictionary" % seed)
			continue
		_check_stage(seed, stage)


func _check_stage(seed: int, stage: Dictionary) -> void:
	var stage_index := int(stage.get("stage_index", 0))
	var theme_id := str(stage.get("theme_id", "stage_%d" % stage_index))
	var rooms: Array = stage.get("rooms", [])
	if rooms.is_empty():
		_fail("seed %d stage %d has no rooms" % [seed, stage_index])
	for room in rooms:
		if not (room is Dictionary):
			_fail("seed %d stage %d has non-Dictionary room" % [seed, stage_index])
			continue
		var room_type := str(room.get("type", ""))
		if not COMBAT_ROOM_TYPES.has(room_type):
			continue
		_check_combat_room(seed, stage_index, theme_id, room)


func _check_combat_room(seed: int, stage_index: int, theme_id: String, room: Dictionary) -> void:
	_rooms_checked += 1
	var room_type := str(room.get("type", "combat"))
	var room_index := int(room.get("room_index", 0))
	var label := "seed %d stage %d room %d %s" % [seed, stage_index, room_index, room_type]
	var layout_id := str(room.get("layout_id", ""))
	if layout_id.is_empty():
		_fail("%s missing layout_id" % label)
		return
	_check_room_surface(label, room)
	var profile := _layout_profile_for_room(room)
	var rng := RunRng.stage_room(stage_index, room_index, room_type)
	var layout: Dictionary = RoomLayoutGenerator.build_with_profile(layout_id, rng, profile)
	_check_layout(label, theme_id, room, profile, layout)


func _check_room_surface(label: String, room: Dictionary) -> void:
	for key in ["theme_id", "tileset", "room_background", "terrain_props"]:
		if str(room.get(key, "")).is_empty():
			_fail("%s missing runtime surface key: %s" % [label, key])
	for key in ["tileset", "room_background", "terrain_props"]:
		var path := str(room.get(key, ""))
		if not path.is_empty() and not ResourceLoader.exists(path):
			_fail("%s resource is not import-visible: %s=%s" % [label, key, path])
	var arena: Dictionary = room.get("arena", {})
	var bounds: Dictionary = arena.get("world_bounds", {})
	var cells: Array = arena.get("tilemap_cells", [])
	var tile_size := int(arena.get("tile_size", 0))
	if bounds.is_empty():
		_fail("%s missing arena.world_bounds" % label)
	elif float(bounds.get("width", 0.0)) <= 0.0 or float(bounds.get("height", 0.0)) <= 0.0:
		_fail("%s invalid arena.world_bounds: %s" % [label, str(bounds)])
	if cells.size() < 2 or tile_size <= 0:
		_fail("%s missing tilemap_cells/tile_size" % label)
	else:
		var expected_w := int(cells[0]) * tile_size
		var expected_h := int(cells[1]) * tile_size
		if absi(expected_w - int(bounds.get("width", expected_w))) > tile_size:
			_fail("%s tilemap width does not match bounds: %s * %d vs %s" % [label, str(cells[0]), tile_size, str(bounds.get("width"))])
		if absi(expected_h - int(bounds.get("height", expected_h))) > tile_size:
			_fail("%s tilemap height does not match bounds: %s * %d vs %s" % [label, str(cells[1]), tile_size, str(bounds.get("height"))])

	var base_weights: Dictionary = room.get("base_terrain_feature_weights", {})
	var adjusted_weights: Dictionary = room.get("terrain_feature_weights", {})
	var profile: Dictionary = room.get("layout_profile", {})
	var profile_weights: Dictionary = profile.get("terrain_feature_weights", {})
	if adjusted_weights.is_empty():
		_fail("%s missing terrain_feature_weights" % label)
	if not _dict_int_equal(adjusted_weights, profile_weights):
		_fail("%s profile terrain_feature_weights differ from room terrain_feature_weights" % label)
	if not base_weights.is_empty():
		var expected := StageGenerator.weather_adjusted_terrain_feature_weights(base_weights, str(room.get("weather_id", "clear")))
		if not _dict_int_equal(adjusted_weights, expected):
			_fail("%s weather-adjusted terrain weights mismatch; expected %s got %s" % [label, str(expected), str(adjusted_weights)])
		_check_weather_boost(label, str(room.get("weather_id", "clear")), base_weights, adjusted_weights)


func _check_weather_boost(label: String, weather_id: String, base_weights: Dictionary, adjusted_weights: Dictionary) -> void:
	_weather_seen[weather_id] = true
	var boosts: Dictionary = WEATHER_TERRAIN_BOOSTS.get(weather_id, {})
	for key in boosts.keys():
		var expected_min := int(base_weights.get(key, 0)) + int(boosts.get(key, 0))
		if int(adjusted_weights.get(key, 0)) < expected_min:
			_fail("%s weather %s did not boost terrain %s to at least %d" % [label, weather_id, str(key), expected_min])


func _check_layout(label: String, theme_id: String, room: Dictionary, profile: Dictionary, layout: Dictionary) -> void:
	var obstacles: Array = layout.get("obstacles", [])
	var slots: Array = layout.get("terrain_slots", [])
	var features: Array = layout.get("terrain_features", [])
	var arena: Dictionary = room.get("arena", {})
	var bounds: Dictionary = arena.get("world_bounds", {})
	var safe_zones: Array = profile.get("safe_zones", room.get("safe_zones", []))

	if obstacles.is_empty():
		_fail("%s generated zero obstacles" % label)
	if slots.is_empty():
		_fail("%s generated zero terrain_slots" % label)
	if features.size() < MIN_TERRAIN_FEATURES or features.size() > MAX_TERRAIN_FEATURES:
		_fail("%s terrain_features count %d outside %d..%d" % [label, features.size(), MIN_TERRAIN_FEATURES, MAX_TERRAIN_FEATURES])

	var world_area := maxf(float(bounds.get("width", 1280.0)) * float(bounds.get("height", 704.0)), 1.0)
	var obstacle_area := 0.0
	for i in obstacles.size():
		var obstacle: Dictionary = obstacles[i]
		_validate_obstacle("%s obstacle %d" % [label, i], obstacle, obstacles, i, bounds, safe_zones)
		obstacle_area += float(obstacle.get("collision_width", obstacle.get("width", 48.0))) * float(obstacle.get("collision_height", obstacle.get("height", 48.0)))
	if obstacle_area / world_area > MAX_OBSTACLE_AREA_RATIO:
		_fail("%s obstacle area ratio %.3f > %.3f" % [label, obstacle_area / world_area, MAX_OBSTACLE_AREA_RATIO])

	var terrain_area := 0.0
	var rock_area := 0.0
	for i in features.size():
		var feature: Dictionary = features[i]
		_validate_feature("%s terrain_feature %d" % [label, i], feature, features, i, obstacles, slots, bounds, safe_zones, room)
		var terrain_type := str(feature.get("type", ""))
		var radius := float(feature.get("radius", 0.0))
		var area := PI * radius * radius
		terrain_area += area
		if terrain_type == "rock":
			rock_area += area
		_mark_seen(_stage_terrain_seen, theme_id, terrain_type)
		_mark_seen(_weather_terrain_seen, str(room.get("weather_id", "clear")), terrain_type)
	if terrain_area / world_area > MAX_TOTAL_TERRAIN_AREA_RATIO:
		_fail("%s total terrain area ratio %.3f > %.3f" % [label, terrain_area / world_area, MAX_TOTAL_TERRAIN_AREA_RATIO])
	if rock_area / world_area > MAX_ROCK_AREA_RATIO:
		_fail("%s rock blocker area ratio %.3f > %.3f" % [label, rock_area / world_area, MAX_ROCK_AREA_RATIO])


func _layout_profile_for_room(room: Dictionary) -> Dictionary:
	var profile: Dictionary = room.get("layout_profile", {}).duplicate(true)
	if room.has("terrain_feature_weights"):
		profile["terrain_feature_weights"] = room.get("terrain_feature_weights", {})
	if room.has("terrain_feature_count_bias"):
		profile["terrain_feature_count_bias"] = int(room.get("terrain_feature_count_bias", 0))
	profile["weather_id"] = room.get("weather_id", "clear")
	profile["safe_zones"] = room.get("safe_zones", [])
	profile["no_spawn_zones"] = room.get("no_spawn_zones", [])
	var arena: Dictionary = room.get("arena", {})
	profile["arena_bounds"] = arena.get("world_bounds", {})
	return profile


func _validate_obstacle(label: String, obstacle: Dictionary, all_obstacles: Array, index: int, bounds: Dictionary, safe_zones: Array) -> void:
	var pos: Vector2 = obstacle.get("position", Vector2.ZERO)
	var size := Vector2(float(obstacle.get("collision_width", obstacle.get("width", 48.0))), float(obstacle.get("collision_height", obstacle.get("height", 48.0))))
	if not _inside_bounds(pos, bounds, size.length() * 0.5):
		_fail("%s outside arena bounds at %s" % [label, str(pos)])
	if pos.length() < 100.0:
		_fail("%s violates center safe radius at %s" % [label, str(pos)])
	if pos.distance_to(GameConstants.ENEMY_SPAWN_CENTER) < 68.0:
		_fail("%s too close to enemy spawn center" % label)
	if pos.distance_to(GameConstants.ENEMY_BOSS_SPAWN) < 68.0:
		_fail("%s too close to boss spawn" % label)
	if pos.distance_to(PLAYER_SAFE) < 80.0:
		_fail("%s too close to player safe point" % label)
	for zone in safe_zones:
		if _point_in_zone(pos, zone, size.length() * 0.35):
			_fail("%s overlaps safe zone %s" % [label, str(zone.get("id", "<unnamed>"))])
	for j in range(index + 1, all_obstacles.size()):
		var other: Dictionary = all_obstacles[j]
		var other_pos: Vector2 = other.get("position", Vector2.ZERO)
		var other_size := Vector2(float(other.get("collision_width", other.get("width", 48.0))), float(other.get("collision_height", other.get("height", 48.0))))
		if _rects_overlap(pos, size, other_pos, other_size):
			_fail("%s overlaps obstacle %d" % [label, j])


func _validate_feature(
	label: String,
	feature: Dictionary,
	all_features: Array,
	index: int,
	obstacles: Array,
	slots: Array,
	bounds: Dictionary,
	safe_zones: Array,
	room: Dictionary
) -> void:
	var terrain_type := str(feature.get("type", ""))
	var pos: Vector2 = feature.get("position", Vector2.ZERO)
	var radius := float(feature.get("radius", 0.0))
	if radius <= 0.0:
		_fail("%s has non-positive radius %.2f" % [label, radius])
	if not _inside_bounds(pos, bounds, radius + 36.0):
		_fail("%s outside arena bounds at %s radius %.1f" % [label, str(pos), radius])
	var safe_radius := 124.0 if terrain_type == "rock" else 100.0
	if pos.length() < safe_radius:
		_fail("%s violates center safe radius at %s" % [label, str(pos)])
	if pos.distance_to(GameConstants.ENEMY_SPAWN_CENTER) < 96.0:
		_fail("%s too close to enemy spawn center" % label)
	if pos.distance_to(GameConstants.ENEMY_BOSS_SPAWN) < 96.0:
		_fail("%s too close to boss spawn" % label)
	if pos.distance_to(PLAYER_SAFE) < 112.0:
		_fail("%s too close to player safe point" % label)
	for zone in safe_zones:
		if _point_in_zone(pos, zone, radius):
			_fail("%s overlaps safe zone %s" % [label, str(zone.get("id", "<unnamed>"))])
	var weights: Dictionary = room.get("terrain_feature_weights", {})
	if not weights.has(terrain_type):
		_fail("%s type %s not present in room terrain_feature_weights" % [label, terrain_type])
	for obstacle in obstacles:
		var obstacle_pos: Vector2 = obstacle.get("position", Vector2.ZERO)
		var obstacle_size := Vector2(float(obstacle.get("collision_width", obstacle.get("width", 48.0))), float(obstacle.get("collision_height", obstacle.get("height", 48.0))))
		if pos.distance_to(obstacle_pos) < radius + obstacle_size.length() * 0.30:
			_fail("%s too close to obstacle at %s" % [label, str(obstacle_pos)])
	for slot in slots:
		var slot_pos: Vector2 = slot.get("position", Vector2.ZERO)
		var slot_radius := float(slot.get("radius", 36.0))
		if pos.distance_to(slot_pos) < radius + slot_radius + 8.0:
			_fail("%s too close to terrain slot at %s" % [label, str(slot_pos)])
	for j in range(index + 1, all_features.size()):
		var other: Dictionary = all_features[j]
		var other_pos: Vector2 = other.get("position", Vector2.ZERO)
		var other_radius := float(other.get("radius", 36.0))
		if pos.distance_to(other_pos) < radius + other_radius + 8.0:
			_fail("%s overlaps terrain_feature %d" % [label, j])


func _check_aggregate_coverage() -> void:
	for theme_id in THEME_REQUIRED_TERRAIN.keys():
		var seen: Dictionary = _stage_terrain_seen.get(theme_id, {})
		for terrain_type in THEME_REQUIRED_TERRAIN.get(theme_id, []):
			if not seen.has(terrain_type):
				_fail("theme %s never generated required terrain type %s across sampled seeds" % [theme_id, str(terrain_type)])
	for weather_id in _weather_seen.keys():
		if weather_id == "clear":
			continue
		var boosts: Dictionary = WEATHER_TERRAIN_BOOSTS.get(weather_id, {})
		if boosts.is_empty():
			continue
		var seen_weather_terrain: Dictionary = _weather_terrain_seen.get(weather_id, {})
		var found_boosted := false
		for terrain_type in boosts.keys():
			if seen_weather_terrain.has(terrain_type):
				found_boosted = true
				break
		if not found_boosted:
			_fail("weather %s never generated any boosted terrain type across sampled seeds" % weather_id)


func _inside_bounds(pos: Vector2, bounds: Dictionary, margin: float) -> bool:
	var x := float(bounds.get("x", -640.0))
	var y := float(bounds.get("y", -352.0))
	var width := float(bounds.get("width", 1280.0))
	var height := float(bounds.get("height", 704.0))
	return pos.x >= x + margin and pos.x <= x + width - margin and pos.y >= y + margin and pos.y <= y + height - margin


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


func _rects_overlap(a_pos: Vector2, a_size: Vector2, b_pos: Vector2, b_size: Vector2) -> bool:
	var a_half := a_size * 0.5
	var b_half := b_size * 0.5
	return absf(a_pos.x - b_pos.x) < a_half.x + b_half.x and absf(a_pos.y - b_pos.y) < a_half.y + b_half.y


func _dict_int_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in left.keys():
		if not right.has(key):
			return false
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return false
	return true


func _mark_seen(bucket: Dictionary, outer_key: String, inner_key: String) -> void:
	if inner_key.is_empty():
		return
	if not bucket.has(outer_key):
		bucket[outer_key] = {}
	var nested: Dictionary = bucket[outer_key]
	nested[inner_key] = true
	bucket[outer_key] = nested


func _fail(message: String) -> void:
	_failures.append(message)


func _report(message: String) -> void:
	_report_lines.append(message)
	print(message)


func _write_report(exit_code: int) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write %s" % REPORT_PATH)
		return
	for line in _report_lines:
		file.store_line(line)
	file.store_line("Exit code: %d" % exit_code)
