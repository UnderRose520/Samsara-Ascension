extends CharacterBody2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const DamagePipeline = preload("res://systems/combat/damage_pipeline.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/projectile.tscn")

@onready var health: Node = $HealthComponent
@onready var combo: Node = $ComboCounter
@onready var status: Node = $StatusComponent
@onready var affix_holder: Node = $AffixHolder
@onready var spell_caster: Node = $PlayerSpellCaster

var move_speed := 300.0
var attack_power := 10.0
var crit_rate := 0.05
var crit_mult := 1.5
var dodge_cooldown := 1.0

var _dodge_cd := 0.0
var _iframe := 0.0
var _attack_cd := 0.0


func _ready() -> void:
	var stats := ConfigRegistry.get_default_player_stats()
	move_speed = stats.move_speed
	attack_power = stats.attack
	crit_rate = stats.crit_rate
	crit_mult = stats.crit_mult
	dodge_cooldown = stats.dodge_cooldown
	health.max_hp = stats.hp
	health.current_hp = stats.hp
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	affix_holder.changed.connect(func(): queue_redraw())
	_on_health_changed(health.current_hp, health.max_hp)
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_iframe = maxf(_iframe - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _iframe > 0.0:
		velocity = Vector2.ZERO
	else:
		velocity = input_dir * move_speed
		if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0 and input_dir != Vector2.ZERO:
			global_position += input_dir.normalized() * GameConstants.DODGE_DISTANCE
			_iframe = GameConstants.DODGE_IFRAME
			_dodge_cd = dodge_cooldown

	move_and_slide()
	queue_redraw()

	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		_fire_at_mouse()

	if Input.is_action_just_pressed("pet_skill"):
		var pet := get_tree().get_first_node_in_group("pet")
		if pet and pet.has_method("try_coordinated_skill"):
			var dir := (get_global_mouse_position() - global_position).normalized()
			pet.try_coordinated_skill(dir)

	if Input.is_action_just_pressed("suicide"):
		health.take_damage(health.current_hp)


func _fire_at_mouse() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var projectile: Area2D = PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position + dir * 16.0
	projectile.setup(dir, attack_power, self)
	get_tree().current_scene.add_child(projectile)
	var speed_mult: float = affix_holder.attack_speed_mult
	_attack_cd = GameConstants.ATTACK_INTERVAL / maxf(speed_mult, 0.1)


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_hp_changed.emit(current, maximum)


func _on_died() -> void:
	EventBus.player_died.emit()


func receive_contact_damage(amount: float) -> void:
	if _iframe > 0.0 or get_tree().paused:
		return
	_apply_player_damage(amount)


func receive_enemy_projectile(amount: float) -> void:
	receive_contact_damage(amount)


func _apply_player_damage(amount: float) -> void:
	health.take_damage(amount)
	EventBus.damage_dealt.emit({
		"final_damage": amount,
		"world_position": global_position,
		"target_is_player": true,
		"is_crit": false,
		"is_combo": false,
	})


func _draw() -> void:
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
