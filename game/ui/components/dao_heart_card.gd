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
	sb.bg_color = UiTokens.BG_PANEL if not on else Color(0.12, 0.1, 0.08, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = UiTokens.ACCENT_GOLD if on else Color(1, 0.843, 0, 0.25)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(1, 0.843, 0, 0.35) if on else Color(0, 0, 0, 0.25)
	sb.shadow_size = 8 if on else 4
	add_theme_stylebox_override("panel", sb)
	_glow.visible = on
	_glow.color = Color(1, 0.843, 0, 0.08 if on else 0.0)
	if on:
		UiAnimations.pulse_gold(_title, 1)


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
