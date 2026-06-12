extends Control
class_name HudHpBar
## 渐变真元条 — 受击闪白 + 低血量由 HUD 外层控制 modulate

var max_value: float = 100.0
var value: float = 100.0

const _BG := Color(0.04, 0.04, 0.07, 0.85)
const _FILL_START := Color(0.82, 0.28, 0.32, 1.0)
const _FILL_END := Color(1.0, 0.52, 0.42, 1.0)
const _GLOW := Color(1.0, 0.45, 0.38, 0.35)
const _RIM := Color(1, 1, 1, 0.14)


func _ready() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_values(current: float, maximum: float) -> void:
	max_value = maxf(maximum, 1.0)
	value = clampf(current, 0.0, max_value)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var radius := h * 0.5
	var bg_rect := Rect2(0, 1, w, h - 2)
	draw_rect(bg_rect, _BG, true)
	draw_rect(bg_rect, _RIM, false, 1.0)
	var ratio := value / max_value
	if ratio <= 0.001:
		return
	var fill_w := maxf((w - 4.0) * ratio, radius)
	var fill_rect := Rect2(2, 3, fill_w, h - 6)
	var steps := 12
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var seg_x := fill_rect.position.x + fill_rect.size.x * t0
		var seg_w := fill_rect.size.x * (t1 - t0)
		if seg_w <= 0.01:
			continue
		var c := _FILL_START.lerp(_FILL_END, t0 + (t1 - t0) * 0.5)
		draw_rect(Rect2(seg_x, fill_rect.position.y, seg_w, fill_rect.size.y), c, true)
	if ratio > 0.08:
		draw_rect(Rect2(fill_rect.position.x, fill_rect.position.y, minf(fill_w * 0.35, 28.0), fill_rect.size.y), _GLOW, true)
	draw_rect(Rect2(fill_rect.position.x + fill_w - 2.0, fill_rect.position.y, 2.0, fill_rect.size.y), Color(1, 0.92, 0.82, 0.55), true)
