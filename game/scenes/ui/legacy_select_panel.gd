extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var buttons_box: HBoxContainer = $Panel/Margin/VBox/Buttons
@onready var skip_button: Button = $Panel/Margin/VBox/SkipButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	skip_button.pressed.connect(_on_skip)
	EventBus.legacy_choice_requested.connect(_on_legacy_requested)


func _on_legacy_requested(affixes: Array) -> void:
	RunContext.ui_blocking = true
	title_label.text = "择一遗泽 · 带入来世（降一品）"
	for child in buttons_box.get_children():
		child.queue_free()
	for tag in affixes:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 64)
		btn.text = "%s\n降品继承" % tag.name
		btn.pressed.connect(_on_pick.bind(tag.id))
		buttons_box.add_child(btn)
	panel.visible = true
	dimmer.visible = true


func _on_pick(affix_id: String) -> void:
	SaveManager.set_legacy_affix(affix_id)
	_close_and_finish()


func _on_skip() -> void:
	_close_and_finish()


func _close_and_finish() -> void:
	panel.visible = false
	dimmer.visible = false
	RunContext.ui_blocking = false
	EventBus.legacy_choice_closed.emit("")
	EventBus.run_completed.emit(false)
