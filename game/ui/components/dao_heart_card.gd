extends PanelContainer
class_name DaoHeartCard
## 道心选择大卡片 — Setup 界面

signal selected(mode_id: String)

const UiTokens := preload("res://ui/theme/ui_tokens.gd")
const UiAnimations := preload("res://ui/ui_animations.gd")

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _glow: ColorRect = %Glow

var mode_id: String = ""
var _selected: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	_set_children_mouse_ignore(self)
	UiAnimations.bind_hover_lift(self, 3.0)


func setup(id: String, title: String, subtitle: String, icon_path: String) -> void:
	mode_id = id
	_title.text = title
	_subtitle.text = subtitle
	if ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	_set_selected(false)


func set_selected(on: bool) -> void:
	_selected = on
	_set_selected(on)


func _set_selected(on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.094, 0.243, 0.196, 0.96) if on else Color(0.051, 0.137, 0.114, 0.82)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	# 选中：柔和暖金细边 + 金色辉光；未选中：极淡金边，无硬描边
	sb.border_color = Color(0.93, 0.81, 0.46, 0.8) if on else Color(0.85, 0.78, 0.55, 0.16)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	if on:
		sb.shadow_color = Color(1.0, 0.84, 0.4, 0.3)
		sb.shadow_size = 16
	else:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
		sb.shadow_size = 5
	add_theme_stylebox_override("panel", sb)
	_glow.visible = on
	_glow.color = Color(1.0, 0.85, 0.42, 0.1 if on else 0.0)


func _set_children_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_children_mouse_ignore(child)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(mode_id)


func _on_hover_in() -> void:
	if not _selected:
		modulate = Color(1.05, 1.02, 0.98, 1.0)


func _on_hover_out() -> void:
	modulate = Color.WHITE
