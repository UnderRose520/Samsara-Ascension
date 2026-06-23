extends Control
class_name HudCharacterPanel

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")

const OBJECTIVE_SAFE_TIME_COLOR := Color(0.82, 0.94, 0.86, 0.96)
const OBJECTIVE_WARNING_TIME_COLOR := Color(1.0, 0.58, 0.36, 1.0)

@onready var panel_frame: TextureRect = $PanelFrame
@onready var accent_stripe: ColorRect = $AccentStripe
@onready var margin: MarginContainer = $Margin
@onready var avatar_frame: PanelContainer = %AvatarFrame
@onready var title_label: Label = %TitleLabel
@onready var wave_label: Label = %WaveLabel
@onready var objective_panel: PanelContainer = %ObjectivePanel
@onready var objective_frame: TextureRect = %ObjectiveFrame
@onready var objective_title_label: Label = %ObjectiveTitleLabel
@onready var objective_timer_label: Label = %ObjectiveTimerLabel
@onready var objective_progress: ProgressBar = %ObjectiveProgress
@onready var objective_detail_label: Label = %ObjectiveDetailLabel
@onready var seed_label: Label = %SeedLabel
@onready var combat_divider: TextureRect = %CombatDivider
@onready var hp_bar: HudResourceBar = %HpBar
@onready var mana_bar: HudResourceBar = %ManaBar
@onready var combo_badge: PanelContainer = %ComboBadge
@onready var combo_label: Label = %ComboLabel
@onready var realm_badge: PanelContainer = %RealmBadge
@onready var realm_label: Label = %RealmLabel
@onready var build_label: Label = %BuildLabel
@onready var affix_rune_row: HBoxContainer = %AffixRuneRow
@onready var dao_label: Label = %DaoLabel
@onready var build_badge_frame: TextureRect = %BuildBadgeFrame
@onready var combo_track_bar: ProgressBar = %ComboTrackBar
@onready var combo_track_label: Label = %ComboTrackLabel
@onready var affix_label: Label = %AffixLabel
@onready var skill_label: Label = %SkillLabel
@onready var gold_icon: TextureRect = %GoldIcon
@onready var gold_label: Label = %GoldLabel

var stage_accent := UiTokens.ACCENT_GOLD
var _rune_slots: Array[PanelContainer] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collect_rune_slots()
	apply_polish()
	_style_info_labels()
	update_affix_runes([], [])


func apply_polish() -> void:
	accent_stripe.visible = false
	call_deferred("_layout_decorations")
	avatar_frame.add_theme_stylebox_override("panel", HudStyles.vital_avatar_frame(stage_accent))
	realm_badge.add_theme_stylebox_override("panel", HudStyles.transparent_panel())
	combo_badge.add_theme_stylebox_override("panel", HudStyles.combo_badge(false))
	_apply_rune_slot_styles()
	objective_panel.add_theme_stylebox_override("panel", HudStyles.objective_panel(stage_accent))
	_apply_texture(objective_frame, AssetPaths.HUD_LEFT_OBJECTIVE_CARD, 1.0)
	_apply_texture(build_badge_frame, AssetPaths.HUD_LEFT_BUILD_BADGE, 0.58)
	_apply_texture(combat_divider, AssetPaths.HUD_LEFT_SECTION_DIVIDER, 0.72)
	_apply_objective_progress_style()
	_apply_combo_track_style()
	_apply_readability_polish()
	var scroll_tex := AssetPaths.load_texture(AssetPaths.HUD_LEFT_PANEL_FRAME)
	if scroll_tex and panel_frame:
		panel_frame.texture = scroll_tex
		panel_frame.modulate = Color(1.0, 1.0, 1.0, 0.34)
		panel_frame.visible = true
	var gold_tex := AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
	if gold_tex:
		gold_icon.texture = gold_tex
	_compact_text_labels()


func _layout_decorations() -> void:
	panel_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_frame.offset_left = 0
	panel_frame.offset_top = 0
	panel_frame.offset_right = 0
	panel_frame.offset_bottom = 0
	panel_frame.visible = panel_frame.texture != null
	_layout_full_rect_texture(objective_frame)
	_layout_full_rect_texture(build_badge_frame)
	accent_stripe.visible = false
	move_child(panel_frame, 0)
	move_child(accent_stripe, 1)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 0
	margin.offset_top = 0
	margin.offset_right = 0
	margin.offset_bottom = 0
	move_child(margin, get_child_count() - 1)
	_layout_rune_slots()


func _layout_full_rect_texture(target: TextureRect) -> void:
	if target == null:
		return
	target.set_anchors_preset(Control.PRESET_FULL_RECT)
	target.offset_left = 0
	target.offset_top = 0
	target.offset_right = 0
	target.offset_bottom = 0
	var parent_node := target.get_parent()
	if parent_node:
		parent_node.move_child(target, 0)


func _layout_rune_slots() -> void:
	for slot in _rune_slots:
		var icon := slot.get_node("Icon") as TextureRect
		var label := slot.get_node("Text") as Label
		if icon:
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 2
			icon.offset_top = 2
			icon.offset_right = -2
			icon.offset_bottom = -2
		if label:
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.offset_left = 0
			label.offset_top = 0
			label.offset_right = 0
			label.offset_bottom = 0


func apply_stage_accent(stage_index: int) -> void:
	stage_accent = UiTokens.stage_accent(stage_index)
	title_label.add_theme_color_override("font_color", stage_accent.lightened(0.28))
	wave_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72, 0.96))
	objective_panel.add_theme_stylebox_override("panel", HudStyles.objective_panel(stage_accent))
	avatar_frame.add_theme_stylebox_override("panel", HudStyles.vital_avatar_frame(stage_accent))
	realm_badge.add_theme_stylebox_override("panel", HudStyles.transparent_panel())
	_apply_rune_slot_styles()
	_apply_objective_progress_style()
	accent_stripe.visible = false
	if panel_frame:
		panel_frame.self_modulate = Color(stage_accent.r, stage_accent.g, stage_accent.b, 0.9)


func update_combo_badge(count: int) -> void:
	var active := count > 0
	combo_badge.add_theme_stylebox_override("panel", HudStyles.combo_badge(active))
	if active:
		combo_label.add_theme_color_override("font_color", UiTokens.ELEM_FIRE)
	else:
		combo_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)


func update_affix_runes(equipped: Array, sealed: Array) -> void:
	if _rune_slots.is_empty():
		_collect_rune_slots()
	var max_active := mini(maxi(_rune_slots.size() - 1, 0), 5)
	for i in _rune_slots.size():
		var slot := _rune_slots[i]
		var icon := slot.get_node("Icon") as TextureRect
		var label := slot.get_node("Text") as Label
		if i < max_active:
			if i < equipped.size():
				_apply_rune_slot(slot, icon, label, equipped[i], false)
			else:
				_apply_empty_rune_slot(slot, icon, label, "无")
		else:
			if sealed.size() > 0:
				_apply_rune_slot(slot, icon, label, sealed[0], true)
			else:
				_apply_empty_rune_slot(slot, icon, label, "封")


func _collect_rune_slots() -> void:
	_rune_slots.clear()
	if affix_rune_row == null:
		return
	for child in affix_rune_row.get_children():
		var slot := child as PanelContainer
		if slot:
			_rune_slots.append(slot)


func _apply_rune_slot(slot: PanelContainer, icon: TextureRect, label: Label, tag, sealed: bool) -> void:
	var element_id := _tag_element(tag)
	var accent := _element_color(element_id)
	slot.add_theme_stylebox_override("panel", HudStyles.affix_rune_slot(accent, true))
	icon.texture = AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_SEAL if sealed else _rune_texture_path(element_id))
	icon.modulate = Color(1, 1, 1, 0.9)
	label.text = "封" if sealed else _element_short(element_id)
	label.add_theme_color_override("font_color", accent.lightened(0.2))
	slot.tooltip_text = _tag_name(tag)


func _apply_empty_rune_slot(slot: PanelContainer, icon: TextureRect, label: Label, text: String) -> void:
	var accent := UiTokens.TEXT_MUTED if text == "封" else UiTokens.ACCENT_JADE
	slot.add_theme_stylebox_override("panel", HudStyles.affix_rune_slot(accent, false))
	icon.texture = AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_SEAL if text == "封" else AssetPaths.HUD_AFFIX_RUNE_WOOD)
	icon.modulate = Color(0.42, 0.48, 0.48, 0.38)
	label.text = text
	label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.88))
	slot.tooltip_text = "空命纹槽" if text == "无" else "封印槽"


func _apply_rune_slot_styles() -> void:
	for slot in _rune_slots:
		slot.add_theme_stylebox_override("panel", HudStyles.affix_rune_slot(UiTokens.ACCENT_JADE, false))


func _rune_texture_path(element_id: int) -> String:
	match ElementUtils.key(element_id):
		"fire": return AssetPaths.HUD_AFFIX_RUNE_FIRE
		"thunder": return AssetPaths.HUD_AFFIX_RUNE_THUNDER
		"water": return AssetPaths.HUD_AFFIX_RUNE_WATER
		"wood": return AssetPaths.HUD_AFFIX_RUNE_WOOD
		"earth": return AssetPaths.HUD_AFFIX_RUNE_EARTH
		"chaos", "soul": return AssetPaths.HUD_AFFIX_RUNE_SEAL
	return AssetPaths.HUD_AFFIX_RUNE_WOOD


func _element_short(element_id: int) -> String:
	match ElementUtils.key(element_id):
		"fire": return "火"
		"thunder": return "雷"
		"water": return "水"
		"wood": return "木"
		"earth": return "土"
		"chaos": return "玄"
		"soul": return "魂"
	return "无"


func _element_color(element_id: int) -> Color:
	match ElementUtils.key(element_id):
		"fire": return UiTokens.ELEM_FIRE
		"thunder": return UiTokens.ELEM_THUNDER
		"water": return UiTokens.ELEM_WATER
		"wood": return UiTokens.ELEM_WOOD
		"earth": return UiTokens.ELEM_EARTH
		"chaos", "soul": return UiTokens.ELEM_CHAOS
	return UiTokens.ACCENT_JADE


func _tag_element(tag) -> int:
	if tag == null:
		return 0
	return int(tag.element)


func _tag_name(tag) -> String:
	if tag == null:
		return ""
	return str(tag.name)


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
	for label in [affix_label, skill_label, combo_track_label]:
		label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72, 0.98))
	dao_label.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0, 0.96))
	build_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)


func _compact_text_labels() -> void:
	for label in [
		wave_label,
		objective_detail_label,
		seed_label,
		realm_label,
		build_label,
		dao_label,
		combo_track_label,
		affix_label,
		skill_label,
		gold_label,
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


func _apply_texture(target: TextureRect, path: String, alpha: float = 1.0) -> void:
	if target == null:
		return
	var tex := AssetPaths.load_texture(path)
	if tex == null:
		target.visible = false
		return
	target.texture = tex
	target.visible = true
	target.modulate = Color(1, 1, 1, alpha)


func _apply_combo_track_style() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(UiTokens.ELEM_THUNDER.r, UiTokens.ELEM_THUNDER.g, UiTokens.ELEM_THUNDER.b, 0.82)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.08, 0.08, 0.44)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	combo_track_bar.add_theme_stylebox_override("fill", fill)
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
