extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")

@export var speed: float = 300.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

var velocity := Vector2.ZERO
var owner_player: CharacterBody2D
var pierce_remaining := 0
var _draw_radius := 5.0
var _draw_color := GameConstants.COLOR_PROJECTILE
var _elapsed := 0.0
var _hit_bodies: Array = []


func _ready() -> void:
	speed = GameConstants.PROJECTILE_SPEED
	body_entered.connect(_on_body_entered)


func setup(direction: Vector2, dmg: float, owner: CharacterBody2D, speed_override: float = -1.0, radius: float = 5.0, color: Color = GameConstants.COLOR_PROJECTILE, pierce_override: int = -1) -> void:
	velocity = direction.normalized() * (speed_override if speed_override > 0.0 else speed)
	damage = dmg
	owner_player = owner
	_draw_radius = radius
	_draw_color = color
	rotation = velocity.angle()
	if owner and owner.has_node("AffixHolder"):
		pierce_remaining = pierce_override if pierce_override >= 0 else owner.get_node("AffixHolder").projectile_pierce


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _draw_radius, _draw_color)


func _on_body_entered(body: Node) -> void:
	if body in _hit_bodies:
		return
	if not body.has_method("receive_projectile_hit"):
		return
	_hit_bodies.append(body)
	body.receive_projectile_hit(self)
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()
