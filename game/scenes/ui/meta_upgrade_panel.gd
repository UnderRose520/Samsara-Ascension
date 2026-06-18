extends CanvasLayer

const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var points_label: Label = $Panel/Margin/VBox/PointsLabel
@onready var list_box: VBoxContainer = $Panel/Margin/VBox/List
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _was_paused_before_open := false
var _was_ui_blocking_before_open := false
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	close_button.pressed.connect(_on_close_pressed)
	dimmer.gui_input.connect(_on_dimmer_gui_input)


func open_panel() -> void:
	if panel.visible:
		_refresh()
		return
	_closing = false
	_was_paused_before_open = get_tree().paused
	_was_ui_blocking_before_open = RunContext.ui_blocking
	RunContext.ui_blocking = true
	get_tree().paused = true
	_refresh()
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible or _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _refresh() -> void:
	points_label.text = "轮回点 %d" % SaveManager.get_reincarnation_points()
	for child in list_box.get_children():
		child.queue_free()
	for row in MetaUpgradeRegistry.get_all():
		var id := str(row.get("id", ""))
		var level := SaveManager.get_meta_level(id)
		var max_level := int(row.get("max_level", 0))
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 56)
		UiHelpers.apply_card_polish(row_panel, false)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		row_panel.add_child(margin)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		margin.add_child(hbox)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cost := MetaUpgradeRegistry.next_cost(id)
		var cost_text := "已满级" if level >= max_level else "%d 轮回点" % cost
		info.text = "%s Lv.%d/%d\n%s · %s" % [
			row.get("name", id),
			level,
			max_level,
			row.get("description", ""),
			cost_text,
		]
		info.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		hbox.add_child(info)
		var btn := Button.new()
		btn.text = "升级"
		btn.theme_type_variation = &"Primary"
		btn.custom_minimum_size = Vector2(72, 40)
		btn.disabled = level >= max_level or cost < 0 or SaveManager.get_reincarnation_points() < cost
		btn.pressed.connect(_on_upgrade_pressed.bind(id))
		hbox.add_child(btn)
		list_box.add_child(row_panel)


func _on_upgrade_pressed(id: String) -> void:
	if SaveManager.try_upgrade_meta(id):
		_refresh()


func _on_close_pressed() -> void:
	_close()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:
	if _closing or not panel.visible:
		return
	_closing = true
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		RunContext.ui_blocking = _was_ui_blocking_before_open
		get_tree().paused = _was_paused_before_open
		_closing = false
	)
