extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const StatusComponent = preload("res://systems/combat/status_component.gd")

@export var speed: float = 300.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

var velocity := Vector2.ZERO
var owner_player: CharacterBody2D
var pierce_remaining := 0
var element_key := "fire"
var source_tag := "projectile"
var status_on_hit := ""
var status_duration := 0.0
var _draw_radius := 5.0
var _draw_color := GameConstants.COLOR_PROJECTILE
var _elapsed := 0.0
var _hit_bodies: Array = []
var _sprite: Sprite2D
var _animation_frames: Array[Texture2D] = []
var _frame_index := 0
var _frame_elapsed := 0.0
var _trail_points: Array[Vector2] = []


func _ready() -> void:
	speed = GameConstants.PROJECTILE_SPEED
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 1
	add_child(_sprite)
	_apply_sprite()


func setup(direction: Vector2, dmg: float, owner: CharacterBody2D, speed_override: float = -1.0, radius: float = 5.0, color: Color = GameConstants.COLOR_PROJECTILE, pierce_override: int = -1, element_override: String = "fire", range_override: float = -1.0, source_override: String = "projectile", status_override: String = "", status_duration_override: float = 0.0) -> void:
	var resolved_speed := speed_override if speed_override > 0.0 else speed
	velocity = direction.normalized() * resolved_speed
	damage = dmg
	owner_player = owner
	_draw_radius = radius
	_draw_color = color
	element_key = element_override
	source_tag = source_override
	status_on_hit = status_override
	status_duration = status_duration_override
	if not status_on_hit.is_empty():
		_draw_color = _draw_color.lerp(StatusComponent.status_color(status_on_hit), 0.55)
	if range_override > 0.0 and resolved_speed > 0.0:
		lifetime = range_override / resolved_speed
	rotation = velocity.angle()
	if owner and owner.has_node("AffixHolder"):
		pierce_remaining = pierce_override if pierce_override >= 0 else owner.get_node("AffixHolder").projectile_pierce
	_apply_sprite()


func _apply_sprite() -> void:
	if _sprite == null:
		return
	_animation_frames.clear()
	_frame_index = 0
	_frame_elapsed = 0.0
	var path := AssetPaths.projectile_for_color(_draw_color)
	var tex := AssetPaths.load_texture(path)
	for frame_path in AssetPaths.animation_frame_paths_for_texture(path, "fly"):
		var frame := AssetPaths.load_texture(frame_path)
		if frame:
			_animation_frames.append(frame)
	if tex:
		_sprite.texture = _animation_frames[0] if not _animation_frames.is_empty() else tex
		var scale_factor := _draw_radius / 8.0
		_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		_sprite.texture = null


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if not status_on_hit.is_empty():
		for i in _trail_points.size():
			_trail_points[i] -= velocity * delta
		_trail_points.push_front(Vector2.ZERO)
		if _trail_points.size() > 8:
			_trail_points.pop_back()
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	_advance_sprite(delta)
	if not status_on_hit.is_empty() or not _sprite or _sprite.texture == null:
		queue_redraw()


func _advance_sprite(delta: float) -> void:
	if _animation_frames.size() <= 1:
		return
	_frame_elapsed += delta
	var frame_time := 1.0 / 12.0
	while _frame_elapsed >= frame_time:
		_frame_elapsed -= frame_time
		_frame_index = (_frame_index + 1) % _animation_frames.size()
		_sprite.texture = _animation_frames[_frame_index]


func _draw() -> void:
	_draw_trail()
	if _sprite and _sprite.texture != null:
		return
	draw_circle(Vector2.ZERO, _draw_radius, _draw_color)


func _draw_trail() -> void:
	if _trail_points.size() < 2:
		return
	var local_points: PackedVector2Array = []
	for p in _trail_points:
		local_points.append(p)
	for i in range(local_points.size() - 1):
		var alpha := 0.30 * (1.0 - float(i) / float(local_points.size()))
		var width := maxf(1.0, _draw_radius * (0.72 - float(i) * 0.06))
		draw_line(local_points[i], local_points[i + 1], Color(_draw_color.r, _draw_color.g, _draw_color.b, alpha), width, true)


func _on_body_entered(body: Node) -> void:
	if body in _hit_bodies:
		return
	if not body.has_method("receive_projectile_hit"):
		return
	_hit_bodies.append(body)
	VfxManager.spawn_world(global_position, "hit", _hit_color())
	body.receive_projectile_hit(self)
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()


func _hit_color() -> Color:
	return StatusComponent.status_color(status_on_hit) if not status_on_hit.is_empty() else _draw_color
