extends CanvasLayer

const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var detail_label: Label = $Panel/Margin/VBox/Detail
@onready var restart_button: Button = $Panel/Margin/VBox/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	restart_button.pressed.connect(_on_restart)
	EventBus.run_completed.connect(_on_run_completed)


func _on_run_completed(victory: bool) -> void:
	RunContext.finalize_run_meta(victory)
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
		title_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
		detail_label.text = "完成五重天试炼 · 房间 %d · 灵石 %d · 轮回点 +%d%s%s" % [
			RunContext.rooms_cleared,
			RunContext.gold,
			100 + RunContext.rooms_cleared * 5,
			dao_text,
			shard_text,
		]
	else:
		title_label.text = "道消"
		title_label.add_theme_color_override("font_color", UiTokens.STATE_DEBUFF)
		detail_label.text = "房间 %d · 灵石 %d · 轮回点 +%d%s%s · 来世再证大道" % [
			RunContext.rooms_cleared,
			RunContext.gold,
			20 + RunContext.rooms_cleared * 2,
			dao_text,
			shard_text,
		]
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)
	if victory:
		UiAnimations.pulse_gold(title_label, 2)


func _on_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
