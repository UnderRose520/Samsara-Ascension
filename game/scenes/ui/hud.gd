extends CanvasLayer

const BuildAnalyzer = preload("res://systems/affix/build_analyzer.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const CultivationPathRegistry = preload("res://systems/realm/cultivation_path_registry.gd")
const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")
const WeaponModCatalog = preload("res://systems/equipment/weapon_mod_catalog.gd")
const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")
const DaoTraditionRegistry = preload("res://systems/dao/dao_tradition_registry.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const HudStyles = preload("res://ui/hud_styles.gd")

const UI_SEP := " / "
const UI_EMPTY := "无"

@onready var character_panel: HudCharacterPanel = $Root/CharacterAnchor/CharacterPanel
@onready var top_objective_anchor: Control = $Root/TopObjectiveAnchor
@onready var top_objective_text: Label = $Root/TopObjectiveAnchor/VBox/ObjectiveText
@onready var top_objective_progress: ProgressBar = $Root/TopObjectiveAnchor/VBox/ObjectiveProgress
@onready var weather_panel: HudWeatherPanel = $Root/WeatherAnchor/WeatherPanel
@onready var skill_dock: HudSkillDock = $Root/SkillDock
@onready var combat_rail: HudCombatRail = $Root/RightCombatRail
@onready var companion_artifact_panel: HudCompanionArtifactPanel = $Root/CompanionArtifactPanel
@onready var jade_codex_overlay: HudJadeCodexOverlay = $Root/JadeCodexOverlay
@onready var hint_label: Label = $Root/HintLabel
@onready var learn_toast: Label = $Root/LearnToastPanel/Margin/Body/LearnToast
@onready var learn_toast_panel: PanelContainer = $Root/LearnToastPanel
@onready var learn_toast_bg: TextureRect = $Root/LearnToastPanel/Margin/Body/ScrollBg

const LEARN_TOAST_COLORS := {
	"spell": Color(1.0, 0.843, 0.0),
	"rebind": Color(0.55, 0.85, 1.0),
	"skill": Color(0.65, 1.0, 0.75),
}

var _learn_toast_timer := 0.0
var _last_hp := -1.0
var _low_hp_tween: Tween
var _combo_count := 0

var _room_title := ""
var _combat_wave := 0
var _horde_kills := 0
var _horde_quota := 0
var _horde_time_left := 0.0
var _horde_next_wave_in := 0.0
var _horde_active := false
var _horde_result_shown := false
var _codex_pause_owner := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.combo_updated.connect(_on_combo_updated)
	EventBus.affix_acquired.connect(func(_id): _refresh_affixes())
	EventBus.all_enemies_cleared.connect(_on_wave_cleared)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.horde_updated.connect(_on_horde_updated)
	EventBus.horde_ended.connect(_on_horde_ended)
	EventBus.combo_discovered.connect(_on_combo_discovered)
	EventBus.skill_layer_unlocked.connect(_on_skill_unlocked)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.pet_acquired.connect(_on_pet_acquired)
	EventBus.realm_changed.connect(_on_realm_changed)
	EventBus.dao_tradition_progress.connect(_on_dao_progress)
	EventBus.dao_tradition_awakened.connect(_on_dao_awakened)
	EventBus.karma_changed.connect(_on_karma_changed)
	EventBus.spell_unlock_changed.connect(_on_spell_unlock_changed)
	EventBus.learn_feedback.connect(_on_learn_feedback)
	EventBus.pet_coord_feedback.connect(_on_pet_coord_feedback)
	EventBus.perfect_dodge_triggered.connect(_on_perfect_dodge_feedback)
	EventBus.run_started.connect(_on_run_started)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.dao_momentum_changed.connect(_on_dao_momentum_changed)
	EventBus.dao_clarity_started.connect(_on_dao_clarity_started)
	EventBus.dao_clarity_ended.connect(_on_dao_clarity_ended)
	hint_label.text = "WASD移动 / 空格闪避 / 左键攻击 / QER法术 / 达成目标过关"
	call_deferred("_bind_player_systems")
	_refresh_pet_label()
	_refresh_active_spell_slots()
	_refresh_seed_label()
	learn_toast_panel.visible = false
	_apply_toast_polish()
	_apply_top_objective_style()
	_on_realm_changed(RunContext.realm_level, RunContext.affix_slot_max())
	_refresh_meta_labels()
	_refresh_dao_progress()
	_on_gold_changed(RunContext.gold)
	_on_weapon_changed(RunContext.get_weapon())
	_on_dao_momentum_changed(RunContext.dao_momentum, RunContext.dao_momentum_max, RunContext.dao_momentum_state, RunContext.dao_momentum_state_time)
	_on_weather_changed(WeatherSystem.current_weather_id, WeatherSystem.current_weather_name)
	if jade_codex_overlay and not jade_codex_overlay.close_requested.is_connected(_close_jade_codex):
		jade_codex_overlay.close_requested.connect(_close_jade_codex)
	if RunContext.run_active:
		var q_spell := ActiveSpellRegistry.get_spell(str(SpellProgress.get_default_bindings().get("q", "")))
		_on_learn_feedback(
			"道途入命 · %s · Q %s" % [
				CultivationPathRegistry.format_summary(RunContext.cultivation_path_id),
				str(q_spell.get("name", "起手法门")),
			],
			"skill"
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if jade_codex_overlay and jade_codex_overlay.visible and jade_codex_overlay.handle_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_TAB:
			_toggle_jade_codex()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_ESCAPE and jade_codex_overlay and jade_codex_overlay.visible:
			_close_jade_codex()
			get_viewport().set_input_as_handled()


func _toggle_jade_codex() -> void:
	if jade_codex_overlay == null:
		return
	if jade_codex_overlay.visible:
		_close_jade_codex()
		return
	if not RunContext.run_active or RunContext.ui_blocking or get_tree().paused:
		return
	_open_jade_codex()


func _open_jade_codex() -> void:
	jade_codex_overlay.set_snapshot(_build_codex_snapshot())
	jade_codex_overlay.open()
	_codex_pause_owner = not get_tree().paused
	if _codex_pause_owner:
		get_tree().paused = true


func _close_jade_codex() -> void:
	jade_codex_overlay.close()
	if _codex_pause_owner:
		get_tree().paused = false
	_codex_pause_owner = false


func _build_codex_snapshot() -> Dictionary:
	var affix_lines := PackedStringArray()
	var sealed_lines := PackedStringArray()
	var slot_summary := {}
	var dao_progress := {}
	var dao_detail := {}
	var combo_display := {}
	var player := _get_player()
	var holder: Node = null
	if player != null and player.has_node("AffixHolder"):
		holder = player.get_node("AffixHolder")
		affix_lines = _format_affix_tags(holder.equipped)
		sealed_lines = _format_affix_tags(holder.sealed_affixes)
		slot_summary = holder.get_slot_summary()
		dao_progress = DaoTraditionRegistry.get_best_progress(holder)
		combo_display = holder.get_combo_display()
		var dao_id := str(dao_progress.get("id", ""))
		if not RunContext.dao_tradition_awakened_this_run.is_empty():
			dao_detail = DaoTraditionRegistry.get_tradition(RunContext.dao_tradition_awakened_this_run)
		elif not dao_id.is_empty():
			dao_detail = DaoTraditionRegistry.get_tradition(dao_id)
	return {
		"realm": character_panel.realm_label.text,
		"build": character_panel.build_label.text,
		"dao": character_panel.dao_label.text,
		"pet": "%s · %s" % [RunContext.pet_display_name if RunContext.pet_acquired else "待结缘", "自动协同" if RunContext.pet_acquired else "未结缘"],
		"artifact": "%s · %s" % [_artifact_display_name(), str(_build_artifact_codex_state().get("state_text", "沉寂"))],
		"stats": "连击峰值 %d / 灵石 %d" % [_combo_count, RunContext.gold],
		"strategy": "自动普攻 %s / 自动索敌 %s / 灵宠 %s / 器灵半自动" % [
			"开" if SaveManager.get_display_setting("auto_attack") else "关",
			"开" if SaveManager.get_display_setting("auto_aim") else "关",
			"自动协同" if RunContext.pet_acquired else "未结缘",
		],
		"affixes": affix_lines,
		"sealed_affixes": sealed_lines,
		"slot_summary": slot_summary,
		"dao_progress": dao_progress,
		"dao_detail": dao_detail,
		"combo_display": combo_display,
		"pet_state": _build_pet_codex_state(),
		"artifact_state": _build_artifact_codex_state(),
		"weapon_mods": _build_weapon_mod_lines(),
		"stats_items": _build_codex_stats_items(),
		"strategy_items": _build_codex_strategy_items(),
		"weather": _codex_weather_summary(),
		"highlight": RunContext.get_best_run_highlight(),
	}


func _format_affix_tags(tags: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for tag in tags:
		if tag == null:
			continue
		lines.append("%s·%s" % [str(tag.name), _quality_label(tag.quality)])
	if lines.is_empty():
		lines.append("暂无")
	return lines


func _quality_label(quality) -> String:
	match int(quality):
		0: return "凡"
		1: return "灵"
		2: return "仙"
		3: return "天"
		4: return "道"
	return "凡"


func _build_pet_codex_state() -> Dictionary:
	var ready := false
	var cooldown_text := "未结缘"
	var detail := "灵宠未结缘"
	if RunContext.pet_acquired:
		cooldown_text = "自动协同"
		detail = "自动协同"
		var pet := get_tree().get_first_node_in_group("pet")
		if pet != null and pet.has_method("get_coord_cd_remaining"):
			var cd: float = pet.get_coord_cd_remaining()
			ready = cd <= 0.05
			cooldown_text = "协同就绪" if ready else "冷却 %.0fs" % ceilf(cd)
			detail = "协同就绪" if ready else "协同冷却 %.0fs" % ceilf(cd)
	return {
		"name": RunContext.pet_display_name if RunContext.pet_acquired else "待结缘",
		"detail": detail,
		"acquired": RunContext.pet_acquired,
		"ready": ready,
		"cooldown_text": cooldown_text,
	}


func _build_artifact_codex_state() -> Dictionary:
	var current := RunContext.dao_momentum
	var maximum := maxf(RunContext.dao_momentum_max, 1.0)
	var state := RunContext.dao_momentum_state
	var state_text := _artifact_state_text(current, maximum, state)
	var hint := "积累道势后，本命器会进入可觉醒状态。"
	if state == "full":
		hint = "道势盈满，器灵已醒；战斗中可归一爆发。"
	elif state == "clarity":
		hint = "通明期间诸法顺行，适合打爆发与清场。"
	elif state == "dao_extreme":
		hint = "连击压入巅峰，短时间获得更强攻势。"
	elif current >= maximum * 0.72:
		hint = "道势接近盈满，继续保持输出节奏。"
	return {
		"name": _artifact_display_name(),
		"current": int(round(current)),
		"maximum": int(round(maximum)),
		"charge_pct": current / maximum,
		"state": state,
		"state_text": state_text,
		"hint": hint,
	}


func _artifact_display_name() -> String:
	var name := RunContext.weapon_display_name
	if name.is_empty():
		name = str(RunContext.get_weapon().get("name", "玄玉葫"))
	return name if not name.is_empty() else "玄玉葫"


func _artifact_state_text(current: float, maximum: float, state: String) -> String:
	match state:
		"full":
			return "可归一"
		"clarity":
			return "道法通明"
		"dao_extreme":
			return "道之极致"
	return "器灵醒" if current >= maxf(maximum, 1.0) * 0.72 else "沉寂"


func _build_weapon_mod_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if RunContext.weapon_mods.is_empty():
		lines.append("未祭炼")
		return lines
	for mod_id in RunContext.weapon_mods:
		var mod := WeaponModCatalog.get_mod(str(mod_id))
		if mod.is_empty():
			continue
		var tags := WeaponModCatalog.format_tags(mod)
		lines.append("%s · %s" % [WeaponModCatalog.format_mod(mod), tags])
	return lines


func _build_codex_stats_items() -> Array:
	return [
		{"label": "灵石", "value": str(RunContext.gold)},
		{"label": "当前连击", "value": str(_combo_count)},
		{"label": "最高连击", "value": str(maxi(RunContext.peak_combo_count, _combo_count))},
		{"label": "道势", "value": "%d/%d" % [int(round(RunContext.dao_momentum)), int(round(RunContext.dao_momentum_max))]},
		{"label": "已清房间", "value": str(RunContext.rooms_cleared)},
		{"label": "斩魔", "value": "%d/%d" % [_horde_kills, _horde_quota]},
		{"label": "天象击杀", "value": str(RunContext.weather_kills_this_room)},
		{"label": "种子", "value": str(RunContext.seed_value)},
	]


func _build_codex_strategy_items() -> Array:
	return [
		{
			"name": "自动普攻",
			"enabled": SaveManager.get_display_setting("auto_attack"),
			"detail": "有目标进入攻击圈时自动出手",
			"accent": UiTokens.ACCENT_GOLD,
		},
		{
			"name": "自动索敌",
			"enabled": SaveManager.get_display_setting("auto_aim"),
			"detail": "普攻与法术朝向优先锁定威胁",
			"accent": UiTokens.ELEM_THUNDER,
		},
		{
			"name": "自动护体",
			"enabled": true,
			"detail": "护体类词条与灵宠护主后台触发",
			"accent": UiTokens.ACCENT_JADE,
		},
		{
			"name": "灵宠协同",
			"enabled": RunContext.pet_acquired,
			"detail": "不占主动技能槽，就绪时符灯提示",
			"accent": UiTokens.ELEM_FIRE,
		},
		{
			"name": "器灵归一",
			"enabled": RunContext.dao_momentum >= RunContext.dao_momentum_max,
			"detail": "道势盈满时进入手动爆发窗口",
			"accent": UiTokens.ELEM_CHAOS,
		},
	]


func _codex_weather_summary() -> String:
	var weather_name := WeatherSystem.current_weather_name
	var terrain := TerrainSystem.get_active_terrain_label()
	if terrain.is_empty():
		return weather_name
	return "%s / %s" % [weather_name, terrain]


func _apply_toast_polish() -> void:
	UiHelpers.apply_panel_polish(learn_toast_panel, false)
	var toast_tex := AssetPaths.load_texture(AssetPaths.SCROLL_TOAST)
	if toast_tex and learn_toast_bg:
		learn_toast_bg.texture = toast_tex
		learn_toast_bg.visible = true


func _apply_top_objective_style() -> void:
	if top_objective_anchor:
		top_objective_anchor.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.46)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	top_objective_progress.add_theme_stylebox_override("background", bg)
	top_objective_progress.add_theme_stylebox_override("fill", HudStyles.objective_bar_fill(UiTokens.ACCENT_GOLD))
	top_objective_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_objective_text.clip_text = true


func _show_top_objective(title: String, kills: int, quota: int, time_left: String, wave: int, next_wave_in: float) -> void:
	if top_objective_anchor == null:
		return
	top_objective_anchor.visible = quota > 0
	if quota <= 0:
		return
	top_objective_text.text = "%s · 斩魔 %d/%d · 第%d波 · 剩 %s" % [
		title,
		kills,
		quota,
		maxi(wave, 1),
		time_left,
	]
	top_objective_progress.max_value = maxi(quota, 1)
	top_objective_progress.value = clampi(kills, 0, quota)


func _hide_top_objective() -> void:
	if top_objective_anchor:
		top_objective_anchor.visible = false


func _get_player() -> Node:
	return EntityCache.get_player()


func get_build_fly_target_global() -> Vector2:
	return character_panel.get_build_fly_target_global()


func _on_run_started(_seed: int) -> void:
	EntityCache.invalidate_player()
	_refresh_seed_label()
	_on_weapon_changed(RunContext.get_weapon())


func _refresh_seed_label() -> void:
	var seed_label := character_panel.seed_label
	if seed_label == null:
		return
	if RunContext.run_active:
		var suffix := " / 训练" if RunContext.training_mode else ""
		seed_label.text = "种子 %d%s" % [RunContext.seed_value, suffix]
		seed_label.visible = false
	else:
		seed_label.text = "种子 未生成"
		seed_label.visible = false


func _bind_player_systems() -> void:
	var player := _get_player()
	if player == null:
		_refresh_active_spell_slots()
		return
	if player.has_node("SkillProgression"):
		player.get_node("SkillProgression").changed.connect(_refresh_skill)
	if player.has_node("PlayerSpellCaster"):
		var caster: Node = player.get_node("PlayerSpellCaster")
		caster.cooldown_changed.connect(_on_spell_cooldown)
		caster.spell_cast.connect(_on_spell_cast)
		if caster.has_signal("spell_state_changed"):
			caster.spell_state_changed.connect(_refresh_active_spell_slots)
	if player.has_node("AffixHolder"):
		player.get_node("AffixHolder").changed.connect(_refresh_combo_track)
		player.get_node("AffixHolder").changed.connect(_refresh_build)
		player.get_node("AffixHolder").changed.connect(_refresh_affixes)
	_refresh_affixes()
	_refresh_skill()
	_refresh_combo_track()
	_refresh_active_spell_slots()


func _on_hp_changed(current: float, maximum: float) -> void:
	character_panel.hp_bar.set_values(current, maximum)
	character_panel.wave_label.text = "命元 %.0f/%.0f" % [current, maximum]
	if _last_hp >= 0.0 and current < _last_hp - 0.01:
		for target in character_panel.get_hp_flash_targets():
			VfxManager.flash_control(target, Color(1.35, 0.55, 0.55), 0.14)
	_last_hp = current
	var ratio := current / maxf(maximum, 1.0)
	var draw_bar := character_panel.hp_bar.get_draw_bar()
	if ratio < 0.25:
		if _low_hp_tween == null or not _low_hp_tween.is_running():
			_low_hp_tween = create_tween().set_loops()
			_low_hp_tween.tween_property(draw_bar, "modulate", Color(1.25, 0.75, 0.75), 0.45)
			_low_hp_tween.tween_property(draw_bar, "modulate", Color.WHITE, 0.45)
	elif _low_hp_tween and _low_hp_tween.is_running():
		_low_hp_tween.kill()
		draw_bar.modulate = Color.WHITE


func _on_combo_updated(count: int) -> void:
	_combo_count = count
	if combat_rail:
		combat_rail.set_combo(count)
	character_panel.combo_label.text = ""
	character_panel.update_combo_badge(0)


func _on_gold_changed(amount: int) -> void:
	character_panel.gold_label.text = "灵石 %d" % amount


func _on_weapon_changed(_weapon: Dictionary) -> void:
	_refresh_build()


func _on_dao_momentum_changed(current: float, maximum: float, state: String, _state_time: float) -> void:
	if character_panel == null:
		return
	var mana_current := maximum if state == "clarity" or state == "dao_extreme" else current
	character_panel.mana_bar.set_values(mana_current, maximum)
	if skill_dock:
		skill_dock.set_artifact_state(current >= maximum * 0.72, state == "full")
	if companion_artifact_panel:
		var state_text := _artifact_state_text(current, maximum, state)
		companion_artifact_panel.set_artifact("玄玉葫", current / maxf(maximum, 1.0), state_text)


func _on_dao_clarity_started(_duration: float, source: String) -> void:
	if not VfxManager.should_reduce_motion():
		var color := Color(1.0, 0.92, 0.42) if source == "combo_200" else UiTokens.ACCENT_GOLD
		VfxManager.spawn_screen(self, character_panel.mana_bar.global_position + character_panel.mana_bar.size * 0.5, "dao", color)


func _on_dao_clarity_ended() -> void:
	_refresh_dao_progress()


func _on_wave_changed(wave: int) -> void:
	_combat_wave = wave
	_refresh_wave_label()


func _on_horde_updated(kills: int, quota: int, time_left: float, wave: int, next_wave_in: float) -> void:
	_horde_active = true
	_horde_kills = kills
	_horde_quota = quota
	_horde_time_left = time_left
	_horde_next_wave_in = next_wave_in
	_combat_wave = wave
	_refresh_wave_label()


func _on_horde_ended(kills: int, quota: int, reason: String) -> void:
	_horde_active = false
	_horde_result_shown = true
	var suffix := "魔劫已尽" if reason == "quota" else "时限已至"
	var title := _room_title if not _room_title.is_empty() else "魔劫"
	character_panel.wave_label.text = "%s / %s %d/%d" % [title, suffix, kills, quota]
	character_panel.hide_objective()
	_hide_top_objective()


func _format_horde_time(seconds: float) -> String:
	var total := maxi(int(ceilf(seconds)), 0)
	return "%d:%02d" % [total / 60, total % 60]


func _refresh_wave_label() -> void:
	var wave_label := character_panel.wave_label
	if _horde_active and _horde_quota > 0:
		var title := _room_title if not _room_title.is_empty() else "魔劫"
		_refresh_hp_caption()
		_show_top_objective(title, _horde_kills, _horde_quota, _format_horde_time(_horde_time_left), _combat_wave, _horde_next_wave_in)
		character_panel.hide_objective()
		return
	character_panel.hide_objective()
	_hide_top_objective()
	if _room_title.is_empty():
		wave_label.text = "第 %d 波" % _combat_wave if _combat_wave > 0 else UI_EMPTY
		return
	if _combat_wave > 0:
		wave_label.text = "%s / 第 %d 波" % [_room_title, _combat_wave]
	else:
		wave_label.text = _room_title


func _on_weather_changed(weather_id: String, weather_name: String) -> void:
	weather_panel.set_weather(
		AssetPaths.load_texture(AssetPaths.weather_icon(weather_id)),
		_format_weather_text(weather_name)
	)


func _format_weather_text(weather_name: String) -> String:
	var weather_summary := WeatherSystem.get_weather_summary(WeatherSystem.current_weather_id)
	var terrain := TerrainSystem.get_active_terrain_label()
	if terrain.is_empty():
		return weather_summary if not weather_summary.is_empty() else weather_name
	return "%s\n%s\n借势" % [weather_summary if not weather_summary.is_empty() else weather_name, terrain]


func _on_room_entered(room: Dictionary, stage: Dictionary) -> void:
	character_panel.title_label.text = str(stage.get("name", "轮回仙途"))
	character_panel.apply_stage_accent(int(stage.get("stage_index", 0)))
	var label := "%s / %s" % [stage.get("name", ""), room.get("label", "")]
	if str(room.get("type", "")) == "boss":
		var boss_name := str(room.get("boss_name", room.get("label", "关底")))
		var is_first_boss := int(stage.get("stage_index", 0)) == 1
		label = "BOSS / %s" % boss_name
		if is_first_boss:
			label += " / 结缘关"
	elif str(room.get("type", "")) == "event":
		label = "机缘房"
	_room_title = label
	_combat_wave = 0
	_horde_active = false
	_horde_kills = 0
	_horde_quota = 0
	_horde_time_left = 0.0
	_horde_next_wave_in = 0.0
	_horde_result_shown = false
	character_panel.hide_objective()
	_hide_top_objective()
	character_panel.wave_label.text = label
	call_deferred("_refresh_weather_text")


func _refresh_weather_text() -> void:
	_on_weather_changed(WeatherSystem.current_weather_id, WeatherSystem.current_weather_name)


func _refresh_hp_caption() -> void:
	var player := _get_player()
	if player == null or not player.has_node("HealthComponent"):
		character_panel.wave_label.text = "命元 --/--"
		return
	var health: Node = player.get_node("HealthComponent")
	var current := float(health.current_hp)
	var maximum := maxf(float(health.max_hp), 1.0)
	character_panel.wave_label.text = "命元 %.0f/%.0f" % [current, maximum]


func _on_realm_changed(_realm_level: int, affix_slots: int) -> void:
	character_panel.realm_label.text = "核心0/%d 临时0/2 封印0/1" % affix_slots
	_refresh_build()
	_refresh_affixes()


func _refresh_build() -> void:
	var player := _get_player()
	var path_summary := CultivationPathRegistry.format_summary(RunContext.cultivation_path_id)
	var weapon_forge := RunContext.weapon_mod_summary()
	if player == null or not player.has_node("AffixHolder"):
		character_panel.build_label.text = "%s%s" % [weapon_forge, path_summary]
		return
	var holder: Node = player.get_node("AffixHolder")
	character_panel.build_label.text = "%s%s" % [weapon_forge, path_summary]
	_refresh_dao_progress()

func _on_pet_acquired(_pet_id: String) -> void:
	_refresh_pet_label()


func _refresh_dao_progress() -> void:
	var dao_label := character_panel.dao_label
	var player := _get_player()
	if player == null or not player.has_node("AffixHolder"):
		dao_label.text = "道统 未成"
		dao_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
		_set_left_dao_track({}, true)
		return
	if not RunContext.dao_tradition_awakened_this_run.is_empty():
		var tradition = DaoTraditionRegistry.get_tradition(RunContext.dao_tradition_awakened_this_run)
		dao_label.text = "道统 %s 已觉醒" % tradition.get("name", RunContext.dao_tradition_awakened_this_run)
		dao_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
		_set_left_dao_track({
			"name": tradition.get("name", "道统"),
			"matched": 1,
			"total": 1,
			"progress": 1.0,
		})
		return
	var info: Dictionary = DaoTraditionRegistry.get_best_progress(player.get_node("AffixHolder"))
	var missing: Array = info.get("missing_slots", [])
	var missing_text := " / Tab玉简" if not missing.is_empty() else ""
	dao_label.text = "道统 %s %d/%d%s" % [
		info.get("name", UI_EMPTY),
		info.get("matched", 0),
		info.get("total", 1),
		missing_text,
	]
	dao_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	_set_left_dao_track(info)


func _set_left_dao_track(info: Dictionary, empty := false) -> void:
	if character_panel == null:
		return
	if empty or info.is_empty():
		character_panel.combo_track_bar.value = 0.0
		character_panel.combo_track_label.text = "道统候选 0/1"
		character_panel.combo_track_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
		return
	var matched := int(info.get("matched", 0))
	var total := maxi(int(info.get("total", 1)), 1)
	var pct := clampf(float(info.get("progress", float(matched) / float(total))), 0.0, 1.0)
	var name := str(info.get("name", "道统"))
	character_panel.combo_track_bar.value = pct
	character_panel.combo_track_label.text = "道统候选 %s %d/%d" % [name, matched, total]
	character_panel.combo_track_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD if pct >= 1.0 else UiTokens.ELEM_THUNDER)


func _on_dao_progress(_progress: Dictionary) -> void:
	_refresh_dao_progress()
	if not _progress.is_empty():
		var name := str(_progress.get("name", "道统"))
		var matched := int(_progress.get("matched", 0))
		var total := int(_progress.get("total", 1))
		_on_learn_feedback("道统推进\n%s %d/%d" % [name, matched, total], "skill")


func _on_dao_awakened(tradition: Dictionary) -> void:
	character_panel.dao_label.text = "道统 %s 已觉醒" % tradition.get("name", "")
	character_panel.dao_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
	_on_learn_feedback("道统觉醒\n%s" % str(tradition.get("name", "")), "skill")


func _on_karma_changed(_karma: Dictionary) -> void:
	_refresh_meta_labels()


func _refresh_meta_labels() -> void:
	var trial := "心魔试炼" if RunContext.heart_demon_trial_active else "无试炼"
	var shard_text := "+%d片" % RunContext.heart_demon_shards_earned if RunContext.heart_demon_shards_earned > 0 else ""
	var good := KarmaTracker.get_karma("good")
	var evil := KarmaTracker.get_karma("evil")
	var greed := KarmaTracker.get_karma("greed")
	var rebellion := KarmaTracker.get_karma("rebellion")
	var dao_heart := KarmaTracker.get_karma("dao_heart")
	var parts: PackedStringArray = [trial]
	if not shard_text.is_empty():
		parts.append(shard_text)
	parts.append("善%d恶%d" % [good, evil])
	if greed > 0:
		parts.append("贪%d" % greed)
	if rebellion > 0:
		parts.append("逆%d" % rebellion)
	if dao_heart > 0:
		parts.append("道%d" % dao_heart)
	weather_panel.set_meta_summary(UI_SEP.join(parts))


func _process(delta: float) -> void:
	_tick_learn_toast(delta)
	if not RunContext.pet_acquired:
		return
	var pet := get_tree().get_first_node_in_group("pet")
	if pet == null or not pet.has_method("get_coord_cd_remaining"):
		return
	var cd: float = pet.get_coord_cd_remaining()
	var base := RunContext.pet_display_name
	if cd <= 0.05:
		skill_dock.set_pet_state(true, true)
		companion_artifact_panel.set_pet(base, "协同就绪", true)
	else:
		skill_dock.set_pet_state(true, false)
		companion_artifact_panel.set_pet(base, "协同冷却 %.0fs" % ceilf(cd), false)


func _refresh_pet_label() -> void:
	if RunContext.pet_acquired:
		if skill_dock:
			skill_dock.set_pet_state(true, false)
		if companion_artifact_panel:
			companion_artifact_panel.set_pet(RunContext.pet_display_name, "自动协同", false)
	else:
		if skill_dock:
			skill_dock.set_pet_state(false, false)
		if companion_artifact_panel:
			companion_artifact_panel.set_pet("待结缘", "灵宠未结缘", false)


func _on_wave_cleared(wave: int) -> void:
	if _horde_active or _horde_result_shown:
		return
	character_panel.wave_label.text = "第 %d 波清场" % wave


func _on_combo_discovered(combo_id: String) -> void:
	if combat_rail:
		combat_rail.push_action("觉醒 %s" % combo_id, UiTokens.ELEM_FIRE)
	if not VfxManager.should_reduce_motion():
		var bar := character_panel.combo_track_bar
		var pos := bar.global_position + bar.size * 0.5
		VfxManager.spawn_screen(self, pos, "combo", UiTokens.ELEM_FIRE)


func _on_skill_unlocked(_skill_id: String, _layer: int) -> void:
	_refresh_skill()


func _on_spell_unlock_changed(_slots: Array) -> void:
	_refresh_active_spell_slots()
	skill_dock.pulse()


func _on_learn_feedback(text: String, accent: String = "spell") -> void:
	if text.is_empty():
		return
	var color: Color = LEARN_TOAST_COLORS.get(accent, LEARN_TOAST_COLORS["spell"])
	learn_toast.text = text
	learn_toast.add_theme_color_override("font_color", color)
	_position_learn_toast(accent)
	learn_toast_panel.visible = true
	UiAnimations.toast_pop(learn_toast_panel)
	UiAnimations.pulse_gold(learn_toast, 1)
	_learn_toast_timer = 2.5 if accent == "skill" else 3.2
	if accent in ["spell", "rebind"]:
		_refresh_active_spell_slots()
		skill_dock.pulse()


func _position_learn_toast(accent: String) -> void:
	learn_toast.add_theme_font_size_override("font_size", 15 if accent == "skill" else 14)
	if accent == "skill":
		learn_toast_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		learn_toast_panel.offset_left = 16.0
		learn_toast_panel.offset_top = 342.0
		learn_toast_panel.offset_right = 292.0
		learn_toast_panel.offset_bottom = 394.0
	else:
		learn_toast_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		learn_toast_panel.offset_left = 20.0
		learn_toast_panel.offset_top = 292.0
		learn_toast_panel.offset_right = 320.0
		learn_toast_panel.offset_bottom = 342.0


func _tick_learn_toast(delta: float) -> void:
	if _learn_toast_timer <= 0.0:
		if learn_toast_panel.visible:
			learn_toast_panel.visible = false
		return
	_learn_toast_timer = maxf(_learn_toast_timer - delta, 0.0)
	if _learn_toast_timer < 0.9:
		learn_toast_panel.modulate.a = clampf(_learn_toast_timer / 0.9, 0.0, 1.0)


func _refresh_affixes() -> void:
	var player := _get_player()
	if player == null or not player.has_node("AffixHolder"):
		character_panel.realm_label.text = "核心0/0 临时0/0 封印0/0"
		character_panel.affix_label.text = "术0 体0 契0"
		character_panel.update_affix_runes([], [])
		return
	var holder: Node = player.get_node("AffixHolder")
	var summary: Dictionary = holder.get_slot_summary()
	character_panel.update_affix_runes(holder.equipped, holder.sealed_affixes)
	character_panel.realm_label.text = "核心%d/%d 临时%d/%d 封印%d/%d" % [
		int(summary.get("core_used", 0)),
		int(summary.get("core_max", 0)),
		int(summary.get("temporary_used", 0)),
		int(summary.get("temporary_max", 0)),
		int(summary.get("sealed_used", 0)),
		int(summary.get("sealed_max", 0)),
	]
	character_panel.affix_label.text = BuildAnalyzer.format_layers(holder.equipped).replace("·", " ")
	_refresh_build()


func _on_pet_coord_feedback(text: String) -> void:
	if text.is_empty() or combat_rail == null:
		return
	var action_keys := ["协同", "连锁", "击杀", "破盾", "完美", "贯穿", "共鸣", "清场", "越阶斩敌", "魔劫进度", "最后 10 秒", "下一波", "波来袭"]
	for key in action_keys:
		if text.find(key) >= 0:
			combat_rail.push_action(_short_feedback(text), _feedback_color(text))
			return


func _on_perfect_dodge_feedback(_world_position: Vector2) -> void:
	if combat_rail:
		combat_rail.push_action("完美身法 +1", UiTokens.ACCENT_JADE)


func _short_feedback(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.length() <= 14:
		return trimmed
	return trimmed.substr(0, 14) + "…"


func _feedback_color(text: String) -> Color:
	if text.find("火") >= 0 or text.find("宠") >= 0 or text.find("协同") >= 0:
		return UiTokens.ELEM_FIRE
	if text.find("雷") >= 0 or text.find("道势") >= 0 or text.find("连锁") >= 0:
		return UiTokens.ELEM_THUNDER
	if text.find("完美") >= 0 or text.find("身法") >= 0:
		return UiTokens.ACCENT_JADE
	return UiTokens.ACCENT_GOLD


func _refresh_skill() -> void:
	var player := _get_player()
	if player == null or not player.has_node("SkillProgression"):
		character_panel.skill_label.text = "功法 烈焰掌 Lv.1"
		return
	var lines: PackedStringArray = player.get_node("SkillProgression").get_display_lines()
	var q_spell := ActiveSpellRegistry.get_spell(str(SpellProgress.get_default_bindings().get("q", "")))
	var q_name := str(q_spell.get("name", "Q"))
	character_panel.skill_label.text = "功法 " + UI_SEP.join(lines) + UI_SEP + "Q·%s" % q_name


func _refresh_active_spell_slots() -> void:
	var player := _get_player()
	if player == null or not player.has_node("PlayerSpellCaster"):
		if skill_dock and skill_dock.has_method("apply_spell_states"):
			skill_dock.apply_spell_states(SpellProgress.get_slot_preview_states())
		return
	var caster: Node = player.get_node("PlayerSpellCaster")
	if not caster.has_method("get_spell_slots_state"):
		if skill_dock and skill_dock.has_method("apply_spell_states"):
			skill_dock.apply_spell_states(SpellProgress.get_slot_preview_states())
		return
	var states: Dictionary = caster.get_spell_slots_state()
	if skill_dock and skill_dock.has_method("apply_spell_states"):
		skill_dock.apply_spell_states(states)


func _on_spell_cooldown(_slot: String, _remaining: float, _total: float) -> void:
	_refresh_active_spell_slots()


func _on_spell_cast(_slot: String, _spell: Dictionary) -> void:
	_refresh_active_spell_slots()


func _refresh_combo_track() -> void:
	var player := _get_player()
	if player == null or not player.has_node("AffixHolder"):
		return
	_refresh_dao_progress()
