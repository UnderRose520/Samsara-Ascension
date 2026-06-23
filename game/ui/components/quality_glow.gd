extends Control
class_name QualityGlow
## Texture-backed reward-card quality aura.

const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@export var glow_color: Color = Color(1.0, 0.843, 0.0, 0.35)
@export var pulse_speed: float = 1.6

var quality_tier: int = 0
var forbidden: bool = false
var locked: bool = false
var hovered: bool = false
var confirm_armed: bool = false

var _strength: float = 0.0
var _time: float = 0.0
var _texture_hit_count := 0
var _edge_layers: Array[TextureRect] = []
var _particle_layers: Array[TextureRect] = []
var _forbidden_layers: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_rebuild_texture_layers()


func configure(tier: int, is_forbidden: bool = false, is_locked: bool = false) -> void:
	quality_tier = clampi(tier, 0, 4)
	forbidden = is_forbidden
	locked = is_locked
	visible = not locked and (quality_tier >= 1 or forbidden)
	set_process(visible)
	_apply_texture_palette()
	_update_texture_layers()


func set_hovered(value: bool) -> void:
	hovered = value
	_update_texture_layers()


func set_confirm_armed(value: bool) -> void:
	confirm_armed = value
	_update_texture_layers()


func get_texture_hit_count() -> int:
	return _texture_hit_count


func get_particle_texture_count() -> int:
	return _visible_texture_count(_particle_layers)


func get_forbidden_texture_count() -> int:
	return _visible_texture_count(_forbidden_layers)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_texture_layers()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_strength = 0.5 + sin(_time * pulse_speed) * 0.5
	_update_texture_layers()


func _rebuild_texture_layers() -> void:
	_clear_children()
	_texture_hit_count = 0
	_edge_layers.clear()
	_particle_layers.clear()
	_forbidden_layers.clear()

	var frame_texture := AssetPaths.load_texture(AssetPaths.REWARD_QUALITY_AURA)
	var particle_texture := AssetPaths.load_texture(AssetPaths.REWARD_QUALITY_MOTE)
	var reverse_texture := AssetPaths.load_texture(AssetPaths.REWARD_FORBIDDEN_REVERSE_MARK)

	for i in 4:
		var edge := _make_texture_layer("QualityEdge_%d" % i, frame_texture)
		edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		edge.stretch_mode = TextureRect.STRETCH_SCALE
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.z_index = 1
		_edge_layers.append(edge)
		add_child(edge)
		_texture_hit_count += int(frame_texture != null)

	for i in 10:
		var mote := _make_texture_layer("QualityMote_%02d" % i, particle_texture)
		mote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.z_index = 2
		_particle_layers.append(mote)
		add_child(mote)
		_texture_hit_count += int(particle_texture != null)

	for i in 6:
		var mark := _make_texture_layer("ForbiddenReverseMark_%02d" % i, reverse_texture)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.z_index = 3
		_forbidden_layers.append(mark)
		add_child(mark)
		_texture_hit_count += int(reverse_texture != null)

	_apply_texture_palette()
	_update_texture_layers()


func _make_texture_layer(node_name: String, texture: Texture2D) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.texture = texture
	node.visible = false
	return node


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _apply_texture_palette() -> void:
	var base := _effect_color()
	for i in _edge_layers.size():
		var edge := _edge_layers[i]
		edge.modulate = Color(base.r, base.g, base.b, 0.0)
	for i in _particle_layers.size():
		var mote := _particle_layers[i]
		var seed := _hash01(i)
		var color := _particle_color(base, i, seed, 1.0)
		mote.modulate = color
	for i in _forbidden_layers.size():
		var mark := _forbidden_layers[i]
		var color := UiTokens.ACCENT_BLOOD.lerp(UiTokens.ELEM_CHAOS, 0.35 + _hash01(i + 11) * 0.25)
		mark.modulate = Color(color.r, color.g, color.b, 0.0)


func _update_texture_layers() -> void:
	if _edge_layers.is_empty():
		return
	if not visible or size.x <= 8.0 or size.y <= 8.0:
		for layer in _edge_layers + _particle_layers + _forbidden_layers:
			layer.visible = false
		return
	var rect := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
	var base := _effect_color()
	var intensity := 0.66 + _strength * 0.22
	if hovered:
		intensity += 0.10
	if confirm_armed:
		intensity += 0.16
	_update_edge_layers(rect, base, intensity)
	_update_particle_layers(rect, base, intensity)
	_update_forbidden_layers(rect, intensity)


func _update_edge_layers(rect: Rect2, base: Color, intensity: float) -> void:
	var visible_edges := 2 if quality_tier < 3 and not forbidden else 4
	for i in _edge_layers.size():
		var edge := _edge_layers[i]
		edge.visible = i < visible_edges
		if not edge.visible:
			continue
		var grow := 3.0 + float(i) * 3.5 + (1.0 + _strength * 2.0 if i >= 2 else 0.0)
		edge.position = rect.position - Vector2(grow, grow)
		edge.size = rect.size + Vector2(grow * 2.0, grow * 2.0)
		var alpha := base.a * (0.11 + float(i) * 0.045) * intensity
		edge.modulate = Color(base.r, base.g, base.b, minf(alpha, 0.28))


func _update_particle_layers(rect: Rect2, base: Color, intensity: float) -> void:
	var count := _particle_count()
	var direction := -1.0 if forbidden else 1.0
	for i in _particle_layers.size():
		var mote := _particle_layers[i]
		mote.visible = i < count
		if not mote.visible:
			continue
		var seed := _hash01(i)
		var progress := seed + _time * (0.018 + float(quality_tier) * 0.006) * direction + float(i) * 0.071
		var pos := _point_on_edge(rect, progress)
		var wobble := Vector2(
			sin(_time * (1.05 + seed) + float(i) * 2.31),
			cos(_time * (0.86 + seed) + float(i) * 1.67)
		) * (1.4 + float(quality_tier) * 0.36)
		var side := _particle_size(i, seed)
		mote.position = pos + wobble - Vector2(side, side) * 0.5
		mote.size = Vector2(side, side)
		mote.rotation = _time * (0.35 + seed * 0.8) * direction + seed * TAU
		mote.modulate = _particle_color(base, i, seed, intensity)


func _update_forbidden_layers(rect: Rect2, intensity: float) -> void:
	var count := 6 if forbidden else 0
	var center := rect.get_center()
	for i in _forbidden_layers.size():
		var mark := _forbidden_layers[i]
		mark.visible = i < count
		if not mark.visible:
			continue
		var seed := _hash01(i + 31)
		var progress := seed - _time * (0.028 if confirm_armed else 0.018)
		var pos := _point_on_edge(rect, progress)
		var inward := (center - pos).normalized()
		var long_side := 22.0 + seed * 16.0
		var short_side := 8.0 + _hash01(i + 57) * 4.0
		mark.position = pos + inward * 5.0 - Vector2(long_side, short_side) * 0.5
		mark.size = Vector2(long_side, short_side)
		mark.rotation = inward.angle()
		var color := UiTokens.ACCENT_BLOOD.lerp(UiTokens.ELEM_CHAOS, 0.35 + seed * 0.25)
		mark.modulate = Color(color.r, color.g, color.b, minf(0.18 * intensity + (0.08 if confirm_armed else 0.0), 0.34))


func _effect_color() -> Color:
	var color := glow_color
	if forbidden:
		color = UiTokens.ELEM_CHAOS.lerp(UiTokens.ACCENT_BLOOD, 0.48)
	color.a = maxf(color.a, 0.22)
	return color


func _particle_count() -> int:
	if forbidden:
		return 8 if confirm_armed else 6
	match quality_tier:
		1:
			return 3
		2:
			return 5
		3:
			return 8
		4:
			return 10
		_:
			return 0


func _particle_size(index: int, seed: float) -> float:
	var pulse := 0.5 + sin(_time * (1.4 + seed) + float(index) * 1.91) * 0.5
	match quality_tier:
		1:
			return lerpf(6.0, 8.0, pulse)
		2:
			return lerpf(6.0, 9.0, pulse)
		3:
			return lerpf(5.0, 10.0, pulse)
		4:
			return lerpf(6.0, 11.0, pulse)
		_:
			return 6.0


func _particle_color(base: Color, index: int, seed: float, intensity: float) -> Color:
	var c := base
	if forbidden:
		c = UiTokens.ELEM_CHAOS.lerp(UiTokens.ACCENT_BLOOD, 0.55 + seed * 0.25)
	elif quality_tier == 3:
		c = base.lerp(UiTokens.ACCENT_GOLD, 0.38 + seed * 0.24)
	elif quality_tier >= 4:
		c = base.lerp(UiTokens.ACCENT_GOLD, 0.28 if index % 2 == 0 else 0.62)
	var alpha := (0.19 + seed * 0.15) * intensity
	if hovered:
		alpha += 0.05
	if confirm_armed:
		alpha += 0.10
	c.a = minf(alpha, 0.50)
	return c


func _point_on_edge(rect: Rect2, progress: float) -> Vector2:
	var perimeter := rect.size.x * 2.0 + rect.size.y * 2.0
	var distance := fposmod(progress, 1.0) * perimeter
	if distance < rect.size.x:
		return rect.position + Vector2(distance, 0.0)
	distance -= rect.size.x
	if distance < rect.size.y:
		return Vector2(rect.end.x, rect.position.y + distance)
	distance -= rect.size.y
	if distance < rect.size.x:
		return Vector2(rect.end.x - distance, rect.end.y)
	distance -= rect.size.x
	return Vector2(rect.position.x, rect.end.y - distance)


func _visible_texture_count(layers: Array[TextureRect]) -> int:
	var count := 0
	for layer in layers:
		if layer.visible and layer.texture != null:
			count += 1
	return count


func _hash01(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898 + float(quality_tier) * 78.233) * 43758.5453, 1.0)
