extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const VfxLibrary = preload("res://vfx/vfx_library.gd")

var velocity := Vector2.ZERO
var damage := 10.0
var lifetime := 2.5
var element_key := ""
var status_on_hit := ""
var status_duration := 0.0
var source_tag := "enemy_projectile"
var _radius := 5.0
var _color := Color(1.0, 0.35, 0.35)
var _draw_color := Color(1.0, 0.35, 0.35)
var _elapsed := 0.0
var _sprite: Sprite2D
var _animation_frames: Array[Texture2D] = []
var _frame_index := 0
var _frame_elapsed := 0.0
var _trail_texture: Texture2D


func _ready() -> void:
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 1
	add_child(_sprite)
	_apply_sprite()


func setup(
	direction: Vector2,
	dmg: float,
	speed: float,
	radius: float = 5.0,
	color: Color = Color(1.0, 0.35, 0.35),
	element: String = "",
	status: String = "",
	status_time: float = 0.0,
	source: String = "enemy_projectile",
) -> void:
	velocity = direction.normalized() * speed
	damage = dmg
	_radius = radius
	_color = color
	element_key = element.strip_edges().to_lower()
	status_on_hit = status.strip_edges().to_lower()
	status_duration = maxf(status_time, 0.0)
	source_tag = source if not source.is_empty() else "enemy_projectile"
	_draw_color = VfxLibrary.ink_vfx_color(_color, "cast", element_key, status_on_hit, 1)
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
	_draw_trail_texture()
	if _sprite and _sprite.texture != null:
		return
	push_error("EnemyProjectile missing image2 core texture for element `%s` status `%s`" % [element_key, status_on_hit])


func _enemy_tip_color() -> Color:
	var danger := Color(1.0, 0.42, 0.2, 0.36)
	if status_on_hit in ["poison", "root"]:
		return Color(0.52, 1.0, 0.36, 0.34)
	if element_key in ["thunder", "lightning"] or status_on_hit in ["paralyze", "shock", "stun"]:
		return Color(0.55, 0.88, 1.0, 0.36)
	if element_key in ["soul", "chaos", "void"] or status_on_hit == "curse":
		return Color(0.86, 0.38, 1.0, 0.34)
	return danger


func _apply_sprite() -> void:
	if _sprite == null:
		return
	_animation_frames.clear()
	_frame_index = 0
	_frame_elapsed = 0.0
	_trail_texture = AssetPaths.load_texture(AssetPaths.enemy_projectile_trail(element_key, status_on_hit))
	var path := AssetPaths.projectile_for_semantics(element_key, status_on_hit, _color)
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


func _draw_trail_texture() -> void:
	if _trail_texture == null:
		push_error("EnemyProjectile missing image2 trail texture for element `%s` status `%s`" % [element_key, status_on_hit])
		return
	var tail_length := clampf(_radius * 4.6, 20.0, 46.0)
	var tail_height := clampf(_radius * 1.62, 9.0, 19.0)
	var rect := Rect2(Vector2(-tail_length, -tail_height * 0.5), Vector2(tail_length, tail_height))
	draw_texture_rect(_trail_texture, rect, false, _trail_modulate())


func _trail_modulate() -> Color:
	var color := _draw_color.lerp(_enemy_tip_color(), 0.28)
	color.a = clampf(0.20 + _radius * 0.008, 0.18, 0.30)
	return color


func get_trail_texture_hit_count() -> int:
	return 1 if _trail_texture != null else 0


func get_trail_texture_path() -> String:
	return AssetPaths.enemy_projectile_trail(element_key, status_on_hit)


func get_core_texture_hit_count() -> int:
	return 1 if _sprite != null and _sprite.texture != null else 0


func get_core_texture_path() -> String:
	return AssetPaths.projectile_for_semantics(element_key, status_on_hit, _color)


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
	var hit_applied := false
	if body.has_method("receive_enemy_projectile"):
		hit_applied = bool(body.receive_enemy_projectile(damage, element_key, status_on_hit, status_duration, source_tag))
	if hit_applied:
		VfxManager.spawn_hit_feedback(global_position, element_key, status_on_hit, _draw_color, 1)
	queue_free()


func cut_by_player_slash(_player: Node = null) -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	VfxManager.spawn_world_semantic(global_position, "crit", Color(0.72, 0.9, 1.0), element_key, status_on_hit, 1)
	queue_free()
	return true
