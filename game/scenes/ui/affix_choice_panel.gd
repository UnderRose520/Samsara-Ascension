extends CanvasLayer

const GameConstants = preload("res://core/constants/game_constants.gd")
const AffixOfferSelector = preload("res://systems/affix/affix_offer_selector.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var gold_label: Label = $Panel/Margin/VBox/GoldLabel
@onready var card_buttons: Array[Button] = [
	$Panel/Margin/VBox/Cards/Card1,
	$Panel/Margin/VBox/Cards/Card2,
	$Panel/Margin/VBox/Cards/Card3,
]
@onready var reroll_button: Button = $Panel/Margin/VBox/Actions/RerollButton
@onready var skip_button: Button = $Panel/Margin/VBox/Actions/SkipButton

var _offers: Array = []
var _context: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	EventBus.affix_choice_requested.connect(_on_choice_requested)
	EventBus.gold_changed.connect(_on_gold_changed)
	for i in card_buttons.size():
		card_buttons[i].pressed.connect(_on_card_pressed.bind(i))
	reroll_button.pressed.connect(_on_reroll_pressed)
	skip_button.pressed.connect(_on_skip_pressed)


func _on_choice_requested(offers: Array, context: Dictionary = {}) -> void:
	_offers = offers
	_context = context
	_refresh_ui()


func _on_gold_changed(amount: int) -> void:
	if panel.visible:
		_context["gold"] = amount
		_update_action_buttons()


func _refresh_ui() -> void:
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
	elif _context.get("pet_bonded", false):
		var pet_name: String = str(_context.get("pet_name", "火萤"))
		title_label.text = "灵宠「%s」结缘！ · 槽位 %d/%d" % [pet_name, owned_count, slot_max]
	elif elite:
		title_label.text = "精英清场 · 高品质机缘" if not slots_full else "词条槽已满(%d) · 可跳过" % slot_max
	elif slots_full:
		title_label.text = "词条槽已满(%d) · 可跳过领灵石" % slot_max
	else:
		title_label.text = "选择机缘 · 槽位 %d/%d" % [owned_count, slot_max]

	gold_label.text = "灵石 %d" % gold
	panel.visible = true
	dimmer.visible = true

	for i in card_buttons.size():
		if i < _offers.size():
			var tag = _offers[i]
			card_buttons[i].visible = true
			var q_label := _quality_label(tag.quality)
			card_buttons[i].text = "%s\n[%s]\n%s" % [tag.name, q_label, tag.description]
			card_buttons[i].modulate = GameConstants.QUALITY_COLORS.get(tag.quality, Color.WHITE)
			card_buttons[i].disabled = slots_full
		else:
			card_buttons[i].visible = false

	_update_action_buttons()


func _update_action_buttons() -> void:
	var gold: int = int(_context.get("gold", 0))
	reroll_button.text = "重随 (%d 灵石)" % RunContext.get_reroll_cost()
	reroll_button.disabled = gold < RunContext.get_reroll_cost()
	skip_button.text = "跳过 (+%d 灵石)" % GameConstants.AFFIX_SKIP_REWARD


func _on_card_pressed(index: int) -> void:
	if index >= _offers.size():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("AffixHolder"):
		var holder: Node = player.get_node("AffixHolder")
		if not holder.can_equip():
			title_label.text = "词条槽已满 · 请重随或跳过"
			return
		holder.add_affix(_offers[index])
	_close()


func _on_reroll_pressed() -> void:
	EventBus.affix_reroll_requested.emit()


func _on_skip_pressed() -> void:
	EventBus.affix_skip_requested.emit()
	_close()


func _close() -> void:
	panel.visible = false
	dimmer.visible = false
	_offers.clear()
	_context.clear()
	EventBus.affix_choice_closed.emit()


func _quality_label(quality: int) -> String:
	match quality:
		0: return "凡品"
		1: return "灵品"
		2: return "仙品"
		3: return "天品"
		4: return "道品"
	return "凡品"
