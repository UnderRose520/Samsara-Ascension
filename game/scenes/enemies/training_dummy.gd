extends CharacterBody2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const DamagePipeline = preload("res://systems/combat/damage_pipeline.gd")
const CombatContextBuilder = preload("res://systems/combat/combat_context_builder.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const HealthComponentScript = preload("res://systems/combat/health_component.gd")
const EnemySkillRegistry = preload("res://systems/combat/enemy_skill_registry.gd")
const EnemySpawnRegistry = preload("res://systems/combat/enemy_spawn_registry.gd")
const EnemySkillController = preload("res://systems/combat/enemy_skill_controller.gd")
const BossPhaseRegistry = preload("res://systems/combat/boss_phase_registry.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var health: Node = $HealthComponent
@onready var status: Node = $StatusComponent
@onready var name_label: Label = $NameLabel
@onready var world_hp: WorldEnemyHealthBar = $WorldEnemyHealthBar
@onready var action_label: Label = $ActionLabel
@onready var body_visual: Sprite2D = $BodyVisual

var _flash := 0.0
var _is_boss := false
var _is_elite := false
var _contact_damage := 12.0
var _display_name := "训练木人"
var _death_handled := false
var _move_speed := GameConstants.ENEMY_MOVE_SPEED
var _steer_velocity := Vector2.ZERO
var _slot_dir := Vector2(0, -1)
var _orbit_radius := GameConstants.ENEMY_ORBIT_RADIUS
var _speed_jitter := 1.0
var _archetype := "normal"
var _room_type := "combat"
var _skills: EnemySkillController
var _anim_state := "idle"
var _visual_facing := Vector2.RIGHT
var _last_damage_source := ""
var _last_damage_element := ""
var _last_damage_had_weather_synergy := false
var _status_feedback_cd := 0.0
var _boss_phase_gates: Array[float] = []
var _boss_phase_gate_index := 0
var _boss_gate_lock := 0.0
var _realm_name := ""
var _realm_level := 1
var _is_promoted_realm := false
var _stat_traits: Array[String] = []
var _spawn_index := 0
var _weapon_id := "claw"
var _sprite_faces_left_by_default := false
var _mutation_timer := 0.0
var _mutation_damage := 0.0
var _mutation_element := "fire"

func _ready() -> void:
	health.max_hp = GameConstants.ENEMY_HP
	health.current_hp = GameConstants.ENEMY_HP
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	add_to_group("enemy")
	EventBus.display_settings_changed.connect(_apply_display_settings)
	_apply_display_settings()
	_refresh_name_label()
	_on_health_changed(health.current_hp, health.max_hp)
	_skills = EnemySkillController.new()
	_skills.setup(self, "normal")


func configure_enemy(display_name: String, is_boss: bool = false, room_type: String = "combat") -> void:
	_display_name = display_name
	_is_boss = is_boss
	_is_elite = EnemySpawnRegistry.is_elite_display_name(display_name) or room_type == "combat_hard"
	_room_type = room_type
	_contact_damage = 22.0 if is_boss else 12.0
	_move_speed = GameConstants.ENEMY_BOSS_MOVE_SPEED if is_boss else GameConstants.ENEMY_MOVE_SPEED
	var arch_row := EnemySkillRegistry.get_archetype(
		EnemySkillRegistry.resolve_archetype(display_name, is_boss, room_type)
	)
	_archetype = EnemySkillRegistry.resolve_archetype(display_name, is_boss, room_type)
	_move_speed *= float(arch_row.get("move_speed_mult", 1.0))
	scale = Vector2(1.6, 1.6) if is_boss else Vector2.ONE
	_skills = EnemySkillController.new()
	_skills.setup(self, _archetype)
	if is_boss:
		var boss_phases := BossPhaseRegistry.get_phases("boss")
		_skills.setup_boss_phases(boss_phases)
		_boss_phase_gates = _build_boss_phase_gates(boss_phases)
		_boss_phase_gate_index = 0
		_boss_gate_lock = 0.0
	_refresh_name_label()
	_apply_body_sprite()


func _apply_body_sprite() -> void:
	if body_visual == null:
		return
	var path: String = AssetPaths.enemy_sprite_for_style(_archetype, _is_boss, SaveManager.get_sprite_style())
	_sprite_faces_left_by_default = _enemy_sprite_faces_left(path)
	if body_visual.has_method("set_texture_path"):
		body_visual.set_texture_path(path)
	elif ResourceLoader.exists(path):
		body_visual.texture = load(path)
	else:
		body_visual.texture = null  # Clear default so _draw() uses fallback circle
	if body_visual.has_method("set_animation_prefix_name"):
		body_visual.set_animation_prefix_name(_anim_state)
	_apply_visual_facing()


func configure_as_boss() -> void:
	configure_enemy("关底守将", true, "boss")


func set_enemy_weapon_id(weapon_id: String) -> void:
	_weapon_id = weapon_id if not weapon_id.is_empty() else "claw"
	_refresh_action_label()
	queue_redraw()


func _build_boss_phase_gates(phases: Array) -> Array[float]:
	var gates: Array[float] = []
	for phase in phases:
		if typeof(phase) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = phase
		var ratio := float(row.get("hp_ratio", 1.0))
		if ratio > 0.0 and ratio < 1.0:
			gates.append(ratio)
	gates.sort()
	gates.reverse()
	return gates


func scale_contact_damage(mult: float) -> void:
	if mult <= 0.0:
		return
	_contact_damage *= mult


func scale_move_speed(mult: float) -> void:
	if mult <= 0.0:
		return
	_move_speed *= mult


func trigger_spirit_mutation(duration: float = 5.0, element_key: String = "fire") -> void:
	if _death_handled or _is_boss or _mutation_timer > 0.0:
		return
	_mutation_timer = maxf(duration, 1.0)
	_mutation_element = element_key if not element_key.is_empty() else "fire"
	_mutation_damage = maxf(18.0, _contact_damage * 1.75)
	_move_speed *= 0.7
	scale *= 1.5
	_flash = 0.45
	_show_status_hit_feedback("burn")
	EventBus.pet_coord_feedback.emit("敌人异变：灵气暴走，5秒后自爆")
	VfxManager.spawn_world(global_position, "gold", Color(1.0, 0.42, 0.16))


func apply_instance_stats(stats: Dictionary) -> void:
	var speed_mult := float(stats.get("speed", 1.0))
	var defense_mult := float(stats.get("def", 1.0))
	var attack_mult := float(stats.get("atk", 1.0))
	_move_speed *= speed_mult
	health.defense *= defense_mult
	_realm_name = str(stats.get("realm_name", ""))
	_realm_level = int(stats.get("realm_level", 1))
	_is_promoted_realm = bool(stats.get("promoted", false))
	_stat_traits.clear()
	if _is_promoted_realm:
		_stat_traits.append("越阶")
	if defense_mult >= 1.35:
		_stat_traits.append("厚甲")
	if speed_mult >= 1.18:
		_stat_traits.append("迅捷")
	if attack_mult >= 1.35:
		_stat_traits.append("强攻")
	_refresh_name_label()


func apply_elite_affixes(affix_ids: Array) -> void:
	const EliteAffixRegistry = preload("res://systems/combat/elite_affix_registry.gd")
	if affix_ids.is_empty():
		return
	_is_elite = true
	_contact_damage *= 1.18
	health.defense *= 1.12
	var suffix: PackedStringArray = []
	for affix_id in affix_ids:
		var row: Dictionary = EliteAffixRegistry.get_affix(str(affix_id))
		if row.is_empty():
			continue
		_move_speed *= float(row.get("move_speed_mult", 1.0))
		_contact_damage *= float(row.get("contact_damage_mult", 1.0))
		var hp_scale: float = float(row.get("hp_mult", 1.0))
		if hp_scale != 1.0:
			health.max_hp *= hp_scale
			health.current_hp = health.max_hp
			health.changed.emit(health.current_hp, health.max_hp)
		suffix.append(EliteAffixRegistry.get_label(str(affix_id)))
	if not suffix.is_empty():
		_display_name = "%s·%s" % [_display_name, "·".join(suffix)]
		_refresh_name_label()


func get_display_name() -> String:
	return _display_name


func set_display_name_override(display_name: String) -> void:
	if display_name.is_empty():
		return
	_display_name = display_name
	_refresh_name_label()


func is_boss_unit() -> bool:
	return _is_boss


func is_elite_unit() -> bool:
	return _is_elite


func init_combat_slot(spawn_pos: Vector2, player_pos: Vector2, index: int, total: int, is_boss: bool) -> void:
	_spawn_index = index
	var count := maxi(total, 1)
	var from_player: Vector2 = spawn_pos - player_pos
	if from_player.length_squared() > 640.0:
		_slot_dir = from_player.normalized()
	else:
		var angle := TAU * float(index) / float(count) - PI * 0.5
		_slot_dir = Vector2.from_angle(angle)
	if is_boss:
		_orbit_radius = maxf(GameConstants.ENEMY_ORBIT_RADIUS_BOSS, 92.0)
	else:
		_orbit_radius = GameConstants.ENEMY_ORBIT_RADIUS + float(index % 7) * GameConstants.ENEMY_ORBIT_SPREAD
	_speed_jitter = RunRng.enemy_jitter(index).randf_range(0.88, 1.08)
	if _skills:
		_skills.apply_spawn_stagger(index)


func _apply_display_settings() -> void:
	var show_hp: bool = SaveManager.get_display_setting("show_enemy_hp")
	if world_hp:
		world_hp.visible = show_hp
	action_label.visible = show_hp
	_apply_body_sprite()


func _refresh_name_label() -> void:
	name_label.text = _display_name
	if not _is_boss and not _is_promoted_realm and not _realm_name.is_empty() and not _display_name.begins_with(_realm_name):
		name_label.text = "%s·%s" % [_realm_name, _display_name]
	if _is_boss:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
		name_label.add_theme_font_size_override("font_size", 13)
	elif _is_promoted_realm:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
		name_label.add_theme_font_size_override("font_size", 12)
	elif _is_elite:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.28))
		name_label.add_theme_font_size_override("font_size", 12)
	else:
		name_label.add_theme_color_override("font_color", Color(0.941, 0.925, 0.894, 1))
		name_label.add_theme_font_size_override("font_size", 12)


func _on_health_changed(current: float, maximum: float) -> void:
	if world_hp:
		world_hp.set_values(current, maximum)
	if _is_boss and maximum > 0.0:
		var ratio := current / maximum
		if current <= HealthComponentScript.HP_EPSILON:
			ratio = maxf(RunContext.last_boss_hp_ratio, 0.01)
		RunContext.record_boss_hp_ratio(_display_name, ratio)
	if current <= HealthComponentScript.HP_EPSILON:
		if not _death_handled:
			_on_died()
		return


func _emit_damage(result: Dictionary) -> void:
	result["world_position"] = global_position
	result["target_is_player"] = false
	result["target"] = self
	result["target_weapon_id"] = _weapon_id
	result["target_killed"] = health.current_hp <= HealthComponentScript.HP_EPSILON
	result["source_tag"] = _last_damage_source
	_last_damage_had_weather_synergy = bool(result.get("weather_synergy", false)) or bool(result.get("terrain_synergy", false))
	result["target_status"] = {
		"burning": status.is_burning(),
		"paralyzed": status.is_paralyzed(),
		"slowed": status.is_slowed(),
		"frozen": status.is_frozen(),
		"poisoned": status.is_poisoned(),
	}
	EventBus.damage_dealt.emit(result)


func _get_player() -> Node2D:
	return EntityCache.get_player() as Node2D


func _apply_movement() -> void:
	move_and_slide()
	var radius := 20.0 if _is_boss else 16.0
	global_position = GameConstants.clamp_to_arena(global_position, radius)
	_refresh_action_label()
	_update_animation_state()
	if _needs_redraw():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if get_tree().paused or _death_handled:
		return
	_status_feedback_cd = maxf(_status_feedback_cd - delta, 0.0)
	_boss_gate_lock = maxf(_boss_gate_lock - delta, 0.0)
	TerrainSystem.apply_body_effects(self, delta)
	if not health.is_alive():
		velocity = Vector2.ZERO
		return

	var player: Node2D = _get_player()
	if player == null:
		velocity = Vector2.ZERO
		_apply_movement()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if _skills:
		if _is_boss and health.max_hp > 0.0:
			var hp_ratio: float = float(health.current_hp) / float(health.max_hp)
			_skills.update_phase(hp_ratio)
			RunContext.record_boss_hp_ratio(_display_name, hp_ratio)
		_skills.tick(delta, player)
		if _skills.is_busy():
			_update_chase_visual_facing(to_player)
			_apply_movement()
			return

	var speed: float = _move_speed * _speed_jitter * status.get_move_speed_mult()
	var target: Vector2 = _compute_chase_velocity(player, dist, speed)
	var blend: float = minf(1.0, delta * 8.0)
	_steer_velocity = _steer_velocity.lerp(target, blend)
	if target.length_squared() < 1.0:
		_steer_velocity = _steer_velocity.lerp(Vector2.ZERO, minf(1.0, delta * 12.0))
	if _steer_velocity.length_squared() < 16.0 and target.length_squared() < 1.0:
		_steer_velocity = Vector2.ZERO
	velocity = _steer_velocity
	_update_chase_visual_facing(to_player)

	_apply_movement()


func _refresh_action_label() -> void:
	if _skills and _skills.get_action_label().length() > 0:
		action_label.text = "%s · %s" % [_weapon_label(), _skills.get_action_label()]
		if _is_boss and _skills.get_phase_name().length() > 0 and not _skills.is_busy():
			action_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.85))
		elif _skills.is_busy():
			action_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
		return
	if status.is_paralyzed():
		action_label.text = "僵直"
		action_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	elif status.is_slowed():
		action_label.text = "缓行"
		action_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	elif _steer_velocity.length() > 55.0:
		if _is_elite:
			action_label.text = "疾行"
			action_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
		elif _is_boss:
			action_label.text = "压近"
			action_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
		elif _archetype == "ranged":
			action_label.text = "游走"
			action_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		elif _archetype == "sniper":
			action_label.text = "瞄准"
			action_label.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		elif _archetype == "berserker":
			action_label.text = "冲锋"
			action_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		elif _archetype == "shaman":
			action_label.text = "结印"
			action_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.85))
		else:
			action_label.text = "逼近"
			action_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	elif _steer_velocity.length() > 8.0:
		action_label.text = _stat_trait_label("%s · 移动" % _weapon_label())
		action_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	else:
		action_label.text = _stat_trait_label("%s · 待机" % _weapon_label())
		action_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))


func _stat_trait_label(fallback: String) -> String:
	if _stat_traits.is_empty():
		return fallback
	return "%s · %s" % [fallback, "·".join(_stat_traits.slice(0, 2))]

func _update_animation_state() -> void:
	if body_visual == null or not body_visual.has_method("set_animation_prefix_name"):
		return
	var next_state: String = "idle"
	if _skills and _skills.is_busy():
		next_state = "combat"
	elif velocity.length() > 25.0 or _steer_velocity.length() > 25.0:
		next_state = "walk"
	if next_state == _anim_state:
		return
	_anim_state = next_state
	body_visual.set_animation_prefix_name(_anim_state)


func _update_visual_facing(direction: Vector2) -> void:
	if absf(direction.x) < 0.05:
		return
	_visual_facing = direction.normalized()
	_apply_visual_facing()


func _update_chase_visual_facing(to_player: Vector2) -> void:
	var horizontal := 0.0
	if absf(to_player.x) > 1.0:
		horizontal = to_player.x
	if horizontal != 0.0:
		_visual_facing = Vector2(signf(horizontal), 0.0)
		_apply_visual_facing()


func _apply_visual_facing() -> void:
	if body_visual == null or absf(_visual_facing.x) < 0.05:
		return
	body_visual.flip_h = _visual_facing.x > 0.0 if _sprite_faces_left_by_default else _visual_facing.x < 0.0


func _enemy_sprite_faces_left(path: String) -> bool:
	var file_name := path.get_file()
	if file_name.begins_with("enemy_style_"):
		return true
	return false


func _needs_redraw() -> bool:
	if body_visual == null or body_visual.texture == null:
		return true
	if _flash > 0.0:
		return true
	if _skills and (_skills.get_windup_progress() > 0.0 or _skills.is_dashing()):
		return true
	if status.is_burning() or status.is_poisoned() or status.is_frozen() or status.is_paralyzed() or status.is_slowed():
		return true
	return false


func _compute_chase_velocity(player: Node2D, dist_to_player: float, speed: float) -> Vector2:
	if dist_to_player > GameConstants.ENEMY_AGGRO_RANGE:
		return Vector2.ZERO

	var desired_radius := _orbit_radius
	if _is_boss:
		desired_radius = maxf(desired_radius, GameConstants.ENEMY_CONTACT_RANGE + 38.0)
	var slot_pos: Vector2 = player.global_position + _slot_dir * desired_radius
	var to_slot: Vector2 = slot_pos - global_position
	var slot_dist: float = to_slot.length()

	if _is_boss and dist_to_player < desired_radius * 0.8:
		return (global_position - player.global_position).normalized() * speed

	var desired := Vector2.ZERO
	if slot_dist > GameConstants.ENEMY_ARRIVAL_THRESHOLD:
		desired = to_slot.normalized() * speed

	var push := _compute_separation_push(dist_to_player < 72.0)
	if desired.length_squared() < 0.001:
		if push.length_squared() < 0.001:
			return Vector2.ZERO
		return push.normalized() * minf(speed * 0.28, push.length() * 2.0)

	if _is_boss and dist_to_player < desired_radius * 1.2:
		desired += (global_position - player.global_position).normalized() * speed * 0.35

	if push.length_squared() > 0.001:
		return (desired + push * 0.55).limit_length(speed)
	return desired


func _compute_separation_push(near_player: bool) -> Vector2:
	var push := Vector2.ZERO
	var sep_radius: float = GameConstants.ENEMY_SEPARATION_RADIUS
	if near_player:
		sep_radius *= 1.4
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()
		if dist < sep_radius and dist > 0.001:
			push += offset.normalized() * (sep_radius - dist)
	return push


func _process(delta: float) -> void:
	var dot: float = status.tick(self, delta)
	if dot > 0.0:
		_apply_incoming_damage(dot)
	if _mutation_timer > 0.0:
		_mutation_timer = maxf(_mutation_timer - delta, 0.0)
		if _mutation_timer <= 0.0:
			_explode_mutation()
	_flash = maxf(_flash - delta, 0.0)
	var needs_redraw := _flash > 0.0 or _steer_velocity.length() > 10.0
	if _skills and (_skills.get_windup_progress() > 0.0 or _skills.is_dashing()):
		needs_redraw = true
	if status.is_burning() or status.is_poisoned() or status.is_frozen() or status.is_paralyzed() or status.is_slowed():
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func get_burn_stacks() -> int:
	return status.get_burn_stacks()


func apply_status(status_name: String, duration: float) -> void:
	status.apply_status(status_name, duration)


func receive_terrain_damage(amount: float, terrain_type: String = "") -> void:
	if amount <= 0.0 or _death_handled:
		return
	_remember_damage_source("terrain_%s" % terrain_type, terrain_type)
	var result := {
		"final_damage": amount,
		"world_position": global_position,
		"target_is_player": false,
		"is_crit": false,
		"is_combo": false,
		"element": terrain_type,
	}
	result["final_damage"] = _apply_incoming_damage(amount)
	_flash = 0.12
	_emit_damage(result)


func detonate_burn(base_damage: float) -> float:
	var raw: float = status.consume_combust(base_damage)
	if raw <= 0.0:
		return 0.0
	var ctx: Dictionary
	var holder: Node = null
	var player := _get_player()
	if player and player.has_node("AffixHolder"):
		holder = player.get_node("AffixHolder")
		ctx = holder.build_damage_context(
			raw,
			maxf(health.defense - holder.flat_defense * 0.5, 0.0),
			player.crit_rate,
			player.crit_mult,
			"combust",
		)
	else:
		ctx = CombatContextBuilder.build_fallback(
			raw,
			health.defense,
			player.crit_rate if player else 0.0,
			1.5,
			"fire",
			player,
			"combust",
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	_remember_damage_source("combo_combust", "fire")
	result["final_damage"] = _apply_incoming_damage(result.final_damage)
	_flash = 0.2
	result["is_combo"] = true
	_emit_damage(result)
	return result.final_damage


func receive_projectile_hit(projectile: Area2D) -> void:
	var ctx: Dictionary
	var holder: Node = null
	var projectile_element := str(projectile.get("element_key") if "element_key" in projectile else "fire")
	var projectile_source := str(projectile.get("source_tag") if "source_tag" in projectile else "projectile")
	if projectile.owner_player and projectile.owner_player.has_node("AffixHolder"):
		holder = projectile.owner_player.get_node("AffixHolder")
		if projectile_element.is_empty():
			ctx = holder.build_damage_context(
				projectile.damage,
				maxf(health.defense - holder.flat_defense * 0.5, 0.0),
				projectile.owner_player.crit_rate,
				projectile.owner_player.crit_mult,
				"proj",
			)
		else:
			ctx = CombatContextBuilder.build_fallback(
				projectile.damage + holder.flat_attack,
				maxf(health.defense - holder.flat_defense * 0.5, 0.0),
				projectile.owner_player.crit_rate,
				projectile.owner_player.crit_mult,
				projectile_element,
				projectile.owner_player,
				"proj_%s" % projectile_element,
				true,
			)
			for value in holder.bucket_a:
				ctx["bucket_a"].append(value)
			for value in holder.bucket_b:
				ctx["bucket_b"].append(value)
			for value in holder.bucket_c:
				ctx["bucket_c"].append(value)
			for value in holder.bucket_d:
				ctx["bucket_d"].append(value)
	else:
		var owner := projectile.owner_player as Node2D
		ctx = CombatContextBuilder.build_fallback(
			projectile.damage,
			health.defense,
			owner.crit_rate if owner else 0.0,
			1.5,
			projectile_element,
			owner,
			"proj_%s" % projectile_element,
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	_remember_damage_source(projectile_source, projectile_element)
	result["final_damage"] = _apply_incoming_damage(result.final_damage)
	_flash = 0.12
	_emit_damage(result)
	var projectile_status := str(projectile.get("status_on_hit") if "status_on_hit" in projectile else "")
	if not projectile_status.is_empty():
		apply_status(projectile_status, float(projectile.get("status_duration") if "status_duration" in projectile else 1.0))
		_show_status_hit_feedback(projectile_status)
	if projectile_source == "pet_coord":
		EventBus.pet_coord_hit.emit(self)

	if holder:
		var bonus: float = holder.proc_on_hit(self)
		if bonus > 0.0:
			pass
		if projectile.owner_player.has_node("ComboCounter"):
			projectile.owner_player.get_node("ComboCounter").register_hit()
		if projectile.owner_player.has_node("SkillProgression"):
			projectile.owner_player.get_node("SkillProgression").register_hit()


func receive_player_weapon_hit(player: CharacterBody2D, damage: float, element_key: String = "", hit_label: String = "weapon") -> void:
	if player == null or _death_handled:
		return
	var holder: Node = player.get_node("AffixHolder") if player.has_node("AffixHolder") else null
	var resolved_element := element_key
	if resolved_element.is_empty() or resolved_element == "physical":
		resolved_element = holder.get_element_bias() if holder and holder.has_method("get_element_bias") else ""
	if resolved_element.is_empty() or resolved_element == "physical":
		resolved_element = "earth"

	var ctx: Dictionary
	if holder:
		ctx = CombatContextBuilder.build_fallback(
			damage + holder.flat_attack,
			maxf(health.defense - holder.flat_defense * 0.5, 0.0),
			player.crit_rate,
			player.crit_mult,
			resolved_element,
			player,
			hit_label,
			true,
		)
		for value in holder.bucket_a:
			ctx["bucket_a"].append(value)
		for value in holder.bucket_b:
			ctx["bucket_b"].append(value)
		for value in holder.bucket_c:
			ctx["bucket_c"].append(value)
		for value in holder.bucket_d:
			ctx["bucket_d"].append(value)
	else:
		ctx = CombatContextBuilder.build_fallback(
			damage,
			health.defense,
			player.crit_rate,
			player.crit_mult,
			resolved_element,
			player,
			hit_label,
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	_remember_damage_source(hit_label, resolved_element)
	result["final_damage"] = _apply_incoming_damage(result.final_damage)
	_flash = 0.14
	_emit_damage(result)

	if holder:
		holder.proc_on_hit(self)
	if player.has_node("ComboCounter"):
		player.get_node("ComboCounter").register_hit()
	if player.has_node("SkillProgression"):
		player.get_node("SkillProgression").register_hit()
	RunContext.add_dao_momentum(1.5, "weapon_hit")


func _apply_incoming_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	if not _is_boss or health.max_hp <= 0.0 or _boss_phase_gate_index >= _boss_phase_gates.size():
		return health.take_damage(amount)
	if _boss_gate_lock > 0.0:
		return 0.0
	var gate_ratio: float = float(_boss_phase_gates[_boss_phase_gate_index])
	var gate_hp: float = float(health.max_hp) * gate_ratio
	var current_hp: float = float(health.current_hp)
	if current_hp > gate_hp and current_hp - amount <= gate_hp:
		var applied: float = health.take_damage(maxf(current_hp - gate_hp, 0.0))
		_boss_phase_gate_index += 1
		_boss_gate_lock = 0.35
		_flash = 0.24
		EventBus.crit_moment_requested.emit("%s · 阶段突破" % _display_name, 0.3)
		EventBus.pet_coord_feedback.emit("%s 守势崩裂，余劲被化去" % _display_name)
		VfxManager.spawn_world(global_position, "gold", Color(1.0, 0.45, 0.22))
		return applied
	return health.take_damage(amount)


func show_weapon_mod_status_feedback(status_name: String) -> void:
	_show_status_hit_feedback(status_name)


func _remember_damage_source(source: String, element: String = "") -> void:
	_last_damage_source = source
	_last_damage_element = element


func _show_status_hit_feedback(status_name: String) -> void:
	if _status_feedback_cd > 0.0:
		return
	_status_feedback_cd = 0.08
	var color := StatusComponent.status_color(status_name)
	_flash = maxf(_flash, 0.18)
	VfxManager.spawn_world(global_position, "hit", color)
	if body_visual:
		VfxManager.flash_control(body_visual, color.lightened(0.25), 0.12)


func _on_died() -> void:
	if _death_handled:
		return
	_death_handled = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	if status.is_burning():
		var player := _get_player()
		if player and player.has_node("SkillProgression"):
			player.get_node("SkillProgression").register_status_kill()
	remove_from_group("enemy")
	EventBus.enemy_killed.emit(self)
	var momentum := 2.0 + (13.0 if _is_elite else 0.0) + (18.0 if _is_boss else 0.0)
	var bonus_label := ""
	if _last_damage_source.begins_with("terrain_") or _last_damage_source == "combo_combust" or _last_damage_had_weather_synergy:
		momentum += 12.0
		bonus_label = "天象地形"
		RunContext.record_weather_kill(self, WeatherSystem.current_weather_id, {
			"source": _last_damage_source,
			"element": _last_damage_element,
			"elite": _is_elite,
		})
	RunContext.add_dao_momentum(momentum, "kill_%s" % _last_damage_source)
	if not bonus_label.is_empty():
		EventBus.pet_coord_feedback.emit("%s击杀 · 道势 +%d" % [bonus_label, int(round(momentum))])
	_maybe_grant_promoted_reward()
	if _is_boss:
		EventBus.crit_moment_requested.emit("%s · 传承现世" % _display_name, 0.65)
		EventBus.pet_coord_feedback.emit("%s败退，本命器祭炼开启" % _display_name)
	var burst_preset := "gold" if _is_boss else ("combo" if _is_elite else "hit")
	var burst_color := Color(1.0, 0.84, 0.2) if _is_boss else GameConstants.COLOR_ENEMY
	VfxManager.spawn_world(global_position, burst_preset, burst_color)
	queue_free()


func _explode_mutation() -> void:
	if _death_handled:
		return
	var radius := 130.0
	_death_handled = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemy")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if global_position.distance_to((enemy as Node2D).global_position) > radius:
			continue
		if enemy.has_method("receive_terrain_damage"):
			enemy.receive_terrain_damage(_mutation_damage, _mutation_element)
	var player := _get_player()
	if player and global_position.distance_to(player.global_position) <= radius and player.has_method("receive_terrain_damage"):
		player.receive_terrain_damage(_mutation_damage * 0.55, _mutation_element)
	EventBus.pet_coord_feedback.emit("灵气暴走炸裂，可伤敌我")
	EventBus.crit_moment_requested.emit("灵气暴走", 0.28)
	VfxManager.spawn_world(global_position, "combo", Color(1.0, 0.38, 0.12))
	EventBus.enemy_killed.emit(self)
	queue_free()


func _maybe_grant_promoted_reward() -> void:
	if not _is_promoted_realm or _is_boss:
		return
	var rng := RunRng.make("promoted_reward_%d_%d_%d_%s" % [RunContext.current_stage, RunContext.current_room, _spawn_index, _display_name])
	if rng.randf() >= 0.35:
		return
	var gold_bonus := 4 + maxi(_realm_level, 1) * 2
	RunContext.gold += gold_bonus
	EventBus.gold_changed.emit(RunContext.gold)
	RunContext.add_dao_momentum(3.0 + float(_realm_level), "promoted_enemy")
	EventBus.pet_coord_feedback.emit("越阶斩敌 · 灵石 +%d · 道势微涨" % gold_bonus)
	VfxManager.spawn_world(global_position, "gold", Color(1.0, 0.72, 0.24))


func _draw() -> void:
	var radius := 16.0 if not _is_boss else 20.0
	var color: Color = GameConstants.COLOR_ENEMY.lerp(status.get_visual_tint(), 0.45)
	if _is_elite:
		color = color.lerp(Color(1.0, 0.45, 0.2), 0.2)
	elif _archetype == "sniper":
		color = color.lerp(Color(0.65, 0.55, 0.95), 0.25)
	elif _archetype == "berserker":
		color = color.lerp(Color(0.95, 0.25, 0.2), 0.3)
	elif _archetype == "shaman":
		color = color.lerp(Color(0.35, 0.85, 0.65), 0.25)
	elif _archetype == "ranged":
		color = color.lerp(Color(0.55, 0.7, 1.0), 0.15)
	if _is_boss:
		color = color.lerp(Color(0.85, 0.35, 0.2), 0.25)
	if _flash > 0.0:
		color = color.lightened(0.5)

	var move_speed := _steer_velocity.length()
	if move_speed > 10.0:
		var dir := _steer_velocity.normalized()
		var streak := radius * clampf(move_speed / maxf(_move_speed, 1.0), 0.35, 1.2)
		var streak_color := color.darkened(0.25)
		streak_color.a = 0.55
		draw_line(Vector2.ZERO, -dir * streak, streak_color, 2.0 + streak * 0.08)

	if _skills and _skills.get_windup_progress() > 0.0:
		var progress := _skills.get_windup_progress()
		var phase_color := Color(1.0, 0.35, 0.2, 0.9)
		if _is_boss:
			phase_color = Color(1.0, 0.45, 0.85, 0.9)
		draw_circle(Vector2.ZERO, radius + 12.0, Color(1.0, 0.25, 0.15, 0.15))
		draw_arc(Vector2.ZERO, radius + 10.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 28, phase_color, 3.0)
		_draw_weapon_outline(radius, phase_color, progress)
	elif _skills and _skills.is_dashing():
		draw_circle(Vector2.ZERO, radius + 8.0, Color(1.0, 0.2, 0.15, 0.25))
		_draw_weapon_outline(radius, Color(1.0, 0.58, 0.22, 0.95), 1.0)
	else:
		_draw_weapon_outline(radius, Color(1.0, 0.72, 0.36, 0.48), 0.35)

	if body_visual:
		body_visual.modulate = color
		return

	if body_visual == null:
		draw_circle(Vector2.ZERO, radius, color)


func _weapon_label() -> String:
	match _weapon_id:
		"claw": return "爪"
		"poison_spit": return "毒囊"
		"mud_bow", "cloud_crossbow": return "弩"
		"wind_blade": return "风刃"
		"furnace_core": return "炉心"
		"xuanwu_shield": return "盾"
		"soul_banner": return "魂幡"
	return "兵器"


func _draw_weapon_outline(radius: float, color: Color, charge: float) -> void:
	var dir := _visual_facing.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var side := dir.orthogonal()
	var alpha := clampf(color.a + charge * 0.35, 0.25, 1.0)
	var c := Color(color.r, color.g, color.b, alpha)
	var hand := dir * (radius + 4.0)
	match _weapon_id:
		"mud_bow", "cloud_crossbow":
			draw_line(hand - side * 13.0, hand + side * 13.0, c, 3.0)
			draw_line(hand, hand + dir * (22.0 + charge * 14.0), Color(1.0, 0.95, 0.62, alpha), 2.0)
		"wind_blade", "claw":
			for offset in [-7.0, 0.0, 7.0]:
				draw_line(hand + side * offset, hand + side * offset + dir * (16.0 + charge * 10.0), c, 2.5)
		"furnace_core":
			draw_circle(hand, 8.0 + charge * 5.0, Color(1.0, 0.34, 0.14, 0.18 + charge * 0.25))
			draw_arc(hand, 12.0 + charge * 7.0, 0.0, TAU, 30, c, 2.5)
		"xuanwu_shield":
			draw_arc(hand, 16.0 + charge * 4.0, -PI * 0.55, PI * 0.55, 24, c, 4.0)
			draw_line(hand - side * 12.0, hand + side * 12.0, c, 2.0)
		"soul_banner":
			draw_line(hand - dir * 5.0, hand + dir * (30.0 + charge * 12.0), c, 3.0)
			draw_rect(Rect2(hand + dir * 16.0 - side * 2.0, Vector2(18.0, 14.0)), Color(0.75, 0.35, 1.0, alpha * 0.72), true)
		"poison_spit":
			draw_circle(hand, 6.0 + charge * 4.0, Color(0.45, 1.0, 0.36, alpha * 0.75))
			draw_line(hand, hand + dir * (14.0 + charge * 12.0), c, 2.0)
		_:
			draw_line(hand, hand + dir * (20.0 + charge * 8.0), c, 3.0)
