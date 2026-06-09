extends CanvasLayer

const GameConstants = preload("res://core/constants/game_constants.gd")

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
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(420, 52)
		var cost: int = int(offer.get("cost", 0))
		btn.text = "%s\n%s" % [offer.get("label", ""), offer.get("desc", "")]
		btn.disabled = RunContext.gold < cost
		btn.pressed.connect(_on_buy_pressed.bind(offer))
		buttons_box.add_child(btn)
	var leave := Button.new()
	leave.custom_minimum_size = Vector2(420, 44)
	leave.text = "离开坊市"
	leave.pressed.connect(_on_leave_pressed)
	buttons_box.add_child(leave)
	panel.visible = true
	dimmer.visible = true


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
	panel.visible = false
	dimmer.visible = false
	_offers.clear()
	EventBus.shop_closed.emit(purchased)
