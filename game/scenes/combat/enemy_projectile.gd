extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")

var velocity := Vector2.ZERO
var damage := 10.0
var lifetime := 2.5
var _radius := 5.0
var _color := Color(1.0, 0.35, 0.35)
var _elapsed := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(direction: Vector2, dmg: float, speed: float, radius: float = 5.0, color: Color = Color(1.0, 0.35, 0.35)) -> void:
	velocity = direction.normalized() * speed
	damage = dmg
	_radius = radius
	_color = color
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, _color)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("receive_enemy_projectile"):
		body.receive_enemy_projectile(damage)
	queue_free()
