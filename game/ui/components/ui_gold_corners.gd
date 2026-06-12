extends Control
class_name UiGoldCorners
## 四角金线装饰 — 用于 HUD 侧栏 / Modal 内框

@export var corner_color: Color = Color(1.0, 0.843, 0.0, 0.85)
@export var line_width: float = 2.5
@export var corner_len: float = 18.0
@export var inset: float = 4.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var l := corner_len
	var i := inset
	var c := corner_color
	# 左上
	draw_line(Vector2(i, i + l), Vector2(i, i), c, line_width)
	draw_line(Vector2(i, i), Vector2(i + l, i), c, line_width)
	# 右上
	draw_line(Vector2(w - i - l, i), Vector2(w - i, i), c, line_width)
	draw_line(Vector2(w - i, i), Vector2(w - i, i + l), c, line_width)
	# 左下
	draw_line(Vector2(i, h - i - l), Vector2(i, h - i), c, line_width)
	draw_line(Vector2(i, h - i), Vector2(i + l, h - i), c, line_width)
	# 右下
	draw_line(Vector2(w - i - l, h - i), Vector2(w - i, h - i), c, line_width)
	draw_line(Vector2(w - i, h - i - l), Vector2(w - i, h - i), c, line_width)
