extends Node



const GameConstants = preload("res://core/constants/game_constants.gd")

const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")

const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")

const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")

const CultivationPathRegistry = preload("res://systems/realm/cultivation_path_registry.gd")
const WeaponModCatalog = preload("res://systems/equipment/weapon_mod_catalog.gd")
const CsvLoader = preload("res://systems/affix/csv_loader.gd")



var seed_value := 0

var gold := GameConstants.STARTING_GOLD

var run_active := false

var current_stage := 0

var current_room := 0

var rooms_cleared := 0

var run_plan: Array = []

var pet_id := ""

var pet_display_name := ""

var pet_acquired := false

var cultivation_path_id := CultivationPathRegistry.DEFAULT_PATH_ID

var cultivation_path_name := ""

var weapon_id := WeaponRegistry.DEFAULT_WEAPON_ID

var weapon_display_name := ""
var weapon_mods: Array = []

var dao_momentum := 0.0

var dao_momentum_max := 100.0

var dao_momentum_state := "idle"

var dao_momentum_state_time := 0.0



var dao_heart: int = DaoHeartConfig.DaoHeart.ENLIGHTEN

var realm_level := 1

var breakthrough_done := false

var affix_slot_cap := 3

var realm_talents: Array = []

var ui_blocking := false



var heart_demon_trial_active := false

var heart_demon_boost := false

var heart_demon_shards_earned := 0

var dao_tradition_awakened_this_run := ""

var next_affix_bias := ""
var pending_temptation_penalty: Dictionary = {}

var peak_dao_momentum := 0.0

var peak_combo_count := 0

var last_horde_kills := 0

var last_horde_quota := 0

var last_boss_hp_ratio := 1.0

var last_boss_name := ""

var last_death_summary: Dictionary = {}

var run_highlights: Array[Dictionary] = []
var weather_kills_this_room := 0
var rooms_without_weather_kill := 0

var _death_line_pool: Array[Dictionary] = []



var training_mode := false

var training_wave := 0



const REALM_CORE_SLOT_BEFORE := {1: 3, 2: 4, 3: 5, 4: 6, 5: 7}
const REALM_CORE_SLOT_AFTER := {1: 4, 2: 5, 3: 6, 4: 7, 5: 7}
const REALM_TEMP_SLOT_BEFORE := {1: 2, 2: 3, 3: 3, 4: 4, 5: 4}
const REALM_TEMP_SLOT_AFTER := {1: 3, 2: 3, 3: 4, 4: 4, 5: 4}
const REALM_SEALED_SLOT_BEFORE := {1: 1, 2: 1, 3: 2, 4: 2, 5: 3}
const REALM_SEALED_SLOT_AFTER := {1: 1, 2: 2, 3: 2, 4: 3, 5: 3}
const REALM_SLOT_BEFORE := {1: 5, 2: 7, 3: 8, 4: 10, 5: 11}
const REALM_SLOT_AFTER := {1: 7, 2: 8, 3: 10, 4: 11, 5: 11}

const REALM_STAT_GROWTH := {
	1: {"hp": 1.0, "mana": 1.0, "attack": 1.0, "defense": 1.0, "move_speed": 1.0, "dodge_cooldown": 1.0, "spell_cooldown": 1.0, "crit_rate": 0.0, "crit_mult": 0.0},
	2: {"hp": 1.45, "mana": 1.35, "attack": 1.22, "defense": 1.25, "move_speed": 1.08, "dodge_cooldown": 0.94, "spell_cooldown": 0.94, "crit_rate": 0.03, "crit_mult": 0.08},
	3: {"hp": 2.05, "mana": 1.85, "attack": 1.55, "defense": 1.65, "move_speed": 1.16, "dodge_cooldown": 0.88, "spell_cooldown": 0.88, "crit_rate": 0.06, "crit_mult": 0.16},
	4: {"hp": 2.85, "mana": 2.45, "attack": 1.95, "defense": 2.15, "move_speed": 1.24, "dodge_cooldown": 0.82, "spell_cooldown": 0.82, "crit_rate": 0.09, "crit_mult": 0.26},
	5: {"hp": 3.8, "mana": 3.2, "attack": 2.45, "defense": 2.8, "move_speed": 1.32, "dodge_cooldown": 0.76, "spell_cooldown": 0.76, "crit_rate": 0.12, "crit_mult": 0.38},
}

const PATH_STAT_BIAS := {
	"caster": {"hp": 0.94, "mana": 1.28, "attack": 1.06, "defense": 0.92, "move_speed": 0.98, "dodge_cooldown": 1.02, "spell_cooldown": 0.82, "crit_rate": 0.02, "crit_mult": 0.08},
	"sword": {"hp": 1.06, "mana": 0.88, "attack": 1.14, "defense": 1.0, "move_speed": 1.1, "dodge_cooldown": 0.9, "spell_cooldown": 1.06, "crit_rate": 0.04, "crit_mult": 0.12},
	"talisman": {"hp": 1.22, "mana": 1.08, "attack": 0.96, "defense": 1.18, "move_speed": 0.94, "dodge_cooldown": 1.04, "spell_cooldown": 0.96, "crit_rate": 0.0, "crit_mult": 0.0},
	"soul": {"hp": 0.9, "mana": 1.18, "attack": 1.18, "defense": 0.88, "move_speed": 1.04, "dodge_cooldown": 0.96, "spell_cooldown": 0.9, "crit_rate": 0.03, "crit_mult": 0.18},
}



const FNV_OFFSET := 2166136261

const FNV_PRIME := 16777619



var _bootstrap_rng := RandomNumberGenerator.new()

const DAO_CLARITY_DURATION := 6.0
const DAO_EXTREME_DURATION := 8.0

const DAO_MOMENTUM_GRACE_SEC := 8.0





func derive_rng_seed(context: String) -> int:

	var h := FNV_OFFSET

	h = _fnv_mix_int(h, seed_value)

	for i in context.length():

		h = _fnv_mix_int(h, context.unicode_at(i))

	return h & 0x7FFFFFFF





func _fnv_mix_int(h: int, value: int) -> int:

	h = h ^ (value & 0xFFFFFFFF)

	return int((h * FNV_PRIME) & 0xFFFFFFFF)





func begin_run(
	heart: int,
	seed_override: int = -1,
	use_heart_demon_boost: bool = false,
	is_training: bool = false,
	path_id: String = CultivationPathRegistry.DEFAULT_PATH_ID,
) -> void:

	training_mode = is_training

	training_wave = 0

	dao_heart = heart

	realm_level = 1

	breakthrough_done = false

	affix_slot_cap = int(REALM_SLOT_BEFORE.get(1, 3))

	realm_talents.clear()

	heart_demon_trial_active = false

	heart_demon_boost = use_heart_demon_boost and SaveManager.get_heart_demon_shards() >= 3

	heart_demon_shards_earned = 0

	dao_tradition_awakened_this_run = ""

	next_affix_bias = ""
	pending_temptation_penalty.clear()
	weapon_mods.clear()

	reset_run_highlights()

	set_cultivation_path(path_id, false)

	reset_dao_momentum()

	KarmaTracker.reset()

	SpellProgress.reset()

	start_run(seed_override)

	if is_training:

		run_plan = []





func begin_training_run(seed_override: int = -1) -> void:

	begin_run(DaoHeartConfig.DaoHeart.ENLIGHTEN, seed_override, false, true, CultivationPathRegistry.DEFAULT_PATH_ID)





func start_run(seed_override: int = -1) -> void:

	seed_value = seed_override if seed_override >= 0 else (_bootstrap_rng.randi() & 0x7FFFFFFF)

	CombatRngService.reset()

	gold = GameConstants.STARTING_GOLD + int(MetaUpgradeRegistry.get_total("start_gold"))

	run_active = true

	current_stage = 0

	current_room = 0

	rooms_cleared = 0

	pet_id = ""

	pet_display_name = ""

	pet_acquired = false

	reset_run_highlights()

	set_weapon(weapon_id, false)

	reset_dao_momentum()

	var StageGenerator = preload("res://systems/world/stage_generator.gd")

	if training_mode:

		run_plan = []

	else:

		run_plan = StageGenerator.generate(dao_heart, KarmaTracker.events_seen)

	SaveManager.set_last_run_seed(seed_value)

	EventBus.run_started.emit(seed_value)

	EventBus.realm_changed.emit(realm_level, affix_slot_max())

	EventBus.weapon_changed.emit(WeaponRegistry.get_weapon(weapon_id))

	_emit_dao_momentum_changed()

	if heart_demon_boost and not training_mode:

		SaveManager.consume_heart_demon_shards(3)





func affix_slot_max() -> int:

	return affix_slot_cap





func affix_slot_info(level: int = -1, after_breakthrough: bool = false) -> Dictionary:
	if level < 0:
		level = realm_level
	var core_table := REALM_CORE_SLOT_AFTER if after_breakthrough else REALM_CORE_SLOT_BEFORE
	var temp_table := REALM_TEMP_SLOT_AFTER if after_breakthrough else REALM_TEMP_SLOT_BEFORE
	var sealed_table := REALM_SEALED_SLOT_AFTER if after_breakthrough else REALM_SEALED_SLOT_BEFORE
	var core := int(core_table.get(level, 3))
	var temporary := int(temp_table.get(level, 2))
	var sealed := int(sealed_table.get(level, 1))
	return {
		"core": core,
		"temporary": temporary,
		"sealed": sealed,
		"active": core + temporary,
	}


func affix_core_slot_max() -> int:
	return int(affix_slot_info().get("core", 3))


func affix_temporary_slot_max() -> int:
	return int(affix_slot_info().get("temporary", 2))


func affix_sealed_slot_max() -> int:
	return int(affix_slot_info().get("sealed", 1))


func preview_slots_after_breakthrough() -> int:

	return int(REALM_SLOT_AFTER.get(realm_level, affix_slot_cap + 2))





func realm_name() -> String:

	match realm_level:

		1: return "炼气"

		2: return "筑基"

		3: return "金丹"

		4: return "元婴"

		5: return "渡劫"

	return "炼气"


func realm_stat_growth(level: int = -1) -> Dictionary:
	if level < 0:
		level = realm_level
	var clamped_level := clampi(level, 1, 5)
	return REALM_STAT_GROWTH.get(clamped_level, REALM_STAT_GROWTH[1]).duplicate()


func apply_realm_growth_to_stats(stats: Dictionary, level: int = -1) -> Dictionary:
	if level < 0:
		level = realm_level
	var growth := realm_stat_growth(level)
	var bias := path_stat_bias()
	var out := stats.duplicate()
	out["hp"] = float(out.get("hp", 100.0)) * float(growth.get("hp", 1.0)) * float(bias.get("hp", 1.0))
	out["mana"] = float(out.get("mana", 100.0)) * float(growth.get("mana", 1.0)) * float(bias.get("mana", 1.0))
	out["attack"] = float(out.get("attack", 10.0)) * float(growth.get("attack", 1.0)) * float(bias.get("attack", 1.0))
	out["defense"] = float(out.get("defense", 0.0)) * float(growth.get("defense", 1.0)) * float(bias.get("defense", 1.0))
	out["move_speed"] = float(out.get("move_speed", 255.0)) * float(growth.get("move_speed", 1.0)) * float(bias.get("move_speed", 1.0))
	out["dodge_cooldown"] = float(out.get("dodge_cooldown", 1.0)) * float(growth.get("dodge_cooldown", 1.0)) * float(bias.get("dodge_cooldown", 1.0))
	out["spell_cooldown"] = float(out.get("spell_cooldown", 1.0)) * float(growth.get("spell_cooldown", 1.0)) * float(bias.get("spell_cooldown", 1.0))
	out["crit_rate"] = float(out.get("crit_rate", 0.0)) + float(growth.get("crit_rate", 0.0)) + float(bias.get("crit_rate", 0.0))
	out["crit_mult"] = float(out.get("crit_mult", 1.5)) + float(growth.get("crit_mult", 0.0)) + float(bias.get("crit_mult", 0.0))
	return out


func path_stat_bias(path_id: String = "") -> Dictionary:
	var key := path_id if not path_id.is_empty() else cultivation_path_id
	if not PATH_STAT_BIAS.has(key):
		key = CultivationPathRegistry.DEFAULT_PATH_ID
	return (PATH_STAT_BIAS.get(key, {}) as Dictionary).duplicate()


func get_spell_cooldown_mult(base_mult: float = 1.0) -> float:
	var growth := realm_stat_growth()
	var bias := path_stat_bias()
	return base_mult * float(growth.get("spell_cooldown", 1.0)) * float(bias.get("spell_cooldown", 1.0)) * get_dao_clarity_cooldown_mult()


func realm_growth_summary(level: int = -1) -> String:
	if level < 0:
		level = realm_level
	var growth := realm_stat_growth(level)
	var bias := path_stat_bias()
	return "生命x%.2f / 攻击x%.2f / 移速x%.2f / 法冷x%.2f" % [
		float(growth.get("hp", 1.0)) * float(bias.get("hp", 1.0)),
		float(growth.get("attack", 1.0)) * float(bias.get("attack", 1.0)),
		float(growth.get("move_speed", 1.0)) * float(bias.get("move_speed", 1.0)),
		float(growth.get("spell_cooldown", 1.0)) * float(bias.get("spell_cooldown", 1.0)),
	]





func sync_realm_to_stage(stage_index: int) -> void:

	realm_level = stage_index

	breakthrough_done = false

	affix_slot_cap = int(REALM_SLOT_BEFORE.get(realm_level, 3))

	EventBus.realm_changed.emit(realm_level, affix_slot_cap)





func complete_breakthrough() -> void:

	if breakthrough_done:

		return

	breakthrough_done = true

	affix_slot_cap = preview_slots_after_breakthrough()

	SpellProgress.grant_for_realm(realm_level, affix_slot_cap)

	EventBus.realm_changed.emit(realm_level, affix_slot_cap)





func add_realm_talent(talent_id: String) -> void:

	if talent_id not in realm_talents:

		realm_talents.append(talent_id)





func get_reroll_cost() -> int:

	var discount := int(MetaUpgradeRegistry.get_total("reroll_discount"))

	return maxi(GameConstants.AFFIX_REROLL_COST - discount, 10)





func get_meta_hp_bonus() -> float:

	return MetaUpgradeRegistry.get_total("hp")





func get_enemy_hp_mult(is_boss: bool) -> float:

	var mult := DaoHeartConfig.enemy_hp_mult(dao_heart, is_boss)

	if heart_demon_trial_active:

		mult *= 1.15

	if heart_demon_boost:

		mult *= 1.10

	return mult





func get_current_room_def() -> Dictionary:

	if run_plan.is_empty() or current_stage >= run_plan.size():

		return {}

	var stage: Dictionary = run_plan[current_stage]

	var rooms: Array = stage.get("rooms", [])

	if current_room >= rooms.size():

		return {}

	return rooms[current_room]





func get_current_stage_def() -> Dictionary:

	if run_plan.is_empty() or current_stage >= run_plan.size():

		return {}

	return run_plan[current_stage]


func set_temptation_penalty(penalty_id: String, label: String, params: Dictionary = {}) -> void:
	if penalty_id.is_empty():
		return
	pending_temptation_penalty = {
		"id": penalty_id,
		"label": label,
		"params": params.duplicate(true),
	}


func consume_temptation_penalty() -> Dictionary:
	var out := pending_temptation_penalty.duplicate(true)
	pending_temptation_penalty.clear()
	return out





func advance_room() -> void:

	current_room += 1

	rooms_cleared += 1

	var stage: Dictionary = get_current_stage_def()

	if current_room >= stage.get("rooms", []).size():

		current_stage += 1

		current_room = 0

		if current_stage < run_plan.size():

			var next_stage: Dictionary = run_plan[current_stage]

			sync_realm_to_stage(int(next_stage.get("stage_index", current_stage + 1)))

		if current_stage >= run_plan.size():

			run_active = false





func is_run_finished() -> bool:

	return not run_active and current_stage >= run_plan.size()





func acquire_pet(id: String) -> void:

	pet_id = id

	pet_display_name = ConfigRegistry.get_pet_display_name(id)

	pet_acquired = true

	EventBus.pet_acquired.emit(id)


func set_cultivation_path(path_id: String, announce: bool = true) -> void:
	var path := CultivationPathRegistry.get_path_def(path_id)
	cultivation_path_id = str(path.get("path_id", CultivationPathRegistry.DEFAULT_PATH_ID))
	cultivation_path_name = str(path.get("name", cultivation_path_id))
	set_weapon(str(path.get("weapon_id", WeaponRegistry.DEFAULT_WEAPON_ID)), announce)


func set_weapon(id: String, announce: bool = true) -> void:
	var weapon := WeaponRegistry.get_weapon(id)
	weapon_id = str(weapon.get("weapon_id", WeaponRegistry.DEFAULT_WEAPON_ID))
	weapon_display_name = str(weapon.get("name", weapon_id))
	if announce:
		EventBus.weapon_changed.emit(weapon)


func get_weapon() -> Dictionary:
	return WeaponRegistry.get_weapon(weapon_id)


func add_weapon_mod(mod_id: String) -> bool:
	if mod_id.is_empty() or mod_id in weapon_mods:
		return false
	var mod := WeaponModCatalog.get_mod(mod_id)
	if mod.is_empty():
		return false
	weapon_mods.append(mod_id)
	EventBus.weapon_changed.emit(get_weapon())
	EventBus.learn_feedback.emit("本命器祭炼 · %s" % str(mod.get("name", mod_id)), "skill")
	return true


func get_weapon_mod_effects() -> Dictionary:
	var effects := {
		"damage_mult": 1.0,
		"range_mult": 1.0,
		"attack_interval_mult": 1.0,
		"element_override": "",
		"status_on_hit": "",
		"status_duration": 0.0,
	}
	for mod_id in weapon_mods:
		var mod := WeaponModCatalog.get_mod(str(mod_id))
		if mod.is_empty():
			continue
		effects["damage_mult"] = float(effects.get("damage_mult", 1.0)) * float(mod.get("damage_mult", 1.0))
		effects["range_mult"] = float(effects.get("range_mult", 1.0)) * float(mod.get("range_mult", 1.0))
		effects["attack_interval_mult"] = float(effects.get("attack_interval_mult", 1.0)) * float(mod.get("attack_interval_mult", 1.0))
		if not str(mod.get("element_override", "")).is_empty():
			effects["element_override"] = str(mod.get("element_override", ""))
		if not str(mod.get("status_on_hit", "")).is_empty():
			effects["status_on_hit"] = str(mod.get("status_on_hit", ""))
			effects["status_duration"] = maxf(float(effects.get("status_duration", 0.0)), float(mod.get("status_duration", 0.0)))
	return effects


func weapon_mod_summary() -> String:
	if weapon_mods.is_empty():
		return "未祭炼"
	var names: PackedStringArray = []
	for mod_id in weapon_mods:
		var mod := WeaponModCatalog.get_mod(str(mod_id))
		if not mod.is_empty():
			names.append(str(mod.get("name", mod_id)))
	return "、".join(names)


func reset_dao_momentum() -> void:
	dao_momentum = 0.0
	dao_momentum_state = "idle"
	dao_momentum_state_time = 0.0
	_emit_dao_momentum_changed()


func add_dao_momentum(amount: float, source: String = "") -> void:
	if amount <= 0.0 or dao_momentum_state == "clarity" or dao_momentum_state == "dao_extreme":
		return
	dao_momentum = clampf(dao_momentum + amount, 0.0, dao_momentum_max)
	peak_dao_momentum = maxf(peak_dao_momentum, dao_momentum)
	if dao_momentum >= dao_momentum_max:
		dao_momentum = dao_momentum_max
		if dao_momentum_state != "full":
			dao_momentum_state = "full"
			dao_momentum_state_time = DAO_MOMENTUM_GRACE_SEC
			EventBus.learn_feedback.emit("道韵盈满 · 万法将成", "skill")
			EventBus.crit_moment_requested.emit("道韵盈满 · F归一", 0.55)
	_emit_dao_momentum_changed()


func consume_dao_momentum(amount: float) -> bool:
	if dao_momentum < amount:
		return false
	dao_momentum = maxf(dao_momentum - amount, 0.0)
	if dao_momentum_state != "idle" and dao_momentum < dao_momentum_max:
		dao_momentum_state = "idle"
		dao_momentum_state_time = 0.0
	_emit_dao_momentum_changed()
	return true


func trigger_dao_clarity(source: String = "auto") -> void:
	if dao_momentum_state == "clarity" or dao_momentum_state == "dao_extreme":
		return
	dao_momentum = 0.0
	if source == "combo_200":
		dao_momentum_state = "dao_extreme"
		dao_momentum_state_time = DAO_EXTREME_DURATION
		EventBus.dao_clarity_started.emit(DAO_EXTREME_DURATION, source)
		EventBus.learn_feedback.emit("道之极致 · 金痕绕身", "skill")
		EventBus.crit_moment_requested.emit("道之极致", 0.8)
	else:
		dao_momentum_state = "clarity"
		dao_momentum_state_time = DAO_CLARITY_DURATION
		EventBus.dao_clarity_started.emit(DAO_CLARITY_DURATION, source)
		EventBus.learn_feedback.emit("道法通明 · 诸法皆顺", "skill")
		EventBus.crit_moment_requested.emit("道法通明", 0.45)
	_emit_dao_momentum_changed()


func trigger_unity_burst(source: String = "manual") -> bool:
	if dao_momentum_state != "full" and dao_momentum < dao_momentum_max:
		return false
	var payload := {
		"source": source,
		"weapon_id": weapon_id,
		"weapon_family": str(get_weapon().get("family", "")),
	}
	dao_momentum = 0.0
	dao_momentum_state = "idle"
	dao_momentum_state_time = 0.0
	EventBus.unity_burst_requested.emit(payload)
	EventBus.learn_feedback.emit("万法归一 · %s" % weapon_display_name, "skill")
	_emit_dao_momentum_changed()
	return true


func tick_dao_momentum(delta: float) -> void:
	if dao_momentum_state == "idle":
		return
	dao_momentum_state_time = maxf(dao_momentum_state_time - delta, 0.0)
	if dao_momentum_state_time > 0.0:
		_emit_dao_momentum_changed()
		return
	if dao_momentum_state == "full":
		trigger_dao_clarity("auto")
	elif dao_momentum_state == "clarity" or dao_momentum_state == "dao_extreme":
		dao_momentum = 0.0
		dao_momentum_state = "idle"
		dao_momentum_state_time = 0.0
		EventBus.dao_clarity_ended.emit()
		_emit_dao_momentum_changed()


func get_dao_clarity_attack_mult() -> float:
	if dao_momentum_state == "dao_extreme":
		return 1.6
	return 1.35 if dao_momentum_state == "clarity" else 1.0


func get_dao_clarity_cooldown_mult() -> float:
	if dao_momentum_state == "dao_extreme":
		return 0.5
	return 0.75 if dao_momentum_state == "clarity" else 1.0


func _emit_dao_momentum_changed() -> void:
	EventBus.dao_momentum_changed.emit(dao_momentum, dao_momentum_max, dao_momentum_state, dao_momentum_state_time)





func finalize_run_meta(victory: bool) -> void:

	if heart_demon_shards_earned > 0:

		SaveManager.add_heart_demon_shards(heart_demon_shards_earned)

	if not dao_tradition_awakened_this_run.is_empty():

		SaveManager.record_dao_tradition(dao_tradition_awakened_this_run)

	if victory:

		SaveManager.add_reincarnation_points(100 + rooms_cleared * 5)

	else:

		SaveManager.add_reincarnation_points(20 + rooms_cleared * 2)


func reset_run_highlights() -> void:
	peak_dao_momentum = 0.0
	peak_combo_count = 0
	last_horde_kills = 0
	last_horde_quota = 0
	last_boss_hp_ratio = 1.0
	last_boss_name = ""
	run_highlights.clear()
	weather_kills_this_room = 0
	rooms_without_weather_kill = 0
	last_death_summary.clear()


func record_combo_count(count: int) -> void:
	peak_combo_count = maxi(peak_combo_count, count)


func record_horde_progress(kills: int, quota: int) -> void:
	last_horde_kills = maxi(kills, 0)
	last_horde_quota = maxi(quota, 0)


func record_boss_hp_ratio(boss_name: String, ratio: float) -> void:
	last_boss_hp_ratio = clampf(ratio, 0.0, 1.0)
	last_boss_name = boss_name


func record_run_highlight(id: String, title: String, detail: String, priority: int = 1) -> void:
	if id.is_empty() or title.is_empty():
		return
	var existing_index := -1
	for i in run_highlights.size():
		if str(run_highlights[i].get("id", "")) == id:
			existing_index = i
			break
	var row := {
		"id": id,
		"title": title,
		"detail": detail,
		"priority": priority,
		"room": rooms_cleared,
		"time_ms": Time.get_ticks_msec(),
	}
	if existing_index >= 0:
		if priority >= int(run_highlights[existing_index].get("priority", 0)):
			run_highlights[existing_index] = row
	else:
		run_highlights.append(row)


func begin_weather_kill_room() -> void:
	weather_kills_this_room = 0


func finish_weather_kill_room() -> void:
	if weather_kills_this_room > 0:
		rooms_without_weather_kill = 0
	else:
		rooms_without_weather_kill += 1


func record_weather_kill(enemy: Node, weather_id: String, payload: Dictionary = {}) -> void:
	if weather_id.is_empty() or weather_id == "clear":
		return
	weather_kills_this_room += 1
	var weather_name := WeatherSystem.current_weather_name
	EventBus.weather_kill.emit(enemy, weather_id, payload)
	if weather_kills_this_room == 1:
		record_run_highlight("weather_kill_%d_%d" % [current_stage, current_room], "%s天象击杀" % weather_name, "借天时地利斩落敌人，道势因此翻涌。", 65)


func get_best_run_highlight() -> Dictionary:
	var best: Dictionary = {}
	for row in run_highlights:
		if best.is_empty():
			best = row
			continue
		var priority := int(row.get("priority", 0))
		var best_priority := int(best.get("priority", 0))
		if priority > best_priority:
			best = row
		elif priority == best_priority and int(row.get("time_ms", 0)) > int(best.get("time_ms", 0)):
			best = row
	return best.duplicate()


func build_death_summary() -> Dictionary:
	var regret := "generic_low"
	var regret_title := "本局遗憾"
	var regret_detail := "这一世的路还未走完。"
	var last_words := "尘土盖住脚印，但道心还未冷。"
	var progress_level := "low"

	var dao_pct := 0
	if dao_momentum_max > 0.0:
		dao_pct = int(round(clampf(peak_dao_momentum / dao_momentum_max, 0.0, 1.0) * 100.0))

	if last_boss_hp_ratio > 0.0 and last_boss_hp_ratio <= 0.15:
		regret = "boss_low_hp"
		regret_title = "一息之差"
		regret_detail = "%s 只剩最后一口气，若再撑一轮就能斩落。" % (last_boss_name if not last_boss_name.is_empty() else "Boss")
		last_words = "他只剩最后一口气了。"
		progress_level = "high"
	elif not dao_tradition_awakened_this_run.is_empty():
		regret = "dao_complete"
		regret_title = "道统已醒"
		regret_detail = "这一世已唤醒道统，来世可从这条路继续深挖。"
		last_words = "道已留痕，下一世不必从零开始。"
		progress_level = "high"
	elif dao_pct >= 80:
		regret = "dao_power_high"
		regret_title = "道势将满"
		regret_detail = "道势峰值 %d/%d，只差一次爆发就能改写战局。" % [int(round(peak_dao_momentum)), int(dao_momentum_max)]
		last_words = "天地之势已聚，只差最后一息。"
		progress_level = "high"
	elif peak_combo_count >= 50:
		regret = "combo_broken"
		regret_title = "道韵中断"
		regret_detail = "最高连击 %d，节奏已经成形，却没能踏到最后一拍。" % peak_combo_count
		last_words = "道韵奔流而中断，可惜。"
		progress_level = "medium"
	elif last_horde_quota > 0 and last_horde_kills >= maxi(last_horde_quota - 3, 1):
		regret = "missed_room_momentum"
		regret_title = "魔劫未尽"
		regret_detail = "最后一波斩魔 %d/%d，只差几只就能脱身。" % [last_horde_kills, last_horde_quota]
		last_words = "你没有等到破局的那一刻。"
		progress_level = "medium"
	elif rooms_cleared >= 3:
		regret = "run_cut_short"
		regret_title = "半途折返"
		regret_detail = "已清理房间 %d 间，构筑刚开始长出形状。" % rooms_cleared
		last_words = "你看见了方向，只是还没走近。"
		progress_level = "low"

	var line_row := _pick_death_line(regret, progress_level)
	if not line_row.is_empty():
		last_words = str(line_row.get("line", last_words))
		SaveManager.record_death_line(str(line_row.get("line_id", "")))

	var best_highlight := get_best_run_highlight()
	var highlight_line := ""
	if not best_highlight.is_empty():
		highlight_line = "%s——%s" % [str(best_highlight.get("title", "")), str(best_highlight.get("detail", ""))]

	last_death_summary = {
		"regret": regret,
		"title": regret_title,
		"detail": regret_detail,
		"line": last_words,
		"highlight_line": highlight_line,
		"highlight": best_highlight,
		"progress_level": progress_level,
		"dao_peak": int(round(peak_dao_momentum)),
		"dao_max": int(dao_momentum_max),
		"combo_peak": peak_combo_count,
		"horde_kills": last_horde_kills,
		"horde_quota": last_horde_quota,
		"boss_hp_ratio": last_boss_hp_ratio,
		"boss_name": last_boss_name,
	}
	return last_death_summary.duplicate()


func _pick_death_line(regret: String, progress_level: String) -> Dictionary:
	if _death_line_pool.is_empty():
		_death_line_pool = CsvLoader.load_rows("res://data/design/death_line_pool.csv")
	var candidates: Array[Dictionary] = []
	for row in _death_line_pool:
		if str(row.get("regret_type", "")) == regret:
			candidates.append(row)
	if candidates.is_empty() and regret == "dao_complete":
		for row in _death_line_pool:
			if str(row.get("regret_type", "")) == "dao_almost":
				candidates.append(row)
	if candidates.is_empty():
		for row in _death_line_pool:
			if str(row.get("progress_level", "")) == progress_level:
				candidates.append(row)
	if candidates.is_empty():
		return {}
	var recent := SaveManager.get_recent_death_line_ids()
	for row in candidates:
		if not str(row.get("line_id", "")) in recent:
			return row
	return candidates[0]





func _ready() -> void:

	_bootstrap_rng.randomize()
	EventBus.combo_updated.connect(record_combo_count)
	EventBus.horde_updated.connect(_on_horde_updated)
	EventBus.combo_milestone.connect(_on_combo_milestone)
	EventBus.hidden_chain_discovered.connect(_on_hidden_chain_discovered)
	EventBus.dao_tradition_awakened.connect(_on_dao_tradition_awakened)
	EventBus.unity_burst_requested.connect(_on_unity_burst_requested)
	EventBus.room_entered.connect(func(_room: Dictionary, _stage: Dictionary) -> void: begin_weather_kill_room())


func _on_combo_milestone(count: int) -> void:
	if count >= 200:
		record_run_highlight("combo_200", "道之极致", "二百连击压住全场，攻势短暂踏入巅峰。", 90)
	elif count >= 100:
		record_run_highlight("combo_100", "百连道韵", "连击破百，节奏已经被你打成自己的道。", 70)
	elif count >= 60:
		record_run_highlight("combo_60", "连击成势", "六十连击不断，构筑开始真正转起来。", 50)


func _on_hidden_chain_discovered(chain_id: String, display_name: String, payload: Dictionary) -> void:
	var hint := str(payload.get("hint", "隐藏连锁被这一世亲手点亮。"))
	record_run_highlight("hidden_%s" % chain_id, "连锁发现：%s" % display_name, hint, 95)


func _on_dao_tradition_awakened(tradition: Dictionary) -> void:
	var display_name := str(tradition.get("display_name", tradition.get("name", "道统觉醒")))
	record_run_highlight("dao_awaken_%s" % str(tradition.get("id", display_name)), display_name, "道统在战场中成形，这条路已经留下痕迹。", 85)


func _on_unity_burst_requested(payload: Dictionary) -> void:
	var source := str(payload.get("source", "manual"))
	record_run_highlight("unity_%s_%d" % [source, rooms_cleared], "万法归一", "道势爆发的一刻，整场战斗被强行改写。", 80)


func _on_horde_updated(kills: int, quota: int, _time_left: float, _wave: int, _next_wave_in: float) -> void:
	record_horde_progress(kills, quota)
