extends Node

const GameConstants = preload("res://core/constants/game_constants.gd")

const TERRAIN_LABELS := {
	"wet": "积水",
	"dry": "干燥",
	"ice": "冰面",
}

var _zones: Array = []
var _terrain_root: Node2D = null
var _host: Node2D = null
var _current_terrain_type := "none"
var _synergy_element := ""
var _synergy_mult := 1.0


func clear() -> void:
	_zones.clear()
	_current_terrain_type = "none"
	_synergy_element = ""
	_synergy_mult = 1.0
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
	if _current_terrain_type == "none" or _current_terrain_type.is_empty():
		return
	_synergy_element = str(row.get("synergy_element", ""))
	_synergy_mult = float(row.get("synergy_mult", 1.0))
	var zone_color := Color(str(row.get("terrain_color", "#3388CC66")))
	var default_radius := 36.0
	_terrain_root = Node2D.new()
	_terrain_root.name = "TerrainRoot"
	_terrain_root.z_index = 0
	host.add_child(_terrain_root)
	var slots: Array = layout.get("terrain_slots", [])
	if slots.is_empty():
		var count := int(row.get("terrain_zone_count", 3))
		slots = _generate_fallback_slots(count, layout.get("obstacles", []), rng)
	for slot in slots:
		var pos: Vector2 = slot.get("position", Vector2.ZERO)
		var radius := float(slot.get("radius", default_radius))
		_add_zone(pos, radius, _current_terrain_type, zone_color)


func query_at(global_pos: Vector2) -> String:
	if _host == null or not is_instance_valid(_host):
		return "none"
	var local_pos := _host.to_local(global_pos)
	for zone in _zones:
		var center: Vector2 = zone.get("position", Vector2.ZERO)
		var radius := float(zone.get("radius", 36.0))
		if local_pos.distance_to(center) <= radius:
			return str(zone.get("terrain_type", "none"))
	return "none"


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


func _add_zone(local_pos: Vector2, radius: float, terrain_type: String, color: Color) -> void:
	_zones.append({
		"position": local_pos,
		"radius": radius,
		"terrain_type": terrain_type,
	})
	# 天气地形池可走入，供 query_at / 天象×地形加成；阻挡由 layout 乱石/石柱负责
	var area := Area2D.new()
	area.position = local_pos
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitorable = false
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	var visual := ColorRect.new()
	var size := Vector2(radius * 2.0, radius * 2.0)
	visual.size = size
	visual.position = -size * 0.5
	visual.color = color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(visual)
	var ring := ColorRect.new()
	ring.size = size + Vector2(6, 6)
	ring.position = -(size + Vector2(6, 6)) * 0.5
	ring.color = Color(color.r, color.g, color.b, minf(color.a + 0.12, 0.55))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(ring)
	area.move_child(ring, 0)
	_terrain_root.add_child(area)


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
		_: return element_key
