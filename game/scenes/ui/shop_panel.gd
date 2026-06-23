extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: TextureRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var gold_label: Label = $Panel/Margin/VBox/GoldLabel
@onready var content_scroll: ScrollContainer = $Panel/Margin/VBox/ContentScroll
@onready var buttons_box: VBoxContainer = $Panel/Margin/VBox/ContentScroll/Buttons
@onready var footer_actions: HBoxContainer = $Panel/Margin/VBox/FooterActions

var _offers: Array = []
var _pending_affix_offer: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_modal_veil(dimmer, 0.72)
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
	for child in footer_actions.get_children():
		child.queue_free()
	content_scroll.scroll_vertical = 0
	if not _pending_affix_offer.is_empty():
		_build_full_slot_actions(_pending_affix_offer)
		_show_panel()
		return
	for offer in _offers:
		buttons_box.add_child(_make_offer_row(offer))
	var leave := Button.new()
	leave.name = "ShopLeaveButton"
	leave.custom_minimum_size = Vector2(220, 44)
	leave.theme_type_variation = &"Secondary"
	leave.text = "离开坊市"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiHelpers.apply_button_asset(leave, false)
	leave.pressed.connect(_on_leave_pressed)
	footer_actions.add_child(leave)
	_show_panel()


func _show_panel() -> void:
	var opening := not panel.visible
	panel.visible = true
	dimmer.visible = true
	if opening:
		UiAnimations.modal_open(panel, dimmer)


func _make_offer_row(offer: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(560, 82)
	row.add_theme_stylebox_override("panel", UiHelpers.make_ninepatch_panel_style())
	var margin := MarginContainer.new()
	margin.name = "OfferMargin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.name = "OfferRow"
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	var icon := TextureRect.new()
	icon.name = "OfferIcon"
	icon.custom_minimum_size = Vector2(42, 42)
	var icon_path := _offer_icon_path(offer)
	var icon_tex := AssetPaths.load_texture(icon_path)
	if icon_tex:
		icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1.0, 0.95, 0.76, 1.0)
	hbox.add_child(icon)
	var vbox := VBoxContainer.new()
	vbox.name = "OfferText"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)
	var title := Label.new()
	title.name = "OfferTitle"
	title.text = str(offer.get("label", ""))
	title.add_theme_color_override("font_color", _offer_accent_color(offer))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.82))
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)
	var desc := Label.new()
	desc.name = "OfferDesc"
	desc.text = str(offer.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	vbox.add_child(desc)
	var cost_row := HBoxContainer.new()
	cost_row.name = "CostRow"
	cost_row.add_theme_constant_override("separation", 5)
	vbox.add_child(cost_row)
	var cost_icon := TextureRect.new()
	cost_icon.name = "CostIcon"
	cost_icon.custom_minimum_size = Vector2(18, 18)
	cost_icon.texture = AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_row.add_child(cost_icon)
	var cost: int = int(offer.get("cost", 0))
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "%d 灵石" % cost
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED if RunContext.gold < cost else UiTokens.ACCENT_GOLD_SOFT)
	cost_row.add_child(cost_label)
	var buy := Button.new()
	buy.name = "OfferBuyButton"
	buy.text = "购入"
	buy.theme_type_variation = &"Primary"
	buy.custom_minimum_size = Vector2(112, 44)
	buy.disabled = RunContext.gold < cost
	UiHelpers.apply_button_asset(buy, true)
	buy.icon = AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
	buy.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	var offer_label := str(offer.get("label", tag.name if tag else "词条"))
	var hint := _make_full_slot_hint(
		"想买 %s · %d 灵石，但生效槽已满。先选一个旧词条替换，或在底部封印/分解。" % [offer_label, cost],
		_offer_icon_path(offer)
	)
	buttons_box.add_child(hint)
	var section := Label.new()
	section.name = "FullSlotReplaceSection"
	section.text = "可替换词条 · 替换后立即生效"
	section.custom_minimum_size = Vector2(0, 22)
	section.add_theme_font_size_override("font_size", 13)
	section.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	section.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.82))
	section.add_theme_constant_override("outline_size", 1)
	buttons_box.add_child(section)
	for i in holder.equipped.size():
		var old_label: String = str(holder.get_affix_label(i))
		var replace := _make_shop_action_button(
			"替换  %s" % old_label,
			_offer_icon_path({"kind": "affix", "tag": holder.equipped[i]}),
			true
		)
		replace.name = "ReplaceAffixButton_%d" % i
		replace.custom_minimum_size = Vector2(0, 50)
		replace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replace.tooltip_text = "用 %s 替换 %s" % [offer_label, old_label]
		replace.disabled = RunContext.gold < cost
		replace.pressed.connect(_on_replace_affix_pressed.bind(i, offer))
		buttons_box.add_child(replace)
	var seal := _make_shop_action_button("封印", AssetPaths.status_icon("shield"), false)
	seal.name = "SealAffixButton"
	seal.custom_minimum_size = Vector2(0, 48)
	seal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal.tooltip_text = "花费灵石把新词条封入封印槽，之后再处理"
	seal.disabled = RunContext.gold < cost or not holder.can_seal()
	seal.pressed.connect(_on_seal_affix_pressed.bind(offer))
	footer_actions.add_child(seal)
	var dissolve := _make_shop_action_button("分解 +%d" % holder.dissolve_value(tag), AssetPaths.ICON_SPIRIT_STONE, false)
	dissolve.name = "DissolveAffixButton"
	dissolve.custom_minimum_size = Vector2(0, 48)
	dissolve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dissolve.tooltip_text = "放弃新词条，立刻转化为灵石"
	dissolve.pressed.connect(_on_dissolve_affix_pressed.bind(offer))
	footer_actions.add_child(dissolve)
	var back := _make_shop_action_button("返回", AssetPaths.path_icon("shop"), false)
	back.name = "ShopBackButton"
	back.custom_minimum_size = Vector2(0, 48)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.tooltip_text = "回到坊市商品列表"
	back.pressed.connect(func() -> void:
		_pending_affix_offer.clear()
		title_label.text = "坊市 · 灵石购机缘"
		_refresh()
	)
	footer_actions.add_child(back)


func _make_full_slot_hint(text: String, icon_path: String) -> PanelContainer:
	var hint_panel := PanelContainer.new()
	hint_panel.name = "FullSlotHintPanel"
	hint_panel.custom_minimum_size = Vector2(0, 72)
	hint_panel.add_theme_stylebox_override("panel", UiHelpers.make_ninepatch_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	hint_panel.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.name = "FullSlotHintRow"
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	var icon := TextureRect.new()
	icon.name = "FullSlotHintIcon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = AssetPaths.load_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1.0, 0.96, 0.78, 1.0)
	hbox.add_child(icon)
	var hint := Label.new()
	hint.name = "FullSlotHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.text = text
	hbox.add_child(hint)
	return hint_panel


func _make_shop_action_button(text: String, icon_path: String, primary: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 46)
	button.theme_type_variation = &"Primary" if primary else &"Secondary"
	button.text = text
	UiHelpers.apply_button_asset(button, primary)
	button.icon = AssetPaths.load_texture(icon_path)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button


func _offer_icon_path(offer: Dictionary) -> String:
	var kind := str(offer.get("kind", ""))
	if kind == "heal":
		return AssetPaths.ICON_HEAL
	var tag = offer.get("tag")
	if tag != null:
		var element_key := ElementUtils.key(int(tag.element))
		if not element_key.is_empty():
			return AssetPaths.ELEMENT_ICONS.get(element_key, AssetPaths.ELEMENT_ICONS["none"])
	if kind == "rare_affix":
		return AssetPaths.status_icon("dao")
	if kind == "affix":
		return AssetPaths.status_icon("promoted")
	return AssetPaths.path_icon("shop")


func _offer_accent_color(offer: Dictionary) -> Color:
	var kind := str(offer.get("kind", ""))
	if kind == "heal":
		return UiTokens.ELEM_WOOD
	var tag = offer.get("tag")
	if tag != null:
		return _quality_color(int(tag.quality))
	if kind == "rare_affix":
		return UiTokens.QUALITY_LEGENDARY
	return UiTokens.ACCENT_GOLD_SOFT


func _quality_color(quality: int) -> Color:
	match quality:
		1:
			return UiTokens.QUALITY_RARE
		2:
			return UiTokens.QUALITY_EPIC
		3:
			return UiTokens.QUALITY_LEGENDARY
		4:
			return UiTokens.QUALITY_DAO
		_:
			return UiTokens.ACCENT_GOLD_SOFT


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
