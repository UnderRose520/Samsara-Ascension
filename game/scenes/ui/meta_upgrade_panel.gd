extends CanvasLayer

const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var points_label: Label = $Panel/Margin/VBox/PointsLabel
@onready var list_box: VBoxContainer = $Panel/Margin/VBox/List
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	close_button.pressed.connect(_on_close_pressed)


func open_panel() -> void:
	_refresh()
	panel.visible = true
	dimmer.visible = true


func _refresh() -> void:
	points_label.text = "轮回点 %d" % SaveManager.get_reincarnation_points()
	for child in list_box.get_children():
		child.queue_free()
	for row in MetaUpgradeRegistry.get_all():
		var id := str(row.get("id", ""))
		var level := SaveManager.get_meta_level(id)
		var max_level := int(row.get("max_level", 0))
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
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
		hbox.add_child(info)
		var btn := Button.new()
		btn.text = "升级"
		btn.disabled = level >= max_level or cost < 0 or SaveManager.get_reincarnation_points() < cost
		btn.pressed.connect(_on_upgrade_pressed.bind(id))
		hbox.add_child(btn)
		list_box.add_child(hbox)


func _on_upgrade_pressed(id: String) -> void:
	if SaveManager.try_upgrade_meta(id):
		_refresh()


func _on_close_pressed() -> void:
	panel.visible = false
	dimmer.visible = false
