extends CanvasLayer

const GameConstants = preload("res://core/constants/game_constants.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiFlyEffects = preload("res://vfx/ui_fly_effects.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")
const AFFIX_CARD_SCENE = preload("res://ui/components/affix_card.tscn")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: TextureRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var gold_label: Label = $Panel/Margin/VBox/GoldLabel
@onready var cards_box: HBoxContainer = $Panel/Margin/VBox/Cards
@onready var reroll_button: Button = $Panel/Margin/VBox/Actions/RerollButton
@onready var skip_button: Button = $Panel/Margin/VBox/Actions/SkipButton

var _offers: Array = []
var _context: Dictionary = {}
var _card_nodes: Array = []
var _action_nodes: Array[Node] = []
var _pending_offer = null
var _closing := false
var _close_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_modal_veil(dimmer, 0.72)
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	UiHelpers.apply_button_asset(reroll_button, false)
	UiHelpers.apply_button_asset(skip_button, false)
	reroll_button.icon = AssetPaths.load_texture(AssetPaths.ICON_REROLL)
	reroll_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skip_button.icon = AssetPaths.load_texture(AssetPaths.ICON_SKIP)
	skip_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	EventBus.affix_choice_requested.connect(_on_choice_requested)
	EventBus.gold_changed.connect(_on_gold_changed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	for _i in 3:
		var card = AFFIX_CARD_SCENE.instantiate()
		card.visible = false
		cards_box.add_child(card)
		card.offer_selected.connect(_on_card_selected.bind(card))
		_card_nodes.append(card)


func _on_choice_requested(offers: Array, context: Dictionary = {}) -> void:
	_offers = offers
	_context = context
	_refresh_ui()


func _on_gold_changed(amount: int) -> void:
	if panel.visible:
		_context["gold"] = amount
		_update_action_buttons()


func _refresh_ui() -> void:
	_close_token += 1
	_closing = false
	_pending_offer = null
	_clear_full_slot_actions()
	var gold: int = int(_context.get("gold", 0))
	var elite: bool = _context.get("elite", false)
	var player := get_tree().get_first_node_in_group("player")
	var slots_full := false
	var owned_count := 0
	var slot_max := int(_context.get("affix_slots", RunContext.affix_slot_max()))
	if player and player.has_node("AffixHolder"):
		var holder: Node = player.get_node("AffixHolder")
		owned_count = holder.equipped.size()
		slots_full = not holder.can_equip()
		slot_max = holder.get_max_affixes()

	if _context.get("from_event", false):
		title_label.text = "机缘化词条 · 槽位 %d/%d" % [owned_count, slot_max]
	elif _context.get("opening_choice", false):
		title_label.text = "开局机缘 · 选择起手词条"
	elif _context.get("pet_bonded", false):
		var pet_name: String = str(_context.get("pet_name", "火萤"))
		title_label.text = "灵宠「%s」结缘 · 槽位 %d/%d" % [pet_name, owned_count, slot_max]
	elif elite:
		title_label.text = "精英清场 · 高品质机缘" if not slots_full else "词条槽已满(%d)" % slot_max
	elif slots_full:
		title_label.text = "词条槽已满 · 可跳过领灵石"
	else:
		title_label.text = "选择机缘 · 槽位 %d/%d" % [owned_count, slot_max]
	var director_hint := str(_context.get("director_reason", _context.get("director_hint", "")))
	if not director_hint.is_empty():
		title_label.text += "\n%s" % director_hint
	var build_hint := str(_context.get("build_archetype_hint", ""))
	if not build_hint.is_empty():
		title_label.text += "\n流派牵引 · %s" % build_hint

	gold_label.text = "灵石 %d" % gold
	var opening := not panel.visible
	panel.visible = true
	dimmer.visible = true
	if opening:
		UiAnimations.modal_open(panel, dimmer)
	else:
		UiAnimations.reset_modal(panel)

	for i in _card_nodes.size():
		var card: Control = _card_nodes[i]
		if i < _offers.size():
			card.bind_offer(_offers[i], false)
			if card.has_method("play_entrance"):
				card.play_entrance(float(i) * UiAnimations.CARD_STAGGER)
		else:
			card.visible = false

	_update_action_buttons()


func _update_action_buttons() -> void:
	var gold: int = int(_context.get("gold", 0))
	reroll_button.visible = _action_nodes.is_empty()
	skip_button.visible = _action_nodes.is_empty()
	reroll_button.text = "重随 (%d 灵石)" % RunContext.get_reroll_cost()
	reroll_button.disabled = gold < RunContext.get_reroll_cost()
	if _context.get("opening_choice", false):
		skip_button.text = "开局必须择一"
		skip_button.disabled = true
	else:
		skip_button.text = "跳过 (+%d 灵石)" % GameConstants.AFFIX_SKIP_REWARD
		skip_button.disabled = false


func _on_card_selected(card: Control) -> void:
	var tag = card.get_offer() if card.has_method("get_offer") else null
	if tag == null:
		return
	var payload = card.get_offer_payload() if card.has_method("get_offer_payload") else tag
	if typeof(payload) == TYPE_DICTIONARY and bool(payload.get("locked", false)):
		title_label.text = "这道机缘尚未悟透 · %s" % str(payload.get("lock_reason", "条件未满足"))
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("AffixHolder"):
		var holder: Node = player.get_node("AffixHolder")
		if typeof(payload) == TYPE_DICTIONARY and str(payload.get("offer_type", "")) == "temptation":
			var shift := int(payload.get("bonus_shift", 0))
			if shift > 0:
				var boosted = ConfigRegistry.compile_affix(tag.id, shift)
				if boosted:
					tag = boosted
		if not holder.can_equip():
			_open_full_slot_actions(tag, payload)
			return
		if not holder.add_affix(tag):
			title_label.text = "无法装备此词条 · 请选择其他"
			return
		_apply_temptation_payload(tag, payload)
		_play_pickup_fx(card, tag)
	_close()


func _open_full_slot_actions(tag, payload) -> void:
	_pending_offer = payload
	for card in _card_nodes:
		card.visible = false
	_clear_full_slot_actions()
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var holder: Node = player.get_node("AffixHolder")
	var summary: Dictionary = holder.get_slot_summary()
	title_label.text = "词条槽已满 · 处理「%s」" % tag.name
	gold_label.text = "灵石 %d · 核心 %d/%d · 临时 %d/%d · 封印 %d/%d" % [
		RunContext.gold,
		int(summary.get("core_used", 0)),
		int(summary.get("core_max", 0)),
		int(summary.get("temporary_used", 0)),
		int(summary.get("temporary_max", 0)),
		int(summary.get("sealed_used", 0)),
		int(summary.get("sealed_max", 0)),
	]
	var actions_panel := PanelContainer.new()
	actions_panel.name = "FullSlotActionsPanel"
	actions_panel.custom_minimum_size = Vector2(760, 438)
	actions_panel.add_theme_stylebox_override("panel", UiHelpers.make_ninepatch_panel_style())
	cards_box.add_child(actions_panel)
	_action_nodes.append(actions_panel)
	var actions_margin := MarginContainer.new()
	actions_margin.name = "FullSlotMargin"
	actions_margin.add_theme_constant_override("margin_left", 24)
	actions_margin.add_theme_constant_override("margin_top", 20)
	actions_margin.add_theme_constant_override("margin_right", 24)
	actions_margin.add_theme_constant_override("margin_bottom", 20)
	actions_panel.add_child(actions_margin)
	var actions := VBoxContainer.new()
	actions.name = "FullSlotActions"
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_margin.add_child(actions)
	var hint := Label.new()
	hint.name = "FullSlotHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "生效槽已满。可替换一个已有词条、封印新词条留待之后，或分解为灵石。"
	hint.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	actions.add_child(hint)
	for i in holder.equipped.size():
		var replace := _make_full_slot_action_button(
			"替换：%s" % holder.get_affix_label(i),
			_tag_icon_path(holder.equipped[i]),
			true
		)
		replace.name = "ReplaceAffixButton_%d" % i
		replace.pressed.connect(_on_replace_affix_pressed.bind(i, tag, payload))
		actions.add_child(replace)
	var seal := _make_full_slot_action_button("封印新词条（暂不生效）", AssetPaths.status_icon("shield"), false)
	seal.name = "SealAffixButton"
	seal.disabled = not holder.can_seal()
	seal.pressed.connect(_on_seal_affix_pressed.bind(tag, payload))
	actions.add_child(seal)
	var dissolve := _make_full_slot_action_button("分解新词条（+%d 灵石）" % holder.dissolve_value(tag), AssetPaths.ICON_SPIRIT_STONE, false)
	dissolve.name = "DissolveAffixButton"
	dissolve.pressed.connect(_on_dissolve_affix_pressed.bind(tag))
	actions.add_child(dissolve)
	var back := _make_full_slot_action_button("返回选择", AssetPaths.ICON_SKIP, false)
	back.name = "RewardBackButton"
	back.pressed.connect(_return_to_offer_cards)
	actions.add_child(back)
	_update_action_buttons()


func _make_full_slot_action_button(text: String, icon_path: String, primary: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(560, 42)
	button.theme_type_variation = &"Primary" if primary else &"Secondary"
	button.text = text
	UiHelpers.apply_button_asset(button, primary)
	button.icon = AssetPaths.load_texture(icon_path)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


func _tag_icon_path(tag) -> String:
	if tag == null:
		return AssetPaths.status_icon("promoted")
	var element_key := ElementUtils.key(int(tag.element))
	if not element_key.is_empty():
		return str(AssetPaths.ELEMENT_ICONS.get(element_key, AssetPaths.ELEMENT_ICONS["none"]))
	return AssetPaths.status_icon("promoted")


func _clear_full_slot_actions() -> void:
	for node in _action_nodes:
		if is_instance_valid(node):
			var parent := node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.free()
	_action_nodes.clear()
	if reroll_button != null:
		reroll_button.visible = true
	if skip_button != null:
		skip_button.visible = true


func _return_to_offer_cards() -> void:
	_pending_offer = null
	_clear_full_slot_actions()
	_refresh_ui()


func _apply_temptation_payload(tag, payload) -> void:
	if typeof(payload) != TYPE_DICTIONARY or str(payload.get("offer_type", "")) != "temptation":
		return
	RunContext.set_temptation_penalty(
		str(payload.get("penalty_id", "")),
		str(payload.get("cost_text", "下一房压力上升")).replace("代价：", ""),
		{"temptation_id": str(payload.get("temptation_id", ""))}
	)
	EventBus.pet_coord_feedback.emit("破格诱惑已立誓：%s" % str(payload.get("cost_text", "")))


func _on_replace_affix_pressed(index: int, tag, payload) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var holder: Node = player.get_node("AffixHolder")
	if not holder.replace_affix(index, tag):
		title_label.text = "无法替换 · 已拥有或词条无效"
		return
	_apply_temptation_payload(tag, payload)
	EventBus.pet_coord_feedback.emit("机缘替换 · %s" % tag.name)
	_close()


func _on_seal_affix_pressed(tag, payload) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var holder: Node = player.get_node("AffixHolder")
	if not holder.seal_affix(tag):
		title_label.text = "无法封印 · 封印槽已满或已拥有"
		return
	_apply_temptation_payload(tag, payload)
	EventBus.pet_coord_feedback.emit("机缘封印 · %s" % tag.name)
	_close()


func _on_dissolve_affix_pressed(tag) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var holder: Node = player.get_node("AffixHolder")
	var value: int = holder.dissolve_value(tag)
	RunContext.gold += value
	EventBus.gold_changed.emit(RunContext.gold)
	EventBus.pet_coord_feedback.emit("分解机缘 · +%d 灵石" % value)
	_close()


func _play_pickup_fx(card: Control, tag) -> void:
	if VfxManager.should_reduce_motion():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("get_build_fly_target_global"):
		return
	var start_global: Vector2 = card.global_position + card.size * 0.5
	var target_global: Vector2 = hud.get_build_fly_target_global()
	var icon_path := AssetPaths.elem_icon(tag.element)
	UiFlyEffects.fly_icon(start_global, target_global, icon_path, self)
	VfxManager.spawn_world(start_global, "gold", UiTokens.quality_color(tag.quality))


func _on_reroll_pressed() -> void:
	if _closing:
		return
	EventBus.affix_reroll_requested.emit()


func _on_skip_pressed() -> void:
	EventBus.affix_skip_requested.emit()
	_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	var token := _close_token
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		if token != _close_token:
			_closing = false
			return
		panel.visible = false
		dimmer.visible = false
		_offers.clear()
		_context.clear()
		_closing = false
		EventBus.affix_choice_closed.emit()
	)
