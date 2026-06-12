extends CanvasLayer

const BuildAnalyzer = preload("res://systems/affix/build_analyzer.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")

@onready var character_panel: HudCharacterPanel = $Root/CharacterAnchor/CharacterPanel
@onready var weather_panel: HudWeatherPanel = $Root/WeatherAnchor/WeatherPanel
@onready var skill_dock: HudSkillDock = $Root/SkillDock
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
var _horde_active := false
var _horde_result_shown := false


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
	EventBus.run_started.connect(_on_run_started)
	hint_label.text = "WASD 移动 · 空格闪避 · 左键/QER 输出 · 斩够魔劫或倒计时结束即可过关"
	call_deferred("_bind_player_systems")
	_refresh_pet_label()
	_refresh_active_spell_slots()
	_refresh_seed_label()
	learn_toast_panel.visible = false
	_apply_toast_polish()
	_on_realm_changed(RunContext.realm_level, RunContext.affix_slot_max())
	_refresh_meta_labels()
	_refresh_dao_progress()
	_on_gold_changed(RunContext.gold)
	_on_weather_changed(WeatherSystem.current_weather_id, WeatherSystem.current_weather_name)


func _apply_toast_polish() -> void:
	UiHelpers.apply_panel_polish(learn_toast_panel, false)
	var toast_tex := AssetPaths.load_texture(AssetPaths.SCROLL_TOAST)
	if toast_tex and learn_toast_bg:
		learn_toast_bg.texture = toast_tex
		learn_toast_bg.visible = true


func _get_player() -> Node:
	return EntityCache.get_player()


func get_build_fly_target_global() -> Vector2:
	return character_panel.get_build_fly_target_global()


func _on_run_started(_seed: int) -> void:
	EntityCache.invalidate_player()
	_refresh_seed_label()


func _refresh_seed_label() -> void:
	var seed_label := character_panel.seed_label
	if seed_label == null:
		return
	if RunContext.run_active:
		var suffix := " · 训练" if RunContext.training_mode else ""
		seed_label.text = "种子 %d%s" % [RunContext.seed_value, suffix]
		seed_label.visible = true
	else:
		seed_label.text = "种子 —"
		seed_label.visible = false


func _bind_player_systems() -> void:
	var player := _get_player()
	if player == null:
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


func _on_hp_changed(current: float, maximum: float) -> void:
	character_panel.hp_bar.set_values(current, maximum)
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
	if count > 0:
		character_panel.combo_label.text = "连击\n%d" % count
	else:
		character_panel.combo_label.text = "连击\n—"
	character_panel.update_combo_badge(count)


func _on_gold_changed(amount: int) -> void:
	character_panel.gold_label.text = "灵石 %d" % amount


func _on_wave_changed(wave: int) -> void:
	_combat_wave = wave
	_refresh_wave_label()


func _on_horde_updated(kills: int, quota: int, time_left: float, wave: int) -> void:
	_horde_active = true
	_horde_kills = kills
	_horde_quota = quota
	_horde_time_left = time_left
	_combat_wave = wave
	_refresh_wave_label()


func _on_horde_ended(kills: int, quota: int, reason: String) -> void:
	_horde_active = false
	_horde_result_shown = true
	var suffix := "魔劫已尽" if reason == "quota" else "时限已至"
	var title := _room_title if not _room_title.is_empty() else "魔劫"
	character_panel.wave_label.text = "%s · %s %d/%d" % [title, suffix, kills, quota]


func _format_horde_time(seconds: float) -> String:
	var total := maxi(int(ceilf(seconds)), 0)
	return "%d:%02d" % [total / 60, total % 60]


func _refresh_wave_label() -> void:
	var wave_label := character_panel.wave_label
	if _horde_active and _horde_quota > 0:
		var title := _room_title if not _room_title.is_empty() else "魔劫"
		wave_label.text = "%s · 斩魔 %d/%d · %s · 第%d波" % [
			title,
			_horde_kills,
			_horde_quota,
			_format_horde_time(_horde_time_left),
			_combat_wave,
		]
		return
	if _room_title.is_empty():
		wave_label.text = "第 %d 波" % _combat_wave if _combat_wave > 0 else "—"
		return
	if _combat_wave > 0:
		wave_label.text = "%s · 第 %d 波" % [_room_title, _combat_wave]
	else:
		wave_label.text = _room_title


func _on_weather_changed(weather_id: String, weather_name: String) -> void:
	weather_panel.set_weather(
		AssetPaths.load_texture(AssetPaths.weather_icon(weather_id)),
		_format_weather_text(weather_name)
	)


func _format_weather_text(weather_name: String) -> String:
	var terrain := TerrainSystem.get_active_terrain_label()
	if terrain.is_empty():
		return weather_name
	return "%s · %s" % [weather_name, terrain]


func _on_room_entered(room: Dictionary, stage: Dictionary) -> void:
	character_panel.title_label.text = str(stage.get("name", "轮回仙途"))
	character_panel.apply_stage_accent(int(stage.get("stage_index", 0)))
	var label := "%s · %s" % [stage.get("name", ""), room.get("label", "")]
	if str(room.get("type", "")) == "boss":
		var boss_name := str(room.get("boss_name", room.get("label", "关底")))
		var is_first_boss := int(stage.get("stage_index", 0)) == 1
		label = "BOSS · %s" % boss_name
		if is_first_boss:
			label += " · 结缘关"
	elif str(room.get("type", "")) == "event":
		label = "机缘房"
	_room_title = label
	_combat_wave = 0
	_horde_active = false
	_horde_kills = 0
	_horde_quota = 0
	_horde_time_left = 0.0
	_horde_result_shown = false
	character_panel.wave_label.text = label
	call_deferred("_refresh_weather_text")


func _refresh_weather_text() -> void:
	_on_weather_changed(WeatherSystem.current_weather_id, WeatherSystem.current_weather_name)


func _on_realm_changed(_realm_level: int, affix_slots: int) -> void:
	character_panel.realm_label.text = "%s · 槽位 %d" % [RunContext.realm_name(), affix_slots]
	_refresh_build()
	_refresh_affixes()


func _refresh_build() -> void:
	var player := _get_player()
	if player == null or not player.has_node("AffixHolder"):
		character_panel.build_label.text = "层 · 术0 体0 契0"
		return
	var holder: Node = player.get_node("AffixHolder")
	character_panel.build_label.text = "层 · " + BuildAnalyzer.format_layers(holder.equipped).replace("·", " ")
	_refresh_dao_progress()


func _on_pet_acquired(_pet_id: String) -> void:
	_refresh_pet_label()


func _refresh_dao_progress() -> void:
	const DaoTraditionRegistry = preload("res://systems/dao/dao_tradition_registry.gd")
	var dao_label := character_panel.dao_label
	var player := _get_player()
	if player == null or not player.has_node("AffixHolder"):
		dao_label.text = "道统 · —"
		dao_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
		return
	if not RunContext.dao_tradition_awakened_this_run.is_empty():
		var tradition = DaoTraditionRegistry.get_tradition(RunContext.dao_tradition_awakened_this_run)
		dao_label.text = "道统 · %s ✓" % tradition.get("name", RunContext.dao_tradition_awakened_this_run)
		dao_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
		return
	var info: Dictionary = DaoTraditionRegistry.get_best_progress(player.get_node("AffixHolder"))
	dao_label.text = "道统 · %s %d/%d" % [info.get("name", "—"), info.get("matched", 0), info.get("total", 1)]
	dao_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)


func _on_dao_progress(_progress: Dictionary) -> void:
	_refresh_dao_progress()


func _on_dao_awakened(tradition: Dictionary) -> void:
	character_panel.dao_label.text = "道统 · %s ✓" % tradition.get("name", "")
	character_panel.dao_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)


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
	weather_panel.set_meta_summary(" · ".join(parts))


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
		weather_panel.set_pet(
			AssetPaths.load_texture(AssetPaths.PET_HUO_YING),
			"%s · V" % base,
			UiTokens.ELEM_FIRE
		)
	else:
		weather_panel.set_pet(
			AssetPaths.load_texture(AssetPaths.PET_HUO_YING),
			"%s · %.0fs" % [base, ceilf(cd)],
			UiTokens.ELEM_FIRE
		)


func _refresh_pet_label() -> void:
	if RunContext.pet_acquired:
		weather_panel.set_pet(
			AssetPaths.load_texture(AssetPaths.PET_HUO_YING),
			RunContext.pet_display_name,
			UiTokens.ELEM_FIRE
		)
	else:
		weather_panel.set_pet(null, "待结缘", UiTokens.TEXT_MUTED)


func _on_wave_cleared(wave: int) -> void:
	if _horde_active or _horde_result_shown:
		return
	character_panel.wave_label.text = "第 %d 波清场" % wave


func _on_combo_discovered(combo_id: String) -> void:
	character_panel.combo_track_label.text = "觉醒 · %s" % combo_id
	character_panel.combo_track_label.add_theme_color_override("font_color", UiTokens.ELEM_FIRE)
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
	if accent == "skill":
		learn_toast_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		learn_toast_panel.offset_left = 16.0
		learn_toast_panel.offset_top = 400.0
		learn_toast_panel.offset_right = 280.0
		learn_toast_panel.offset_bottom = 460.0
	else:
		learn_toast_panel.set_anchors_preset(Control.PRESET_CENTER)
		learn_toast_panel.offset_left = -260.0
		learn_toast_panel.offset_top = -80.0
		learn_toast_panel.offset_right = 260.0
		learn_toast_panel.offset_bottom = -8.0


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
		character_panel.affix_label.text = "词条 · —"
		return
	var holder: Node = player.get_node("AffixHolder")
	var lines: PackedStringArray = holder.get_summary_lines()
	var slot_text := "%d/%d" % [holder.equipped.size(), holder.get_max_affixes()]
	if lines.is_empty():
		character_panel.affix_label.text = "词条 %s · —" % slot_text
	else:
		character_panel.affix_label.text = "词条 %s · %s" % [slot_text, " · ".join(lines)]
	_refresh_build()


func _refresh_skill() -> void:
	var player := _get_player()
	if player == null or not player.has_node("SkillProgression"):
		character_panel.skill_label.text = "功法 · 烈焰掌 Lv.1"
		return
	var lines: PackedStringArray = player.get_node("SkillProgression").get_display_lines()
	character_panel.skill_label.text = "功法 · " + " · ".join(lines)


func _refresh_active_spell_slots() -> void:
	var player := _get_player()
	if player == null or not player.has_node("PlayerSpellCaster"):
		return
	var caster: Node = player.get_node("PlayerSpellCaster")
	if not caster.has_method("get_spell_slots_state"):
		return
	var states: Dictionary = caster.get_spell_slots_state()
	for slot in skill_dock.spell_slots.keys():
		var node = skill_dock.spell_slots[slot]
		if not states.has(slot) or not node.has_method("apply_state"):
			continue
		var info: Dictionary = states[slot]
		node.apply_state(
			slot,
			str(info.get("name", slot)),
			VariantUtils.as_bool(info.get("unlocked", false)),
			float(info.get("cd_remaining", 0.0)),
			float(info.get("cd_total", 1.0)),
			VariantUtils.as_bool(info.get("casting", false))
		)


func _on_spell_cooldown(_slot: String, _remaining: float, _total: float) -> void:
	_refresh_active_spell_slots()


func _on_spell_cast(_slot: String, _spell: Dictionary) -> void:
	_refresh_active_spell_slots()


func _refresh_combo_track() -> void:
	var player := _get_player()
	if player == null or not player.has_node("AffixHolder"):
		return
	var info: Dictionary = player.get_node("AffixHolder").get_combo_display()
	var pct: float = float(info.get("progress", 0.0))
	var matched: Array = info.get("matched", [])
	var total: int = maxi(int(info.get("total", 1)), 1)
	character_panel.combo_track_bar.value = pct
	character_panel.combo_track_label.text = "%s %d/%d" % [
		info.get("name", "—"),
		matched.size(),
		total,
	]
