extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var card_buttons: Array[Button] = [
	$Panel/Margin/VBox/Cards/Card1,
	$Panel/Margin/VBox/Cards/Card2,
	$Panel/Margin/VBox/Cards/Card3,
]

var _offers: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	EventBus.breakthrough_requested.connect(_on_breakthrough_requested)
	for i in card_buttons.size():
		card_buttons[i].pressed.connect(_on_card_pressed.bind(i))


func _on_breakthrough_requested(offers: Array, context: Dictionary) -> void:
	_offers = offers
	var before: int = int(context.get("slots_before", RunContext.affix_slot_max()))
	var after: int = int(context.get("slots_after", RunContext.preview_slots_after_breakthrough()))
	title_label.text = "%s 突破 · 词条槽 %d → %d · 择一天赋" % [RunContext.realm_name(), before, after]
	panel.visible = true
	dimmer.visible = true
	for i in card_buttons.size():
		if i < offers.size():
			var talent: Dictionary = offers[i]
			card_buttons[i].visible = true
			card_buttons[i].disabled = false
			card_buttons[i].text = "%s\n%s" % [talent.get("name", ""), talent.get("description", "")]
		else:
			card_buttons[i].visible = false


func _on_card_pressed(index: int) -> void:
	if index >= _offers.size():
		return
	var talent: Dictionary = _offers[index]
	var talent_id := str(talent.get("id", ""))
	panel.visible = false
	dimmer.visible = false
	_offers.clear()
	RunContext.complete_breakthrough()
	EventBus.breakthrough_closed.emit(talent_id)
