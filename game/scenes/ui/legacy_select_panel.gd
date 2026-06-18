extends CanvasLayer

const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var buttons_box: HBoxContainer = $Panel/Margin/VBox/Buttons
@onready var skip_button: Button = $Panel/Margin/VBox/SkipButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	skip_button.text = "不选遗泽"
	skip_button.pressed.connect(_on_skip)
	EventBus.legacy_choice_requested.connect(_on_legacy_requested)


func _on_legacy_requested(affixes: Array) -> void:
	RunContext.ui_blocking = true
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
	card.custom_minimum_size = Vector2(210, 116)
	UiHelpers.apply_card_polish(card, false)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 3
	sb.border_color = UiTokens.quality_color(tag.quality)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var name_l := Label.new()
	name_l.text = tag.name
	name_l.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_l)

	var sub := Label.new()
	sub.text = "%s · 带入来世" % UiHelpers.quality_name(tag.quality)
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UiTokens.quality_color(tag.quality))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var promise := Label.new()
	var legacy_copy := _legacy_copy_for(index)
	promise.text = str(legacy_copy.get("promise", "承诺：下一局开局保留这缕道痕"))
	promise.add_theme_font_size_override("font_size", 11)
	promise.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	promise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	promise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(promise)

	var cost := Label.new()
	cost.text = str(legacy_copy.get("cost", "代价：品质下降一阶"))
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost)

	var btn := Button.new()
	btn.text = "带入来世"
	btn.theme_type_variation = &"Primary"
	btn.custom_minimum_size = Vector2(0, 32)
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


func _play_card_entrance(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2(0.9, 0.9)
	var tw := card.create_tween()
	tw.tween_interval(float(index) * UiAnimations.CARD_STAGGER)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.28)


func _on_pick(affix_id: String) -> void:
	SaveManager.set_legacy_affix(affix_id)
	_close_and_finish(affix_id)


func _on_skip() -> void:
	_close_and_finish("")


func _close_and_finish(affix_id: String) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		RunContext.ui_blocking = false
		EventBus.legacy_choice_closed.emit(affix_id)
		EventBus.run_completed.emit(false)
	)
