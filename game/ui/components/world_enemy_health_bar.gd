extends Control
class_name WorldEnemyHealthBar

const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var bar: ProgressBar = $Bar
@onready var value_label: Label = $ValueLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_styles()
	EventBus.display_settings_changed.connect(_apply_visibility)
	_apply_visibility()


func _apply_styles() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.18, 0.85)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.STATE_HP
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


func set_values(current: float, maximum: float, show_numbers: bool = true) -> void:
	bar.max_value = maxf(maximum, 1.0)
	bar.value = maxf(current, 0.0)
	if not show_numbers or current <= 0.01:
		value_label.text = "0/%.0f" % maximum if show_numbers else ""
	else:
		value_label.text = "%d/%.0f" % [ceili(current), maximum]


func _apply_visibility() -> void:
	var show_hp := SaveManager.get_display_setting("show_enemy_hp")
	visible = show_hp
	bar.visible = show_hp
	value_label.visible = show_hp
