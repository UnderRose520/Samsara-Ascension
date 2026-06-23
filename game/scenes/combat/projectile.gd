extends Area2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const StatusComponent = preload("res://systems/combat/status_component.gd")
const VfxLibrary = preload("res://vfx/vfx_library.gd")

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
var evolution_layer := 1
var evolution_branch := "base"
var synergy_rank := 0
var vfx_tier := 1
var _draw_radius := 5.0
var _draw_color := GameConstants.COLOR_PROJECTILE
var _elapsed := 0.0
var _hit_bodies: Array = []
var _sprite: Sprite2D
var _animation_frames: Array[Texture2D] = []
var _frame_index := 0
var _frame_elapsed := 0.0
var _trail_points: Array[Vector2] = []
var _trail_style := "default"
var _trail_texture: Texture2D


func _ready() -> void:
	speed = GameConstants.PROJECTILE_SPEED
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 1
	add_child(_sprite)
	_apply_sprite()


func setup(direction: Vector2, dmg: float, owner: CharacterBody2D, speed_override: float = -1.0, radius: float = 5.0, color: Color = GameConstants.COLOR_PROJECTILE, pierce_override: int = -1, element_override: String = "fire", range_override: float = -1.0, source_override: String = "projectile", status_override: String = "", status_duration_override: float = 0.0, evolution_layer_override: int = 1, evolution_branch_override: String = "base", synergy_rank_override: int = 0) -> void:
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
	evolution_layer = maxi(evolution_layer_override, 1)
	evolution_branch = evolution_branch_override
	synergy_rank = maxi(synergy_rank_override, 0)
	vfx_tier = clampi(maxi(evolution_layer, 1) + floori(float(maxi(synergy_rank, 0)) * 0.5), 1, 3)
	_trail_style = _resolve_trail_style(source_tag, element_key, status_on_hit)
	if not status_on_hit.is_empty():
		_draw_color = _draw_color.lerp(StatusComponent.status_color(status_on_hit), 0.55)
	_draw_color = VfxLibrary.ink_vfx_color(_draw_color, "cast", element_key, status_on_hit, vfx_tier)
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
	_trail_texture = AssetPaths.load_texture(AssetPaths.projectile_trail(element_key, status_on_hit))
	var path := AssetPaths.projectile_for_semantics(element_key, status_on_hit, _draw_color)
	var tex := AssetPaths.load_texture(path)
	for frame_path in AssetPaths.animation_frame_paths_for_texture(path, "fly"):
		var frame := AssetPaths.load_texture(frame_path)
		if frame:
			_animation_frames.append(frame)
	if tex:
		_sprite.texture = _animation_frames[0] if not _animation_frames.is_empty() else tex
		var scale_factor := _draw_radius / 8.0 * (1.0 + float(evolution_layer - 1) * 0.08 + float(synergy_rank) * 0.06)
		_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		_sprite.texture = null


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	_advance_sprite(delta)
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
	_draw_trail_texture()
	if _sprite and _sprite.texture != null:
		return
	push_error("Projectile missing image2 core texture for element `%s` status `%s`" % [element_key, status_on_hit])


func _draw_trail_texture() -> void:
	if _trail_texture == null:
		push_error("Projectile missing image2 trail texture for element `%s` status `%s`" % [element_key, status_on_hit])
		return
	var branch_scale := 1.0
	match _trail_style:
		"fire":
			branch_scale = 1.05
		"sword":
			branch_scale = 0.92
		"thunder":
			branch_scale = 1.10
		"ice":
			branch_scale = 1.05
	var tail_length := clampf(
		_draw_radius * (4.4 + float(evolution_layer - 1) * 0.36 + float(synergy_rank) * 0.22) * branch_scale,
		24.0,
		58.0
	)
	var tail_height := clampf(_draw_radius * (1.56 + float(evolution_layer - 1) * 0.06), 10.0, 22.0)
	var rect := Rect2(Vector2(-tail_length, -tail_height * 0.5), Vector2(tail_length, tail_height))
	draw_texture_rect(_trail_texture, rect, false, _trail_modulate())


func _on_body_entered(body: Node) -> void:
	if body in _hit_bodies:
		return
	if not body.has_method("receive_projectile_hit"):
		return
	_hit_bodies.append(body)
	_spawn_hit_feedback()
	body.receive_projectile_hit(self)
	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()


func _hit_color() -> Color:
	return StatusComponent.status_color(status_on_hit) if not status_on_hit.is_empty() else _draw_color


func _spawn_hit_feedback() -> void:
	var anchor := "hit_light"
	if _trail_style == "fire":
		anchor = "spell_fire"
	elif _trail_style == "sword":
		anchor = "spell_sword"
	elif _trail_style == "thunder":
		anchor = "spell_thunder"
	elif _trail_style == "ice":
		anchor = "spell_ice"
	if VfxManager.has_method("spawn_hit_feedback"):
		VfxManager.spawn_hit_feedback(global_position, element_key, status_on_hit, _hit_color(), vfx_tier)
	EventBus.feedback_anchor_requested.emit(anchor, {
		"world_position": Vector2.INF,
		"color": _hit_color(),
		"element": element_key,
		"status": status_on_hit,
		"tier": vfx_tier,
		"freeze": 0.0 if anchor == "hit_light" else 0.025 + float(evolution_layer - 1) * 0.01,
		"shake": 0.0 if anchor == "hit_light" else 3.0 + float(evolution_layer - 1) * 1.5 + float(synergy_rank) * 1.2,
	})


func _resolve_trail_style(source: String, element: String, status_name: String) -> String:
	if source.find("yu_jian") >= 0 or source.find("sword") >= 0:
		return "sword"
	if source.find("lei_") >= 0 or element == "thunder":
		return "thunder"
	if source.find("xuan_bing") >= 0 or element == "water" or status_name == "slow" or status_name == "freeze":
		return "ice"
	if source.find("lie_yan") >= 0 or element == "fire" or status_name == "burn":
		return "fire"
	if source.find("qi_fu") >= 0 or source.find("talisman") >= 0:
		return "default"
	return "default"


func _trail_modulate() -> Color:
	var color := _draw_color
	match _trail_style:
		"fire":
			color = color.lerp(Color(1.0, 0.26, 0.08), 0.18)
		"sword":
			color = color.lerp(Color(0.50, 0.88, 1.0), 0.20)
		"thunder":
			color = color.lerp(Color(0.74, 0.56, 1.0), 0.22)
		"ice":
			color = color.lerp(Color(0.44, 0.88, 1.0), 0.20)
	color.a = clampf(0.22 + float(evolution_layer - 1) * 0.022 + float(synergy_rank) * 0.010, 0.20, 0.32)
	return color


func get_trail_texture_hit_count() -> int:
	return 1 if _trail_texture != null else 0


func get_trail_texture_path() -> String:
	return AssetPaths.projectile_trail(element_key, status_on_hit)


func get_core_texture_hit_count() -> int:
	return 1 if _sprite != null and _sprite.texture != null else 0


func get_core_texture_path() -> String:
	return AssetPaths.projectile_for_semantics(element_key, status_on_hit, _draw_color)
