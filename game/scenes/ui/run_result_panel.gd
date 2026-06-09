extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var detail_label: Label = $Panel/Margin/VBox/Detail
@onready var restart_button: Button = $Panel/Margin/VBox/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	restart_button.pressed.connect(_on_restart)
	EventBus.run_completed.connect(_on_run_completed)


func _on_run_completed(victory: bool) -> void:
	RunContext.finalize_run_meta(victory)
	panel.visible = true
	var dao_text := ""
	if not RunContext.dao_tradition_awakened_this_run.is_empty():
		dao_text = "\n觉醒道统：%s" % RunContext.dao_tradition_awakened_this_run
	var shard_text := ""
	if RunContext.heart_demon_shards_earned > 0:
		shard_text = "\n心魔碎片 +%d（库存 %d）" % [
			RunContext.heart_demon_shards_earned,
			SaveManager.get_heart_demon_shards(),
		]
	if victory:
		title_label.text = "飞升成功"
		detail_label.text = "完成五重天试炼 · 房间 %d · 灵石 %d · 轮回点 +%d%s%s" % [
			RunContext.rooms_cleared,
			RunContext.gold,
			100 + RunContext.rooms_cleared * 5,
			dao_text,
			shard_text,
		]
	else:
		title_label.text = "道消"
		detail_label.text = "房间 %d · 灵石 %d · 轮回点 +%d%s%s · 来世再证大道" % [
			RunContext.rooms_cleared,
			RunContext.gold,
			20 + RunContext.rooms_cleared * 2,
			dao_text,
			shard_text,
		]


func _on_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
