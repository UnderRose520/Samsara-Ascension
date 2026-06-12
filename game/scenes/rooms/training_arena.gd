extends ArenaBase

const AffixOfferSelector = preload("res://systems/affix/affix_offer_selector.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const RoomLayoutGenerator = preload("res://systems/world/room_layout_generator.gd")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const HUD_SCENE = preload("res://scenes/ui/hud.tscn")

@onready var spawn_points: Node2D = $SpawnPoints

var wave := 0
var gold := GameConstants.STARTING_GOLD
var _waiting_for_affix := false
var _offer_context: Dictionary = {}
var _affix_roll_seq := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("world_vfx")
	RunContext.begin_training_run(4242)
	gold = RunContext.gold

	var floor := setup_combat_floor()
	setup_horde_controller()
	get_horde().set_dao_heart_override(RunContext.dao_heart)

	add_child(HUD_SCENE.instantiate())

	_player = PLAYER_SCENE.instantiate()
	_player.global_position = spawn_points.get_node("PlayerSpawn").global_position
	add_child(_player)
	bind_arena_player(_player)

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.affix_choice_closed.connect(_on_affix_choice_closed)
	EventBus.affix_reroll_requested.connect(_on_affix_reroll)
	EventBus.affix_skip_requested.connect(_on_affix_skip)
	EventBus.gold_changed.emit(gold)

	if floor and floor.has_method("apply_theme"):
		floor.apply_theme(1)
	_start_training_wave(1)


func _start_training_wave(next_wave: int) -> void:
	wave = next_wave
	RunContext.training_wave = wave
	CombatRngService.reset()
	_clear_enemies()
	_apply_training_layout()
	get_horde().set_dao_heart_override(RunContext.dao_heart)
	get_horde().start(_training_room_def())


func _training_room_def() -> Dictionary:
	return {
		"type": "combat",
		"stage_index": mini(wave, 5),
		"room_index": wave,
		"hp_mult": 1.0 + float(wave - 1) * 0.08,
		"layout_id": "open_scatter",
	}


func _get_horde_room_def() -> Dictionary:
	return _training_room_def()


func _apply_training_layout() -> void:
	var floor := get_combat_floor()
	if floor == null or not floor.has_method("apply_layout"):
		return
	var room := _training_room_def()
	var rng := RunRng.training("layout_%d" % wave)
	room["layout_id"] = RoomLayoutGenerator.pick_layout_id("combat", int(room["stage_index"]), rng)
	var weather_id := "rain" if wave % 2 == 0 else "clear"
	floor.apply_layout(room, rng, weather_id)


func _arena_flow_rng(context: String) -> RandomNumberGenerator:
	return RunRng.training(context)


func _arena_ring_layer(index: int) -> int:
	return index % 7


func _spawn_rng_context(index: int) -> String:
	return "spawn_%d_%d" % [wave, index]


func _horde_tick_paused() -> bool:
	return get_tree().paused


func _process(delta: float) -> void:
	_tick_horde(delta, _waiting_for_affix)


func _enemy_kill_blocked() -> bool:
	return _waiting_for_affix


func _on_horde_cleared() -> void:
	_offer_affix()


func _offer_affix() -> void:
	_waiting_for_affix = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_affix_roll_seq = 0
	_present_offers()
	EventBus.all_enemies_cleared.emit(wave)


func _present_offers() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var owned: Array = []
	var element_bias := ""
	if player and player.has_node("AffixHolder"):
		var holder: Node = player.get_node("AffixHolder")
		owned = holder.get_owned_ids()
		element_bias = holder.get_element_bias()
	_offer_context = {
		"elite": wave >= 3,
		"element_bias": element_bias,
		"gold": gold,
	}
	var offers := AffixOfferSelector.roll_offers(
		ConfigRegistry.get_all_affixes(),
		3,
		owned,
		RunRng.training("affix_%d_%d" % [wave, _affix_roll_seq]),
		_offer_context,
	)
	_affix_roll_seq += 1
	EventBus.affix_choice_requested.emit(offers, _offer_context)


func _on_affix_reroll() -> void:
	if not _waiting_for_affix:
		return
	if gold < GameConstants.AFFIX_REROLL_COST:
		return
	gold -= GameConstants.AFFIX_REROLL_COST
	EventBus.gold_changed.emit(gold)
	_offer_context["gold"] = gold
	_present_offers()


func _on_affix_skip() -> void:
	if not _waiting_for_affix:
		return
	gold += GameConstants.AFFIX_SKIP_REWARD
	EventBus.gold_changed.emit(gold)


func _on_affix_choice_closed() -> void:
	_waiting_for_affix = false
	get_tree().paused = false
	_start_training_wave(wave + 1)
