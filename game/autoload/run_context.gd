extends Node



const GameConstants = preload("res://core/constants/game_constants.gd")

const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")

const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")



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



const FNV_OFFSET := 2166136261

const FNV_PRIME := 16777619



var _bootstrap_rng := RandomNumberGenerator.new()





func derive_rng_seed(context: String) -> int:

	var h := FNV_OFFSET

	h = _fnv_mix_int(h, seed_value)

	for i in context.length():

		h = _fnv_mix_int(h, context.unicode_at(i))

	return h & 0x7FFFFFFF





func _fnv_mix_int(h: int, value: int) -> int:

	h = h ^ (value & 0xFFFFFFFF)

	return int((h * FNV_PRIME) & 0xFFFFFFFF)





func begin_run(heart: int, seed_override: int = -1, use_heart_demon_boost: bool = false, is_training: bool = false) -> void:

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

	KarmaTracker.reset()

	SpellProgress.reset()

	start_run(seed_override)

	if is_training:

		run_plan = []





func begin_training_run(seed_override: int = -1) -> void:

	begin_run(DaoHeartConfig.DaoHeart.ENLIGHTEN, seed_override, false, true)





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

	var StageGenerator = preload("res://systems/world/stage_generator.gd")

	if training_mode:

		run_plan = []

	else:

		run_plan = StageGenerator.generate(dao_heart, KarmaTracker.events_seen)

	SaveManager.set_last_run_seed(seed_value)

	EventBus.run_started.emit(seed_value)

	EventBus.realm_changed.emit(realm_level, affix_slot_max())

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
