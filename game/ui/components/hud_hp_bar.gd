extends Control
class_name HudHpBar
## 渐变真元条 — 受击闪白 + 低血量由 HUD 外层控制 modulate

const AssetPaths = preload("res://assets/asset_paths.gd")

var max_value: float = 100.0
var value: float = 100.0

var _track_texture: Texture2D
var _fill_texture: Texture2D
var _track_texture_hits := 0
var _fill_texture_hits := 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_texture = AssetPaths.load_texture(AssetPaths.HUD_LEFT_RESOURCE_TRACK)
	_fill_texture = AssetPaths.load_texture(AssetPaths.PROGRESS_HP)
	resized.connect(queue_redraw)


func set_values(current: float, maximum: float) -> void:
	max_value = maxf(maximum, 1.0)
	value = clampf(current, 0.0, max_value)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	_track_texture_hits = 0
	_fill_texture_hits = 0
	var bg_rect := Rect2(0, 1, w, h - 2)
	if _track_texture:
		draw_texture_rect(_track_texture, bg_rect, false, Color(0.58, 0.82, 0.78, 0.62))
		_track_texture_hits += 1
	var ratio := value / max_value
	if ratio <= 0.001:
		return
	var fill_w := maxf((w - 4.0) * ratio, h * 0.5)
	var fill_rect := Rect2(2, 3, fill_w, h - 6)
	if _fill_texture:
		draw_texture_rect(_fill_texture, fill_rect, false, Color(1.15, 0.86, 0.80, 0.98))
		_fill_texture_hits += 1
	if ratio > 0.08:
		var glow_rect := Rect2(fill_rect.position.x, fill_rect.position.y, minf(fill_w * 0.38, 36.0), fill_rect.size.y)
		if _fill_texture:
			draw_texture_rect(_fill_texture, glow_rect, false, Color(1.35, 1.04, 0.92, 0.34))
			_fill_texture_hits += 1
	if _track_texture:
		var cap_rect := Rect2(fill_rect.position.x + fill_w - 5.0, fill_rect.position.y - 2.0, 10.0, fill_rect.size.y + 4.0)
		draw_texture_rect(_track_texture, cap_rect, false, Color(1.10, 0.92, 0.70, 0.46))
		_track_texture_hits += 1


func get_track_texture_hit_count() -> int:
	return _track_texture_hits


func get_fill_texture_hit_count() -> int:
	return _fill_texture_hits
