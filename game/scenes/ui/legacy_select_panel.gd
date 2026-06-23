extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: TextureRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var buttons_box: HBoxContainer = $Panel/Margin/VBox/Buttons
@onready var skip_button: Button = $Panel/Margin/VBox/SkipButton

var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_modal_veil(dimmer, 0.80)
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	skip_button.text = "不选遗泽"
	skip_button.icon = AssetPaths.load_texture(AssetPaths.status_icon("curse"))
	skip_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiHelpers.apply_button_asset(skip_button, false)
	skip_button.pressed.connect(_on_skip)
	EventBus.legacy_choice_requested.connect(_on_legacy_requested)


func _on_legacy_requested(affixes: Array) -> void:
	RunContext.ui_blocking = true
	_closing = false
	skip_button.disabled = false
	title_label.text = "择一遗泽 · 带入来世（降一品）"
	for child in buttons_box.get_children():
		child.queue_free()
	for i in affixes.size():
		_create_legacy_card(affixes[i], i)
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)


func _create_legacy_card(tag, index: int) -> void:
	var card := PanelContainer.new()
	card.name = "LegacyCard_%d" % index
	card.custom_minimum_size = Vector2(256, 316)
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.name = "LegacyCardMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var frame := TextureRect.new()
	frame.name = "LegacyRewardFrame"
	frame.texture = AssetPaths.load_texture(AssetPaths.reward_card_frame(int(tag.quality)))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.show_behind_parent = true

	var vbox := VBoxContainer.new()
	vbox.name = "LegacyCardVBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var legacy_copy := _legacy_copy_for(index)
	var icon_row := HBoxContainer.new()
	icon_row.name = "LegacyIconRow"
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_theme_constant_override("separation", 10)
	vbox.add_child(icon_row)

	var type_icon := TextureRect.new()
	type_icon.name = "LegacyTypeIcon"
	type_icon.custom_minimum_size = Vector2(42, 42)
	type_icon.texture = AssetPaths.load_texture(_legacy_type_icon_path(str(legacy_copy.get("type", ""))))
	type_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_row.add_child(type_icon)

	var element_icon := TextureRect.new()
	element_icon.name = "LegacyElementIcon"
	element_icon.custom_minimum_size = Vector2(42, 42)
	element_icon.texture = AssetPaths.load_texture(_legacy_element_icon_path(tag))
	element_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	element_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_row.add_child(element_icon)

	var name_l := Label.new()
	name_l.name = "LegacyName"
	name_l.text = tag.name
	name_l.add_theme_color_override("font_color", UiTokens.quality_color(tag.quality))
	name_l.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.88))
	name_l.add_theme_constant_override("outline_size", 2)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_l)

	var sub := Label.new()
	sub.name = "LegacySub"
	sub.text = "%s · %s · 带入来世" % [UiHelpers.quality_name(tag.quality), str(legacy_copy.get("type", "道痕"))]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UiTokens.quality_color(tag.quality))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var promise := Label.new()
	promise.name = "LegacyPromise"
	promise.text = str(legacy_copy.get("promise", "承诺：下一局开局保留这缕道痕"))
	promise.add_theme_font_size_override("font_size", 12)
	promise.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	promise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	promise.custom_minimum_size = Vector2(0, 52)
	vbox.add_child(promise)

	var cost := Label.new()
	cost.name = "LegacyCost"
	cost.text = str(legacy_copy.get("cost", "代价：品质下降一阶"))
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.custom_minimum_size = Vector2(0, 42)
	vbox.add_child(cost)

	var btn := Button.new()
	btn.name = "LegacyPickButton"
	btn.text = "带入来世"
	btn.theme_type_variation = &"Primary"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.icon = AssetPaths.load_texture(AssetPaths.status_icon("dao"))
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiHelpers.apply_button_asset(btn, true)
	btn.pressed.connect(_on_pick.bind(tag.id))
	vbox.add_child(btn)

	buttons_box.add_child(card)
	_play_card_entrance(card, index)


func _legacy_copy_for(index: int) -> Dictionary:
	match index % 3:
		0:
			return {
				"type": "道痕",
				"promise": "承诺：上一世的道意未散",
				"cost": "代价：道痕入轮回，品质下降一阶",
			}
		1:
			return {
				"type": "执念",
				"promise": "承诺：你死前最后一个念头仍在发烫",
				"cost": "代价：执念有缺，品质下降一阶",
			}
	return {
		"type": "残魂",
		"promise": "承诺：上一世的残魂不愿离去",
		"cost": "代价：残魂残缺，品质下降一阶",
	}


func _legacy_type_icon_path(type_name: String) -> String:
	match type_name:
		"道痕":
			return AssetPaths.status_icon("dao")
		"执念":
			return AssetPaths.status_icon("curse")
		"残魂":
			return AssetPaths.status_icon("mutation")
	return AssetPaths.status_icon("dao")


func _legacy_element_icon_path(tag) -> String:
	var element_key := ElementUtils.key(int(tag.element))
	if not element_key.is_empty():
		return AssetPaths.ELEMENT_ICONS.get(element_key, AssetPaths.ELEMENT_ICONS["none"])
	return AssetPaths.status_icon("promoted")


func _play_card_entrance(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2(0.9, 0.9)
	var tw := card.create_tween()
	tw.tween_interval(float(index) * UiAnimations.CARD_STAGGER)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.28)


func _on_pick(affix_id: String) -> void:
	if _closing:
		return
	SaveManager.set_legacy_affix(affix_id)
	_close_and_finish(affix_id)


func _on_skip() -> void:
	if _closing:
		return
	_close_and_finish("")


func _close_and_finish(affix_id: String) -> void:
	_closing = true
	skip_button.disabled = true
	for child in buttons_box.get_children():
		var card := child as PanelContainer
		if card == null:
			continue
		var button := card.get_node_or_null("LegacyCardMargin/LegacyCardVBox/LegacyPickButton") as Button
		if button != null:
			button.disabled = true
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		RunContext.ui_blocking = false
		EventBus.legacy_choice_closed.emit(affix_id)
		EventBus.run_completed.emit(false)
	)
