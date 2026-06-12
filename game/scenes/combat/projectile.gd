extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

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
var _sprite: Sprite2D


func _ready() -> void:
	speed = GameConstants.PROJECTILE_SPEED
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 1
	add_child(_sprite)
	_apply_sprite()


func setup(direction: Vector2, dmg: float, owner: CharacterBody2D, speed_override: float = -1.0, radius: float = 5.0, color: Color = GameConstants.COLOR_PROJECTILE, pierce_override: int = -1) -> void:
	velocity = direction.normalized() * (speed_override if speed_override > 0.0 else speed)
	damage = dmg
	owner_player = owner
	_draw_radius = radius
	_draw_color = color
	rotation = velocity.angle()
	if owner and owner.has_node("AffixHolder"):
		pierce_remaining = pierce_override if pierce_override >= 0 else owner.get_node("AffixHolder").projectile_pierce
	_apply_sprite()


func _apply_sprite() -> void:
	if _sprite == null:
		return
	var path := AssetPaths.projectile_for_color(_draw_color)
	var tex := AssetPaths.load_texture(path)
	if tex:
		_sprite.texture = tex
		var scale_factor := _draw_radius / 8.0
		_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		_sprite.texture = null


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	if not _sprite or _sprite.texture == null:
		queue_redraw()


func _draw() -> void:
	if _sprite and _sprite.texture != null:
		return
	draw_circle(Vector2.ZERO, _draw_radius, _draw_color)


func _on_body_entered(body: Node) -> void:
	if body in _hit_bodies:
		return
	if not body.has_method("receive_projectile_hit"):
		return
	_hit_bodies.append(body)
	VfxManager.spawn_world(global_position, "hit", _draw_color)
	body.receive_projectile_hit(self)
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()
