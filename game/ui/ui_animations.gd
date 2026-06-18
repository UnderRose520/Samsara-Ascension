class_name UiAnimations
extends RefCounted
## UIUX §7 — Modal / Card / Toast 动效曲线

const MODAL_IN := 0.25
const MODAL_OUT := 0.18
const CARD_STAGGER := 0.08
const TOAST_IN := 0.35
const HOVER_LIFT := 4.0

static func modal_open(node: Control, dimmer: CanvasItem = null) -> void:
	if node == null:
		return
	var tree := node.get_tree()
	if tree == null:
		_apply_modal_open(node, dimmer)
		return
	tree.process_frame.connect(func() -> void:
		_apply_modal_open(node, dimmer)
	, CONNECT_ONE_SHOT)


static func modal_close(node: Control, dimmer: CanvasItem = null, on_finished: Callable = Callable()) -> void:
	if node == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	_apply_modal_close(node, dimmer, on_finished)


static func reset_modal(node: Control) -> void:
	if node == null:
		return
	node.modulate = Color.WHITE
	node.scale = Vector2.ONE
	node.pivot_offset = node.size * 0.5


static func _apply_modal_open(node: Control, dimmer: CanvasItem) -> void:
	node.pivot_offset = node.size * 0.5
	node.modulate.a = 0.0
	node.scale = Vector2.ONE
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 1.0, MODAL_IN)
	if dimmer:
		dimmer.modulate.a = 0.0
		tw.tween_property(dimmer, "modulate:a", 1.0, MODAL_IN)


static func _apply_modal_close(node: Control, dimmer: CanvasItem, on_finished: Callable) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 0.0, MODAL_OUT)
	if dimmer:
		tw.tween_property(dimmer, "modulate:a", 0.0, MODAL_OUT)
	tw.chain().tween_callback(func() -> void:
		reset_modal(node)
		if dimmer:
			dimmer.modulate = Color.WHITE
		if on_finished.is_valid():
			on_finished.call()
	)


static func stagger_cards(cards: Array, base_delay: float = 0.0) -> void:
	var i := 0
	for card in cards:
		if card is Control:
			_play_card_entrance(card as Control, base_delay + float(i) * CARD_STAGGER)
		i += 1


static func _play_card_entrance(card: Control, delay: float) -> void:
	card.modulate.a = 0.0
	card.scale = Vector2(0.88, 0.88)
	card.pivot_offset = card.size * 0.5
	var tw := card.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.28)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.32)


static func toast_pop(panel: Control) -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.88, 0.88)
	var tw := panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, TOAST_IN * 0.6)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, TOAST_IN)


static func bind_hover_lift(card: Control, _lift: float = HOVER_LIFT) -> void:
	if card == null:
		return
	var base_scale := card.scale
	card.mouse_entered.connect(func() -> void:
		card.pivot_offset = card.size * 0.5
		var tw := card.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", base_scale * Vector2(1.03, 1.03), 0.12)
	)
	card.mouse_exited.connect(func() -> void:
		var tw := card.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", base_scale, 0.14)
	)


static func pulse_gold(control: CanvasItem, loops: int = 2) -> void:
	if control == null:
		return
	var base := control.modulate
	var tw := control.create_tween().set_loops(loops)
	tw.tween_property(control, "modulate", Color(1.15, 1.05, 0.75, base.a), 0.22)
	tw.tween_property(control, "modulate", base, 0.22)
