extends CanvasLayer

const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var dimmer: TextureRect = $Dimmer
@onready var backdrop: TextureRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var result_seal_wrap: Control = $Panel/Margin/VBox/ResultSealWrap
@onready var seal_glow: TextureRect = $Panel/Margin/VBox/ResultSealWrap/SealGlow
@onready var seal_icon: TextureRect = $Panel/Margin/VBox/ResultSealWrap/SealIcon
@onready var seal_caption: Label = $Panel/Margin/VBox/ResultSealWrap/SealCaption
@onready var stats_row: HBoxContainer = $Panel/Margin/VBox/StatsRow
@onready var rooms_stat: PanelContainer = $Panel/Margin/VBox/StatsRow/RoomsStat
@onready var combo_stat: PanelContainer = $Panel/Margin/VBox/StatsRow/ComboStat
@onready var gold_stat: PanelContainer = $Panel/Margin/VBox/StatsRow/GoldStat
@onready var detail_scroll: ScrollContainer = $Panel/Margin/VBox/DetailScroll
@onready var detail_label: Label = $Panel/Margin/VBox/DetailScroll/Detail
@onready var restart_button: Button = $Panel/Margin/VBox/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var result_backdrop := load(AssetPaths.RUN_RESULT_BACKDROP)
	if result_backdrop is Texture2D:
		backdrop.texture = result_backdrop
	panel.visible = false
	dimmer.visible = false
	backdrop.visible = false
	UiHelpers.apply_modal_veil(dimmer, 0.76)
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	_apply_result_stat_styles()
	UiHelpers.apply_button_asset(restart_button, true)
	restart_button.icon = AssetPaths.load_texture(AssetPaths.status_icon("dao"))
	restart_button.add_theme_font_size_override("font_size", 16)
	restart_button.add_theme_color_override("font_color", Color(0.13, 0.075, 0.025, 1.0))
	restart_button.add_theme_constant_override("h_separation", 8)
	restart_button.pressed.connect(_on_restart)
	EventBus.run_completed.connect(_on_run_completed)


func _on_run_completed(victory: bool) -> void:
	var death_summary := {}
	if not victory:
		death_summary = RunContext.build_death_summary()
	RunContext.finalize_run_meta(victory)
	var epitaph_text := _format_epitaph_text(SaveManager.get_latest_run_record())
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
		panel.custom_minimum_size = Vector2(780, 640)
		if detail_scroll:
			detail_scroll.custom_minimum_size = Vector2(0, 210)
		title_label.text = "飞升成功"
		title_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
		_apply_result_seal(true, "天门留名 · 轮回归档")
		_update_stat_cards(RunContext.rooms_cleared, RunContext.peak_combo_count, RunContext.gold)
		detail_label.text = "完成五重天试炼\n房间 %d · 灵石 %d · 轮回点 +%d%s%s" % [
			RunContext.rooms_cleared,
			RunContext.gold,
			100 + RunContext.rooms_cleared * 5,
			dao_text,
			shard_text,
		]
		if not epitaph_text.is_empty():
			detail_label.text += "\n\n" + epitaph_text
	else:
		panel.custom_minimum_size = Vector2(820, 700)
		if detail_scroll:
			detail_scroll.custom_minimum_size = Vector2(0, 255)
		title_label.text = "道消 · %s" % str(death_summary.get("title", "本局遗憾"))
		title_label.add_theme_color_override("font_color", UiTokens.STATE_DEBUFF)
		_apply_result_seal(false, str(death_summary.get("line", "来世再证大道。")))
		_update_stat_cards(
			RunContext.rooms_cleared,
			int(death_summary.get("combo_peak", RunContext.peak_combo_count)),
			RunContext.gold
		)
		detail_label.text = _format_death_detail(death_summary, dao_text, shard_text)
		if not epitaph_text.is_empty():
			detail_label.text += "\n\n" + epitaph_text

	panel.visible = true
	dimmer.visible = true
	backdrop.visible = true
	UiAnimations.modal_open(panel, dimmer)
	if victory:
		UiAnimations.pulse_gold(title_label, 2)


func _apply_result_stat_styles() -> void:
	for stat in [rooms_stat, combo_stat, gold_stat]:
		UiHelpers.apply_card_polish(stat)
		stat.modulate = Color(0.9, 1.0, 0.96, 0.82)
		var value := stat.get_node_or_null("Margin/VBox/Value") as Label
		var name := stat.get_node_or_null("Margin/VBox/Name") as Label
		for label in [value, name]:
			if label == null:
				continue
			label.add_theme_constant_override("outline_size", 2)
			label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))


func _apply_result_seal(victory: bool, caption: String) -> void:
	result_seal_wrap.visible = true
	var icon_path := AssetPaths.RUN_RESULT_VICTORY_SEAL if victory else AssetPaths.DEATH_SOUL_TOTEM_DISC
	var seal_texture := AssetPaths.load_texture(icon_path)
	var glow_texture := AssetPaths.load_texture(AssetPaths.DEATH_SOUL_TOTEM_DISC)
	seal_icon.texture = seal_texture
	seal_glow.texture = glow_texture
	var tint := UiTokens.ACCENT_GOLD if victory else UiTokens.STATE_DEBUFF
	seal_icon.modulate = Color(1.0, 1.0, 1.0, 0.96)
	seal_glow.modulate = Color(tint.r, tint.g, tint.b, 0.30)
	seal_caption.text = caption
	seal_caption.add_theme_color_override("font_color", Color(tint.r, tint.g, tint.b, 0.92))


func _update_stat_cards(rooms: int, combo: int, gold: int) -> void:
	_set_stat_card(rooms_stat, rooms, "房间")
	_set_stat_card(combo_stat, combo, "最高连击")
	_set_stat_card(gold_stat, gold, "灵石")


func _set_stat_card(card: PanelContainer, value: int, label_text: String) -> void:
	if card == null:
		return
	var value_label := card.get_node_or_null("Margin/VBox/Value") as Label
	var name_label := card.get_node_or_null("Margin/VBox/Name") as Label
	if value_label:
		value_label.text = str(value)
	if name_label:
		name_label.text = label_text


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
			return "长连道势——最高连击 %d，节奏曾经成形。" % int(death_summary.get("combo_peak", 0))
		"missed_room_momentum":
			return "魔劫将破——最后一波只差几只就能脱身。"
	if int(death_summary.get("combo_peak", 0)) >= 100:
		return "百连道势——这一世曾把攻势打到滚烫。"
	return "未竟之路——这一世留下了下一局要补上的缺口。"


func _format_epitaph_text(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	var summary := SaveManager.get_codex_summary()
	var highlight: Dictionary = record.get("highlight", {})
	var mark := str(highlight.get("title", ""))
	if mark.is_empty():
		mark = "构筑刻痕"
	var build := "%s · %s" % [
		str(record.get("cultivation_path_name", record.get("cultivation_path_id", "未知道途"))),
		str(record.get("weapon_name", record.get("weapon_id", "本命器"))),
	]
	return "前世碑\n第 %d 世 · 房间 %d · 最高连击 %d · 道势峰值 %d/%d\n刻痕：%s · %s\n玉简：敌录 %d · 天象 %d · 地形 %d · 连锁 %d" % [
		int(summary.get("runs_total", 0)),
		int(record.get("rooms_cleared", 0)),
		int(record.get("best_combo", 0)),
		int(record.get("dao_peak", 0)),
		int(record.get("dao_max", 100)),
		build,
		mark,
		int(summary.get("enemy_count", 0)),
		int(summary.get("weather_count", 0)),
		int(summary.get("terrain_count", 0)),
		int(summary.get("hidden_chain_count", 0)),
	]


func _on_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
