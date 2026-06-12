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
@onready var hp_bar: ProgressBar = $HpBar
@onready var hp_label: Label = $HpLabel
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
		_skills.setup_boss_phases(BossPhaseRegistry.get_phases("boss"))
	_refresh_name_label()
	_apply_body_sprite()


func _apply_body_sprite() -> void:
	if body_visual == null:
		return
	var path := AssetPaths.enemy_sprite(_archetype, _is_boss)
	if body_visual.has_method("set_texture_path"):
		body_visual.set_texture_path(path)
	elif ResourceLoader.exists(path):
		body_visual.texture = load(path)
	else:
		body_visual.texture = null  # Clear default so _draw() uses fallback circle


func configure_as_boss() -> void:
	configure_enemy("关底守将", true, "boss")


func scale_contact_damage(mult: float) -> void:
	if mult <= 0.0:
		return
	_contact_damage *= mult


func apply_elite_affixes(affix_ids: Array) -> void:
	const EliteAffixRegistry = preload("res://systems/combat/elite_affix_registry.gd")
	if affix_ids.is_empty():
		return
	_is_elite = true
	var suffix: PackedStringArray = []
	for affix_id in affix_ids:
		var row: Dictionary = EliteAffixRegistry.get_affix(str(affix_id))
		if row.is_empty():
			continue
		_move_speed *= float(row.get("move_speed_mult", 1.0))
		_contact_damage *= float(row.get("contact_damage_mult", 1.0))
		var hp_scale := float(row.get("hp_mult", 1.0))
		if hp_scale != 1.0:
			health.max_hp *= hp_scale
			health.current_hp = health.max_hp
		suffix.append(EliteAffixRegistry.get_label(str(affix_id)))
	if not suffix.is_empty():
		_display_name = "%s·%s" % [_display_name, "·".join(suffix)]
		_refresh_name_label()


func get_display_name() -> String:
	return _display_name


func is_boss_unit() -> bool:
	return _is_boss


func is_elite_unit() -> bool:
	return _is_elite


func init_combat_slot(spawn_pos: Vector2, player_pos: Vector2, index: int, total: int, is_boss: bool) -> void:
	var count := maxi(total, 1)
	var from_player: Vector2 = spawn_pos - player_pos
	if from_player.length_squared() > 640.0:
		_slot_dir = from_player.normalized()
	else:
		var angle := TAU * float(index) / float(count) - PI * 0.5
		_slot_dir = Vector2.from_angle(angle)
	if is_boss:
		_orbit_radius = GameConstants.ENEMY_ORBIT_RADIUS_BOSS
	else:
		_orbit_radius = GameConstants.ENEMY_ORBIT_RADIUS + float(index % 7) * GameConstants.ENEMY_ORBIT_SPREAD
	_speed_jitter = RunRng.enemy_jitter(index).randf_range(0.82, 1.18)
	if _skills:
		_skills.apply_spawn_stagger(index)


func _apply_display_settings() -> void:
	var show_hp := SaveManager.get_display_setting("show_enemy_hp")
	hp_bar.visible = show_hp
	hp_label.visible = show_hp
	action_label.visible = show_hp


func _refresh_name_label() -> void:
	name_label.text = _display_name
	if _is_boss:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
		name_label.add_theme_font_size_override("font_size", 13)
	else:
		name_label.add_theme_color_override("font_color", Color(0.941, 0.925, 0.894, 1))
		name_label.add_theme_font_size_override("font_size", 12)


func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = maxf(current, 0.0)
	if current <= HealthComponentScript.HP_EPSILON:
		hp_label.text = "0/%.0f" % maximum
		if not _death_handled:
			_on_died()
		return
	var display_hp := int(ceili(current))
	hp_label.text = "%d/%.0f" % [display_hp, maximum]


func _emit_damage(result: Dictionary) -> void:
	result["world_position"] = global_position
	result["target_is_player"] = false
	EventBus.damage_dealt.emit(result)


func _get_player() -> Node2D:
	return EntityCache.get_player() as Node2D


func _apply_movement() -> void:
	move_and_slide()
	var radius := 20.0 if _is_boss else 16.0
	global_position = GameConstants.clamp_to_arena(global_position, radius)
	_refresh_action_label()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if get_tree().paused or _death_handled:
		return
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
			_skills.update_phase(health.current_hp / health.max_hp)
		_skills.tick(delta, player)
		if _skills.is_busy():
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

	_apply_movement()


func _refresh_action_label() -> void:
	if _skills and _skills.get_action_label().length() > 0:
		action_label.text = _skills.get_action_label()
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
			action_label.text = "疾逼"
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
		action_label.text = "移动"
		action_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	else:
		action_label.text = "待机"
		action_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))


func _compute_chase_velocity(player: Node2D, dist_to_player: float, speed: float) -> Vector2:
	if dist_to_player > GameConstants.ENEMY_AGGRO_RANGE:
		return Vector2.ZERO

	var slot_pos: Vector2 = player.global_position + _slot_dir * _orbit_radius
	var to_slot: Vector2 = slot_pos - global_position
	var slot_dist: float = to_slot.length()

	var desired := Vector2.ZERO
	if slot_dist > GameConstants.ENEMY_ARRIVAL_THRESHOLD:
		desired = to_slot.normalized() * speed

	var push := _compute_separation_push(dist_to_player < 72.0)
	if desired.length_squared() < 0.001:
		if push.length_squared() < 0.001:
			return Vector2.ZERO
		return push.normalized() * minf(speed * 0.28, push.length() * 2.0)

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
		health.take_damage(dot)
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
	health.take_damage(result.final_damage)
	_flash = 0.2
	result["is_combo"] = true
	_emit_damage(result)
	return result.final_damage


func receive_projectile_hit(projectile: Area2D) -> void:
	var ctx: Dictionary
	var holder: Node = null
	if projectile.owner_player and projectile.owner_player.has_node("AffixHolder"):
		holder = projectile.owner_player.get_node("AffixHolder")
		ctx = holder.build_damage_context(
			projectile.damage,
			maxf(health.defense - holder.flat_defense * 0.5, 0.0),
			projectile.owner_player.crit_rate,
			projectile.owner_player.crit_mult,
			"proj",
		)
	else:
		var owner := projectile.owner_player as Node2D
		ctx = CombatContextBuilder.build_fallback(
			projectile.damage,
			health.defense,
			owner.crit_rate if owner else 0.0,
			1.5,
			"fire",
			owner,
			"proj",
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	health.take_damage(result.final_damage)
	_flash = 0.12
	_emit_damage(result)

	if holder:
		var bonus: float = holder.proc_on_hit(self)
		if bonus > 0.0:
			pass
		if projectile.owner_player.has_node("ComboCounter"):
			projectile.owner_player.get_node("ComboCounter").register_hit()
		if projectile.owner_player.has_node("SkillProgression"):
			projectile.owner_player.get_node("SkillProgression").register_hit()


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
	var burst_preset := "gold" if _is_boss else ("combo" if _is_elite else "hit")
	var burst_color := Color(1.0, 0.84, 0.2) if _is_boss else GameConstants.COLOR_ENEMY
	VfxManager.spawn_world(global_position, burst_preset, burst_color)
	queue_free()


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
	elif _skills and _skills.is_dashing():
		draw_circle(Vector2.ZERO, radius + 8.0, Color(1.0, 0.2, 0.15, 0.25))

	if body_visual:
		body_visual.modulate = color
		return

	if body_visual == null:
		draw_circle(Vector2.ZERO, radius, color)
