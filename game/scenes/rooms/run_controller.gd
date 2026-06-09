extends Node2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")
const AffixOfferSelector = preload("res://systems/affix/affix_offer_selector.gd")
const TalentSelector = preload("res://systems/realm/talent_selector.gd")
const EventSelector = preload("res://systems/world/event_selector.gd")
const EventResolver = preload("res://systems/world/event_resolver.gd")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE = preload("res://scenes/enemies/training_dummy.tscn")
const HUD_SCENE = preload("res://scenes/ui/hud.tscn")
const PET_SCENE = preload("res://scenes/pet/pet.tscn")

enum RoomPhase { COMBAT, EVENT, BREAKTHROUGH, AFFIX, PATH, REST, TRANSITION }

@onready var spawn_points: Node2D = $SpawnPoints
@onready var dummy_spawns: Node2D = $SpawnPoints/DummySpawns

var _rng := RandomNumberGenerator.new()
var _waiting_for_affix := false
var _waiting_for_path := false
var _waiting_for_breakthrough := false
var _waiting_for_event := false
var _waiting_for_shop := false
var _event_after_affix := false
var _phase := RoomPhase.COMBAT
var _offer_context: Dictionary = {}
var _current_event: Dictionary = {}
var _player: CharacterBody2D
var _pet: Node2D
var _pet_bonded_this_clear := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	add_child(HUD_SCENE.instantiate())

	_player = PLAYER_SCENE.instantiate()
	_player.global_position = spawn_points.get_node("PlayerSpawn").global_position
	add_child(_player)

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
	_enter_current_room()
	queue_redraw()


func _apply_run_start_bonuses() -> void:
	var legacy_id := SaveManager.consume_legacy_affix()
	if not legacy_id.is_empty() and _player.has_node("AffixHolder"):
		var tag = ConfigRegistry.compile_affix(legacy_id, 1)
		if tag:
			_player.get_node("AffixHolder").add_affix(tag)
			EventBus.pet_coord_feedback.emit("前世遗泽：%s" % tag.name)

	if RunContext.heart_demon_boost and _player.has_node("AffixHolder"):
		var epics: Array = []
		for tag in ConfigRegistry.get_all_affixes():
			if int(tag.quality) >= 2:
				epics.append(tag)
		if not epics.is_empty():
			var pick = epics[_rng.randi_range(0, epics.size() - 1)]
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
	EventBus.room_entered.emit(room, stage)
	_phase = RoomPhase.COMBAT

	if str(room.get("type", "")) == "rest":
		_enter_rest_room()
		return
	if str(room.get("type", "")) == "event":
		_enter_event_room()
		return

	_spawn_room_enemies(room)


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
	if bool(result.get("offer_affix", false)):
		_event_after_affix = true
		_offer_affix()
	else:
		RunContext.ui_blocking = false
		get_tree().paused = false
		_offer_path_choice()


func _spawn_room_enemies(room: Dictionary) -> void:
	var is_boss := str(room.get("type", "")) == "boss"
	var count: int = int(room.get("enemy_count", 3)) + DaoHeartConfig.enemy_count_delta(RunContext.dao_heart)
	if not is_boss and str(room.get("type", "")) in ["combat", "combat_hard"]:
		var stage_idx := int(room.get("stage_index", RunContext.current_stage + 1))
		if stage_idx >= 2:
			count = maxi(count, 4)
	count = clampi(count, 1, 5)
	var hp_mult: float = float(room.get("hp_mult", 1.0))
	var heart_hp := RunContext.get_enemy_hp_mult(is_boss)
	for i in count:
		var dummy: CharacterBody2D = DUMMY_SCENE.instantiate()
		add_child(dummy)
		var spawn_pos: Vector2
		if is_boss:
			spawn_pos = GameConstants.ENEMY_BOSS_SPAWN
		else:
			spawn_pos = _spawn_pos_on_ring(i, count)
		dummy.global_position = spawn_pos
		var display_name := _resolve_enemy_display_name(i, count, room, is_boss)
		if dummy.has_method("configure_enemy"):
			dummy.configure_enemy(display_name, is_boss, str(room.get("type", "combat")))
		elif is_boss and dummy.has_method("configure_as_boss"):
			dummy.configure_as_boss()
		if dummy.has_method("init_combat_slot"):
			dummy.init_combat_slot(spawn_pos, _player.global_position, i, count, is_boss)
		if dummy.has_node("HealthComponent"):
			var health: Node = dummy.get_node("HealthComponent")
			if is_boss:
				health.max_hp = GameConstants.ENEMY_BOSS_HP * heart_hp
			else:
				health.max_hp = GameConstants.ENEMY_HP * hp_mult * heart_hp
			health.current_hp = health.max_hp
			health.changed.emit(health.current_hp, health.max_hp)
	EventBus.wave_changed.emit(RunContext.rooms_cleared + 1)


func _resolve_enemy_display_name(index: int, count: int, room: Dictionary, is_boss: bool) -> String:
	if is_boss:
		return str(room.get("boss_name", "关底守将"))
	if count >= 4:
		return _special_enemy_layout(index, count)
	if count >= 2 and index == count - 1:
		return "投弹木人"
	if count >= 3 and index == count - 2:
		return "弩手木人"
	if count >= 3 and index == 0:
		return "狂战木人"
	return "训练木人"


func _special_enemy_layout(index: int, count: int) -> String:
	var layout: PackedStringArray = ["狂战木人", "符师木人"]
	var filler_count := maxi(count - 4, 0)
	for _i in filler_count:
		layout.append("训练木人")
	layout.append("弩手木人")
	layout.append("投弹木人")
	if index >= 0 and index < layout.size():
		return layout[index]
	return "训练木人"


func _spawn_pos_on_ring(index: int, total: int) -> Vector2:
	var count := maxi(total, 1)
	var angle := TAU * float(index) / float(count) - PI * 0.5
	angle += _rng.randf_range(-0.06, 0.06)
	var ring := GameConstants.ENEMY_SPAWN_RING + float(index % 2) * 12.0
	var pos := GameConstants.ENEMY_SPAWN_CENTER + Vector2.from_angle(angle) * ring
	return pos + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))


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


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()


func _on_enemy_killed(_enemy: Node) -> void:
	if _waiting_for_affix or _waiting_for_path or _waiting_for_breakthrough or _waiting_for_event or _waiting_for_shop:
		return
	call_deferred("_check_wave_clear")


func _check_wave_clear() -> void:
	if _waiting_for_affix or _waiting_for_path or _waiting_for_breakthrough or _waiting_for_event or _waiting_for_shop:
		return
	if _count_living_enemies() <= 0:
		_on_room_cleared()


func _count_living_enemies() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_node("HealthComponent") and node.get_node("HealthComponent").is_alive():
			count += 1
	return count


func _on_room_cleared() -> void:
	var room: Dictionary = RunContext.get_current_room_def()
	var stage: Dictionary = RunContext.get_current_stage_def()
	var is_first_boss := str(room.get("type", "")) == "boss" and int(stage.get("stage_index", 0)) == 1
	_pet_bonded_this_clear = false
	if is_first_boss and not RunContext.pet_acquired:
		RunContext.acquire_pet("huo_ying")
		_pet_bonded_this_clear = true
		if _pet:
			_pet.bind_player(_player)
	if str(room.get("type", "")) == "boss" and RunContext.heart_demon_trial_active:
		RunContext.heart_demon_shards_earned += 1
		EventBus.pet_coord_feedback.emit(
			"心魔碎片 +1（本局 %d · 库存 %d）" % [
				RunContext.heart_demon_shards_earned,
				SaveManager.get_heart_demon_shards() + RunContext.heart_demon_shards_earned,
			]
		)
	if str(room.get("type", "")) == "boss":
		_offer_breakthrough()
	else:
		_offer_affix()


func _offer_breakthrough() -> void:
	_waiting_for_breakthrough = true
	_phase = RoomPhase.BREAKTHROUGH
	RunContext.ui_blocking = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	var offers := TalentSelector.roll_talents(RunContext.realm_level, 3, RunContext.realm_talents, _rng)
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
	if str(room.get("type", "")) == "boss" and not RunContext.breakthrough_done:
		RunContext.complete_breakthrough()
	_waiting_for_affix = true
	_phase = RoomPhase.AFFIX
	RunContext.ui_blocking = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_present_offers()
	if str(room.get("type", "")) != "event":
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
	var from_event := str(room.get("type", "")) == "event" or _event_after_affix
	_offer_context = {
		"elite": bool(room.get("is_boss", false)) or RunContext.current_stage >= 1 or RunContext.heart_demon_trial_active,
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
		_rng,
		_offer_context
	)
	if RunContext.heart_demon_trial_active:
		for i in offers.size():
			var better = ConfigRegistry.compile_affix(offers[i].id, 1)
			if better:
				offers[i] = better
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
	var branches := [
		{"id": "continue", "label": "继续深入", "desc": "进入下一房间"},
		{"id": "rest", "label": "调息片刻", "desc": "恢复 20% 真元"},
	]
	var room_type := str(room.get("type", ""))
	if room_type in ["combat", "combat_hard"] and RunContext.gold >= GameConstants.SHOP_HEAL_COST:
		branches.append({
			"id": "shop",
			"label": "踏入坊市",
			"desc": "消耗灵石购入机缘",
		})
	if room_type == "boss":
		branches = [{"id": "continue", "label": "踏入下一重天", "desc": "进入下一关"}]
	elif str(room.get("type", "")) == "event":
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
		ConfigRegistry.get_all_affixes(), 1, owned, _rng, base_ctx
	)
	var rare_ctx := base_ctx.duplicate()
	rare_ctx["elite"] = true
	var rare_offers := AffixOfferSelector.roll_offers(
		ConfigRegistry.get_all_affixes(), 1, owned, _rng, rare_ctx
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


func _draw() -> void:
	draw_rect(Rect2(-600, -400, 1200, 800), GameConstants.COLOR_ARENA)
	draw_rect(Rect2(-600, -400, 1200, 800), Color(0.176, 0.176, 0.267, 0.35), false, 2.0)
