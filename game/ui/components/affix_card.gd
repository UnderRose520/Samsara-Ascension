extends PanelContainer

signal offer_selected

const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var frame_bg: TextureRect = $FrameBg
@onready var state_overlay: TextureRect = $StateOverlay
@onready var icon: TextureRect = $Margin/VBox/Icon
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var quality_label: Label = $Margin/VBox/QualityLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var combo_label: Label = $Margin/VBox/ComboLabel
@onready var select_button: Button = $Margin/VBox/SelectButton

var _tag = null
var _offer = null
var _hover_bound := false
var _quality_glow: QualityGlow = null
var _tag_strip: HBoxContainer = null
var _requires_second_confirm := false
var _second_confirm_armed := false


func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	UiHelpers.apply_button_asset(select_button, true)
	_ensure_tag_strip()


func get_offer():
	return _tag


func get_offer_payload():
	return _offer


func bind_offer(offer, disabled: bool = false) -> void:
	_offer = offer
	var tag = offer.get("tag") if typeof(offer) == TYPE_DICTIONARY else offer
	var display_tag = offer.get("preview_tag", tag) if typeof(offer) == TYPE_DICTIONARY else tag
	_tag = tag
	_requires_second_confirm = false
	_second_confirm_armed = false
	if tag == null:
		visible = false
		return
	var locked := typeof(offer) == TYPE_DICTIONARY and bool(offer.get("locked", false))
	var offer_type := str(offer.get("offer_type", "")) if typeof(offer) == TYPE_DICTIONARY else ""
	visible = true
	scale = Vector2.ONE
	var badge := str(offer.get("badge", "")) if typeof(offer) == TYPE_DICTIONARY else ""
	name_label.text = ("%s · %s" % [badge, display_tag.name]) if not badge.is_empty() else display_tag.name
	quality_label.text = "%s · %s" % [UiHelpers.quality_name(display_tag.quality), UiHelpers.category_name(display_tag.category)]
	quality_label.add_theme_color_override("font_color", UiTokens.quality_color(display_tag.quality))
	var extra := ""
	if typeof(offer) == TYPE_DICTIONARY:
		if locked:
			extra = "\n%s\n%s" % [str(offer.get("lock_reason", "")), str(offer.get("preview_text", ""))]
		elif str(offer.get("offer_type", "")) == "temptation":
			var benefit_text := str(offer.get("benefit_text", ""))
			var cost_text := str(offer.get("cost_text", ""))
			extra = "\n%s\n%s" % [benefit_text, cost_text] if not benefit_text.is_empty() else "\n%s" % cost_text
	desc_label.text = "%s%s" % [display_tag.description, extra]
	var combo_text := " · ".join(display_tag.combo_tags) if display_tag.combo_tags.size() > 0 else "—"
	combo_label.text = "Combo %s" % combo_text
	UiHelpers.set_icon(icon, AssetPaths.elem_icon_large(display_tag.element))
	UiHelpers.apply_reward_card_frame(frame_bg, display_tag.quality)
	_apply_state_overlay(offer_type, locked)
	_refresh_tag_strip(display_tag, offer, locked)
	_apply_quality_glow(display_tag.quality, offer_type, locked)
	select_button.disabled = disabled or locked
	_requires_second_confirm = offer_type == "temptation" and not select_button.disabled
	_update_select_button_text(locked)
	modulate = Color(0.56, 0.56, 0.6) if locked else (Color(0.72, 0.72, 0.72) if disabled else Color.WHITE)
	if not select_button.disabled and not _hover_bound:
		UiAnimations.bind_hover_lift(self)
		_hover_bound = true


func play_entrance(delay: float = 0.0) -> void:
	call_deferred("_play_entrance_deferred", delay)


func _play_entrance_deferred(delay: float) -> void:
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.88, 0.88)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.28)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.32)


func _on_mouse_enter() -> void:
	if _tag == null or select_button.disabled:
		return
	frame_bg.modulate = Color(1.08, 1.05, 0.95, 1.0)
	if _quality_glow:
		_quality_glow.set_hovered(true)


func _on_mouse_exit() -> void:
	if _second_confirm_armed:
		_second_confirm_armed = false
		_update_select_button_text(false)
		if _quality_glow:
			_quality_glow.set_confirm_armed(false)
	frame_bg.modulate = Color.WHITE
	if _quality_glow:
		_quality_glow.set_hovered(false)


func _on_select_pressed() -> void:
	if _tag != null:
		if _requires_second_confirm and not _second_confirm_armed:
			_second_confirm_armed = true
			select_button.text = "确认立誓"
			frame_bg.modulate = Color(1.16, 0.78, 0.92, 1.0)
			if _quality_glow:
				_quality_glow.set_confirm_armed(true)
			return
		offer_selected.emit()


func _update_select_button_text(locked: bool) -> void:
	if locked:
		select_button.text = "条件不足"
	elif _requires_second_confirm:
		select_button.text = "承受代价"
	else:
		select_button.text = "择此机缘"


func _apply_state_overlay(offer_type: String, locked: bool) -> void:
	if state_overlay == null:
		return
	var overlay_path := ""
	var overlay_alpha := 0.0
	if locked:
		overlay_path = AssetPaths.REWARD_CARD_LOCKED_OVERLAY
		overlay_alpha = 0.58
	elif offer_type == "temptation":
		overlay_path = AssetPaths.REWARD_CARD_FORBIDDEN_OVERLAY
		overlay_alpha = 0.42
	if overlay_path.is_empty():
		state_overlay.visible = false
		state_overlay.texture = null
		return
	state_overlay.texture = AssetPaths.load_texture(overlay_path)
	state_overlay.visible = state_overlay.texture != null
	state_overlay.modulate = Color(1, 1, 1, overlay_alpha)


func _apply_quality_glow(quality: int, offer_type: String, locked: bool) -> void:
	if _quality_glow == null:
		_quality_glow = QualityGlow.new()
		_quality_glow.name = "QualityGlow"
		add_child(_quality_glow)
		_quality_glow.z_index = 5
	_quality_glow.glow_color = UiTokens.quality_color(quality)
	_quality_glow.glow_color.a = 0.45 if quality < 4 else 0.6
	_quality_glow.configure(quality, offer_type == "temptation", locked)
	_quality_glow.set_hovered(false)
	_quality_glow.set_confirm_armed(false)


func _ensure_tag_strip() -> void:
	if _tag_strip != null:
		return
	_tag_strip = HBoxContainer.new()
	_tag_strip.name = "TagStrip"
	_tag_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_tag_strip.add_theme_constant_override("separation", 5)
	var vbox := $Margin/VBox as VBoxContainer
	vbox.add_child(_tag_strip)
	vbox.move_child(_tag_strip, combo_label.get_index())


func _refresh_tag_strip(display_tag, offer, locked: bool) -> void:
	_ensure_tag_strip()
	for child in _tag_strip.get_children():
		child.queue_free()
	_add_icon_tag(AssetPaths.elem_icon(display_tag.element), _element_text(display_tag.element), _element_color(display_tag.element))
	_add_text_tag(UiHelpers.category_name(display_tag.category), UiTokens.ACCENT_JADE)
	_add_text_tag(UiHelpers.quality_name(display_tag.quality), UiTokens.quality_color(display_tag.quality))
	if typeof(offer) == TYPE_DICTIONARY:
		var offer_type := str(offer.get("offer_type", ""))
		if offer_type == "temptation":
			_add_text_tag("禁忌", UiTokens.ELEM_CHAOS)
			_add_text_tag("有代价", UiTokens.ACCENT_BLOOD)
		elif offer_type == "gray" or locked:
			_add_text_tag("缺口", UiTokens.TEXT_SECONDARY)


func _add_icon_tag(texture_path: String, value: String, accent: Color) -> void:
	var box := _make_tag_box(accent)
	var row := _make_tag_row(box)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(18, 18)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = AssetPaths.load_texture(texture_path)
	row.add_child(tex)
	var label := _make_tag_label(value, accent)
	row.add_child(label)
	_tag_strip.add_child(box)


func _add_text_tag(value: String, accent: Color) -> void:
	var box := _make_tag_box(accent)
	var row := _make_tag_row(box)
	row.add_child(_make_tag_label(value, accent))
	_tag_strip.add_child(box)


func _make_tag_box(accent: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 22)
	var style := UiHelpers.make_button_texture_style(
		AssetPaths.BTN_SECONDARY,
		Color(accent.r, accent.g, accent.b, 0.30),
		Vector2(20, 10)
	)
	style.content_margin_left = 6
	style.content_margin_top = 2
	style.content_margin_right = 6
	style.content_margin_bottom = 2
	if style.texture != null:
		box.add_theme_stylebox_override("panel", style)
	else:
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	return box


func _make_tag_row(box: PanelContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	return row


func _make_tag_label(value: String, accent: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	return label


func _element_text(element_id: int) -> String:
	match element_id:
		1: return "火"
		2: return "水"
		3: return "雷"
		4: return "木"
		5: return "土"
		6: return "玄"
		7: return "魂"
		_: return "无"


func _element_color(element_id: int) -> Color:
	match element_id:
		1: return UiTokens.ELEM_FIRE
		2: return UiTokens.ELEM_WATER
		3: return UiTokens.ELEM_THUNDER
		4: return UiTokens.ELEM_WOOD
		5: return UiTokens.ELEM_EARTH
		6, 7: return UiTokens.ELEM_CHAOS
		_: return UiTokens.TEXT_SECONDARY
