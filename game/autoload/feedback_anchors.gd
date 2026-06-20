extends Node

const VariantUtils = preload("res://core/utils/variant_utils.gd")

const ANCHORS := {
	"hit_light": {
		"preset": "hit",
		"color": Color(0.94, 0.92, 0.88),
		"freeze": 0.0,
		"shake": 0.0,
		"label": "",
		"duration": 0.0,
	},
	"hit_heavy": {
		"preset": "crit",
		"color": Color(1.0, 0.88, 0.34),
		"freeze": 0.035,
		"shake": 6.0,
		"label": "",
		"duration": 0.0,
	},
	"enemy_death": {
		"preset": "hit",
		"color": Color(0.92, 0.88, 0.78),
		"freeze": 0.0,
		"shake": 0.0,
		"label": "",
		"duration": 0.0,
	},
	"path_caster": {
		"preset": "cast",
		"color": Color(1.0, 0.62, 0.22),
		"freeze": 0.0,
		"shake": 0.0,
		"label": "",
		"duration": 0.0,
	},
	"path_talisman": {
		"preset": "cast",
		"color": Color(0.42, 0.9, 0.42),
		"freeze": 0.0,
		"shake": 0.0,
		"label": "",
		"duration": 0.0,
	},
	"spell_fire": {
		"preset": "combo",
		"color": Color(1.0, 0.42, 0.14),
		"freeze": 0.03,
		"shake": 4.0,
		"label": "",
		"duration": 0.0,
	},
	"spell_sword": {
		"preset": "crit",
		"color": Color(0.72, 0.9, 1.0),
		"freeze": 0.035,
		"shake": 5.0,
		"label": "",
		"duration": 0.0,
	},
	"spell_thunder": {
		"preset": "dao",
		"color": Color(0.58, 0.78, 1.0),
		"freeze": 0.05,
		"shake": 6.0,
		"label": "",
		"duration": 0.0,
	},
	"spell_ice": {
		"preset": "cast",
		"color": Color(0.42, 0.92, 1.0),
		"freeze": 0.04,
		"shake": 4.0,
		"label": "",
		"duration": 0.0,
	},
	"spell_talisman": {
		"preset": "cast",
		"color": Color(0.44, 0.85, 0.48),
		"freeze": 0.02,
		"shake": 3.0,
		"label": "",
		"duration": 0.0,
	},
	"spell_fusion": {
		"preset": "combo",
		"color": Color(1.0, 0.72, 0.26),
		"freeze": 0.06,
		"shake": 7.0,
		"label": "合体技",
		"duration": 0.34,
	},
	"spell_element_burst": {
		"preset": "dao",
		"color": Color(1.0, 0.86, 0.24),
		"freeze": 0.12,
		"shake": 11.0,
		"label": "元素爆发",
		"duration": 0.48,
	},
	"chain_trigger": {
		"preset": "combo",
		"color": Color(1.0, 0.58, 0.18),
		"freeze": 0.08,
		"shake": 7.0,
		"label": "连锁触发",
		"duration": 0.4,
	},
	"dao_awaken": {
		"preset": "dao",
		"color": Color(1.0, 0.82, 0.24),
		"freeze": 0.12,
		"shake": 8.0,
		"label": "道统觉醒",
		"duration": 0.55,
	},
	"ultimate_release": {
		"preset": "dao",
		"color": Color(1.0, 0.84, 0.22),
		"freeze": 0.28,
		"shake": 14.0,
		"label": "万法归一",
		"duration": 0.72,
	},
	"boss_phase_break": {
		"preset": "gold",
		"color": Color(1.0, 0.48, 0.2),
		"freeze": 0.18,
		"shake": 12.0,
		"label": "阶段破势",
		"duration": 0.45,
	},
	"boss_inheritance": {
		"preset": "dao",
		"color": Color(1.0, 0.82, 0.24),
		"freeze": 0.16,
		"shake": 10.0,
		"label": "传承现世",
		"duration": 0.65,
	},
	"death_regret": {
		"preset": "dao",
		"color": Color(1.0, 0.65, 0.25),
		"freeze": 0.0,
		"shake": 4.0,
		"label": "",
		"duration": 0.0,
	},
	"combo_30": {
		"preset": "gold",
		"color": Color(1.0, 0.78, 0.24),
		"freeze": 0.04,
		"shake": 5.0,
		"label": "势如破竹",
		"duration": 0.28,
	},
	"combo_60": {
		"preset": "dao",
		"color": Color(1.0, 0.82, 0.28),
		"freeze": 0.08,
		"shake": 7.0,
		"label": "道势奔流",
		"duration": 0.38,
	},
	"combo_100": {
		"preset": "dao",
		"color": Color(1.0, 0.9, 0.42),
		"freeze": 0.16,
		"shake": 9.0,
		"label": "万法将成",
		"duration": 0.5,
	},
	"combo_200": {
		"preset": "dao",
		"color": Color(1.0, 0.95, 0.36),
		"freeze": 0.32,
		"shake": 14.0,
		"label": "道之极致",
		"duration": 0.8,
	},
}

var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_seed := 0
var _camera: Camera2D
var _camera_base_offset := Vector2.ZERO
var _freeze_token := 0
var _pause_modified := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.feedback_anchor_requested.connect(_on_feedback_anchor_requested)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.hidden_chain_discovered.connect(_on_hidden_chain_discovered)
	EventBus.dao_tradition_awakened.connect(_on_dao_tradition_awakened)
	EventBus.unity_burst_visual_requested.connect(_on_unity_burst_visual)
	EventBus.combo_milestone.connect(_on_combo_milestone)
	EventBus.run_completed.connect(func(_victory: bool) -> void: _reset_camera())
	EventBus.room_entered.connect(func(_room: Dictionary, _stage: Dictionary) -> void: _reset_camera())


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	var camera := _current_camera()
	if camera == null:
		_shake_time = 0.0
		return
	_shake_time = maxf(_shake_time - delta, 0.0)
	var t := _shake_time / maxf(_shake_duration, 0.01)
	var strength := _shake_strength * t * t
	var x := sin(float(_shake_seed) + Time.get_ticks_msec() * 0.047) * strength
	var y := cos(float(_shake_seed) * 1.37 + Time.get_ticks_msec() * 0.053) * strength
	camera.offset = _camera_base_offset + Vector2(x, y)
	if _shake_time <= 0.0:
		camera.offset = _camera_base_offset


func trigger(anchor_id: String, payload: Dictionary = {}) -> void:
	_on_feedback_anchor_requested(anchor_id, payload)


func _on_feedback_anchor_requested(anchor_id: String, payload: Dictionary = {}) -> void:
	var cfg: Dictionary = (ANCHORS.get(anchor_id, ANCHORS["hit_light"]) as Dictionary)
	var position: Vector2 = payload.get("world_position", payload.get("position", Vector2.INF))
	var color: Color = payload.get("color", cfg.get("color", Color.WHITE))
	var preset := str(payload.get("preset", cfg.get("preset", "hit")))
	if position != Vector2.INF:
		VfxManager.spawn_world(position, preset, color)
	var freeze := float(payload.get("freeze", cfg.get("freeze", 0.0)))
	var shake := float(payload.get("shake", cfg.get("shake", 0.0)))
	if freeze > 0.0:
		_hit_stop(freeze)
	if shake > 0.0:
		_add_screen_shake(shake, maxf(0.10, freeze + 0.12))
	var label := str(payload.get("label", cfg.get("label", "")))
	var duration := float(payload.get("duration", cfg.get("duration", 0.0)))
	if not label.is_empty():
		EventBus.crit_moment_requested.emit(label, duration)


func _on_damage_dealt(result: Dictionary) -> void:
	if VariantUtils.as_bool(result.get("target_is_player", false)):
		return
	var source := str(result.get("source_tag", ""))
	var pos: Vector2 = result.get("world_position", Vector2.INF)
	var color := _color_for_damage(result)
	if VariantUtils.as_bool(result.get("is_unity", false)):
		return
	if VariantUtils.as_bool(result.get("is_crit", false)) or source.find("short_arc") >= 0 or source.find("qing_feng_sword") >= 0:
		trigger("hit_heavy", {"world_position": pos, "color": color})
	else:
		trigger("hit_light", {"world_position": pos, "color": color})


func _on_enemy_killed(enemy: Node) -> void:
	if enemy == null or not enemy is Node2D:
		return
	if enemy.has_method("is_boss_unit") and enemy.is_boss_unit():
		return
	var color := Color(0.92, 0.88, 0.78)
	if enemy.has_method("is_elite_unit") and enemy.is_elite_unit():
		color = Color(1.0, 0.62, 0.28)
	trigger("enemy_death", {"world_position": (enemy as Node2D).global_position, "color": color})


func _on_hidden_chain_discovered(_chain_id: String, display_name: String, payload: Dictionary) -> void:
	if VariantUtils.as_bool(payload.get("effect_anchor_handled", false)):
		return
	var pos: Vector2 = payload.get("world_position", payload.get("position", Vector2.INF))
	trigger("chain_trigger", {
		"world_position": pos,
		"label": "连锁发现 · %s" % display_name,
		"color": Color(1.0, 0.58, 0.18),
	})


func _on_dao_tradition_awakened(tradition: Dictionary) -> void:
	var player := EntityCache.get_player() as Node2D
	trigger("dao_awaken", {
		"world_position": player.global_position if player else Vector2.INF,
		"label": "道统觉醒 · %s" % str(tradition.get("name", "成道")),
	})


func _on_unity_burst_visual(payload: Dictionary) -> void:
	trigger("ultimate_release", {
		"world_position": payload.get("world_position", Vector2.INF),
		"color": payload.get("color", Color(1.0, 0.84, 0.22)),
		"label": "万法归一",
	})


func _on_combo_milestone(count: int) -> void:
	var anchor_id := ""
	if count >= 200:
		anchor_id = "combo_200"
	elif count >= 100:
		anchor_id = "combo_100"
	elif count >= 60:
		anchor_id = "combo_60"
	elif count >= 30:
		anchor_id = "combo_30"
	if anchor_id.is_empty():
		return
	var player := EntityCache.get_player() as Node2D
	trigger(anchor_id, {
		"world_position": player.global_position if player else Vector2.INF,
	})


func _color_for_damage(result: Dictionary) -> Color:
	if result.has("color") and result["color"] is Color:
		return result["color"]
	if VariantUtils.as_bool(result.get("is_combo", false)):
		return Color(1.0, 0.42, 0.12)
	if VariantUtils.as_bool(result.get("is_crit", false)):
		return Color(1.0, 0.88, 0.25)
	var element := str(result.get("element", ""))
	match element:
		"fire":
			return Color(1.0, 0.42, 0.14)
		"thunder":
			return Color(0.66, 0.82, 1.0)
		"wood":
			return Color(0.46, 0.9, 0.38)
		"water":
			return Color(0.45, 0.78, 1.0)
		"soul":
			return Color(0.72, 0.42, 1.0)
	return Color(0.94, 0.92, 0.88)


func _hit_stop(duration: float) -> void:
	if VfxManager.should_reduce_motion():
		return
	if get_tree().paused:
		return
	_freeze_token += 1
	var token := _freeze_token
	get_tree().paused = true
	_pause_modified = true
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if token == _freeze_token and _pause_modified:
			_pause_modified = false
			get_tree().paused = false
	, CONNECT_ONE_SHOT)


func _add_screen_shake(strength: float, duration: float) -> void:
	if VfxManager.should_reduce_motion():
		return
	var camera := _current_camera()
	if camera == null:
		return
	_shake_seed += 17
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time = maxf(_shake_time, duration)


func _current_camera() -> Camera2D:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var camera := viewport.get_camera_2d()
	if camera == null:
		var player := EntityCache.get_player()
		if player:
			camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera != _camera:
		_camera = camera
		_camera_base_offset = _camera.offset if _camera else Vector2.ZERO
	return _camera


func _reset_camera() -> void:
	_freeze_token += 1
	if _pause_modified and get_tree():
		_pause_modified = false
		get_tree().paused = false
	if _camera and is_instance_valid(_camera):
		_camera.offset = _camera_base_offset
	_shake_time = 0.0
	_shake_strength = 0.0
