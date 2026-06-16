class_name EnemySkillController

const EnemySkillRegistry = preload("res://systems/combat/enemy_skill_registry.gd")
const BossPhaseRegistry = preload("res://systems/combat/boss_phase_registry.gd")
const RunRng = preload("res://core/utils/run_rng.gd")

var owner_body: CharacterBody2D
var skills: Array = []
var _cooldowns: Dictionary = {}
var _windup := 0.0
var _windup_skill: Dictionary = {}
var _dash_time := 0.0
var _dash_dir := Vector2.ZERO
var _dash_damage := 0.0
var _dash_hit_done := false
var _boss_phases: Array = []
var _phase_index := 0
var _phase_name := ""
var _using_phases := false
var _attack_delay := 0.0
var _windup_scale := 1.0
var _timing_rng: RandomNumberGenerator


func setup(body: CharacterBody2D, archetype: String) -> void:
	owner_body = body
	skills = EnemySkillRegistry.get_skills_for_archetype(archetype)
	_reset_cooldowns()


func apply_spawn_stagger(spawn_index: int) -> void:
	_timing_rng = RunRng.enemy_jitter(spawn_index)
	_attack_delay = _timing_rng.randf_range(0.3, 1.25)
	_windup_scale = _timing_rng.randf_range(0.82, 1.18)
	for skill in skills:
		var skill_id := str(skill.get("id", ""))
		if skill_id.is_empty():
			continue
		var cd := float(skill.get("cooldown", 1.0))
		_cooldowns[skill_id] = _timing_rng.randf_range(0.0, cd * 0.55)


func setup_boss_phases(phases: Array) -> void:
	_boss_phases = phases
	_using_phases = not phases.is_empty()
	if _using_phases:
		_apply_boss_phase(0)


func update_phase(hp_ratio: float) -> void:
	if not _using_phases or _boss_phases.is_empty():
		return
	var target := 0
	for i in range(_boss_phases.size() - 1, -1, -1):
		if hp_ratio <= float(_boss_phases[i].get("hp_ratio", 1.0)) + 0.001:
			target = i
			break
	if target != _phase_index:
		_apply_boss_phase(target)


func get_phase_name() -> String:
	return _phase_name


func is_busy() -> bool:
	return _windup > 0.0 or _dash_time > 0.0


func is_dashing() -> bool:
	return _dash_time > 0.0


func get_action_label() -> String:
	if _dash_time > 0.0:
		return "猛扑"
	if _windup > 0.0:
		return str(_windup_skill.get("name", "蓄力")) + "·蓄力"
	if _using_phases and not _phase_name.is_empty():
		return _phase_name
	return ""


func get_windup_progress() -> float:
	if _windup <= 0.0 or _windup_skill.is_empty():
		return 0.0
	var total := float(_windup_skill.get("windup", 0.4)) * _windup_scale
	if total <= 0.0:
		return 1.0
	return 1.0 - (_windup / total)


func tick(delta: float, player: Node2D) -> void:
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(float(_cooldowns[skill_id]) - delta, 0.0)

	if _dash_time > 0.0:
		_dash_time = maxf(_dash_time - delta, 0.0)
		if owner_body:
			owner_body.velocity = _dash_dir * float(_windup_skill.get("speed", 300.0))
		if not _dash_hit_done and player and owner_body.global_position.distance_to(player.global_position) < 34.0:
			_hit_player(player, _dash_damage)
			_dash_hit_done = true
		return

	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		if owner_body:
			owner_body.velocity = owner_body.velocity.lerp(Vector2.ZERO, minf(1.0, delta * 16.0))
		if _windup <= 0.0 and not _windup_skill.is_empty():
			_execute_skill(_windup_skill, player)
		return

	if player == null:
		return
	if _attack_delay > 0.0:
		_attack_delay = maxf(_attack_delay - delta, 0.0)
		return
	var dist := owner_body.global_position.distance_to(player.global_position)
	var pick := _pick_skill(dist)
	if pick.is_empty():
		return
	_start_windup(pick, player)


func _apply_boss_phase(index: int) -> void:
	if index < 0 or index >= _boss_phases.size():
		return
	var entering := index != _phase_index
	_phase_index = index
	var phase: Dictionary = _boss_phases[index]
	_phase_name = str(phase.get("phase_name", ""))
	skills = BossPhaseRegistry.get_skills_for_phase(phase)
	_reset_cooldowns()
	_windup = 0.0
	_windup_skill = {}
	_dash_time = 0.0
	_dash_hit_done = false
	if entering and index > 0 and owner_body:
		var boss_name := "关底守将"
		if owner_body.has_method("get_display_name"):
			boss_name = owner_body.get_display_name()
		EventBus.pet_coord_feedback.emit("%s · %s" % [boss_name, _phase_name])


func _reset_cooldowns() -> void:
	_cooldowns.clear()
	for skill in skills:
		_cooldowns[str(skill.get("id", ""))] = 0.0


func _pick_skill(dist: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for skill in skills:
		var skill_id := str(skill.get("id", ""))
		if float(_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		var skill_type := str(skill.get("type", ""))
		var skill_range := float(skill.get("range", 0.0))
		var score := -INF
		match skill_type:
			"melee":
				if dist <= skill_range + 8.0:
					score = 100.0 - dist
			"dash":
				if dist > 42.0 and dist <= skill_range:
					score = 80.0 - absf(dist - 90.0)
			"sniper":
				if dist >= 140.0 and dist <= skill_range:
					score = 75.0 - absf(dist - 280.0)
			"projectile":
				var extra := str(skill.get("extra", ""))
				if extra.begins_with("count:"):
					if dist >= 90.0 and dist <= skill_range:
						score = 65.0 - absf(dist - 180.0)
				elif dist >= 70.0 and dist <= skill_range:
					score = 60.0 - absf(dist - 160.0)
		if score > best_score:
			best_score = score
			best = skill
	return best


func _start_windup(skill: Dictionary, player: Node2D) -> void:
	_windup_skill = skill
	_windup = float(skill.get("windup", 0.4)) * _windup_scale
	_show_windup_telegraph(skill, player)


func _show_windup_telegraph(skill: Dictionary, player: Node2D) -> void:
	if owner_body == null or player == null:
		return
	var dir := (player.global_position - owner_body.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var skill_type := str(skill.get("type", ""))
	var duration := maxf(float(skill.get("windup", 0.4)) * _windup_scale, 0.16)
	var length := clampf(float(skill.get("range", 160.0)), 72.0, 420.0)
	var width := 8.0
	var color := Color(1.0, 0.38, 0.24, 1.0)
	match skill_type:
		"dash":
			width = 13.0
			color = Color(1.0, 0.46, 0.18, 1.0)
		"sniper":
			width = 5.0
			color = Color(1.0, 0.28, 0.22, 1.0)
		"projectile":
			width = 7.0
			color = Color(1.0, 0.55, 0.22, 1.0)
		"melee":
			length = 64.0
			width = 16.0
			color = Color(1.0, 0.62, 0.28, 1.0)
	VfxManager.spawn_enemy_attack_telegraph(owner_body.global_position, dir, length, duration, width, color)


func _execute_skill(skill: Dictionary, player: Node2D) -> void:
	var skill_id := str(skill.get("id", ""))
	var base_cd := float(skill.get("cooldown", 1.0))
	if _timing_rng:
		_cooldowns[skill_id] = base_cd * _timing_rng.randf_range(0.88, 1.15)
	else:
		_cooldowns[skill_id] = base_cd
	match str(skill.get("type", "")):
		"melee":
			if player and owner_body.global_position.distance_to(player.global_position) < float(skill.get("range", 48.0)):
				_hit_player(player, float(skill.get("damage", 12.0)))
		"dash":
			if player:
				_dash_dir = (player.global_position - owner_body.global_position).normalized()
				_dash_damage = float(skill.get("damage", 18.0))
				_dash_time = 0.28
				_dash_hit_done = false
		"projectile", "sniper":
			_fire_projectiles(skill, player)
	_windup_skill = {}


func _fire_projectiles(skill: Dictionary, player: Node2D) -> void:
	if player == null or owner_body == null:
		return
	var base_dir := (player.global_position - owner_body.global_position).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.DOWN
	var count := 1
	var extra := str(skill.get("extra", ""))
	if extra.begins_with("count:"):
		count = int(extra.get_slice(":", 1))
	var spread := 0.18 if count > 1 else 0.0
	if extra.contains("spread:"):
		spread = float(extra.get_slice("spread:", 1).split(",")[0])
	for i in count:
		var dir := base_dir.rotated(spread * (float(i) - float(count - 1) * 0.5))
		EventBus.spawn_enemy_projectile_requested.emit({
			"scene_root": owner_body.get_tree().current_scene,
			"position": owner_body.global_position + dir * 18.0,
			"direction": dir,
			"damage": float(skill.get("damage", 10.0)),
			"speed": float(skill.get("speed", 240.0)),
			"radius": 5.5 if count == 1 else 4.5,
			"color": Color(1.0, 0.35, 0.35) if count == 1 else Color(1.0, 0.55, 0.2),
		})


func _hit_player(player: Node2D, amount: float) -> void:
	if player.has_method("receive_enemy_projectile"):
		player.receive_enemy_projectile(amount)
