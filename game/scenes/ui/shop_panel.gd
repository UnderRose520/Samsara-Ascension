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
var _pending_affix_offer: Dictionary = {}


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
	_pending_affix_offer.clear()
	title_label.text = "坊市 · 灵石购机缘"
	_refresh()


func _on_gold_changed(_amount: int) -> void:
	if panel.visible:
		_refresh()


func _refresh() -> void:
	gold_label.text = "灵石 %d" % RunContext.gold
	for child in buttons_box.get_children():
		child.queue_free()
	if not _pending_affix_offer.is_empty():
		_build_full_slot_actions(_pending_affix_offer)
		_show_panel()
		return
	for offer in _offers:
		buttons_box.add_child(_make_offer_row(offer))
	var leave := Button.new()
	leave.custom_minimum_size = Vector2(420, 44)
	leave.theme_type_variation = &"Secondary"
	leave.text = "离开坊市"
	leave.pressed.connect(_on_leave_pressed)
	buttons_box.add_child(leave)
	_show_panel()


func _show_panel() -> void:
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
			var tag = offer.get("tag")
			if tag == null:
				return
			if not holder.can_equip():
				_pending_affix_offer = offer.duplicate(true)
				title_label.text = "词条槽已满 · 选择处理方式"
				_refresh()
				return
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


func _build_full_slot_actions(offer: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		_pending_affix_offer.clear()
		return
	var holder: Node = player.get_node("AffixHolder")
	var tag = offer.get("tag")
	var cost := int(offer.get("cost", 0))
	var summary: Dictionary = holder.get_slot_summary()
	gold_label.text = "灵石 %d · 核心 %d/%d · 临时 %d/%d · 封印 %d/%d" % [
		RunContext.gold,
		int(summary.get("core_used", 0)),
		int(summary.get("core_max", 0)),
		int(summary.get("temporary_used", 0)),
		int(summary.get("temporary_max", 0)),
		int(summary.get("sealed_used", 0)),
		int(summary.get("sealed_max", 0)),
	]
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "想买 %s，但生效槽已满。可替换已有词条、封印留待之后，或分解换灵石。" % str(offer.get("label", tag.name if tag else "词条"))
	hint.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	buttons_box.add_child(hint)
	for i in holder.equipped.size():
		var replace := Button.new()
		replace.custom_minimum_size = Vector2(420, 40)
		replace.theme_type_variation = &"Primary"
		replace.text = "替换：%s" % holder.get_affix_label(i)
		replace.disabled = RunContext.gold < cost
		replace.pressed.connect(_on_replace_affix_pressed.bind(i, offer))
		buttons_box.add_child(replace)
	var seal := Button.new()
	seal.custom_minimum_size = Vector2(420, 40)
	seal.theme_type_variation = &"Secondary"
	seal.text = "封印新词条（暂不生效）"
	seal.disabled = RunContext.gold < cost or not holder.can_seal()
	seal.pressed.connect(_on_seal_affix_pressed.bind(offer))
	buttons_box.add_child(seal)
	var dissolve := Button.new()
	dissolve.custom_minimum_size = Vector2(420, 40)
	dissolve.theme_type_variation = &"Secondary"
	dissolve.text = "分解新词条（+%d 灵石）" % holder.dissolve_value(tag)
	dissolve.pressed.connect(_on_dissolve_affix_pressed.bind(offer))
	buttons_box.add_child(dissolve)
	var back := Button.new()
	back.custom_minimum_size = Vector2(420, 40)
	back.theme_type_variation = &"Secondary"
	back.text = "返回坊市"
	back.pressed.connect(func() -> void:
		_pending_affix_offer.clear()
		title_label.text = "坊市 · 灵石购机缘"
		_refresh()
	)
	buttons_box.add_child(back)


func _on_replace_affix_pressed(index: int, offer: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var cost := int(offer.get("cost", 0))
	if RunContext.gold < cost:
		return
	var holder: Node = player.get_node("AffixHolder")
	var tag = offer.get("tag")
	if not holder.replace_affix(index, tag):
		title_label.text = "无法替换 · 已拥有或词条无效"
		return
	RunContext.gold -= cost
	EventBus.gold_changed.emit(RunContext.gold)
	EventBus.pet_coord_feedback.emit("词条替换 · -%d 灵石" % cost)
	_close(true)


func _on_seal_affix_pressed(offer: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var cost := int(offer.get("cost", 0))
	if RunContext.gold < cost:
		return
	var holder: Node = player.get_node("AffixHolder")
	var tag = offer.get("tag")
	if not holder.seal_affix(tag):
		title_label.text = "无法封印 · 封印槽已满或已拥有"
		return
	RunContext.gold -= cost
	EventBus.gold_changed.emit(RunContext.gold)
	EventBus.pet_coord_feedback.emit("词条封印 · -%d 灵石" % cost)
	_close(true)


func _on_dissolve_affix_pressed(offer: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var holder: Node = player.get_node("AffixHolder")
	var tag = offer.get("tag")
	var value: int = holder.dissolve_value(tag)
	RunContext.gold += value
	EventBus.gold_changed.emit(RunContext.gold)
	EventBus.pet_coord_feedback.emit("分解词条 · +%d 灵石" % value)
	_pending_affix_offer.clear()
	title_label.text = "坊市 · 灵石购机缘"
	_refresh()


func _on_leave_pressed() -> void:
	_close(false)


func _close(purchased: bool) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		_offers.clear()
		_pending_affix_offer.clear()
		EventBus.shop_closed.emit(purchased)
	)
