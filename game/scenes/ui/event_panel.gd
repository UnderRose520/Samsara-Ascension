extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var art_banner: TextureRect = $Panel/Margin/VBox/ArtBanner
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var buttons_box: VBoxContainer = $Panel/Margin/VBox/Buttons

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	EventBus.event_requested.connect(_on_event_requested)


func _on_event_requested(event: Dictionary, choices: Array) -> void:
	title_label.text = str(event.get("title", "机缘"))
	body_label.text = str(event.get("body", ""))
	art_banner.texture = AssetPaths.load_texture(AssetPaths.EVENT_BANNER)
	art_banner.custom_minimum_size = Vector2(0, 120)
	for child in buttons_box.get_children():
		child.queue_free()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.texture = AssetPaths.load_texture(AssetPaths.ELEMENT_ICONS["wood"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.theme_type_variation = &"Secondary"
		btn.text = str(choice.get("label", "选择"))
		btn.pressed.connect(_on_choice_pressed.bind(i))
		row.add_child(btn)
		buttons_box.add_child(row)
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)


func _on_choice_pressed(index: int) -> void:
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		EventBus.event_closed.emit(index)
	)
