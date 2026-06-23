class_name UiHelpers
extends RefCounted

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const HudStyles = preload("res://ui/hud_styles.gd")

const QUALITY_NAMES := ["凡品", "灵品", "仙品", "天品", "道品"]
const CATEGORY_NAMES := ["功法", "法术", "体质", "神通", "联动", "灵宠"]


static func quality_name(quality: int) -> String:
	if quality < 0 or quality >= QUALITY_NAMES.size():
		return "凡品"
	return QUALITY_NAMES[quality]


static func category_name(category: int) -> String:
	if category < 0 or category >= CATEGORY_NAMES.size():
		return "法术"
	return CATEGORY_NAMES[category]


static func set_icon(texture_rect: TextureRect, path: String) -> void:
	if texture_rect == null:
		return
	var tex := AssetPaths.load_texture(path)
	texture_rect.texture = tex
	texture_rect.visible = tex != null


static func apply_quality_frame(frame: TextureRect, quality: int) -> void:
	if frame == null:
		return
	var path := AssetPaths.quality_frame(quality)
	var tex := AssetPaths.load_texture(path)
	frame.texture = tex
	frame.visible = tex != null


static func apply_reward_card_frame(frame: TextureRect, quality: int) -> void:
	if frame == null:
		return
	var path := AssetPaths.reward_card_frame(quality)
	var tex := AssetPaths.load_texture(path)
	frame.texture = tex
	frame.visible = tex != null


static func apply_modal_veil(veil: TextureRect, alpha: float = 0.86) -> void:
	if veil == null:
		return
	var tex := AssetPaths.load_texture(AssetPaths.MODAL_INK_VEIL)
	veil.texture = tex
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.modulate = Color(1.0, 1.0, 1.0, alpha)
	veil.set_meta("modal_veil_alpha", alpha)


static func make_ninepatch_panel_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = AssetPaths.load_texture(AssetPaths.PANEL_NINEPATCH)
	sb.texture_margin_left = 32
	sb.texture_margin_top = 32
	sb.texture_margin_right = 32
	sb.texture_margin_bottom = 32
	sb.content_margin_left = 12
	sb.content_margin_top = 10
	sb.content_margin_right = 12
	sb.content_margin_bottom = 10
	sb.modulate_color = Color(0.76, 0.94, 0.88, 0.50)
	return sb


static func make_button_texture_style(texture_path: String, tint: Color, margins := Vector2(24, 16)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = AssetPaths.load_texture(texture_path)
	sb.texture_margin_left = int(margins.x)
	sb.texture_margin_top = int(margins.y)
	sb.texture_margin_right = int(margins.x)
	sb.texture_margin_bottom = int(margins.y)
	sb.content_margin_left = 16
	sb.content_margin_top = 9
	sb.content_margin_right = 16
	sb.content_margin_bottom = 9
	sb.modulate_color = tint
	return sb


static func apply_button_asset(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	var path := AssetPaths.BTN_PRIMARY_GOLD if primary else AssetPaths.BTN_SECONDARY
	var normal := make_button_texture_style(path, Color(1, 1, 1, 0.96 if primary else 0.88))
	if normal.texture == null:
		return
	var hover := make_button_texture_style(path, Color(1.08, 1.05, 0.94, 1.0) if primary else Color(0.78, 1.05, 0.96, 1.0))
	var pressed := make_button_texture_style(path, Color(0.82, 0.76, 0.62, 1.0) if primary else Color(0.55, 0.82, 0.78, 0.96))
	var disabled := make_button_texture_style(path, Color(0.38, 0.38, 0.38, 0.48))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)


static func attach_gold_corners(parent: Control) -> UiGoldCorners:
	var existing := parent.get_node_or_null("UiGoldCorners") as UiGoldCorners
	if existing:
		return existing
	var corners := UiGoldCorners.new()
	corners.name = "UiGoldCorners"
	parent.add_child(corners)
	corners.set_anchors_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return corners


static func apply_panel_polish(panel: PanelContainer, with_corners: bool = false) -> void:
	if panel == null:
		return
	var ink_panel := make_ninepatch_panel_style()
	if ink_panel.texture:
		panel.add_theme_stylebox_override("panel", ink_panel)
	else:
		panel.add_theme_stylebox_override("panel", HudStyles.modal_panel())
	if with_corners:
		var host := panel.get_child(0) as Control
		if host:
			attach_gold_corners(host)


static func apply_card_polish(card: PanelContainer, with_corners: bool = false) -> void:
	if card == null:
		return
	card.add_theme_stylebox_override("panel", HudStyles.decision_card(UiTokens.ACCENT_GOLD, false))
	if with_corners:
		var host := card.get_child(0) as Control
		if host:
			attach_gold_corners(host)


static func make_hp_bar_styles() -> Dictionary:
	var bg := StyleBoxTexture.new()
	bg.texture = AssetPaths.load_texture(AssetPaths.PROGRESS_HP)
	bg.texture_margin_left = 8
	bg.texture_margin_top = 2
	bg.texture_margin_right = 8
	bg.texture_margin_bottom = 2
	var fill := StyleBoxTexture.new()
	fill.texture = AssetPaths.load_texture(AssetPaths.PROGRESS_HP)
	fill.texture_margin_left = 8
	fill.texture_margin_top = 4
	fill.texture_margin_right = 8
	fill.texture_margin_bottom = 4
	return {"background": bg, "fill": fill}


static func apply_hp_bar_polish(bar: ProgressBar) -> void:
	var styles := make_hp_bar_styles()
	if styles["background"].texture:
		bar.add_theme_stylebox_override("background", styles["background"])
	if styles["fill"].texture:
		bar.add_theme_stylebox_override("fill", styles["fill"])


static func add_gold_divider(parent: Control, before: Control = null) -> TextureRect:
	var div := TextureRect.new()
	div.name = "UiGoldDivider_%s" % (before.name if before else "tail")
	div.custom_minimum_size = Vector2(0, 6)
	div.texture = AssetPaths.load_texture(AssetPaths.DIVIDER_GOLD)
	div.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	div.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(div)
	if before:
		parent.move_child(div, before.get_index())
	return div


static func decorate_modal_header(vbox: VBoxContainer, title: Label) -> void:
	if vbox.get_node_or_null("ModalTitleDivider") != null:
		return
	var divider := TextureRect.new()
	divider.name = "ModalTitleDivider"
	divider.custom_minimum_size = Vector2(0, 6)
	divider.texture = AssetPaths.load_texture(AssetPaths.DIVIDER_GOLD)
	divider.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)
	vbox.move_child(divider, title.get_index() + 1)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.88))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.62))


static func wrap_with_panel_texture(panel: PanelContainer, texture_path: String) -> void:
	var margin := panel.get_child(0) as Control
	if margin == null or margin.get_node_or_null("PanelTextureBg") != null:
		return
	var tex := AssetPaths.load_texture(texture_path)
	if tex == null:
		return
	var bg := TextureRect.new()
	bg.name = "PanelTextureBg"
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bg)
	margin.move_child(bg, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = -4
	bg.offset_top = -4
	bg.offset_right = 4
	bg.offset_bottom = 4
