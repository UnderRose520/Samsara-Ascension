extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

var velocity := Vector2.ZERO
var damage := 10.0
var lifetime := 2.5
var _radius := 5.0
var _color := Color(1.0, 0.35, 0.35)
var _elapsed := 0.0
var _sprite: Sprite2D
var _animation_frames: Array[Texture2D] = []
var _frame_index := 0
var _frame_elapsed := 0.0


func _ready() -> void:
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 1
	add_child(_sprite)
	_apply_sprite()


func setup(direction: Vector2, dmg: float, speed: float, radius: float = 5.0, color: Color = Color(1.0, 0.35, 0.35)) -> void:
	velocity = direction.normalized() * speed
	damage = dmg
	_radius = radius
	_color = color
	rotation = velocity.angle()
	_apply_sprite()


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	_advance_sprite(delta)
	queue_redraw()


func _draw() -> void:
	var dir := Vector2.RIGHT
	var tail_color := Color(_color.r, _color.g, _color.b, 0.42)
	var hot_color := Color(1.0, 0.78, 0.36, 0.34)
	draw_line(-dir * (_radius * 5.0), -dir * (_radius * 1.2), tail_color, maxf(2.0, _radius * 0.55))
	draw_line(-dir * (_radius * 4.2), dir * (_radius * 1.1), hot_color, 1.2)
	if _sprite and _sprite.texture != null:
		return
	draw_rect(Rect2(Vector2(-_radius, -_radius), Vector2(_radius * 2.0, _radius * 2.0)), _color, true)


func _apply_sprite() -> void:
	if _sprite == null:
		return
	_animation_frames.clear()
	_frame_index = 0
	_frame_elapsed = 0.0
	var path := AssetPaths.projectile_for_color(_color)
	for frame_path in AssetPaths.animation_frame_paths_for_texture(path, "fly"):
		var frame := AssetPaths.load_texture(frame_path)
		if frame:
			_animation_frames.append(frame)
	var tex := AssetPaths.load_texture(path)
	if tex:
		_sprite.texture = _animation_frames[0] if not _animation_frames.is_empty() else tex
		var scale_factor := _radius / 8.0
		_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		_sprite.texture = null


func _advance_sprite(delta: float) -> void:
	if _animation_frames.size() <= 1 or _sprite == null:
		return
	_frame_elapsed += delta
	var frame_time := 1.0 / 12.0
	while _frame_elapsed >= frame_time:
		_frame_elapsed -= frame_time
		_frame_index = (_frame_index + 1) % _animation_frames.size()
		_sprite.texture = _animation_frames[_frame_index]


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("receive_enemy_projectile"):
		body.receive_enemy_projectile(damage)
	queue_free()


func cut_by_player_slash(_player: Node = null) -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	VfxManager.spawn_world(global_position, "crit", Color(0.72, 0.9, 1.0))
	queue_free()
	return true
