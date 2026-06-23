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
	return build_with_profile(layout_id, rng, {})


static func build_with_profile(layout_id: String, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	var layout_row: Dictionary = {}
	for row in _layouts:
		if str(row.get("layout_id", "")) == layout_id:
			layout_row = row
			break
	if layout_row.is_empty():
		layout_row = _layouts[0] if not _layouts.is_empty() else {}
	var pattern := str(layout_row.get("pattern", "scatter"))
	if not profile.is_empty():
		pattern = str(profile.get("preferred_pattern", pattern))
	var count := int(layout_row.get("obstacle_count", 4)) + int(profile.get("obstacle_count_bias", 0))
	var spacing := float(layout_row.get("min_spacing", 100.0)) + float(profile.get("min_spacing_bias", 0.0))
	var obstacles: Array = []
	var template_ids := _template_ids_for_profile(profile)
	if template_ids.is_empty():
		return {"layout_id": layout_id, "obstacles": obstacles, "terrain_slots": []}
	match pattern:
		"edge_pockets":
			obstacles = _build_edge_pocket_layout(count, spacing, template_ids, rng, profile)
		"lane_gates":
			obstacles = _build_lane_gate_layout(count, spacing, template_ids, rng, profile)
		"corner_shrines":
			obstacles = _build_corner_shrine_layout(count, spacing, template_ids, rng, profile)
		"broken_columns":
			obstacles = _build_broken_column_layout(count, spacing, template_ids, rng, profile)
		"boss_clear":
			obstacles = _build_boss_clear_layout(count, spacing, template_ids, rng, profile)
		"cross":
			obstacles = _build_cross_layout(count, spacing, template_ids, rng, profile)
		"pillars":
			obstacles = _build_pillar_layout(count, spacing, template_ids, rng, profile)
		_:
			obstacles = _build_scatter_layout(count, spacing, template_ids, rng, profile)
	var terrain_slots := _build_terrain_slots(mini(maxi(count, 2), 3), obstacles, rng, profile)
	var terrain_features := _build_terrain_features(maxi(count + 2, 6), obstacles, terrain_slots, rng, profile)
	return {
		"layout_id": layout_id,
		"profile_id": str(profile.get("profile_id", "default")),
		"obstacles": obstacles,
		"terrain_slots": terrain_slots,
		"terrain_features": terrain_features,
	}


static func _arena_half() -> Vector2:
	return Vector2(
		GameConstants.ARENA_HALF_WIDTH - 52.0,
		GameConstants.ARENA_HALF_HEIGHT - 52.0,
	)


static func _arena_half_for_profile(profile: Dictionary = {}, margin: float = 52.0) -> Vector2:
	var bounds: Dictionary = profile.get("arena_bounds", {})
	var width := float(bounds.get("width", GameConstants.ARENA_HALF_WIDTH * 2.0))
	var height := float(bounds.get("height", GameConstants.ARENA_HALF_HEIGHT * 2.0))
	return Vector2(maxf(width * 0.5 - margin, 120.0), maxf(height * 0.5 - margin, 90.0))


static func _scale_for_profile(profile: Dictionary = {}) -> Vector2:
	var raw: Array = profile.get("room_scale", [1.0, 1.0])
	if raw.size() >= 2:
		return Vector2(maxf(float(raw[0]), 0.5), maxf(float(raw[1]), 0.5))
	return Vector2.ONE


static func _template_ids_for_profile(profile: Dictionary) -> Array:
	var ids: Array = []
	for raw in profile.get("template_bias", []):
		var template_id := str(raw)
		if _obstacles.has(template_id):
			ids.append(template_id)
	if ids.is_empty():
		ids = _obstacles.keys()
	return ids


static func _build_scatter_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Array:
	var obstacles: Array = []
	var half := _arena_half_for_profile(profile)
	var attempts := 0
	while obstacles.size() < count and attempts < count * 24:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(-half.x, half.x),
			rng.randf_range(-half.y, half.y),
		)
		var template_id := str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
		var size := _template_size(template_id)
		if not _is_valid_obstacle_pos(pos, obstacles, spacing, size, profile):
			continue
		obstacles.append(_make_obstacle(template_id, pos, profile))
	return obstacles


static func _build_pillar_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Array:
	var obstacles: Array = []
	var scale := _scale_for_profile(profile)
	var ring := 190.0 * minf(scale.x, scale.y)
	for i in count:
		var angle := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.12, 0.12)
		var pos := Vector2.from_angle(angle) * ring + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		var template_id: String = "pillar"
		if not ("pillar" in template_ids):
			template_id = str(template_ids[0])
		if not _is_valid_obstacle_pos(pos, obstacles, spacing * 0.85, _template_size(template_id), profile):
			continue
		obstacles.append(_make_obstacle(template_id, pos, profile))
	return obstacles


static func _build_cross_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Array:
	var obstacles: Array = []
	var scale := _scale_for_profile(profile)
	var anchors: Array = _scaled_points([
		Vector2(-150, 0), Vector2(150, 0), Vector2(0, -120), Vector2(0, 120),
		Vector2(-100, -80), Vector2(100, 80),
	], scale)
	for i in mini(count, anchors.size()):
		var pos: Vector2 = anchors[i] + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		var template_id: String = str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
		if not _is_valid_obstacle_pos(pos, obstacles, spacing * 0.8, _template_size(template_id), profile):
			continue
		obstacles.append(_make_obstacle(template_id, pos, profile))
	return obstacles


static func _build_edge_pocket_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary) -> Array:
	var anchors := _scaled_points([
		Vector2(-360, -168), Vector2(360, -168), Vector2(-410, 96), Vector2(410, 96),
		Vector2(-210, 238), Vector2(210, 238),
	], _scale_for_profile(profile))
	return _build_anchor_layout(anchors, count, spacing, template_ids, rng, profile)


static func _build_lane_gate_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary) -> Array:
	var anchors := _scaled_points([
		Vector2(-270, -96), Vector2(270, -96), Vector2(-270, 86), Vector2(270, 86),
		Vector2(-505, -12), Vector2(505, -12),
	], _scale_for_profile(profile))
	return _build_anchor_layout(anchors, count, spacing, template_ids, rng, profile)


static func _build_corner_shrine_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary) -> Array:
	var anchors := _scaled_points([
		Vector2(-420, -216), Vector2(420, -216), Vector2(-420, 214), Vector2(420, 214),
		Vector2(-130, -230), Vector2(130, 230),
	], _scale_for_profile(profile))
	return _build_anchor_layout(anchors, count, spacing, template_ids, rng, profile)


static func _build_broken_column_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary) -> Array:
	var anchors := _scaled_points([
		Vector2(-330, -185), Vector2(-155, -122), Vector2(190, -175), Vector2(365, -84),
		Vector2(-360, 156), Vector2(115, 194), Vector2(330, 142),
	], _scale_for_profile(profile))
	return _build_anchor_layout(anchors, count, spacing, template_ids, rng, profile)


static func _build_boss_clear_layout(count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary) -> Array:
	var anchors := _scaled_points([
		Vector2(-475, -232), Vector2(475, -232), Vector2(-495, 222), Vector2(495, 222),
		Vector2(-285, 270), Vector2(285, 270),
	], _scale_for_profile(profile))
	return _build_anchor_layout(anchors, maxi(count - 1, 4), spacing + 18.0, template_ids, rng, profile)


static func _scaled_points(points: Array, scale: Vector2) -> Array:
	var result: Array = []
	for point in points:
		var p: Vector2 = point
		result.append(Vector2(p.x * scale.x, p.y * scale.y))
	return result


static func _build_anchor_layout(anchors: Array, count: int, spacing: float, template_ids: Array, rng: RandomNumberGenerator, profile: Dictionary) -> Array:
	var obstacles: Array = []
	for i in mini(count, anchors.size()):
		var pos: Vector2 = anchors[i] + Vector2(rng.randf_range(-18, 18), rng.randf_range(-14, 14))
		var template_id := str(template_ids[rng.randi_range(0, template_ids.size() - 1)])
		var size := _template_size(template_id)
		if not _is_valid_obstacle_pos(pos, obstacles, spacing * 0.72, size, profile):
			continue
		obstacles.append(_make_obstacle(template_id, pos, profile))
	return obstacles


static func _template_size(template_id: String) -> Vector2:
	var row: Dictionary = _obstacles.get(template_id, {})
	return Vector2(float(row.get("width", 48)), float(row.get("height", 48)))


static func _make_obstacle(template_id: String, position: Vector2, profile: Dictionary = {}) -> Dictionary:
	var row: Dictionary = _obstacles.get(template_id, {})
	var size := _template_size(template_id)
	var padding := float(profile.get("collision_padding", 8.0))
	return {
		"template_id": template_id,
		"position": position,
		"width": size.x,
		"height": size.y,
		"collision_width": size.x + padding,
		"collision_height": size.y + padding,
		"shape": "circle" if template_id == "pillar" else "rect",
		"color": str(row.get("color", "#5A5A6E")),
		"label": str(row.get("label", "")),
	}


static func _is_valid_obstacle_pos(pos: Vector2, existing: Array, spacing: float, size: Vector2 = Vector2(48, 48), profile: Dictionary = {}) -> bool:
	var half := _arena_half_for_profile(profile)
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
	for zone in profile.get("safe_zones", []):
		if _point_in_zone(pos, zone, size.length() * 0.35):
			return false
	for obs in existing:
		var other: Vector2 = obs.get("position", Vector2.ZERO)
		var other_size := Vector2(float(obs.get("collision_width", obs.get("width", 48))), float(obs.get("collision_height", obs.get("height", 48))))
		if pos.distance_to(other) < spacing + (size.length() + other_size.length()) * 0.12:
			return false
	return true


static func _point_in_zone(pos: Vector2, zone: Dictionary, padding: float = 0.0) -> bool:
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


static func _build_terrain_slots(count: int, obstacles: Array, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Array:
	var slots: Array = []
	var half := _arena_half_for_profile(profile, 52.0)
	var attempts := 0
	while slots.size() < count and attempts < count * 24:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(-half.x + 40, half.x - 40),
			rng.randf_range(-half.y + 40, half.y - 40),
		)
		if not _is_valid_terrain_slot(pos, obstacles, slots, profile):
			continue
		slots.append({
			"position": pos,
			"radius": rng.randf_range(28, 42),
		})
	return slots


static func _build_terrain_features(count: int, obstacles: Array, terrain_slots: Array, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Array:
	var features: Array = []
	var half := _arena_half_for_profile(profile, 72.0)
	var room_scale := _scale_for_profile(profile)
	var size_scale := clampf((room_scale.x + room_scale.y) * 0.5, 0.85, 1.55)
	var weighted_types := _terrain_feature_weights_for_profile(profile)
	var count_bias := int(profile.get("terrain_feature_count_bias", 0))
	var target_count := clampi(int(round(float(count + count_bias) * size_scale)), 5, 11)
	var attempts := 0
	while features.size() < target_count and attempts < target_count * 36:
		attempts += 1
		var terrain_type := _pick_weighted_type(weighted_types, rng)
		var radius := _terrain_feature_radius(terrain_type, rng, size_scale)
		var pos := Vector2(
			rng.randf_range(-half.x + radius, half.x - radius),
			rng.randf_range(-half.y + radius, half.y - radius),
		)
		if not _is_valid_terrain_feature(pos, radius, terrain_type, obstacles, terrain_slots, features, profile):
			continue
		features.append({
			"type": terrain_type,
			"position": pos,
			"radius": radius,
			"width": radius * 1.65,
			"height": radius * 1.35,
		})
	return features


static func _terrain_feature_weights_for_profile(profile: Dictionary = {}) -> Array:
	var raw_weights: Dictionary = profile.get("terrain_feature_weights", {})
	var weighted_types: Array = []
	for key in raw_weights.keys():
		var terrain_type := str(key)
		var weight := int(raw_weights.get(key, 0))
		if terrain_type.is_empty() or weight <= 0:
			continue
		weighted_types.append({"type": terrain_type, "weight": weight})
	if not weighted_types.is_empty():
		return weighted_types
	return [
		{"type": "rock", "weight": 4},
		{"type": "water", "weight": 3},
		{"type": "swamp", "weight": 2},
		{"type": "fire", "weight": 2},
	]


static func _pick_weighted_type(weighted_types: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for entry in weighted_types:
		total += int(entry.get("weight", 1))
	var roll := rng.randi_range(1, maxi(total, 1))
	var cursor := 0
	for entry in weighted_types:
		cursor += int(entry.get("weight", 1))
		if roll <= cursor:
			return str(entry.get("type", "water"))
	return "water"


static func _terrain_feature_radius(terrain_type: String, rng: RandomNumberGenerator, size_scale: float) -> float:
	match terrain_type:
		"rock":
			return rng.randf_range(26.0, 40.0) * size_scale
		"swamp":
			return rng.randf_range(34.0, 54.0) * size_scale
		"fire":
			return rng.randf_range(24.0, 36.0) * size_scale
		_:
			return rng.randf_range(38.0, 62.0) * size_scale


static func _is_valid_terrain_feature(pos: Vector2, radius: float, terrain_type: String, obstacles: Array, terrain_slots: Array, existing: Array, profile: Dictionary = {}) -> bool:
	var half := _arena_half_for_profile(profile)
	var edge_margin := radius + 36.0
	if absf(pos.x) > half.x - edge_margin or absf(pos.y) > half.y - edge_margin:
		return false
	var safe_radius := CENTER_SAFE_RADIUS + (24.0 if terrain_type == "rock" else 0.0)
	if pos.length() < safe_radius:
		return false
	if pos.distance_to(GameConstants.ENEMY_SPAWN_CENTER) < 96.0:
		return false
	if pos.distance_to(PLAYER_SAFE) < 112.0:
		return false
	if pos.distance_to(GameConstants.ENEMY_BOSS_SPAWN) < 96.0:
		return false
	for zone in profile.get("safe_zones", []):
		if _point_in_zone(pos, zone, radius):
			return false
	for obs in obstacles:
		var other: Vector2 = obs.get("position", Vector2.ZERO)
		var size := Vector2(float(obs.get("collision_width", obs.get("width", 48))), float(obs.get("collision_height", obs.get("height", 48))))
		if pos.distance_to(other) < radius + size.length() * 0.38 + 26.0:
			return false
	for slot in terrain_slots:
		var slot_pos: Vector2 = slot.get("position", Vector2.ZERO)
		var slot_r := float(slot.get("radius", 36.0))
		if pos.distance_to(slot_pos) < radius + slot_r + 28.0:
			return false
	for feature in existing:
		var other_pos: Vector2 = feature.get("position", Vector2.ZERO)
		var other_r := float(feature.get("radius", 36.0))
		if pos.distance_to(other_pos) < radius + other_r + 34.0:
			return false
	return true


static func _is_valid_terrain_slot(pos: Vector2, obstacles: Array, existing: Array, profile: Dictionary = {}) -> bool:
	var half := _arena_half_for_profile(profile)
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
