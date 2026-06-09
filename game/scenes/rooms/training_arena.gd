extends Node2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const AffixOfferSelector = preload("res://systems/affix/affix_offer_selector.gd")
const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const DUMMY_SCENE = preload("res://scenes/enemies/training_dummy.tscn")
const HUD_SCENE = preload("res://scenes/ui/hud.tscn")

@onready var spawn_points: Node2D = $SpawnPoints
@onready var dummy_spawns: Node2D = $SpawnPoints/DummySpawns

var wave := 0
var gold := GameConstants.STARTING_GOLD
var _rng := RandomNumberGenerator.new()
var _waiting_for_affix := false
var _offer_context: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	add_child(HUD_SCENE.instantiate())

	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.global_position = spawn_points.get_node("PlayerSpawn").global_position
	add_child(player)

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.affix_choice_closed.connect(_on_affix_choice_closed)
	EventBus.affix_reroll_requested.connect(_on_affix_reroll)
	EventBus.affix_skip_requested.connect(_on_affix_skip)
	EventBus.run_started.emit(_rng.seed)
	EventBus.gold_changed.emit(gold)

	_spawn_wave(1)
	queue_redraw()


func _spawn_wave(next_wave: int) -> void:
	wave = next_wave
	var count := mini(2 + wave, 5)
	for i in count:
		var dummy: CharacterBody2D = DUMMY_SCENE.instantiate()
		add_child(dummy)
		var spawn_pos := _spawn_pos_on_ring(i, count)
		dummy.global_position = spawn_pos
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var player_pos := player.global_position if player else Vector2(0, 120)
		if dummy.has_method("init_combat_slot"):
			dummy.init_combat_slot(spawn_pos, player_pos, i, count, false)
	EventBus.wave_changed.emit(wave)


func _spawn_pos_on_ring(index: int, total: int) -> Vector2:
	var count := maxi(total, 1)
	var angle := TAU * float(index) / float(count) - PI * 0.5
	angle += _rng.randf_range(-0.06, 0.06)
	var ring := GameConstants.ENEMY_SPAWN_RING + float(index % 2) * 12.0
	var pos := GameConstants.ENEMY_SPAWN_CENTER + Vector2.from_angle(angle) * ring
	return pos + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))


func _on_enemy_killed(_enemy: Node) -> void:
	if _waiting_for_affix:
		return
	call_deferred("_check_wave_clear")


func _check_wave_clear() -> void:
	if _waiting_for_affix:
		return
	if _count_living_enemies() <= 0:
		_offer_affix()


func _count_living_enemies() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_node("HealthComponent") and node.get_node("HealthComponent").is_alive():
			count += 1
	return count


func _offer_affix() -> void:
	_waiting_for_affix = true
	Engine.time_scale = 1.0
	get_tree().paused = true
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
		_rng,
		_offer_context
	)
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
	_spawn_wave(wave + 1)


func _draw() -> void:
	draw_rect(Rect2(-600, -400, 1200, 800), GameConstants.COLOR_ARENA)
	draw_rect(Rect2(-600, -400, 1200, 800), Color(0.176, 0.176, 0.267, 0.35), false, 2.0)
