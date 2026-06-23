extends Control
class_name WorldEnemyHealthBar

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var bar: ProgressBar = $Bar
@onready var value_label: Label = $ValueLabel

var _texture_style_hits := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_styles()
	EventBus.display_settings_changed.connect(_apply_visibility)
	_apply_visibility()


func _apply_styles() -> void:
	_texture_style_hits = 0
	var base_texture := AssetPaths.load_texture(AssetPaths.ENEMY_HP_BAR)
	if base_texture == null:
		push_warning("WorldEnemyHealthBar missing image2 texture: %s" % AssetPaths.ENEMY_HP_BAR)
		bar.visible = false
		return
	var bg := _make_enemy_hp_style(Color(0.33, 0.52, 0.48, 0.46))
	var fill := _make_enemy_hp_style(Color(UiTokens.STATE_HP.r, UiTokens.STATE_HP.g, UiTokens.STATE_HP.b, 0.92))
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	_texture_style_hits = 2


func _make_enemy_hp_style(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = AssetPaths.load_texture(AssetPaths.ENEMY_HP_BAR)
	sb.texture_margin_left = 8
	sb.texture_margin_top = 2
	sb.texture_margin_right = 8
	sb.texture_margin_bottom = 2
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	sb.modulate_color = tint
	return sb


func set_values(current: float, maximum: float, show_numbers: bool = true) -> void:
	bar.max_value = maxf(maximum, 1.0)
	bar.value = maxf(current, 0.0)
	value_label.visible = show_numbers and SaveManager.get_display_setting("show_enemy_hp")
	if not show_numbers or current <= 0.01:
		value_label.text = "0/%.0f" % maximum if show_numbers else ""
	else:
		value_label.text = "%d/%.0f" % [ceili(current), maximum]


func _apply_visibility() -> void:
	var show_hp := SaveManager.get_display_setting("show_enemy_hp")
	visible = show_hp
	bar.visible = show_hp and _texture_style_hits > 0
	value_label.visible = show_hp and not value_label.text.is_empty()


func get_texture_style_hit_count() -> int:
	return _texture_style_hits
