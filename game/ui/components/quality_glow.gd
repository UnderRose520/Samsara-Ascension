extends Control
class_name QualityGlow
## 仙品及以上词条卡片外发光脉冲

@export var glow_color: Color = Color(1.0, 0.843, 0.0, 0.35)
@export var pulse_speed: float = 1.6

var _strength: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)


func _process(_delta: float) -> void:
	_strength = 0.5 + sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * 0.5
	queue_redraw()


func _draw() -> void:
	var inset := 4.0
	var rect := Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0)
	var c := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * _strength)
	draw_rect(rect, c, false, 2.0)
