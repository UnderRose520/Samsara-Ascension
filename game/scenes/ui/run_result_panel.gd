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
		detail_label.text = "完成五重天试炼\n房间 %d · 灵石 %d · 轮回点 +%d%s%s" % [
			RunContext.rooms_cleared,
			RunContext.gold,
			100 + RunContext.rooms_cleared * 5,
			dao_text,
			shard_text,
		]
	else:
		var death_summary := RunContext.build_death_summary()
		title_label.text = "道消 · %s" % str(death_summary.get("title", "本局遗憾"))
		title_label.add_theme_color_override("font_color", UiTokens.STATE_DEBUFF)
		detail_label.text = _format_death_detail(death_summary, dao_text, shard_text)

	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)
	if victory:
		UiAnimations.pulse_gold(title_label, 2)


func _format_death_detail(death_summary: Dictionary, dao_text: String, shard_text: String) -> String:
	var horde_text := ""
	if int(death_summary.get("horde_quota", 0)) > 0:
		horde_text = "\n最后魔劫：%d/%d" % [
			int(death_summary.get("horde_kills", 0)),
			int(death_summary.get("horde_quota", 0)),
		]

	return "%s\n\n本局名场面\n%s\n道势峰值 %d/%d · 最高连击 %d%s\n\n遗言：%s\n\n房间 %d · 灵石 %d · 轮回点 +%d%s%s" % [
		str(death_summary.get("detail", "这一世的路还未走完。")),
		_format_highlight_line(death_summary),
		int(death_summary.get("dao_peak", 0)),
		int(death_summary.get("dao_max", 100)),
		int(death_summary.get("combo_peak", 0)),
		horde_text,
		str(death_summary.get("line", "来世再证大道。")),
		RunContext.rooms_cleared,
		RunContext.gold,
		20 + RunContext.rooms_cleared * 2,
		dao_text,
		shard_text,
	]


func _format_highlight_line(death_summary: Dictionary) -> String:
	var recorded := str(death_summary.get("highlight_line", ""))
	if not recorded.is_empty():
		return recorded
	match str(death_summary.get("regret", "")):
		"boss_low_hp":
			return "一息 Boss——%s 只差一次爆发就会倒下。" % str(death_summary.get("boss_name", "Boss"))
		"dao_complete":
			return "道统已醒——这一世留下了可继承的修行方向。"
		"dao_power_high":
			return "道势将满——灵机已聚，只差一次万法归一。"
		"combo_broken":
			return "长连道韵——最高连击 %d，节奏曾经成形。" % int(death_summary.get("combo_peak", 0))
		"missed_room_momentum":
			return "魔劫将破——最后一波只差几只就能脱身。"
	if int(death_summary.get("combo_peak", 0)) >= 100:
		return "百连道韵——这一世曾把攻势打到滚烫。"
	return "未竟之路——这一世留下了下一局要补上的缺口。"


func _on_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
