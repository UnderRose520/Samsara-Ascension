extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var gold_label: Label = $Panel/Margin/VBox/GoldLabel
@onready var buttons_box: VBoxContainer = $Panel/Margin/VBox/Buttons

var _offers: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.gold_changed.connect(_on_gold_changed)


func _on_shop_requested(offers: Array, _context: Dictionary = {}) -> void:
	_offers = offers
	title_label.text = "坊市 · 灵石购机缘"
	_refresh()


func _on_gold_changed(_amount: int) -> void:
	if panel.visible:
		_refresh()


func _refresh() -> void:
	gold_label.text = "灵石 %d" % RunContext.gold
	for child in buttons_box.get_children():
		child.queue_free()
	for offer in _offers:
		buttons_box.add_child(_make_offer_row(offer))
	var leave := Button.new()
	leave.custom_minimum_size = Vector2(420, 44)
	leave.theme_type_variation = &"Secondary"
	leave.text = "离开坊市"
	leave.pressed.connect(_on_leave_pressed)
	buttons_box.add_child(leave)
	var opening := not panel.visible
	panel.visible = true
	dimmer.visible = true
	if opening:
		UiAnimations.modal_open(panel, dimmer)


func _make_offer_row(offer: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(420, 64)
	UiHelpers.apply_card_polish(row, false)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	var kind := str(offer.get("kind", ""))
	var icon_path := AssetPaths.ICON_HEAL if kind == "heal" else AssetPaths.ELEMENT_ICONS["fire"]
	var icon_tex := AssetPaths.load_texture(icon_path)
	if icon_tex:
		icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	var title := Label.new()
	title.text = str(offer.get("label", ""))
	title.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	vbox.add_child(title)
	var desc := Label.new()
	desc.text = str(offer.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	vbox.add_child(desc)
	var cost: int = int(offer.get("cost", 0))
	var buy := Button.new()
	buy.text = "购入 %d" % cost
	buy.theme_type_variation = &"Primary"
	buy.custom_minimum_size = Vector2(88, 40)
	buy.disabled = RunContext.gold < cost
	buy.pressed.connect(_on_buy_pressed.bind(offer))
	hbox.add_child(buy)
	return row


func _on_buy_pressed(offer: Dictionary) -> void:
	var cost: int = int(offer.get("cost", 0))
	if RunContext.gold < cost:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var kind := str(offer.get("kind", ""))
	match kind:
		"affix", "rare_affix":
			if not player.has_node("AffixHolder"):
				return
			var holder: Node = player.get_node("AffixHolder")
			if not holder.can_equip():
				title_label.text = "词条槽已满，无法购入"
				return
			var tag = offer.get("tag")
			if tag:
				holder.add_affix(tag)
		"heal":
			if player.has_node("HealthComponent"):
				var health: Node = player.get_node("HealthComponent")
				health.current_hp = minf(health.max_hp, health.current_hp + health.max_hp * 0.35)
				health.changed.emit(health.current_hp, health.max_hp)
	RunContext.gold -= cost
	EventBus.gold_changed.emit(RunContext.gold)
	EventBus.pet_coord_feedback.emit("坊市成交 · -%d 灵石" % cost)
	_close(true)


func _on_leave_pressed() -> void:
	_close(false)


func _close(purchased: bool) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		_offers.clear()
		EventBus.shop_closed.emit(purchased)
	)
