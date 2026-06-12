extends PanelContainer
class_name HudCharacterPanel

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel_frame: TextureRect = $PanelFrame
@onready var accent_stripe: ColorRect = $AccentStripe
@onready var title_label: Label = %TitleLabel
@onready var wave_label: Label = %WaveLabel
@onready var seed_label: Label = %SeedLabel
@onready var hp_bar: HudResourceBar = %HpBar
@onready var mana_bar: HudResourceBar = %ManaBar
@onready var combo_badge: PanelContainer = %ComboBadge
@onready var combo_label: Label = %ComboLabel
@onready var realm_badge: PanelContainer = %RealmBadge
@onready var realm_label: Label = %RealmLabel
@onready var build_label: Label = %BuildLabel
@onready var dao_label: Label = %DaoLabel
@onready var combo_track_bar: ProgressBar = %ComboTrackBar
@onready var combo_track_label: Label = %ComboTrackLabel
@onready var affix_label: Label = %AffixLabel
@onready var skill_label: Label = %SkillLabel
@onready var gold_icon: TextureRect = %GoldIcon
@onready var gold_label: Label = %GoldLabel

var stage_accent := UiTokens.ACCENT_GOLD


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_polish()
	_style_info_labels()


func apply_polish() -> void:
	add_theme_stylebox_override("panel", HudStyles.left_scroll_panel(stage_accent))
	accent_stripe.color = Color(stage_accent.r, stage_accent.g, stage_accent.b, 0.88)
	call_deferred("_layout_decorations")
	realm_badge.add_theme_stylebox_override("panel", HudStyles.realm_badge())
	combo_badge.add_theme_stylebox_override("panel", HudStyles.combo_badge(false))
	_apply_combo_track_style()
	var scroll_tex := AssetPaths.load_texture(AssetPaths.HUD_PANEL_BG)
	if scroll_tex and panel_frame:
		panel_frame.texture = scroll_tex
		panel_frame.modulate = Color(1, 1, 1, 0.42)
	var gold_tex := AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
	if gold_tex:
		gold_icon.texture = gold_tex


func _layout_decorations() -> void:
	panel_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_frame.offset_left = 6
	panel_frame.offset_top = 4
	panel_frame.offset_right = -6
	panel_frame.offset_bottom = -4
	accent_stripe.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent_stripe.offset_left = 0
	accent_stripe.offset_top = 10
	accent_stripe.offset_right = 3
	accent_stripe.offset_bottom = -10
	move_child(panel_frame, 0)
	move_child(accent_stripe, 1)
	move_child(get_node("Margin"), get_child_count() - 1)


func apply_stage_accent(stage_index: int) -> void:
	stage_accent = UiTokens.stage_accent(stage_index)
	title_label.add_theme_color_override("font_color", stage_accent)
	wave_label.add_theme_color_override("font_color", Color(stage_accent.r, stage_accent.g, stage_accent.b, 0.72))
	add_theme_stylebox_override("panel", HudStyles.left_scroll_panel(stage_accent))
	accent_stripe.color = Color(stage_accent.r, stage_accent.g, stage_accent.b, 0.88)


func update_combo_badge(count: int) -> void:
	var active := count > 0
	combo_badge.add_theme_stylebox_override("panel", HudStyles.combo_badge(active))
	if active:
		combo_label.add_theme_color_override("font_color", UiTokens.ELEM_FIRE)
	else:
		combo_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)


func get_build_fly_target_global() -> Vector2:
	return affix_label.global_position + Vector2(minf(affix_label.size.x, 160.0) * 0.5, 6.0)


func get_hp_flash_targets() -> Array:
	return [hp_bar.get_draw_bar(), hp_bar]


func _style_info_labels() -> void:
	for label in [build_label, dao_label, affix_label, skill_label, combo_track_label]:
		label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)


func _apply_combo_track_style() -> void:
	var fill := StyleBoxTexture.new()
	fill.texture = AssetPaths.load_texture(AssetPaths.COMBO_TRACK)
	if fill.texture:
		fill.texture_margin_left = 2
		fill.texture_margin_right = 2
		combo_track_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	combo_track_bar.add_theme_stylebox_override("background", bg)
