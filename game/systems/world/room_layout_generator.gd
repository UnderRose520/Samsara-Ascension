class_name RoomLayoutGenerator

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")

const CENTER_SAFE_RADIUS := 100.0
const PLAYER_SAFE := Vector2(0, 120)

static var _layouts: Array = []
static var _obstacles: Dictionary = {}
static var _loaded := false


static func pick_layout_id(room_type: String, stage_index: int, rng: RandomNumberGenerator) -> String:
	_ensure_loaded()
	var candidates: Array = []
	for row in _layouts:
		var types := str(row.get("room_types", "")).split("|")
		if room_type in types:
			candidates.append(str(row.get("layout_id", "")))
	if candidates.is_empty():
		return "open_scatter"
	if stage_index >= 3 and "cross_blocks" in candidates:
		return "cross_blocks" if rng.randf() < 0.35 else candidates[rng.randi_range(0, candidates.size() - 1)]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func build(layout_id: String, rng: RandomNumberGenerator) -> Dictionary:
	_ensure_loaded()
	var layout_row: Dictionary = {}
	for row in _layouts:
		if str(row.get("layout_id", "")) == layout_id:
			layout_row = row
			break
	if layout_row.is_empty():
		layout_row = _layouts[0] if not _layouts.is_empty() else {}
	var pattern := str(layout_row.get("pattern", "scatter"))
	var count := int(layout_row.get("obstacle_count", 4))
	var spacing := float(layout_row.get("min_spacing", 100.0))
	var obstacles: Array = []
	var template_ids := _obstacles.keys()
	if template_ids.is_empty():
		return {"layout_id": layout_id, "obstacles": obstacles, "terrain_slots": []}
	match pattern:
		"cross":
			obstacles = _build_cross_layout(count, spacing, template_ids, rng)
		"pillars":
			obstacles = _build_pillar_layout(count, spacing, template_ids, rng)
		_:
			obstacles = _build_scatter_layout(count, spacing, template_ids, rng)
	var terrain_slots := _build_terrain_slots(mini(maxi(count, 2), 3), obstacles, rng)
	return {
		"layout_id": layout_id,
		"obstacles": obstacles,
		"terrain_slots": terrain_slots,
	}


static func _arena_half() -> Vector2:
	return Vector2(
		GameConstants.ARENA_HALF_WIDTH - 52.0,
		GameConstants.ARENA_HALF_HEIGHT - 52.0,
	)


static func _build_scatter_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator) -> Array:
	var obstacles: Array = []
	var half := _arena_half()
	var attempts := 0
	while obstacles.size() < count and attempts < count * 24:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(-half.x, half.x),
			rng.randf_range(-half.y, half.y),
		)
		if not _is_valid_obstacle_pos(pos, obstacles, spacing):
			continue
		obstacles.append(_make_obstacle(str(template_ids[rng.randi_range(0, template_ids.size() - 1)]), pos))
	return obstacles


static func _build_pillar_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator) -> Array:
	var obstacles: Array = []
	var ring := 190.0
	for i in count:
		var angle := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.12, 0.12)
		var pos := Vector2.from_angle(angle) * ring + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		if not _is_valid_obstacle_pos(pos, obstacles, spacing * 0.85):
			continue
		var template_id: String = "pillar"
		if not ("pillar" in template_ids):
			template_id = str(template_ids[0])
		obstacles.append(_make_obstacle(template_id, pos))
	return obstacles


static func _build_cross_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator) -> Array:
	var obstacles: Array = []
	var anchors: Array = [
		Vector2(-150, 0), Vector2(150, 0), Vector2(0, -120), Vector2(0, 120),
		Vector2(-100, -80), Vector2(100, 80),
	]
	for i in mini(count, anchors.size()):
		var pos: Vector2 = anchors[i] + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		if not _is_valid_obstacle_pos(pos, obstacles, spacing * 0.8):
			continue
		var template_id: String = str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
		obstacles.append(_make_obstacle(template_id, pos))
	return obstacles


static func _make_obstacle(template_id: String, position: Vector2) -> Dictionary:
	var row: Dictionary = _obstacles.get(template_id, {})
	return {
		"template_id": template_id,
		"position": position,
		"width": float(row.get("width", 48)),
		"height": float(row.get("height", 48)),
		"color": str(row.get("color", "#5A5A6E")),
		"label": str(row.get("label", "")),
	}


static func _is_valid_obstacle_pos(pos: Vector2, existing: Array, spacing: float) -> bool:
	var half := _arena_half()
	if pos.distance_to(Vector2.ZERO) < CENTER_SAFE_RADIUS:
		return false
	if pos.distance_to(GameConstants.ENEMY_SPAWN_CENTER) < 68.0:
		return false
	if pos.distance_to(GameConstants.ENEMY_BOSS_SPAWN) < 68.0:
		return false
	if pos.distance_to(PLAYER_SAFE) < 80.0:
		return false
	var edge_margin := 20.0
	if absf(pos.x) > half.x - edge_margin or absf(pos.y) > half.y - edge_margin:
		return false
	for obs in existing:
		var other: Vector2 = obs.get("position", Vector2.ZERO)
		if pos.distance_to(other) < spacing:
			return false
	return true


static func _build_terrain_slots(count: int, obstacles: Array, rng: RandomNumberGenerator) -> Array:
	var slots: Array = []
	var half := _arena_half()
	var attempts := 0
	while slots.size() < count and attempts < count * 24:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(-half.x + 40, half.x - 40),
			rng.randf_range(-half.y + 40, half.y - 40),
		)
		if not _is_valid_terrain_slot(pos, obstacles, slots):
			continue
		slots.append({
			"position": pos,
			"radius": rng.randf_range(28, 42),
		})
	return slots


static func _is_valid_terrain_slot(pos: Vector2, obstacles: Array, existing: Array) -> bool:
	var half := _arena_half()
	var edge_margin := 44.0
	if absf(pos.x) > half.x - edge_margin or absf(pos.y) > half.y - edge_margin:
		return false
	if pos.length() < CENTER_SAFE_RADIUS:
		return false
	if pos.distance_to(GameConstants.ENEMY_SPAWN_CENTER) < 80.0:
		return false
	if pos.distance_to(PLAYER_SAFE) < 84.0:
		return false
	if pos.distance_to(GameConstants.ENEMY_BOSS_SPAWN) < 80.0:
		return false
	for obs in obstacles:
		var other: Vector2 = obs.get("position", Vector2.ZERO)
		var size := Vector2(float(obs.get("width", 48)), float(obs.get("height", 48)))
		if pos.distance_to(other) < size.length() * 0.55 + 36.0:
			return false
	for slot in existing:
		var slot_pos: Vector2 = slot.get("position", Vector2.ZERO)
		var slot_r := float(slot.get("radius", 36.0))
		if pos.distance_to(slot_pos) < slot_r + 48.0:
			return false
	return true


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/rooms/room_layouts.csv"):
		_layouts.append(row)
	for row in CsvLoader.load_rows("res://data/rooms/obstacle_templates.csv"):
		var id := str(row.get("id", ""))
		if id.is_empty():
			continue
		_obstacles[id] = row
	_loaded = true
