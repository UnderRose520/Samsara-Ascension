extends CanvasLayer

const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const TALENT_CARD_SCENE = preload("res://ui/components/talent_card.tscn")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var before_label: Label = $Panel/Margin/VBox/SlotRow/BeforeLabel
@onready var after_label: Label = $Panel/Margin/VBox/SlotRow/AfterLabel
@onready var cards_box: HBoxContainer = $Panel/Margin/VBox/Cards

var _card_nodes: Array = []
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	_apply_weak_backdrop()
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	UiHelpers.add_gold_divider($Panel/Margin/VBox, cards_box)
	EventBus.breakthrough_requested.connect(_on_breakthrough_requested)
	for _i in 3:
		var card = TALENT_CARD_SCENE.instantiate()
		card.visible = false
		cards_box.add_child(card)
		card.talent_selected.connect(_on_talent_selected)
		_card_nodes.append(card)


func _apply_weak_backdrop() -> void:
	var tex := AssetPaths.load_texture(AssetPaths.MENU_BACKDROP)
	if tex == null:
		return
	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = tex
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(1, 1, 1, 0.22)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)


func _on_breakthrough_requested(offers: Array, context: Dictionary) -> void:
	_closing = false
	var before: int = int(context.get("slots_before", RunContext.affix_slot_max()))
	var after: int = int(context.get("slots_after", RunContext.preview_slots_after_breakthrough()))
	title_label.text = "%s 破境 · 择一天赋" % RunContext.realm_name()
	_animate_slot_counter(before, after)
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


func _animate_slot_counter(before: int, after: int) -> void:
	before_label.text = str(before)
	after_label.text = str(before)
	after_label.modulate = Color(0.72, 0.72, 0.72, 1.0)
	after_label.scale = Vector2.ONE
	after_label.pivot_offset = after_label.size * 0.5
	if VfxManager.should_reduce_motion() or before == after:
		after_label.text = str(after)
		after_label.modulate = Color.WHITE
		return
	var tw := create_tween()
	tw.tween_interval(0.32)
	tw.tween_callback(func() -> void:
		after_label.text = str(after)
	)
	tw.parallel().tween_property(after_label, "modulate", Color.WHITE, 0.28)
	tw.parallel().tween_property(after_label, "scale", Vector2(1.18, 1.18), 0.14)
	tw.tween_property(after_label, "scale", Vector2.ONE, 0.16)


func _spawn_breakthrough_vfx() -> void:
	var burst_pos := panel.global_position + panel.size * 0.5
	VfxManager.spawn_world(burst_pos, "dao", UiTokens.ELEM_WOOD)


func _on_talent_selected(talent_id: String) -> void:
	if _closing:
		return
	_closing = true
	if not VfxManager.should_reduce_motion():
		var burst_pos := panel.global_position + panel.size * 0.5
		VfxManager.spawn_world(burst_pos, "dao", UiTokens.ELEM_WOOD)
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		RunContext.complete_breakthrough()
		EventBus.breakthrough_closed.emit(talent_id)
	)
