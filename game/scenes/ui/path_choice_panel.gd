extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: TextureRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var buttons_box: GridContainer = $Panel/Margin/VBox/Buttons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_modal_veil(dimmer, 0.70)
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
	card.custom_minimum_size = Vector2(320, 176)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiHelpers.make_ninepatch_panel_style())
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "CardVBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var row := HBoxContainer.new()
	row.name = "PathHeader"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	var icon := TextureRect.new()
	icon.name = "PathIcon"
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = AssetPaths.load_texture(AssetPaths.path_icon(path_id))
	icon.modulate = Color(1.0, 0.94, 0.72, 1.0)
	row.add_child(icon)
	var title := Label.new()
	title.name = "PathTitle"
	title.text = str(branch.get("label", ""))
	title.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.88))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_font_size_override("font_size", 16)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var desc := Label.new()
	desc.name = "PathDesc"
	desc.text = str(branch.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	desc.add_theme_font_size_override("font_size", 12)
	desc.custom_minimum_size = Vector2(0, 42)
	vbox.add_child(desc)
	var tag := Label.new()
	tag.name = "PathRiskTag"
	tag.text = _path_tag_text(path_id)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", _path_accent_color(path_id))
	tag.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.82))
	tag.add_theme_constant_override("outline_size", 1)
	tag.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tag)
	var btn := Button.new()
	btn.name = "PathEnterButton"
	btn.text = "踏入"
	btn.custom_minimum_size = Vector2(0, 38)
	btn.theme_type_variation = &"Primary"
	UiHelpers.apply_button_asset(btn, true)
	var choice_id := str(branch.get("id", ""))
	btn.pressed.connect(_on_branch_pressed.bind(choice_id))
	vbox.add_child(btn)
	return card


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


func _path_tag_text(path_id: String) -> String:
	match path_id:
		"combat", "continue":
			return "魔潮续战 · 常规机缘"
		"rest":
			return "调息回元 · 稳定修整"
		"shop":
			return "坊市交易 · 灵石换缘"
		"event":
			return "奇遇未明 · 因果浮动"
		"elite":
			return "精英劫影 · 高危高赏"
		_:
			return "未知岔路 · 谨慎前行"


func _on_branch_pressed(choice_id: String) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		EventBus.path_choice_closed.emit(choice_id)
	)
