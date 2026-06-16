extends PanelContainer
class_name HudCharacterPanel

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

const OBJECTIVE_SAFE_TIME_COLOR := Color(0.82, 0.94, 0.86, 0.96)
const OBJECTIVE_WARNING_TIME_COLOR := Color(1.0, 0.58, 0.36, 1.0)

@onready var panel_frame: TextureRect = $PanelFrame
@onready var accent_stripe: ColorRect = $AccentStripe
@onready var title_label: Label = %TitleLabel
@onready var wave_label: Label = %WaveLabel
@onready var objective_panel: PanelContainer = %ObjectivePanel
@onready var objective_title_label: Label = %ObjectiveTitleLabel
@onready var objective_timer_label: Label = %ObjectiveTimerLabel
@onready var objective_progress: ProgressBar = %ObjectiveProgress
@onready var objective_detail_label: Label = %ObjectiveDetailLabel
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
	objective_panel.add_theme_stylebox_override("panel", HudStyles.objective_panel(stage_accent))
	_apply_objective_progress_style()
	_apply_combo_track_style()
	_apply_readability_polish()
	var scroll_tex := AssetPaths.load_texture(AssetPaths.HUD_PANEL_BG)
	if scroll_tex and panel_frame:
		panel_frame.texture = scroll_tex
		panel_frame.modulate = Color(0.95, 1.0, 0.88, 0.18)
	var gold_tex := AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
	if gold_tex:
		gold_icon.texture = gold_tex
	_compact_text_labels()


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
	title_label.add_theme_color_override("font_color", stage_accent.lightened(0.28))
	wave_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72, 0.96))
	add_theme_stylebox_override("panel", HudStyles.left_scroll_panel(stage_accent))
	objective_panel.add_theme_stylebox_override("panel", HudStyles.objective_panel(stage_accent))
	_apply_objective_progress_style()
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


func show_objective(
	title: String,
	kills: int,
	quota: int,
	time_left: String,
	wave: int,
	next_wave_in: float,
) -> void:
	objective_panel.visible = quota > 0
	if quota <= 0:
		return
	objective_title_label.text = title
	objective_progress.max_value = maxi(quota, 1)
	objective_progress.value = clampi(kills, 0, quota)
	objective_timer_label.text = "下波 %.1fs" % next_wave_in if next_wave_in > 0.05 else "下波将至"
	objective_detail_label.text = "斩魔 %d/%d / 第%d波 / 剩 %s" % [kills, quota, maxi(wave, 1), time_left]
	if next_wave_in <= 1.5:
		objective_timer_label.add_theme_color_override("font_color", OBJECTIVE_WARNING_TIME_COLOR)
	else:
		objective_timer_label.add_theme_color_override("font_color", OBJECTIVE_SAFE_TIME_COLOR)


func hide_objective() -> void:
	objective_panel.visible = false


func _style_info_labels() -> void:
	for label in [build_label, dao_label, affix_label, skill_label, combo_track_label]:
		label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72, 0.98))


func _compact_text_labels() -> void:
	for label in [
		wave_label,
		seed_label,
		realm_label,
		build_label,
		dao_label,
		combo_track_label,
		affix_label,
		skill_label,
	]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true


func _apply_readability_polish() -> void:
	title_label.add_theme_color_override("font_color", stage_accent.lightened(0.28))
	wave_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72, 0.96))
	for label in [
		title_label,
		wave_label,
		objective_title_label,
		objective_timer_label,
		objective_detail_label,
		seed_label,
		combo_label,
		realm_label,
		build_label,
		dao_label,
		combo_track_label,
		affix_label,
		skill_label,
		gold_label,
	]:
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))


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


func _apply_objective_progress_style() -> void:
	objective_progress.add_theme_stylebox_override("fill", HudStyles.objective_bar_fill(stage_accent))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.38)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	objective_progress.add_theme_stylebox_override("background", bg)
