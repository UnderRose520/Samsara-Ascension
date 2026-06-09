extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var buttons_box: VBoxContainer = $Panel/Margin/VBox/Buttons

var _event: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	EventBus.event_requested.connect(_on_event_requested)


func _on_event_requested(event: Dictionary, choices: Array) -> void:
	_event = event.duplicate(true)
	title_label.text = str(event.get("title", "机缘"))
	body_label.text = str(event.get("body", ""))
	for child in buttons_box.get_children():
		child.queue_free()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(420, 44)
		btn.text = str(choice.get("label", "选择"))
		btn.pressed.connect(_on_choice_pressed.bind(i))
		buttons_box.add_child(btn)
	panel.visible = true
	dimmer.visible = true


func _on_choice_pressed(index: int) -> void:
	panel.visible = false
	dimmer.visible = false
	EventBus.event_closed.emit(index)
