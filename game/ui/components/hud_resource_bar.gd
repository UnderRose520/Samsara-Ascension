extends Control
class_name HudResourceBar

enum BarKind { HP, MANA }

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@export var bar_kind: BarKind = BarKind.HP

@onready var frame_bg: TextureRect = $FrameBg
@onready var hp_bar: HudHpBar = $HpBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var value_label: Label = $ValueLabel

var _placeholder_mana := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.clip_text = true
	_apply_frame_texture()
	if bar_kind == BarKind.HP:
		hp_bar.visible = true
		mana_bar.visible = false
		value_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		tooltip_text = "气血"
	else:
		hp_bar.visible = false
		mana_bar.visible = true
		_apply_mana_bar_styles()
		tooltip_text = "道势"
		set_values(0.0, 100.0)


func _apply_frame_texture() -> void:
	var tex := AssetPaths.load_texture(AssetPaths.HUD_LEFT_RESOURCE_TRACK)
	if tex and frame_bg:
		frame_bg.texture = tex
		frame_bg.visible = true
		frame_bg.modulate = Color(1, 1, 1, 0.96)


func _apply_mana_bar_styles() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.1, 0.85)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fill_tex := AssetPaths.load_texture(AssetPaths.PROGRESS_MANA)
	var fill: StyleBox
	if fill_tex:
		var sb := StyleBoxTexture.new()
		sb.texture = fill_tex
		sb.texture_margin_left = 8
		sb.texture_margin_top = 2
		sb.texture_margin_right = 8
		sb.texture_margin_bottom = 2
		fill = sb
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTokens.STATE_MANA
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		fill = sb
	mana_bar.add_theme_stylebox_override("background", bg)
	mana_bar.add_theme_stylebox_override("fill", fill)


func set_values(current: float, maximum: float) -> void:
	var max_v := maxf(maximum, 1.0)
	var cur_v := clampf(current, 0.0, max_v)
	if bar_kind == BarKind.HP:
		hp_bar.set_values(cur_v, max_v)
		value_label.text = "%.0f / %.0f" % [cur_v, max_v]
	else:
		mana_bar.max_value = max_v
		mana_bar.value = cur_v
		value_label.text = "道势 %.0f / %.0f" % [cur_v, max_v]
		value_label.modulate = Color.WHITE


func get_hp_row() -> Control:
	return self


func get_draw_bar() -> CanvasItem:
	return hp_bar if bar_kind == BarKind.HP else mana_bar


func get_track_texture_hit_count() -> int:
	if bar_kind == BarKind.HP and hp_bar != null and hp_bar.has_method("get_track_texture_hit_count"):
		return int(hp_bar.call("get_track_texture_hit_count"))
	return 1 if frame_bg != null and frame_bg.texture != null else 0


func get_fill_texture_hit_count() -> int:
	if bar_kind == BarKind.HP and hp_bar != null and hp_bar.has_method("get_fill_texture_hit_count"):
		return int(hp_bar.call("get_fill_texture_hit_count"))
	var fill_style := mana_bar.get_theme_stylebox("fill") if mana_bar != null else null
	if fill_style is StyleBoxTexture and (fill_style as StyleBoxTexture).texture != null:
		return 1
	return 0
