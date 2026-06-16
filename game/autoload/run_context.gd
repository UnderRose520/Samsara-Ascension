extends Node



const GameConstants = preload("res://core/constants/game_constants.gd")

const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")

const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")

const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")

const CultivationPathRegistry = preload("res://systems/realm/cultivation_path_registry.gd")
const WeaponModCatalog = preload("res://systems/equipment/weapon_mod_catalog.gd")



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



var training_mode := false

var training_wave := 0



const REALM_SLOT_BEFORE := {1: 3, 2: 5, 3: 7, 4: 9, 5: 12}

const REALM_SLOT_AFTER := {1: 5, 2: 7, 3: 9, 4: 12, 5: 12}

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
	weapon_mods.clear()

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
	out["spell_cooldown"] = float(growth.get("spell_cooldown", 1.0)) * float(bias.get("spell_cooldown", 1.0))
	out["crit_rate"] = float(out.get("crit_rate", 0.0)) + float(growth.get("crit_rate", 0.0)) + float(bias.get("crit_rate", 0.0))
	out["crit_mult"] = float(out.get("crit_mult", 1.5)) + float(growth.get("crit_mult", 0.0)) + float(bias.get("crit_mult", 0.0))
	return out


func path_stat_bias(path_id: String = "") -> Dictionary:
	var key := path_id if not path_id.is_empty() else cultivation_path_id
	if not PATH_STAT_BIAS.has(key):
		key = CultivationPathRegistry.DEFAULT_PATH_ID
	return (PATH_STAT_BIAS.get(key, {}) as Dictionary).duplicate()


func get_spell_cooldown_mult() -> float:
	var growth := realm_stat_growth()
	var bias := path_stat_bias()
	return float(growth.get("spell_cooldown", 1.0)) * float(bias.get("spell_cooldown", 1.0)) * get_dao_clarity_cooldown_mult()


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
	if amount <= 0.0 or dao_momentum_state == "clarity":
		return
	dao_momentum = clampf(dao_momentum + amount, 0.0, dao_momentum_max)
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
	if dao_momentum_state == "clarity":
		return
	dao_momentum = 0.0
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
	elif dao_momentum_state == "clarity":
		dao_momentum_state = "idle"
		dao_momentum_state_time = 0.0
		EventBus.dao_clarity_ended.emit()
		_emit_dao_momentum_changed()


func get_dao_clarity_attack_mult() -> float:
	return 1.35 if dao_momentum_state == "clarity" else 1.0


func get_dao_clarity_cooldown_mult() -> float:
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





func _ready() -> void:

	_bootstrap_rng.randomize()
