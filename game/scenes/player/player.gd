extends CharacterBody2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const DamagePipeline = preload("res://systems/combat/damage_pipeline.gd")
const CombatAim = preload("res://systems/combat/combat_aim.gd")
const TargetSelector = preload("res://systems/combat/target_selector.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/projectile.tscn")

@onready var health: Node = $HealthComponent
@onready var combo: Node = $ComboCounter
@onready var status: Node = $StatusComponent
@onready var affix_holder: Node = $AffixHolder
@onready var spell_caster: Node = $PlayerSpellCaster
@onready var body_visual: Sprite2D = $BodyVisual

var move_speed := 300.0
var attack_power := 10.0
var crit_rate := 0.05
var crit_mult := 1.5
var defense := 5.0
var dodge_cooldown := 1.0

var _dodge_cd := 0.0
var _dodge_time := 0.0
var _dodge_dir := Vector2.RIGHT
var _iframe := 0.0
var _hit_invuln := 0.0
var _attack_cd := 0.0
var _last_facing := Vector2.RIGHT
var _dodge_trail_cd := 0.0
var _wet_slow_strength := 0.0


func _ready() -> void:
	var stats := ConfigRegistry.get_default_player_stats()
	move_speed = stats.move_speed
	attack_power = stats.attack
	crit_rate = stats.crit_rate
	crit_mult = stats.crit_mult
	defense = stats.defense
	dodge_cooldown = stats.dodge_cooldown
	health.max_hp = stats.hp
	health.current_hp = stats.hp
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	affix_holder.changed.connect(func(): queue_redraw())
	_on_health_changed(health.current_hp, health.max_hp)
	add_to_group("player")
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.run_started.connect(_on_run_started)


func _physics_process(delta: float) -> void:
	if get_tree().paused or RunContext.ui_blocking:
		return
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_iframe = maxf(_iframe - delta, 0.0)
	_hit_invuln = maxf(_hit_invuln - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_dodge_trail_cd = maxf(_dodge_trail_cd - delta, 0.0)
	_update_wet_slow(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		_last_facing = input_dir.normalized()

	_try_start_dodge(input_dir)

	if _dodge_time > 0.0:
		_dodge_time = maxf(_dodge_time - delta, 0.0)
		var dash_speed := _dodge_speed()
		var progress := 1.0 - (_dodge_time / GameConstants.DODGE_DURATION)
		if progress > 0.72:
			var ease := (progress - 0.72) / 0.28
			dash_speed *= lerpf(1.0, 0.35, ease)
		velocity = _dodge_dir * dash_speed
		if _dodge_trail_cd <= 0.0:
			_dodge_trail_cd = 0.045
			VfxManager.spawn_world(global_position, "cast", Color(0.55, 0.82, 1.0, 0.55))
	else:
		var speed: float = move_speed * float(status.get_move_speed_mult()) * _wet_move_mult()
		velocity = input_dir * speed

	move_and_slide()
	global_position = GameConstants.clamp_to_arena(global_position, 12.0)
	if body_visual:
		if _dodge_time > 0.0:
			body_visual.modulate = Color(1.25, 1.25, 1.35, 0.82)
		elif _wet_slow_strength > 0.05:
			body_visual.modulate = Color(0.82, 0.92, 1.08).lerp(Color.WHITE, 1.0 - _wet_slow_strength * 0.55)
		else:
			body_visual.modulate = Color.WHITE
	queue_redraw()

	var move_hint := get_aim_move_hint()
	if _attack_cd <= 0.0:
		if SaveManager.get_display_setting("auto_attack") and TargetSelector.has_attack_target(self):
			_fire_basic_attack(move_hint)
		elif Input.is_action_pressed("attack"):
			_fire_basic_attack(input_dir)

	if Input.is_action_just_pressed("pet_skill"):
		var pet := get_tree().get_first_node_in_group("pet")
		if pet and pet.has_method("try_coordinated_skill"):
			var dir := CombatAim.resolve_direction(self, get_aim_move_hint())
			pet.try_coordinated_skill(dir)


func _try_start_dodge(input_dir: Vector2) -> bool:
	if not Input.is_action_just_pressed("dodge") or _dodge_cd > 0.0 or _dodge_time > 0.0:
		return false
	var dir := input_dir
	if dir.length_squared() < 0.01:
		dir = _last_facing
	if dir.length_squared() < 0.01:
		return false
	_dodge_dir = dir.normalized()
	_dodge_time = GameConstants.DODGE_DURATION
	_iframe = GameConstants.DODGE_IFRAME
	_dodge_cd = dodge_cooldown
	_dodge_trail_cd = 0.0
	VfxManager.spawn_world(global_position, "cast", Color(0.65, 0.88, 1.0))
	return true


func _dodge_speed() -> float:
	return GameConstants.DODGE_DISTANCE / maxf(GameConstants.DODGE_DURATION, 0.01)


func _update_wet_slow(delta: float) -> void:
	if TerrainSystem.query_at(global_position) != "wet":
		if _wet_slow_strength > 0.0:
			var decay := delta / maxf(GameConstants.TERRAIN_WET_RECOVERY_SEC, 0.01)
			_wet_slow_strength = maxf(_wet_slow_strength - decay, 0.0)
		return
	_wet_slow_strength = 1.0


func _wet_move_mult() -> float:
	return lerpf(1.0, GameConstants.TERRAIN_WET_SLOW_MULT, _wet_slow_strength)


func _on_room_entered(_room: Dictionary, _stage: Dictionary) -> void:
	_wet_slow_strength = 0.0
	TargetSelector.clear_lock()


func _on_run_started(_seed_value: int) -> void:
	TargetSelector.clear_lock()


func get_aim_move_hint() -> Vector2:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		return input_dir.normalized()
	if velocity.length_squared() > 0.01:
		return velocity.normalized()
	return _last_facing


func _fire_basic_attack(move_hint: Vector2) -> void:
	var dir := _resolve_basic_attack_direction(move_hint)
	var projectile: Area2D = PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position + dir * 16.0
	projectile.setup(dir, attack_power, self)
	get_tree().current_scene.add_child(projectile)
	VfxManager.spawn_world(global_position + dir * 16.0, "cast", GameConstants.COLOR_PROJECTILE)
	var speed_mult: float = affix_holder.attack_speed_mult
	_attack_cd = GameConstants.ATTACK_INTERVAL / maxf(speed_mult, 0.1)


func _resolve_basic_attack_direction(move_hint: Vector2) -> Vector2:
	if SaveManager.get_display_setting("auto_aim") or SaveManager.get_display_setting("auto_attack"):
		return TargetSelector.direction_to_target(self, move_hint)
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.01:
		return to_mouse.normalized()
	if move_hint.length_squared() > 0.01:
		return move_hint.normalized()
	return _last_facing


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_hp_changed.emit(current, maximum)


func _on_died() -> void:
	EventBus.player_died.emit()


func receive_contact_damage(amount: float) -> void:
	if _iframe > 0.0 or _hit_invuln > 0.0 or get_tree().paused:
		return
	_apply_player_damage(amount)


func receive_enemy_projectile(amount: float) -> void:
	receive_contact_damage(amount)


func _apply_player_damage(amount: float) -> void:
	var defense_val := defense
	if affix_holder:
		defense_val += affix_holder.flat_defense
	var mitigated := amount * (1.0 - DamagePipeline.calc_mitigation(defense_val))
	health.take_damage(mitigated)
	_hit_invuln = GameConstants.HIT_INVULN
	if body_visual:
		VfxManager.flash_control(body_visual, Color(1.45, 0.45, 0.45), 0.16)
	VfxManager.spawn_world(global_position, "hit", Color(0.95, 0.35, 0.35))
	EventBus.damage_dealt.emit({
		"final_damage": mitigated,
		"world_position": global_position,
		"target_is_player": true,
		"is_crit": false,
		"is_combo": false,
	})


func _draw() -> void:
	if body_visual and body_visual.texture != null:
		if _iframe > 0.0:
			draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.25))
		if spell_caster and spell_caster.has_method("is_casting") and spell_caster.is_casting():
			var cast_color := Color(1.0, 0.45, 0.15, 0.85)
			if spell_caster.has_method("get_casting_color"):
				cast_color = spell_caster.get_casting_color()
				cast_color.a = 0.85
			draw_arc(Vector2.ZERO, 18.0, -PI * 0.5, PI * 0.5, 16, cast_color, 2.5)
		return
	var color: Color = GameConstants.COLOR_PLAYER
	if _iframe > 0.0:
		color = color.lightened(0.35)
	draw_circle(Vector2.ZERO, 12.0, color)
	if spell_caster and spell_caster.has_method("is_casting") and spell_caster.is_casting():
		var cast_color := Color(1.0, 0.45, 0.15, 0.85)
		if spell_caster.has_method("get_casting_color"):
			cast_color = spell_caster.get_casting_color()
			cast_color.a = 0.85
		draw_arc(Vector2.ZERO, 18.0, -PI * 0.5, PI * 0.5, 16, cast_color, 2.5)
