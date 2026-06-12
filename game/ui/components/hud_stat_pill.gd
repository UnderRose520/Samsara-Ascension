extends PanelContainer
class_name HudStatPill

@onready var icon: TextureRect = $Margin/HBox/Icon
@onready var label: Label = $Margin/HBox/Label

var _accent := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(accent: Color) -> void:
	_accent = accent
	add_theme_stylebox_override("panel", HudStyles.stat_pill(accent))


func set_text(text: String) -> void:
	label.text = text


func set_icon(texture: Texture2D) -> void:
	icon.texture = texture
	icon.visible = texture != null


func set_accent(accent: Color) -> void:
	if _accent.is_equal_approx(accent):
		return
	_accent = accent
	add_theme_stylebox_override("panel", HudStyles.stat_pill(accent))
