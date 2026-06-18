extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var buttons_box: HBoxContainer = $Panel/Margin/VBox/Buttons

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	EventBus.path_choice_requested.connect(_on_path_requested)


func _on_path_requested(branches: Array) -> void:
	title_label.text = "择路前行"
	for child in buttons_box.get_children():
		child.queue_free()
	var cards: Array = []
	for branch in branches:
		var card := _make_path_card(branch)
		buttons_box.add_child(card)
		cards.append(card)
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)
	call_deferred("_animate_path_cards", cards)


func _animate_path_cards(cards: Array) -> void:
	for i in cards.size():
		var card: Control = cards[i]
		if not is_instance_valid(card):
			continue
		card.modulate.a = 0.0
		card.scale = Vector2.ONE
		var tw := card.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(float(i) * UiAnimations.CARD_STAGGER)
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)


func _make_path_card(branch: Dictionary) -> PanelContainer:
	var path_id := str(branch.get("id", "continue"))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 120)
	UiHelpers.apply_card_polish(card)
	_apply_path_card_accent(card, path_id)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetPaths.load_texture(AssetPaths.path_icon(path_id))
	row.add_child(icon)
	var title := Label.new()
	title.text = str(branch.get("label", ""))
	title.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	title.add_theme_font_size_override("font_size", 16)
	row.add_child(title)
	var desc := Label.new()
	desc.text = str(branch.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)
	var btn := Button.new()
	btn.text = "踏入"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.theme_type_variation = &"Primary"
	var choice_id := str(branch.get("id", ""))
	btn.pressed.connect(_on_branch_pressed.bind(choice_id))
	vbox.add_child(btn)
	return card


func _apply_path_card_accent(card: PanelContainer, path_id: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 3
	sb.border_color = _path_accent_color(path_id)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 8
	card.add_theme_stylebox_override("panel", sb)


func _path_accent_color(path_id: String) -> Color:
	match path_id:
		"combat", "continue":
			return UiTokens.ELEM_FIRE
		"rest":
			return UiTokens.ELEM_WOOD
		"shop":
			return UiTokens.ACCENT_GOLD
		"event":
			return UiTokens.ELEM_CHAOS
		"elite":
			return UiTokens.QUALITY_LEGENDARY
		_:
			return UiTokens.TEXT_SECONDARY


func _on_branch_pressed(choice_id: String) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		EventBus.path_choice_closed.emit(choice_id)
	)
