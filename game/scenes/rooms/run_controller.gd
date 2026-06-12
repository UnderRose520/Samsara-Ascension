extends ArenaBase

const VariantUtils = preload("res://core/utils/variant_utils.gd")
const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")
const AffixOfferSelector = preload("res://systems/affix/affix_offer_selector.gd")
const TalentSelector = preload("res://systems/realm/talent_selector.gd")
const EventSelector = preload("res://systems/world/event_selector.gd")
const EventResolver = preload("res://systems/world/event_resolver.gd")
const RoomLayoutGenerator = preload("res://systems/world/room_layout_generator.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const HUD_SCENE = preload("res://scenes/ui/hud.tscn")
const PET_SCENE = preload("res://scenes/pet/pet.tscn")

enum RoomPhase { COMBAT, EVENT, BREAKTHROUGH, AFFIX, PATH, REST, TRANSITION }

@onready var spawn_points: Node2D = $SpawnPoints
@onready var dummy_spawns: Node2D = $SpawnPoints/DummySpawns

var _waiting_for_affix := false
var _room_waves: Array = []
var _current_wave_index := -1
var _waiting_for_wave := false
var _affix_roll_seq := 0
var _shop_roll_seq := 0
var _waiting_for_path := false
var _waiting_for_breakthrough := false
var _waiting_for_event := false
var _waiting_for_shop := false
var _event_after_affix := false
var _phase := RoomPhase.COMBAT
var _offer_context: Dictionary = {}
var _current_event: Dictionary = {}
var _pet: Node2D
var _pet_bonded_this_clear := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("world_vfx")
	var floor := setup_combat_floor()
	setup_horde_controller()
	add_child(HUD_SCENE.instantiate())

	_player = PLAYER_SCENE.instantiate()
	_player.global_position = spawn_points.get_node("PlayerSpawn").global_position
	add_child(_player)
	bind_arena_player(_player)

	_pet = PET_SCENE.instantiate()
	add_child(_pet)
	_pet.bind_player(_player)

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.affix_choice_closed.connect(_on_affix_choice_closed)
	EventBus.affix_reroll_requested.connect(_on_affix_reroll)
	EventBus.affix_skip_requested.connect(_on_affix_skip)
	EventBus.path_choice_closed.connect(_on_path_choice_closed)
	EventBus.breakthrough_closed.connect(_on_breakthrough_closed)
	EventBus.event_closed.connect(_on_event_closed)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.player_died.connect(_on_player_died)

	EventBus.gold_changed.emit(RunContext.gold)
	call_deferred("_apply_run_start_bonuses")
	if floor and floor.has_method("apply_theme"):
		floor.apply_theme(1)
	_enter_current_room()
	queue_redraw()


func _apply_run_start_bonuses() -> void:
	var legacy_id := SaveManager.consume_legacy_affix()
	if not legacy_id.is_empty() and _player.has_node("AffixHolder"):
		var tag = ConfigRegistry.compile_affix(legacy_id, -1)
		if tag:
			_player.get_node("AffixHolder").add_affix(tag)
			EventBus.pet_coord_feedback.emit("前世遗泽：%s" % tag.name)

	if RunContext.heart_demon_boost and _player.has_node("AffixHolder"):
		var epics: Array = []
		for tag in ConfigRegistry.get_all_affixes():
			if int(tag.quality) >= 2:
				epics.append(tag)
		if not epics.is_empty():
			var pick = epics[_flow_rng("heart_boost").randi_range(0, epics.size() - 1)]
			var boosted = ConfigRegistry.compile_affix(pick.id, 0)
			if boosted:
				_player.get_node("AffixHolder").add_affix(boosted)
				EventBus.pet_coord_feedback.emit("心魔强化：%s · 敌人+10%%" % boosted.name)

	var hp_bonus := RunContext.get_meta_hp_bonus()
	if hp_bonus > 0.0 and _player.has_node("HealthComponent"):
		var health: Node = _player.get_node("HealthComponent")
		health.max_hp += hp_bonus
		health.current_hp = health.max_hp
		health.changed.emit(health.current_hp, health.max_hp)


func _enter_current_room() -> void:
	CombatRngService.reset()
	_clear_enemies()
	if RunContext.is_run_finished():
		EventBus.run_completed.emit(true)
		return

	var room: Dictionary = RunContext.get_current_room_def()
	var stage: Dictionary = RunContext.get_current_stage_def()
	if room.is_empty():
		EventBus.run_completed.emit(true)
		return

	WeatherSystem.set_weather(str(stage.get("weather_id", "clear")))
	var stage_idx := int(stage.get("stage_index", RunContext.current_stage + 1))
	if get_combat_floor() and get_combat_floor().has_method("apply_theme"):
		get_combat_floor().apply_theme(stage_idx)
	_room_waves = []
	_current_wave_index = -1
	_waiting_for_wave = false
	get_horde().reset()
	_phase = RoomPhase.COMBAT
	var room_type := _room_type(room)
	var is_combat_room := GameEnums.is_combat_room_type(room_type) or GameEnums.is_boss_room_type(room_type)
	if is_combat_room:
		_apply_room_layout(room, stage_idx, str(stage.get("weather_id", "clear")))
	elif get_combat_floor() and get_combat_floor().has_method("clear_layout"):
		get_combat_floor().clear_layout()
	EventBus.room_entered.emit(room, stage)

	if room_type == GameEnums.RoomType.REST:
		_enter_rest_room()
		return
	if room_type == GameEnums.RoomType.EVENT:
		_enter_event_room()
		return

	_spawn_room_enemies(room)


func _apply_room_layout(room: Dictionary, stage_idx: int, weather_id: String) -> void:
	var floor := get_combat_floor()
	if floor == null or not floor.has_method("apply_layout"):
		return
	var room_type := str(room.get("type", "combat"))
	var room_idx := int(room.get("room_index", RunContext.current_room))
	var rng := RunRng.stage_room(stage_idx, room_idx, room_type)
	if str(room.get("layout_id", "")).is_empty():
		room["layout_id"] = RoomLayoutGenerator.pick_layout_id(room_type, stage_idx, rng)
	floor.apply_layout(room, rng, weather_id)


func _room_type(room: Dictionary) -> GameEnums.RoomType:
	return GameEnums.parse_room_type(str(room.get("type", "")))


func _enter_event_room() -> void:
	_phase = RoomPhase.EVENT
	_waiting_for_event = true
	RunContext.ui_blocking = true
	get_tree().paused = true
	var room: Dictionary = RunContext.get_current_room_def()
	_current_event = EventSelector.get_event(str(room.get("event_id", "E01")))
	var choices := EventSelector.build_choices(_current_event)
	EventBus.event_requested.emit(_current_event, choices)


func _on_event_closed(choice_index: int) -> void:
	if not _waiting_for_event:
		return
	_waiting_for_event = false
	var result: Dictionary = EventResolver.apply(_current_event, choice_index, _player)
	_current_event.clear()
	EventBus.pet_coord_feedback.emit(str(result.get("message", "机缘已了")))
	if VariantUtils.as_bool(result.get("offer_affix", false)):
		_event_after_affix = true
		_offer_affix()
	else:
		RunContext.ui_blocking = false
		get_tree().paused = false
		_offer_path_choice()


func _spawn_room_enemies(room: Dictionary) -> void:
	var room_type := _room_type(room)
	if GameEnums.is_boss_room_type(room_type):
		_room_waves = [{"delay_after": 0.0, "spawns": [{"enemy_id": "boss", "count": 1}]}]
		_spawn_wave(0)
		return
	_start_combat_horde(room)


func _start_combat_horde(room: Dictionary) -> void:
	get_horde().start(room)


func _horde_tick_paused() -> bool:
	return get_tree().paused or RunContext.ui_blocking


func _process(delta: float) -> void:
	_tick_horde(delta, _phase != RoomPhase.COMBAT)


func _on_horde_cleared() -> void:
	_on_room_cleared()


func _enemy_kill_blocked() -> bool:
	return (
		_waiting_for_affix
		or _waiting_for_path
		or _waiting_for_breakthrough
		or _waiting_for_event
		or _waiting_for_shop
		or _waiting_for_wave
		or get_horde().finishing
	)


func _on_enemy_killed_after_horde() -> void:
	call_deferred("_check_wave_clear")


func _spawn_wave(wave_index: int) -> void:
	if wave_index < 0 or wave_index >= _room_waves.size():
		return
	_current_wave_index = wave_index
	_waiting_for_wave = false
	var room: Dictionary = RunContext.get_current_room_def()
	var room_type := _room_type(room)
	var is_boss := GameEnums.is_boss_room_type(room_type)
	var wave_def: Dictionary = _room_waves[wave_index]
	var hp_mult: float = float(room.get("hp_mult", 1.0))
	var heart_hp := RunContext.get_enemy_hp_mult(is_boss)
	var total_in_wave := _count_wave_enemies(wave_def)
	var spawn_index := 0
	var announced_affix := false
	for spawn in wave_def.get("spawns", []):
		var enemy_id := str(spawn.get("enemy_id", "normal"))
		var count := int(spawn.get("count", 1))
		var affixes: Array = spawn.get("affixes", [])
		if not announced_affix and affixes.size() > 0:
			EventBus.pet_coord_feedback.emit("精英词缀 · %s" % EliteAffixRegistry.format_labels(affixes))
			announced_affix = true
		for _i in count:
			_spawn_single_enemy({
				"enemy_id": enemy_id,
				"index": spawn_index,
				"total": total_in_wave,
				"is_boss": is_boss,
				"hp_mult": hp_mult,
				"heart_hp": heart_hp,
				"affixes": affixes,
			}, room, room_type)
			spawn_index += 1
	EventBus.wave_changed.emit.call_deferred(wave_index + 1)


func _count_wave_enemies(wave_def: Dictionary) -> int:
	var total := 0
	for spawn in wave_def.get("spawns", []):
		total += int(spawn.get("count", 1))
	return maxi(total, 1)


func _spawn_single_enemy(spawn_def: Dictionary, room: Dictionary, room_type: GameEnums.RoomType) -> void:
	spawn_def["room_type_id"] = GameEnums.room_type_id(room_type)
	_spawn_enemy_dummy(spawn_def, room)


func _enter_rest_room() -> void:
	_phase = RoomPhase.REST
	if _player.has_node("HealthComponent"):
		var health: Node = _player.get_node("HealthComponent")
		health.current_hp = minf(health.max_hp, health.current_hp + health.max_hp * 0.3)
		health.changed.emit(health.current_hp, health.max_hp)
	call_deferred("_after_rest")


func _after_rest() -> void:
	RunContext.advance_room()
	_enter_current_room()


func _check_wave_clear() -> void:
	if _waiting_for_affix or _waiting_for_path or _waiting_for_breakthrough or _waiting_for_event or _waiting_for_shop or _waiting_for_wave:
		return
	if _count_living_enemies() <= 0:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	if _has_more_waves():
		_schedule_next_wave()
		return
	_on_room_cleared()


func _has_more_waves() -> bool:
	return _current_wave_index + 1 < _room_waves.size()


func _schedule_next_wave() -> void:
	_waiting_for_wave = true
	var next_wave: Dictionary = _room_waves[_current_wave_index + 1]
	var delay := float(next_wave.get("delay_after", 2.5))
	EventBus.pet_coord_feedback.emit("下一波 %.0f 秒后到来" % delay)
	if delay <= 0.05:
		call_deferred("_advance_wave")
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(_advance_wave, CONNECT_ONE_SHOT)


func _advance_wave() -> void:
	if not _waiting_for_wave:
		return
	_waiting_for_wave = false
	_spawn_wave(_current_wave_index + 1)


func _on_room_cleared() -> void:
	var room: Dictionary = RunContext.get_current_room_def()
	var stage: Dictionary = RunContext.get_current_stage_def()
	var room_type := _room_type(room)
	var is_first_boss := room_type == GameEnums.RoomType.BOSS and int(stage.get("stage_index", 0)) == 1
	_pet_bonded_this_clear = false
	if is_first_boss and not RunContext.pet_acquired:
		RunContext.acquire_pet("huo_ying")
		_pet_bonded_this_clear = true
		if _pet:
			_pet.bind_player(_player)
	if room_type == GameEnums.RoomType.BOSS and RunContext.heart_demon_trial_active:
		RunContext.heart_demon_shards_earned += 1
		EventBus.pet_coord_feedback.emit(
			"心魔碎片 +1（本局 %d · 库存 %d）" % [
				RunContext.heart_demon_shards_earned,
				SaveManager.get_heart_demon_shards() + RunContext.heart_demon_shards_earned,
			]
		)
	if room_type == GameEnums.RoomType.BOSS:
		_offer_breakthrough()
	else:
		_offer_affix()


func _offer_breakthrough() -> void:
	_waiting_for_breakthrough = true
	_phase = RoomPhase.BREAKTHROUGH
	RunContext.ui_blocking = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	var offers := TalentSelector.roll_talents(
		RunContext.realm_level,
		3,
		RunContext.realm_talents,
		_flow_rng("talent_%d" % RunContext.realm_level)
	)
	if offers.is_empty():
		RunContext.complete_breakthrough()
		_waiting_for_breakthrough = false
		RunContext.ui_blocking = false
		EventBus.pet_coord_feedback.emit("突破成功 · 词条槽 %d" % RunContext.affix_slot_max())
		_offer_affix()
		return
	EventBus.breakthrough_requested.emit(offers, {
		"realm": RunContext.realm_name(),
		"slots_before": RunContext.affix_slot_max(),
		"slots_after": RunContext.preview_slots_after_breakthrough(),
	})


func _on_breakthrough_closed(talent_id: String) -> void:
	_waiting_for_breakthrough = false
	RunContext.ui_blocking = false
	if not RunContext.breakthrough_done:
		RunContext.complete_breakthrough()
	var talent = TalentSelector.get_talent(talent_id)
	if talent and _player.has_node("AffixHolder"):
		_player.get_node("AffixHolder").apply_talent(talent)
		RunContext.add_realm_talent(talent_id)
	if RunContext.realm_level >= 3:
		EventBus.pet_coord_feedback.emit("突破成功 · 词条槽 %d" % RunContext.affix_slot_max())
	_offer_affix()


func _offer_affix() -> void:
	var room: Dictionary = RunContext.get_current_room_def()
	var room_type := _room_type(room)
	if room_type == GameEnums.RoomType.BOSS and not RunContext.breakthrough_done:
		RunContext.complete_breakthrough()
	_waiting_for_affix = true
	_phase = RoomPhase.AFFIX
	RunContext.ui_blocking = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_affix_roll_seq = 0
	_present_offers()
	if room_type != GameEnums.RoomType.EVENT:
		EventBus.all_enemies_cleared.emit(RunContext.rooms_cleared + 1)


func _present_offers() -> void:
	var owned: Array = []
	var element_bias := ""
	if _player.has_node("AffixHolder"):
		var holder: Node = _player.get_node("AffixHolder")
		owned = holder.get_owned_ids()
		element_bias = holder.get_element_bias()
	if not RunContext.next_affix_bias.is_empty():
		element_bias = RunContext.next_affix_bias
		RunContext.next_affix_bias = ""
	var room: Dictionary = RunContext.get_current_room_def()
	var room_type := _room_type(room)
	var from_event := room_type == GameEnums.RoomType.EVENT or _event_after_affix
	_offer_context = {
		"elite": VariantUtils.as_bool(room.get("is_boss", false)) or RunContext.current_stage >= 1 or RunContext.heart_demon_trial_active,
		"element_bias": element_bias,
		"gold": RunContext.gold,
		"pet_bonded": _pet_bonded_this_clear,
		"pet_name": RunContext.pet_display_name,
		"affix_slots": RunContext.affix_slot_max(),
		"from_event": from_event,
	}
	var offers := AffixOfferSelector.roll_offers(
		ConfigRegistry.get_all_affixes(),
		3,
		owned,
		_flow_rng("affix_%d_%d" % [RunContext.rooms_cleared, _affix_roll_seq]),
		_offer_context
	)
	_affix_roll_seq += 1
	var quality_shift := 0
	if RunContext.heart_demon_trial_active:
		quality_shift += 1
	if RunContext.dao_heart == DaoHeartConfig.DaoHeart.PROVE_DAO:
		quality_shift += 1
	if quality_shift > 0:
		for i in offers.size():
			var shifted = ConfigRegistry.compile_affix(offers[i].id, quality_shift)
			if shifted:
				offers[i] = shifted
	EventBus.affix_choice_requested.emit(offers, _offer_context)


func _on_affix_reroll() -> void:
	if not _waiting_for_affix:
		return
	if RunContext.gold < RunContext.get_reroll_cost():
		return
	RunContext.gold -= RunContext.get_reroll_cost()
	EventBus.gold_changed.emit(RunContext.gold)
	_offer_context["gold"] = RunContext.gold
	_present_offers()


func _on_affix_skip() -> void:
	if not _waiting_for_affix:
		return
	RunContext.gold += GameConstants.AFFIX_SKIP_REWARD
	EventBus.gold_changed.emit(RunContext.gold)


func _on_affix_choice_closed() -> void:
	_waiting_for_affix = false
	RunContext.ui_blocking = false
	_pet_bonded_this_clear = false
	get_tree().paused = false
	if _event_after_affix:
		_event_after_affix = false
		_offer_path_choice()
		return
	_offer_path_choice()


func _offer_path_choice() -> void:
	_waiting_for_path = true
	_phase = RoomPhase.PATH
	RunContext.ui_blocking = true
	get_tree().paused = true
	var room: Dictionary = RunContext.get_current_room_def()
	var room_type := _room_type(room)
	var branches := [
		{"id": "continue", "label": "继续深入", "desc": "进入下一房间"},
		{"id": "rest", "label": "调息片刻", "desc": "恢复 20% 真元"},
	]
	if GameEnums.is_combat_room_type(room_type) and RunContext.gold >= GameConstants.SHOP_HEAL_COST:
		branches.append({
			"id": "shop",
			"label": "踏入坊市",
			"desc": "消耗灵石购入机缘",
		})
	if room_type == GameEnums.RoomType.BOSS:
		branches = [{"id": "continue", "label": "踏入下一重天", "desc": "进入下一关"}]
	elif room_type == GameEnums.RoomType.EVENT:
		branches = [{"id": "continue", "label": "继续前行", "desc": "离开机缘房"}]
	EventBus.path_choice_requested.emit(branches)


func _on_path_choice_closed(choice_id: String) -> void:
	_waiting_for_path = false
	RunContext.ui_blocking = false
	if choice_id == "shop":
		_open_shop()
		return
	get_tree().paused = false
	if choice_id == "rest" and _player.has_node("HealthComponent"):
		var health: Node = _player.get_node("HealthComponent")
		health.current_hp = minf(health.max_hp, health.current_hp + health.max_hp * 0.2)
		health.changed.emit(health.current_hp, health.max_hp)
	RunContext.advance_room()
	_enter_current_room()


func _open_shop() -> void:
	_waiting_for_shop = true
	_shop_roll_seq = 0
	RunContext.ui_blocking = true
	get_tree().paused = true
	EventBus.shop_requested.emit(_build_shop_offers(), {"gold": RunContext.gold})


func _build_shop_offers() -> Array:
	var owned: Array = []
	var element_bias := ""
	if _player.has_node("AffixHolder"):
		var holder: Node = _player.get_node("AffixHolder")
		owned = holder.get_owned_ids()
		element_bias = holder.get_element_bias()
	var base_ctx := {
		"elite": false,
		"element_bias": element_bias,
		"gold": RunContext.gold,
		"affix_slots": RunContext.affix_slot_max(),
	}
	var normal_offers := AffixOfferSelector.roll_offers(
		ConfigRegistry.get_all_affixes(),
		1,
		owned,
		_flow_rng("shop_normal_%d" % _shop_roll_seq),
		base_ctx
	)
	_shop_roll_seq += 1
	var rare_ctx := base_ctx.duplicate()
	rare_ctx["elite"] = true
	var rare_offers := AffixOfferSelector.roll_offers(
		ConfigRegistry.get_all_affixes(),
		1,
		owned,
		_flow_rng("shop_rare_%d" % _shop_roll_seq),
		rare_ctx
	)
	var offers: Array = [
		{
			"kind": "heal",
			"cost": GameConstants.SHOP_HEAL_COST,
			"label": "调息丹 · %d 灵石" % GameConstants.SHOP_HEAL_COST,
			"desc": "恢复 35% 真元",
		},
	]
	if not normal_offers.is_empty():
		var tag = normal_offers[0]
		offers.append({
			"kind": "affix",
			"cost": GameConstants.SHOP_AFFIX_COST,
			"label": "机缘词条 · %d 灵石" % GameConstants.SHOP_AFFIX_COST,
			"desc": "%s [%s]" % [tag.name, tag.description],
			"tag": tag,
		})
	if not rare_offers.is_empty():
		var rare = rare_offers[0]
		offers.append({
			"kind": "rare_affix",
			"cost": GameConstants.SHOP_RARE_COST,
			"label": "仙品机缘 · %d 灵石" % GameConstants.SHOP_RARE_COST,
			"desc": "%s [%s]" % [rare.name, rare.description],
			"tag": rare,
		})
	return offers


func _on_shop_closed(_purchased: bool) -> void:
	if not _waiting_for_shop:
		return
	_waiting_for_shop = false
	RunContext.ui_blocking = false
	get_tree().paused = false
	RunContext.advance_room()
	_enter_current_room()


func _on_player_died() -> void:
	get_horde().reset()
	EntityCache.invalidate_player()
	RunContext.run_active = false
	Engine.time_scale = 1.0
	get_tree().paused = true
	var legacy_affixes: Array = []
	if _player.has_node("AffixHolder"):
		for tag in _player.get_node("AffixHolder").equipped:
			legacy_affixes.append(tag)
	if not legacy_affixes.is_empty():
		EventBus.legacy_choice_requested.emit(legacy_affixes)
	else:
		EventBus.run_completed.emit(false)


func _flow_rng(context: String) -> RandomNumberGenerator:
	return RunRng.run_controller(context)


func _arena_flow_rng(context: String) -> RandomNumberGenerator:
	return _flow_rng(context)


func _draw() -> void:
	if get_combat_floor() != null:
		return
	draw_rect(Rect2(-640, -360, 1280, 720), GameConstants.COLOR_ARENA)
	draw_rect(Rect2(-640, -360, 1280, 720), Color(0.176, 0.176, 0.267, 0.35), false, 2.0)
