extends Node

const DISCOVER_CHANCE := 0.72
const NEARBY_RADIUS := 170.0
const CHAIN_EFFECT_RADIUS := 190.0
const CHAIN_TRIGGER_COOLDOWN_MS := 1500
const PET_RESONANCE_WINDOW_MS := 900

const CHAINS := {
	"C01": {
		"name": "雷引爆",
		"hint": "雷暴天引爆麻痹之躯，半场雷痕被点亮。",
		"color": Color(0.55, 0.78, 1.0),
	},
	"C02": {
		"name": "连环炮竹",
		"hint": "灼烧残焰牵动周身敌群，炸响成串。",
		"color": Color(1.0, 0.42, 0.18),
	},
	"C03": {
		"name": "护盾反噬",
		"hint": "重盾崩裂，反震之势扫向近敌。",
		"color": Color(0.8, 0.9, 1.0),
	},
	"C04": {
		"name": "风火龙卷",
		"hint": "风势卷起真火，火线被拉成长卷。",
		"color": Color(1.0, 0.62, 0.2),
	},
	"C05": {
		"name": "毒冰入骨",
		"hint": "寒意封住毒息，毒伤沿冰纹钻入骨缝。",
		"color": Color(0.42, 0.95, 0.85),
	},
	"C13": {
		"name": "水雷网格",
		"hint": "积水接住雷劲，电弧在敌群脚下织成网。",
		"color": Color(0.38, 0.72, 1.0),
	},
	"C15": {
		"name": "引火烧身",
		"hint": "灼烧之躯成了火引，靠近它的妖物一并被卷入火线。",
		"color": Color(1.0, 0.24, 0.12),
	},
	"C21": {
		"name": "灵宠共鸣",
		"hint": "你与灵宠同时压住同一破绽，灵息在敌身上回响。",
		"color": Color(1.0, 0.78, 0.36),
	},
}

var _recent_attempts := {}
var _recent_player_hits := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.pet_coord_hit.connect(_on_pet_coord_hit)
	EventBus.run_started.connect(func(_seed: int) -> void: _recent_attempts.clear())


func _on_damage_dealt(result: Dictionary) -> void:
	if not RunContext.run_active or bool(result.get("target_is_player", false)):
		return
	var target := result.get("target") as Node2D
	if target == null:
		return
	var element := str(result.get("element_key", ""))
	var source := str(result.get("source_tag", result.get("damage_source", "")))
	var weather := WeatherSystem.current_weather_id
	var terrain := TerrainSystem.query_at(target.global_position)
	var status: Dictionary = result.get("target_status", {})
	var killed := bool(result.get("target_killed", false))
	var nearby := _nearby_enemy_count(target.global_position)
	var target_weapon := str(result.get("target_weapon_id", ""))
	var now := Time.get_ticks_msec()
	var target_key := _node_key(target)

	if source != "pet_coord":
		_recent_player_hits[target_key] = now
	elif now - int(_recent_player_hits.get(target_key, -99999)) <= PET_RESONANCE_WINDOW_MS:
		_try_discover("C21", target.global_position, 0.18, {"element": element, "source": source, "terrain": terrain})

	if _is_thunder(element) and weather == "thunder" and (bool(status.get("paralyzed", false)) or target_weapon in ["blood_core", "furnace_core"]):
		_try_discover("C01", target.global_position, 0.22, {"element": element, "source": source, "terrain": terrain})
	if killed and _is_fire(element) and bool(status.get("burning", false)) and nearby >= 2:
		_try_discover("C02", target.global_position, 0.18, {"nearby": nearby, "source": source})
	if killed and target_weapon in ["xuanwu_shield", "shield", "heavy_shield"] and nearby >= 1:
		_try_discover("C03", target.global_position, 0.2, {"nearby": nearby, "target_weapon_id": target_weapon})
	if _is_fire(element) and (weather in ["wind", "storm"] or terrain == "wind_eye"):
		_try_discover("C04", target.global_position, 0.14, {"weather_id": weather, "source": source})
	if bool(status.get("poisoned", false)) and (_is_water_or_ice(element) or bool(status.get("slowed", false)) or bool(status.get("frozen", false)) or weather == "snow"):
		_try_discover("C05", target.global_position, 0.16, {"element": element, "weather_id": weather})
	if _is_thunder(element) and terrain in ["water", "wet", "ice"] and (nearby >= 2 or weather in ["thunder", "rain"]):
		_try_discover("C13", target.global_position, 0.18, {"terrain": terrain, "nearby": nearby})
	if _is_fire(element) and bool(status.get("burning", false)) and nearby >= 1:
		_try_discover("C15", target.global_position, 0.12, {"nearby": nearby, "source": source})


func _on_pet_coord_hit(enemy: Node) -> void:
	var pos := Vector2.ZERO
	if enemy is Node2D:
		pos = (enemy as Node2D).global_position
	var key := _node_key(enemy)
	if Time.get_ticks_msec() - int(_recent_player_hits.get(key, -99999)) <= PET_RESONANCE_WINDOW_MS:
		_try_discover("C21", pos, 0.18, {"source": "pet_coord"})
	else:
		_try_discover("C21", pos, 0.04, {"source": "pet_coord"})


func _try_discover(chain_id: String, world_position: Vector2, bonus: float = 0.0, details: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_recent_attempts.get(chain_id, 0)) < CHAIN_TRIGGER_COOLDOWN_MS:
		return
	_recent_attempts[chain_id] = now
	var row: Dictionary = CHAINS.get(chain_id, {})
	if SaveManager.has_discovered_hidden_chain(chain_id):
		_trigger_chain_effect(chain_id, world_position, row, details, false)
		return
	var chance := clampf(DISCOVER_CHANCE + bonus, 0.0, 0.92)
	if not CombatRngService.roll_chance("hidden_chain_%s" % chain_id, chance):
		return
	if not SaveManager.record_hidden_chain(chain_id):
		return
	_trigger_chain_effect(chain_id, world_position, row, details, true)


func _trigger_chain_effect(chain_id: String, world_position: Vector2, row: Dictionary, details: Dictionary, first_discovery: bool) -> void:
	var display_name := str(row.get("name", chain_id))
	if first_discovery:
		var payload := {
			"world_position": world_position,
			"hint": str(row.get("hint", "")),
			"weather_id": WeatherSystem.current_weather_id,
			"chain_id": chain_id,
			"details": details,
			"effect_anchor_handled": true,
		}
		EventBus.hidden_chain_discovered.emit(chain_id, display_name, payload)
		EventBus.learn_feedback.emit("✦ 连锁发现：%s" % display_name, "skill")
		EventBus.combo_discovered.emit(chain_id)
		RunContext.add_dao_momentum(6, "hidden_chain_%s" % chain_id)
		EventBus.pet_coord_feedback.emit("连锁发现：%s" % str(row.get("hint", display_name)))
	_apply_chain_effect(chain_id, world_position, row, details)
	if world_position != Vector2.ZERO:
		VfxManager.spawn_world(world_position, "gold", row.get("color", Color(1.0, 0.82, 0.28)))


func _apply_chain_effect(chain_id: String, world_position: Vector2, row: Dictionary, details: Dictionary) -> void:
	if world_position == Vector2.ZERO:
		return
	var color: Color = row.get("color", Color(1.0, 0.82, 0.28))
	var effect := _chain_effect_spec(chain_id, details)
	EventBus.feedback_anchor_requested.emit("chain_trigger", {
		"world_position": world_position,
		"color": color,
		"label": "连锁爆发 · %s" % str(row.get("name", chain_id)),
		"freeze": float(effect.get("freeze", 0.10)),
		"shake": float(effect.get("shake", 9.0)),
	})
	var radius := float(effect.get("radius", CHAIN_EFFECT_RADIUS))
	var damage := float(effect.get("damage", 18.0))
	var terrain_type := str(effect.get("element", "fire"))
	var status_name := str(effect.get("status", ""))
	var status_duration := float(effect.get("status_duration", 0.0))
	var hit_count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var body := enemy as Node2D
		if body == null or not is_instance_valid(body):
			continue
		if body.global_position.distance_to(world_position) > radius:
			continue
		if enemy.has_method("receive_terrain_damage"):
			enemy.receive_terrain_damage(damage, terrain_type)
			hit_count += 1
		if not status_name.is_empty() and enemy.has_method("apply_status"):
			enemy.apply_status(status_name, status_duration)
		if hit_count <= 10:
			VfxManager.spawn_world(body.global_position, str(effect.get("preset", "combo")), color)
	if hit_count >= 4:
		EventBus.pet_coord_feedback.emit("%s连锁扫过 %d 个目标" % [str(row.get("name", chain_id)), hit_count])
		RunContext.add_dao_momentum(minf(18.0, float(hit_count) * 2.0), "chain_sweep_%s" % chain_id)


func _chain_effect_spec(chain_id: String, details: Dictionary) -> Dictionary:
	match chain_id:
		"C01", "C13":
			return {"radius": 230.0, "damage": 30.0, "element": "thunder", "status": "paralyze", "status_duration": 0.8, "preset": "dao", "freeze": 0.14, "shake": 12.0}
		"C02", "C15":
			return {"radius": 210.0, "damage": 34.0, "element": "fire", "status": "burn", "status_duration": 3.0, "preset": "combo", "freeze": 0.12, "shake": 11.0}
		"C03":
			return {"radius": 185.0, "damage": 24.0, "element": "earth", "status": "slow", "status_duration": 1.2, "preset": "crit", "freeze": 0.10, "shake": 10.0}
		"C04":
			return {"radius": 260.0, "damage": 26.0, "element": "fire", "status": "burn", "status_duration": 2.2, "preset": "combo", "freeze": 0.10, "shake": 9.0}
		"C05":
			return {"radius": 205.0, "damage": 24.0, "element": "water", "status": "slow", "status_duration": 2.5, "preset": "cast", "freeze": 0.11, "shake": 8.0}
		"C21":
			return {"radius": 150.0, "damage": 20.0, "element": str(details.get("element", "fire")), "status": "slow", "status_duration": 1.0, "preset": "gold", "freeze": 0.08, "shake": 7.0}
	return {"radius": CHAIN_EFFECT_RADIUS, "damage": 20.0, "element": "fire", "preset": "combo"}


func _nearby_enemy_count(world_position: Vector2) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var body := enemy as Node2D
		if body == null or not is_instance_valid(body):
			continue
		if body.global_position.distance_to(world_position) <= NEARBY_RADIUS:
			count += 1
	return maxi(count - 1, 0)


func _is_fire(element: String) -> bool:
	return element in ["fire", "burn", "sun"]


func _is_thunder(element: String) -> bool:
	return element in ["thunder", "lightning"]


func _is_water_or_ice(element: String) -> bool:
	return element in ["water", "ice", "frost", "snow"]


func _node_key(node: Node) -> int:
	return node.get_instance_id() if node != null else 0
