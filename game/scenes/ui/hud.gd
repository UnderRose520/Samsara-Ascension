extends CanvasLayer

const BuildAnalyzer = preload("res://systems/affix/build_analyzer.gd")

@onready var hp_bar: ProgressBar = $Margin/VBox/HpBar
@onready var hp_label: Label = $Margin/VBox/HpLabel
@onready var combo_label: Label = $Margin/VBox/ComboLabel
@onready var gold_label: Label = $Margin/VBox/GoldLabel
@onready var skill_label: Label = $Margin/VBox/SkillLabel
@onready var active_spell_label: Label = $Margin/VBox/ActiveSpellLabel
@onready var combo_track_label: Label = $Margin/VBox/ComboTrackLabel
@onready var affix_label: Label = $Margin/VBox/AffixLabel
@onready var wave_label: Label = $Margin/VBox/WaveLabel
@onready var weather_label: Label = $Margin/VBox/WeatherLabel
@onready var pet_label: Label = $Margin/VBox/PetLabel
@onready var realm_label: Label = $Margin/VBox/RealmLabel
@onready var build_label: Label = $Margin/VBox/BuildLabel
@onready var dao_label: Label = $Margin/VBox/DaoLabel
@onready var meta_label: Label = $Margin/VBox/MetaLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var damage_label: Label = $Margin/DamagePopup
@onready var learn_toast: Label = $Margin/LearnToast

const LEARN_TOAST_COLORS := {
	"spell": Color(1.0, 0.843, 0.0),
	"rebind": Color(0.55, 0.85, 1.0),
	"skill": Color(0.65, 1.0, 0.75),
}

var _learn_toast_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.combo_updated.connect(_on_combo_updated)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.affix_acquired.connect(func(_id): _refresh_affixes())
	EventBus.all_enemies_cleared.connect(_on_wave_cleared)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.wave_changed.connect(_on_wave_changed)
	EventBus.combo_discovered.connect(_on_combo_discovered)
	EventBus.skill_layer_unlocked.connect(_on_skill_unlocked)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.pet_acquired.connect(_on_pet_acquired)
	EventBus.realm_changed.connect(_on_realm_changed)
	EventBus.pet_coord_feedback.connect(_on_pet_coord_feedback)
	EventBus.dao_tradition_progress.connect(_on_dao_progress)
	EventBus.dao_tradition_awakened.connect(_on_dao_awakened)
	EventBus.karma_changed.connect(_on_karma_changed)
	EventBus.spell_unlock_changed.connect(_on_spell_unlock_changed)
	EventBus.learn_feedback.connect(_on_learn_feedback)
	hint_label.text = "WASD 移动 | 空格闪避 | 左键攻击 | Q/E/R 法术 | V 灵宠 | Esc 暂停"
	EventBus.display_settings_changed.connect(_on_display_settings_changed)
	call_deferred("_bind_player_systems")
	_refresh_pet_label()
	_refresh_active_spell_label()
	if learn_toast:
		learn_toast.modulate.a = 0.0
	_on_realm_changed(RunContext.realm_level, RunContext.affix_slot_max())
	_refresh_meta_labels()
	_refresh_dao_progress()


func _bind_player_systems() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_node("SkillProgression"):
		player.get_node("SkillProgression").changed.connect(_refresh_skill)
	if player.has_node("PlayerSpellCaster"):
		var caster: Node = player.get_node("PlayerSpellCaster")
		caster.cooldown_changed.connect(_on_spell_cooldown)
		caster.spell_cast.connect(_on_spell_cast)
		if caster.has_signal("spell_state_changed"):
			caster.spell_state_changed.connect(_refresh_active_spell_label)
	if player.has_node("AffixHolder"):
		player.get_node("AffixHolder").changed.connect(_refresh_combo_track)
		player.get_node("AffixHolder").changed.connect(_refresh_build)
		player.get_node("AffixHolder").changed.connect(_refresh_affixes)
	_refresh_affixes()
	_refresh_skill()
	_refresh_combo_track()


func _on_display_settings_changed() -> void:
	if not SaveManager.get_display_setting("show_damage_numbers"):
		damage_label.modulate.a = 0.0


func _on_hp_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "真元 %.0f / %.0f" % [current, maximum]


func _on_combo_updated(count: int) -> void:
	combo_label.text = "连击 %d" % count if count > 0 else "连击 —"


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "灵石 %d" % amount


func _on_wave_changed(wave: int) -> void:
	wave_label.text = "房间 %d" % wave


func _on_weather_changed(_weather_id: String, weather_name: String) -> void:
	weather_label.text = "天象：%s" % weather_name


func _on_room_entered(room: Dictionary, stage: Dictionary) -> void:
	var label := "%s · %s" % [stage.get("name", ""), room.get("label", "")]
	if str(room.get("type", "")) == "boss":
		var boss_name := str(room.get("boss_name", room.get("label", "关底")))
		var is_first_boss := int(stage.get("stage_index", 0)) == 1
		label = "%s · BOSS %s" % [stage.get("name", ""), boss_name]
		if is_first_boss:
			label += " · 结缘关"
	elif str(room.get("type", "")) == "event":
		label = "%s · 机缘房" % stage.get("name", "")
	wave_label.text = label


func _on_realm_changed(_realm_level: int, affix_slots: int) -> void:
	realm_label.text = "%s · 槽位 %d" % [RunContext.realm_name(), affix_slots]
	_refresh_build()
	_refresh_affixes()


func _refresh_build() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		build_label.text = "道路层：术0·体0·契0"
		return
	var holder: Node = player.get_node("AffixHolder")
	build_label.text = "道路层：" + BuildAnalyzer.format_layers(holder.equipped)
	_refresh_dao_progress()


func _on_pet_acquired(_pet_id: String) -> void:
	_refresh_pet_label()


func _refresh_dao_progress() -> void:
	const DaoTraditionRegistry = preload("res://systems/dao/dao_tradition_registry.gd")
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		dao_label.text = "道统：—"
		return
	if not RunContext.dao_tradition_awakened_this_run.is_empty():
		var tradition = DaoTraditionRegistry.get_tradition(RunContext.dao_tradition_awakened_this_run)
		dao_label.text = "道统：%s ✓" % tradition.get("name", RunContext.dao_tradition_awakened_this_run)
		return
	var info: Dictionary = DaoTraditionRegistry.get_best_progress(player.get_node("AffixHolder"))
	dao_label.text = "道统：%s %d/%d" % [info.get("name", "—"), info.get("matched", 0), info.get("total", 1)]


func _on_dao_progress(_progress: Dictionary) -> void:
	_refresh_dao_progress()


func _on_dao_awakened(tradition: Dictionary) -> void:
	dao_label.text = "道统：%s ✓" % tradition.get("name", "")


func _on_karma_changed(karma: Dictionary) -> void:
	_refresh_meta_labels()


func _refresh_meta_labels() -> void:
	var trial := "心魔试炼中" if RunContext.heart_demon_trial_active else "无试炼"
	var shard_text := "碎片+%d" % RunContext.heart_demon_shards_earned if RunContext.heart_demon_shards_earned > 0 else "碎片+0"
	var good := int(RunContext.karma.get("good", 0))
	var evil := int(RunContext.karma.get("evil", 0))
	var greed := int(RunContext.karma.get("greed", 0))
	var rebel := int(RunContext.karma.get("rebellion", 0))
	meta_label.text = "%s · %s · 善%d恶%d贪%d逆%d" % [trial, shard_text, good, evil, greed, rebel]


func _on_pet_coord_feedback(text: String) -> void:
	damage_label.text = text
	damage_label.modulate = Color(1.0, 0.65, 0.25)
	damage_label.modulate.a = 1.0
	_refresh_meta_labels()


func _process(delta: float) -> void:
	_tick_learn_toast(delta)
	if not RunContext.pet_acquired:
		return
	var pet := get_tree().get_first_node_in_group("pet")
	if pet == null or not pet.has_method("get_coord_cd_remaining"):
		return
	var cd: float = pet.get_coord_cd_remaining()
	var base := "灵宠：%s ✓" % RunContext.pet_display_name
	if cd <= 0.05:
		pet_label.text = "%s | 自动助战 | V 协同就绪" % base
	else:
		pet_label.text = "%s | 自动助战 | V 冷却 %.0fs" % [base, ceilf(cd)]


func _refresh_pet_label() -> void:
	if RunContext.pet_acquired:
		pet_label.text = "灵宠：%s ✓ | 自动助战 | V 协同就绪" % RunContext.pet_display_name
	else:
		pet_label.text = "灵宠：未结缘（首关关底 BOSS）"


func _on_damage_dealt(result: Dictionary) -> void:
	if not SaveManager.get_display_setting("show_damage_numbers"):
		damage_label.modulate.a = 0.0
		return
	var dmg: float = result.get("final_damage", 0.0)
	var crit: bool = result.get("is_crit", false)
	var combo_hit: bool = result.get("is_combo", false)
	if combo_hit:
		damage_label.text = "爆燃 %.0f!" % dmg
	elif crit:
		damage_label.text = "天机 %.0f!" % dmg
	else:
		damage_label.text = "伤害 %.0f" % dmg
	damage_label.modulate = Color.WHITE
	damage_label.modulate.a = 1.0


func _on_wave_cleared(wave: int) -> void:
	wave_label.text = "第 %d 波已清场 · 选择机缘" % wave


func _on_combo_discovered(combo_id: String) -> void:
	combo_track_label.text = "Combo 觉醒：%s" % combo_id


func _on_skill_unlocked(_skill_id: String, _layer: int) -> void:
	_refresh_skill()


func _on_spell_unlock_changed(_slots: Array) -> void:
	_refresh_active_spell_label()
	_pulse_active_spell_label()


func _on_learn_feedback(text: String, accent: String = "spell") -> void:
	if text.is_empty():
		return
	var color: Color = LEARN_TOAST_COLORS.get(accent, LEARN_TOAST_COLORS["spell"])
	learn_toast.text = text
	learn_toast.add_theme_color_override("font_color", color)
	learn_toast.modulate = Color.WHITE
	learn_toast.modulate.a = 1.0
	_learn_toast_timer = 3.2
	if accent in ["spell", "rebind"]:
		_refresh_active_spell_label()
		_pulse_active_spell_label()


func _tick_learn_toast(delta: float) -> void:
	if _learn_toast_timer <= 0.0:
		if learn_toast.modulate.a > 0.0:
			learn_toast.modulate.a = 0.0
		return
	_learn_toast_timer = maxf(_learn_toast_timer - delta, 0.0)
	if _learn_toast_timer < 0.9:
		learn_toast.modulate.a = clampf(_learn_toast_timer / 0.9, 0.0, 1.0)


func _pulse_active_spell_label() -> void:
	active_spell_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	var tween := create_tween()
	tween.tween_callback(func():
		active_spell_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
	).set_delay(1.2)


func _refresh_affixes() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		affix_label.text = "道路：暂无词条"
		return
	var holder: Node = player.get_node("AffixHolder")
	var lines: PackedStringArray = holder.get_summary_lines()
	var slot_text := " (%d/%d)" % [holder.equipped.size(), holder.get_max_affixes()]
	affix_label.text = "道路%s：" % slot_text + " | ".join(lines)
	_refresh_build()


func _refresh_skill() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("SkillProgression"):
		skill_label.text = "功法：烈焰掌 Lv.1"
		return
	var lines: PackedStringArray = player.get_node("SkillProgression").get_display_lines()
	skill_label.text = "功法：" + " · ".join(lines)


func _refresh_active_spell_label() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("PlayerSpellCaster"):
		active_spell_label.text = "Q 烈焰弹 · 就绪\nE 雷击印 · 未解锁\nR 玄冰扇 · 未解锁"
		return
	var caster: Node = player.get_node("PlayerSpellCaster")
	if caster.has_method("get_spell_display_lines"):
		active_spell_label.text = "\n".join(caster.get_spell_display_lines())
	else:
		active_spell_label.text = "Q 烈焰弹 · 就绪"


func _on_spell_cooldown(_slot: String, _remaining: float, _total: float) -> void:
	_refresh_active_spell_label()


func _on_spell_cast(_slot: String, _spell: Dictionary) -> void:
	_refresh_active_spell_label()


func _refresh_combo_track() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("AffixHolder"):
		return
	var info: Dictionary = player.get_node("AffixHolder").get_combo_display()
	var pct: int = int(float(info.get("progress", 0.0)) * 100.0)
	var matched: Array = info.get("matched", [])
	var total: int = int(info.get("total", 1))
	combo_track_label.text = "Combo %s %d/%d (%d%%)" % [
		info.get("name", "—"),
		matched.size(),
		total,
		pct,
	]
