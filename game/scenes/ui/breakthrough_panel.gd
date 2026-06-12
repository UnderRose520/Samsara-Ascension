extends CanvasLayer

const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const TALENT_CARD_SCENE = preload("res://ui/components/talent_card.tscn")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var cards_box: HBoxContainer = $Panel/Margin/VBox/Cards

var _card_nodes: Array = []
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	EventBus.breakthrough_requested.connect(_on_breakthrough_requested)
	for _i in 3:
		var card = TALENT_CARD_SCENE.instantiate()
		card.visible = false
		cards_box.add_child(card)
		card.talent_selected.connect(_on_talent_selected)
		_card_nodes.append(card)


func _on_breakthrough_requested(offers: Array, context: Dictionary) -> void:
	_closing = false
	var before: int = int(context.get("slots_before", RunContext.affix_slot_max()))
	var after: int = int(context.get("slots_after", RunContext.preview_slots_after_breakthrough()))
	title_label.text = "%s 破境 · 词条槽 %d → %d" % [RunContext.realm_name(), before, after]
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)
	if not VfxManager.should_reduce_motion():
		call_deferred("_spawn_breakthrough_vfx")
	for i in _card_nodes.size():
		var card = _card_nodes[i]
		if i < offers.size():
			card.bind_talent(offers[i])
			if card.has_method("play_entrance"):
				card.play_entrance(float(i) * UiAnimations.CARD_STAGGER)
		else:
			card.visible = false


func _spawn_breakthrough_vfx() -> void:
	var burst_pos := panel.global_position + panel.size * 0.5
	VfxManager.spawn_world(burst_pos, "gold", Color(1.0, 0.84, 0.2))


func _on_talent_selected(talent_id: String) -> void:
	if _closing:
		return
	_closing = true
	if not VfxManager.should_reduce_motion():
		var burst_pos := panel.global_position + panel.size * 0.5
		VfxManager.spawn_world(burst_pos, "dao", Color(1.0, 0.88, 0.35))
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		RunContext.complete_breakthrough()
		EventBus.breakthrough_closed.emit(talent_id)
	)
