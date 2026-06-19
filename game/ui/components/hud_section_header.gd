extends Control
class_name HudSectionHeader

const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@export var title: String = "":
	set(v):
		title = v
		if _label:
			_label.text = v
		queue_redraw()

var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = title
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	_label.add_theme_constant_override("outline_size", 1)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(_label)
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func _on_resized() -> void:
	if _label:
		_label.position = Vector2(0, 1)


func _draw() -> void:
	if _label == null:
		return
	var line_y := 11.0
	var start_x := _label.size.x + 10.0
	if start_x < size.x - 12.0:
		draw_line(Vector2(start_x, line_y), Vector2(size.x - 4.0, line_y), Color(1, 0.843, 0, 0.16), 1.0)
