extends Node

const MUTATION_DELAY := 3.0
const MUTATION_LIMIT := 2
const GUARDIAN_INVULN := 1.5

var _dao_heart_stir_used := false
var _mutations_this_run := 0
var _elite_kill_seen_this_room := false
var _guardian_used_this_room := false
var _current_room_is_elite := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.run_started.connect(_on_run_started)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.pet_coord_hit.connect(_on_pet_coord_hit)


func _on_run_started(_seed: int) -> void:
	_dao_heart_stir_used = false
	_mutations_this_run = 0
	_elite_kill_seen_this_room = false
	_guardian_used_this_room = false
	_current_room_is_elite = false


func _on_room_entered(room: Dictionary, _stage: Dictionary) -> void:
	_elite_kill_seen_this_room = false
	_guardian_used_this_room = false
	var room_type := GameEnums.parse_room_type(str(room.get("type", "")))
	_current_room_is_elite = room_type in [GameEnums.RoomType.ELITE, GameEnums.RoomType.COMBAT_HARD]
	if _dao_heart_stir_used or RunContext.rooms_without_weather_kill < 2:
		return
	_dao_heart_stir_used = true
	_strengthen_weather_opportunity(room)


func _on_enemy_killed(enemy: Node) -> void:
	if not _current_room_is_elite or _elite_kill_seen_this_room or _mutations_this_run >= MUTATION_LIMIT:
		return
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("is_elite_unit"):
		return
	if not bool(enemy.call("is_elite_unit")):
		return
	_elite_kill_seen_this_room = true
	_mutations_this_run += 1
	get_tree().create_timer(MUTATION_DELAY, false).timeout.connect(_trigger_enemy_mutation, CONNECT_ONE_SHOT)


func _on_pet_coord_hit(enemy: Node) -> void:
	if _guardian_used_this_room or not RunContext.pet_acquired:
		return
	var player := EntityCache.get_player()
	if player == null or not is_instance_valid(player) or not player.has_node("HealthComponent"):
		return
	var health: Node = player.get_node("HealthComponent")
	if float(health.max_hp) <= 0.0 or float(health.current_hp) / float(health.max_hp) > 0.15:
		return
	_guardian_used_this_room = true
	if player.has_method("grant_guardian_invuln"):
		player.grant_guardian_invuln(GUARDIAN_INVULN)
	EventBus.pet_guardian_triggered.emit(enemy, player)
	EventBus.crit_moment_requested.emit("灵兽护主", 0.2)
	EventBus.pet_coord_feedback.emit("灵兽护主 · 1.5秒无敌")
	if player is Node2D:
		VfxManager.spawn_world((player as Node2D).global_position, "gold", Color(1.0, 0.88, 0.32))
	if enemy is Node2D:
		VfxManager.spawn_world((enemy as Node2D).global_position, "cast", Color(1.0, 0.6, 0.22))


func _strengthen_weather_opportunity(room: Dictionary) -> void:
	var weather_id := WeatherSystem.current_weather_id
	if weather_id == "clear":
		weather_id = _weather_for_path()
		WeatherSystem.set_weather(weather_id)
	room["weather_opportunity_boost"] = true
	room["layout_id"] = _layout_for_weather(weather_id)
	EventBus.pet_coord_feedback.emit("道心微动：下一房天象与地脉更易借力")
	RunContext.record_run_highlight("dao_heart_stir_%d" % RunContext.rooms_cleared, "道心微动", "连续未借天象破敌后，天地给出了一次更明显的机会。", 45)


func _trigger_enemy_mutation() -> void:
	if not RunContext.run_active:
		return
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("is_elite_unit") and bool(enemy.call("is_elite_unit")):
			continue
		if enemy.has_method("trigger_spirit_mutation"):
			candidates.append(enemy)
	if candidates.is_empty():
		return
	var rng := RunRng.run_controller("enemy_mutation_%d_%d" % [RunContext.current_stage, RunContext.current_room])
	var target: Node = candidates[rng.randi_range(0, candidates.size() - 1)]
	target.call("trigger_spirit_mutation", 5.0, _element_for_weather(WeatherSystem.current_weather_id))


func _weather_for_path() -> String:
	match RunContext.cultivation_path_id:
		"sword", "talisman":
			return "thunder"
		"alchemy":
			return "rain"
		"soul":
			return "wind"
		"body":
			return "snow"
	return "fire"


func _layout_for_weather(weather_id: String) -> String:
	match weather_id:
		"thunder", "rain":
			return "edge_pockets"
		"fire", "wind", "sand":
			return "lane_gates"
		"snow":
			return "broken_columns"
	return "open_scatter"


func _element_for_weather(weather_id: String) -> String:
	match weather_id:
		"thunder":
			return "thunder"
		"rain", "snow":
			return "water"
		"wind":
			return "wood"
		"sand":
			return "earth"
	return "fire"
