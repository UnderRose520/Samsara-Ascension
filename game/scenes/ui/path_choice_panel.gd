extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var buttons_box: HBoxContainer = $Panel/Margin/VBox/Buttons

var _branches: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	EventBus.path_choice_requested.connect(_on_path_requested)


func _on_path_requested(branches: Array) -> void:
	_branches = branches
	title_label.text = "择路前行"
	for child in buttons_box.get_children():
		child.queue_free()
	for branch in branches:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 80)
		btn.text = "%s\n%s" % [branch.get("label", ""), branch.get("desc", "")]
		btn.pressed.connect(_on_branch_pressed.bind(str(branch.get("id", ""))))
		buttons_box.add_child(btn)
	panel.visible = true
	dimmer.visible = true


func _on_branch_pressed(choice_id: String) -> void:
	panel.visible = false
	dimmer.visible = false
	_branches.clear()
	EventBus.path_choice_closed.emit(choice_id)
