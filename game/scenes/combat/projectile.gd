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
var evolution_layer := 1
var evolution_branch := "base"
var synergy_rank := 0
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
	_trail_style = _resolve_trail_style(source_tag, element_key, status_on_hit)
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
		var scale_factor := _draw_radius / 8.0 * (1.0 + float(evolution_layer - 1) * 0.08 + float(synergy_rank) * 0.06)
		_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		_sprite.texture = null


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if _trail_style != "default" or not status_on_hit.is_empty():
		for i in _trail_points.size():
			_trail_points[i] -= velocity * delta
		_trail_points.push_front(Vector2.ZERO)
		if _trail_points.size() > _trail_length():
			_trail_points.pop_back()
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	_advance_sprite(delta)
	if _trail_style != "default" or not status_on_hit.is_empty() or not _sprite or _sprite.texture == null:
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
	match _trail_style:
		"fire":
			_draw_fire_trail(local_points)
		"sword":
			_draw_sword_trail(local_points)
		"thunder":
			_draw_thunder_trail(local_points)
		"ice":
			_draw_ice_trail(local_points)
		_:
			_draw_default_trail(local_points)


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
	EventBus.feedback_anchor_requested.emit(anchor, {
		"world_position": global_position,
		"color": _hit_color(),
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


func _trail_length() -> int:
	match _trail_style:
		"fire":
			return 10 + evolution_layer * 2 + synergy_rank
		"sword":
			return 7 + evolution_layer + synergy_rank
		"thunder":
			return 8 + evolution_layer * 2 + synergy_rank * 2
		"ice":
			return 9 + evolution_layer * 2 + synergy_rank * 2
	return 8


func _draw_default_trail(points: PackedVector2Array) -> void:
	for i in range(points.size() - 1):
		var alpha := 0.30 * (1.0 - float(i) / float(points.size()))
		var width := maxf(1.0, _draw_radius * (0.72 - float(i) * 0.06))
		draw_line(points[i], points[i + 1], Color(_draw_color.r, _draw_color.g, _draw_color.b, alpha), width, true)


func _draw_fire_trail(points: PackedVector2Array) -> void:
	for i in range(points.size() - 1):
		var t := 1.0 - float(i) / float(points.size())
		var branch_boost := 1.25 if evolution_branch in ["fire_burst", "fire_chain"] else 1.0
		var width := maxf(1.2, _draw_radius * (0.95 - float(i) * 0.055) * (1.0 + 0.12 * float(evolution_layer - 1) + 0.08 * float(synergy_rank)) * branch_boost)
		draw_line(points[i], points[i + 1], Color(1.0, 0.28 + 0.25 * t, 0.08, (0.44 + 0.08 * float(evolution_layer - 1)) * t), width, true)
		draw_circle(points[i], maxf(1.0, width * 0.36), Color(1.0, 0.72, 0.18, 0.22 * t))
		if evolution_branch == "fire_chain" and i % 3 == 0:
			draw_circle(points[i], maxf(1.0, width * 0.55), Color(1.0, 0.24, 0.06, 0.18 * t))


func _draw_sword_trail(points: PackedVector2Array) -> void:
	for i in range(points.size() - 1):
		var t := 1.0 - float(i) / float(points.size())
		var width := maxf(0.8, _draw_radius * (0.54 - float(i) * 0.035) * (1.0 + 0.12 * float(evolution_layer - 1) + 0.06 * float(synergy_rank)))
		draw_line(points[i], points[i + 1], Color(0.78, 0.94, 1.0, 0.62 * t), width, true)
		draw_line(points[i] + Vector2(0, -3), points[i + 1] + Vector2(0, -3), Color(1.0, 1.0, 1.0, 0.28 * t), 1.0, true)
		if evolution_branch == "sword_array":
			draw_line(points[i] + Vector2(0, 4), points[i + 1] + Vector2(0, 4), Color(0.52, 0.82, 1.0, 0.26 * t), 1.0, true)


func _draw_thunder_trail(points: PackedVector2Array) -> void:
	for i in range(points.size() - 1):
		var t := 1.0 - float(i) / float(points.size())
		var jitter := Vector2(sin(float(i) * 2.4 + _elapsed * 40.0), cos(float(i) * 1.7 + _elapsed * 35.0)) * (3.0 + float(evolution_layer - 1) + float(synergy_rank))
		draw_line(points[i] + jitter, points[i + 1] - jitter, Color(0.55, 0.82, 1.0, (0.56 + 0.08 * float(evolution_layer - 1)) * t), 2.2 + float(evolution_layer - 1) * 0.5 + float(synergy_rank) * 0.35, true)
		draw_line(points[i], points[i + 1], Color(1.0, 1.0, 0.75, 0.32 * t), 1.0, true)
		if evolution_branch == "thunder_net":
			draw_line(points[i] + jitter.rotated(1.5708), points[i + 1] - jitter.rotated(1.5708), Color(0.80, 0.95, 1.0, 0.24 * t), 1.0, true)


func _draw_ice_trail(points: PackedVector2Array) -> void:
	for i in range(points.size() - 1):
		var t := 1.0 - float(i) / float(points.size())
		draw_line(points[i], points[i + 1], Color(0.48, 0.92, 1.0, (0.38 + 0.08 * float(evolution_layer - 1)) * t), maxf(1.0, _draw_radius * 0.5 * (1.0 + 0.12 * float(evolution_layer - 1) + 0.08 * float(synergy_rank))), true)
		if i % 2 == 0:
			var p := points[i]
			draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color(0.82, 1.0, 1.0, 0.32 * t), 1.0)
			draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color(0.82, 1.0, 1.0, 0.32 * t), 1.0)
			if evolution_branch == "ice_domain":
				draw_circle(p, 3.6 + float(synergy_rank), Color(0.72, 0.96, 1.0, 0.14 * t))
