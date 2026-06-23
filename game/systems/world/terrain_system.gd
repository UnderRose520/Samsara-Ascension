extends Node

const GameConstants = preload("res://core/constants/game_constants.gd")
const RunRng = preload("res://core/utils/run_rng.gd")

const TERRAIN_LABELS := {
	"wet": "积水",
	"dry": "干燥",
	"ice": "冰面",
	"water": "水池",
	"swamp": "沼泽",
	"fire": "火堆",
	"rock": "岩石",
	"thunder": "雷痕",
}

const TERRAIN_COLORS := {
	"water": Color(0.20, 0.52, 0.86, 0.46),
	"swamp": Color(0.20, 0.42, 0.18, 0.50),
	"fire": Color(1.0, 0.32, 0.10, 0.52),
	"rock": Color(0.42, 0.42, 0.48, 0.88),
	"ice": Color(0.60, 0.92, 1.0, 0.46),
	"wet": Color(0.20, 0.52, 0.86, 0.40),
	"dry": Color(0.78, 0.46, 0.22, 0.42),
	"thunder": Color(0.52, 0.36, 1.0, 0.52),
}

var _zones: Array = []
var _terrain_root: Node2D = null
var _host: Node2D = null
var _current_terrain_type := "none"
var _synergy_element := ""
var _synergy_mult := 1.0
var _swamp_cooldowns: Dictionary = {}
var _fire_tick_accum: Dictionary = {}


func clear() -> void:
	_zones.clear()
	_current_terrain_type = "none"
	_synergy_element = ""
	_synergy_mult = 1.0
	_swamp_cooldowns.clear()
	_fire_tick_accum.clear()
	if _terrain_root and is_instance_valid(_terrain_root):
		_terrain_root.queue_free()
	_terrain_root = null
	_host = null


func setup_for_room(weather_id: String, layout: Dictionary, host: Node2D, rng: RandomNumberGenerator) -> void:
	clear()
	if host == null:
		return
	_host = host
	var row: Dictionary = WeatherSystem.get_weather_row(weather_id)
	_current_terrain_type = str(row.get("terrain_type", "none"))
	_synergy_element = str(row.get("synergy_element", ""))
	_synergy_mult = float(row.get("synergy_mult", 1.0))
	_terrain_root = Node2D.new()
	_terrain_root.name = "TerrainRoot"
	_terrain_root.z_index = 0
	host.add_child(_terrain_root)

	if _current_terrain_type != "none" and not _current_terrain_type.is_empty():
		var zone_color := Color(str(row.get("terrain_color", "#3388CC66")))
		var slots: Array = layout.get("terrain_slots", [])
		if slots.is_empty():
			var count := int(row.get("terrain_zone_count", 3))
			slots = _generate_fallback_slots(count, layout.get("obstacles", []), rng)
		for slot in slots:
			var pos: Vector2 = slot.get("position", Vector2.ZERO)
			var radius := float(slot.get("radius", 36.0))
			_add_zone(pos, radius, _current_terrain_type, zone_color, false)

	var features: Array = layout.get("terrain_features", [])
	for feature in features:
		var terrain_type := str(feature.get("type", "water"))
		var pos: Vector2 = feature.get("position", Vector2.ZERO)
		var radius := float(feature.get("radius", 36.0))
		_add_zone(pos, radius, terrain_type, _terrain_color(terrain_type), terrain_type == "rock")

	if _terrain_root.get_child_count() == 0:
		clear()


func query_at(global_pos: Vector2) -> String:
	var all := query_all_at(global_pos)
	return str(all[0]) if not all.is_empty() else "none"


func query_all_at(global_pos: Vector2) -> Array:
	if _host == null or not is_instance_valid(_host):
		return []
	var local_pos := _host.to_local(global_pos)
	var result: Array = []
	for zone in _zones:
		var center: Vector2 = zone.get("position", Vector2.ZERO)
		var radius := float(zone.get("radius", 36.0))
		if local_pos.distance_to(center) <= radius:
			result.append(str(zone.get("terrain_type", "none")))
	return result


func apply_body_effects(body: Node, delta: float) -> void:
	if body == null or not is_instance_valid(body) or not body is Node2D:
		return
	_tick_body_cooldowns(body, delta)
	var zones := query_all_at((body as Node2D).global_position)
	if zones.is_empty():
		return
	if "water" in zones or "wet" in zones or "ice" in zones:
		_apply_water_slow(body)
	if "swamp" in zones:
		_apply_swamp_root(body)
	if "fire" in zones:
		_apply_fire_damage(body)


func apply_to_context(ctx: Dictionary, element_key: String, source_global_pos: Vector2) -> Dictionary:
	var terrain := query_at(source_global_pos)
	if terrain == "none" or terrain != _current_terrain_type:
		return ctx
	if _synergy_element.is_empty() or element_key != _synergy_element:
		return ctx
	if _synergy_mult <= 1.0:
		return ctx
	var sources: Array = ctx.get("bucket_b", []).duplicate()
	sources.append(_synergy_mult)
	ctx["bucket_b"] = sources
	ctx["terrain_synergy"] = true
	_maybe_show_first_interaction(terrain, element_key)
	return ctx


func get_active_terrain_label() -> String:
	return TERRAIN_LABELS.get(_current_terrain_type, "")


func _add_zone(local_pos: Vector2, radius: float, terrain_type: String, color: Color, blocks_movement := false) -> void:
	_zones.append({
		"position": local_pos,
		"radius": radius,
		"terrain_type": terrain_type,
		"blocks_movement": blocks_movement,
	})
	var node: Node2D = StaticBody2D.new() if blocks_movement else Area2D.new()
	node.position = local_pos
	node.z_index = 2 if blocks_movement else -3
	if blocks_movement:
		var body := node as StaticBody2D
		body.collision_layer = GameConstants.COLLISION_LAYER_OBSTACLE
		body.collision_mask = 0
	else:
		var area := node as Area2D
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitorable = false
		area.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	node.add_child(shape)
	var atlas_visual := _make_runtime_terrain_visual(terrain_type, color, radius, blocks_movement)
	if atlas_visual:
		node.add_child(atlas_visual)
	else:
		node.add_child(_make_fallback_zone_visual(terrain_type, color, radius, blocks_movement))
	_terrain_root.add_child(node)


func _make_runtime_terrain_visual(terrain_type: String, color: Color, radius: float, blocks_movement: bool) -> Node2D:
	if _host == null or not _host.has_method("make_terrain_zone_visual"):
		return null
	var rng := RunRng.make("terrain_visual_%s_%s_%d" % [terrain_type, str(_zones.size()), int(round(radius))])
	return _host.make_terrain_zone_visual(terrain_type, color, radius, rng, blocks_movement)


func _make_fallback_zone_visual(terrain_type: String, color: Color, radius: float, blocks_movement: bool) -> Node2D:
	var visual := Node2D.new()
	visual.name = "%sFallbackVisual" % terrain_type.capitalize()
	visual.z_index = 1 if blocks_movement else -1
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	var steps := 16
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		var wobble := 0.48 + 0.12 * sin(float(i) * 2.7)
		points.append(Vector2(cos(angle), sin(angle)) * radius * wobble)
	poly.polygon = points
	poly.color = Color(color.r, color.g, color.b, minf(color.a, 0.16))
	visual.add_child(poly)
	return visual


func _terrain_color(terrain_type: String) -> Color:
	return TERRAIN_COLORS.get(terrain_type, Color(0.35, 0.55, 0.55, 0.42))


func _body_key(body: Node) -> int:
	return body.get_instance_id()


func _tick_body_cooldowns(body: Node, delta: float) -> void:
	var key := _body_key(body)
	if _swamp_cooldowns.has(key):
		_swamp_cooldowns[key] = maxf(float(_swamp_cooldowns[key]) - delta, 0.0)
		if float(_swamp_cooldowns[key]) <= 0.0:
			_swamp_cooldowns.erase(key)
	if _fire_tick_accum.has(key):
		_fire_tick_accum[key] = maxf(float(_fire_tick_accum[key]) - delta, 0.0)


func _apply_water_slow(body: Node) -> void:
	if body.has_method("apply_terrain_water_slow"):
		body.apply_terrain_water_slow()
	elif body.has_method("apply_status"):
		body.apply_status("slow", GameConstants.TERRAIN_WATER_SLOW_REFRESH_SEC)


func _apply_swamp_root(body: Node) -> void:
	var key := _body_key(body)
	if float(_swamp_cooldowns.get(key, 0.0)) > 0.0:
		return
	_swamp_cooldowns[key] = GameConstants.TERRAIN_SWAMP_RETRIGGER_SEC
	if body.has_method("apply_status"):
		body.apply_status("paralyze", GameConstants.TERRAIN_SWAMP_ROOT_SEC)
	if body.is_in_group("player"):
		EventBus.pet_coord_feedback.emit("陷入沼泽，身法暂滞")


func _apply_fire_damage(body: Node) -> void:
	var key := _body_key(body)
	if float(_fire_tick_accum.get(key, 0.0)) > 0.0:
		return
	_fire_tick_accum[key] = GameConstants.TERRAIN_FIRE_TICK_SEC
	var damage := GameConstants.TERRAIN_FIRE_DAMAGE_PER_SEC * GameConstants.TERRAIN_FIRE_TICK_SEC
	if body.has_method("receive_terrain_damage"):
		body.receive_terrain_damage(damage, "fire")
	elif body.has_node("HealthComponent"):
		var health: Node = body.get_node("HealthComponent")
		health.take_damage(damage)
	if body.has_method("apply_status"):
		body.apply_status("burn", 1.0)


func _generate_fallback_slots(count: int, obstacles: Array, rng: RandomNumberGenerator) -> Array:
	var slots: Array = []
	var attempts := 0
	while slots.size() < count and attempts < count * 24:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(-480, 480),
			rng.randf_range(-280, 280),
		)
		if not _is_valid_terrain_pos(pos, obstacles, slots):
			continue
		slots.append({
			"position": pos,
			"radius": rng.randf_range(28, 40),
		})
	return slots


func _is_valid_terrain_pos(pos: Vector2, obstacles: Array, existing: Array) -> bool:
	if pos.length() < 120.0:
		return false
	if pos.distance_to(GameConstants.ENEMY_SPAWN_CENTER) < 90.0:
		return false
	if pos.distance_to(Vector2(0, 120)) < 96.0:
		return false
	for obs in obstacles:
		var obs_pos: Vector2 = obs.get("position", Vector2.ZERO)
		var obs_size := Vector2(float(obs.get("width", 48)), float(obs.get("height", 48)))
		if pos.distance_to(obs_pos) < obs_size.length() * 0.65 + 48.0:
			return false
	for slot in existing:
		var other: Vector2 = slot.get("position", Vector2.ZERO)
		var other_r := float(slot.get("radius", 36.0))
		if pos.distance_to(other) < other_r + 52.0:
			return false
	return true


func _maybe_show_first_interaction(terrain: String, element_key: String) -> void:
	var demo_key := "%s_%s" % [terrain, element_key]
	if SaveManager.has_seen_terrain_demo(demo_key):
		return
	SaveManager.mark_terrain_demo(demo_key)
	var terrain_label: String = TERRAIN_LABELS.get(terrain, terrain)
	var element_label := _element_label(element_key)
	EventBus.crit_moment_requested.emit("天象×地形 · %s+%s" % [terrain_label, element_label], 0.55)
	EventBus.pet_coord_feedback.emit("%s上%s劲力更盛" % [terrain_label, element_label])


func _element_label(element_key: String) -> String:
	match element_key:
		"fire": return "火"
		"water": return "水"
		"thunder": return "雷"
		"wood": return "木"
		"earth": return "土"
		"soul": return "魂"
		_: return element_key
