extends Node

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")
const CultivationPathRegistry = preload("res://systems/realm/cultivation_path_registry.gd")

const REPORT_PATH := "res://tools/run_flow_contract_qa_report.txt"
const FIXED_SEED := 24681357

var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _profile_snapshot: Dictionary = {}
var _main: Node
var _affix_requests: Array[Dictionary] = []
var _path_requests: Array[Array] = []
var _event_requests: Array[Dictionary] = []
var _weapon_mod_requests: Array[Dictionary] = []
var _room_entries: Array[Dictionary] = []
var _run_started_seeds: Array[int] = []
var _run_completed: Array[bool] = []


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := await _run()
	_restore_profile()
	_write_report(code)
	get_tree().quit(code)


func _run() -> int:
	_report("Run flow contract QA")
	_report("====================")
	_profile_snapshot = SaveManager.profile.duplicate(true)
	_require(SaveManager.is_using_profile_path_override(), "Run flow QA should use --qa-save-path profile isolation")
	_connect_signal_recorders()
	_prepare_runtime_state()

	await _start_from_real_main_scene()
	await _choose_opening_affix()
	await _force_clear_current_room_and_choose_path()
	await _force_clear_current_room_and_choose_path()
	await _resolve_event_room_and_choose_path()
	await _force_finish_run()

	if _main and is_instance_valid(_main):
		_main.queue_free()

	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		return 1
	_report("Run flow contract QA passed")
	return 0


func _connect_signal_recorders() -> void:
	EventBus.run_started.connect(func(seed_value: int) -> void:
		_run_started_seeds.append(seed_value)
	)
	EventBus.room_entered.connect(func(room: Dictionary, stage: Dictionary) -> void:
		_room_entries.append({
			"room": room.duplicate(true),
			"stage": stage.duplicate(true),
		})
	)
	EventBus.affix_choice_requested.connect(func(offers: Array, context: Dictionary) -> void:
		_affix_requests.append({
			"offers": offers.duplicate(true),
			"context": context.duplicate(true),
		})
	)
	EventBus.path_choice_requested.connect(func(branches: Array) -> void:
		_path_requests.append(branches.duplicate(true))
	)
	EventBus.event_requested.connect(func(event: Dictionary, choices: Array) -> void:
		_event_requests.append({
			"event": event.duplicate(true),
			"choices": choices.duplicate(true),
		})
	)
	EventBus.weapon_mod_choice_requested.connect(func(offers: Array, context: Dictionary) -> void:
		_weapon_mod_requests.append({
			"offers": offers.duplicate(true),
			"context": context.duplicate(true),
		})
	)
	EventBus.run_completed.connect(func(victory: bool) -> void:
		_run_completed.append(victory)
	)


func _prepare_runtime_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	SaveManager.profile = _profile_snapshot.duplicate(true)
	SaveManager.save_profile()
	KarmaTracker.reset()
	CombatRngService.reset()
	WeatherSystem.set_weather("clear")
	RunContext.run_active = false
	RunContext.ui_blocking = false
	RunContext.run_plan = []
	RunContext.current_stage = 0
	RunContext.current_room = 0
	RunContext.rooms_cleared = 0
	RunContext.gold = GameConstants.STARTING_GOLD
	RunContext.training_mode = false
	RunContext.heart_demon_boost = false
	RunContext.pending_temptation_penalty.clear()
	RunContext.pending_weather_opportunity.clear()
	RunContext.reset_run_highlights()
	RunContext.set_cultivation_path(CultivationPathRegistry.DEFAULT_PATH_ID, false)


func _start_from_real_main_scene() -> void:
	_report("Starting run through real main.tscn and RunSetupPanel")
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _frames(8)

	var setup := _main.get_node_or_null("RunSetupPanel")
	_require(setup != null, "Main should add RunSetupPanel")
	if setup == null:
		return
	_require(setup.get_node_or_null("Panel") != null, "RunSetupPanel should expose Panel")
	_require(setup.get_node_or_null("Panel/Margin/Root/Footer/ButtonRow/StartButton") != null, "RunSetupPanel should expose StartButton")
	var seed_input := setup.get_node_or_null("Panel/Margin/Root/Footer/SeedRow/SeedInput") as LineEdit
	_require(seed_input != null, "RunSetupPanel should expose SeedInput")
	if seed_input:
		seed_input.text = str(FIXED_SEED)
	if setup.has_method("_select"):
		setup.call("_select", DaoHeartConfig.DaoHeart.ENLIGHTEN)
	if setup.has_method("_select_path"):
		setup.call("_select_path", "sword")
	setup.call("_on_start_pressed")
	await _wait_until(func() -> bool:
		return _main.get_node_or_null("World/RunController") != null
	, 2.5, "Main should instance World/RunController after setup confirm")

	_require(RunContext.run_active, "RunContext.run_active should be true after setup")
	_require(RunContext.seed_value == FIXED_SEED, "RunContext should use fixed seed from RunSetupPanel")
	_require(not RunContext.run_plan.is_empty(), "RunContext.run_plan should be generated for a real run")
	_require(_run_started_seeds.has(FIXED_SEED), "EventBus.run_started should emit fixed seed")
	_require(RunContext.cultivation_path_id == "sword", "RunSetupPanel path selection should reach RunContext")
	var arena := _get_run_controller()
	_require(arena != null and arena.name == "RunController", "World/RunController should be a real RunController node")
	_require(_room_entries.size() >= 1, "RunController should emit first room_entered")
	if not _room_entries.is_empty():
		var first_room: Dictionary = _room_entries[0].get("room", {})
		_require(str(first_room.get("type", "")) == "combat", "First room should be combat")
		_require(int(first_room.get("room_index", -1)) == 0, "First room index should be 0")
	await _wait_for_affix_requests(1, "Opening affix request should be emitted")
	_require(RunContext.ui_blocking, "Opening affix should block gameplay UI")
	_require(get_tree().paused, "Opening affix should pause the tree")
	var first_affix_context: Dictionary = _affix_requests[0].get("context", {})
	_require(bool(first_affix_context.get("opening_choice", false)), "Opening affix context should be marked")
	_require(_affix_offer_count(0) >= 3, "Opening affix should offer at least three choices")


func _choose_opening_affix() -> void:
	_report("Choosing opening affix through real AffixChoicePanel card")
	var panel := _main.get_node_or_null("AffixChoicePanel")
	_require(panel != null, "Main should add AffixChoicePanel")
	if panel == null:
		return
	var card := panel.get_node_or_null("Panel/Margin/VBox/Cards").get_child(0) as Control
	_require(card != null and card.has_method("_on_select_pressed"), "AffixChoicePanel should create selectable card")
	if card == null:
		return
	card.call("_on_select_pressed")
	await _wait_until(func() -> bool:
		return not RunContext.ui_blocking and not get_tree().paused
	, 2.5, "Opening affix choice should close and resume gameplay")
	var player := _get_player()
	_require(player != null, "RunController should have a player after opening affix")
	if player and player.has_node("AffixHolder"):
		var holder: Node = player.get_node("AffixHolder")
		_require(holder.equipped.size() >= 1, "Opening affix should equip one affix on the real player")
	await _frames(4)
	var arena := _get_run_controller()
	_require(arena != null and arena.get_horde() != null, "RunController should keep HordeController after opening affix")
	if arena and arena.get_horde():
		_require(arena.get_horde().active, "Combat horde should start after opening affix closes")


func _force_clear_current_room_and_choose_path() -> void:
	var room_before := RunContext.get_current_room_def().duplicate(true)
	_report("Clearing room %d:%d (%s) through RunController" % [
		RunContext.current_stage,
		RunContext.current_room,
		str(room_before.get("type", "")),
	])
	var affix_target := _affix_requests.size() + 1
	var path_target := _path_requests.size() + 1
	var weapon_mod_target := _weapon_mod_requests.size() + 1
	var arena := _get_run_controller()
	_require(arena != null, "RunController should exist before room clear")
	if arena == null:
		return
	if arena.get_horde():
		arena.get_horde().reset()
	if arena.has_method("_clear_enemies"):
		arena.call("_clear_enemies")
	arena.call("_on_room_cleared")
	await _handle_optional_weapon_mod(weapon_mod_target, affix_target)
	await _wait_for_affix_requests(affix_target, "Room clear should request reward affix")
	_require(RunContext.ui_blocking, "Reward affix should block UI after room clear")
	EventBus.affix_choice_closed.emit()
	await _wait_for_path_requests(path_target, "Closing reward affix should request path choice")
	_require(RunContext.ui_blocking, "Path choice should block UI")
	var branches: Array = _path_requests.back()
	_require(_has_branch(branches, "continue"), "Path choice should include continue branch")
	var previous_cleared := RunContext.rooms_cleared
	EventBus.path_choice_closed.emit("continue")
	await _wait_until(func() -> bool:
		return RunContext.rooms_cleared >= previous_cleared + 1
	, 2.5, "Path continue should advance to the next room")
	_require(_room_entries.size() >= RunContext.rooms_cleared + 1, "Advance should emit next room_entered")
	var next_type := str(RunContext.get_current_room_def().get("type", ""))
	if next_type == "event":
		_require(RunContext.ui_blocking, "Entering an event room should block UI for the event panel")
	else:
		_require(not RunContext.ui_blocking, "Entering a non-event room should leave gameplay UI unblocked")


func _handle_optional_weapon_mod(weapon_mod_target: int, affix_target: int) -> void:
	await _wait_until(func() -> bool:
		return _affix_requests.size() >= affix_target or _weapon_mod_requests.size() >= weapon_mod_target
	, 2.5, "Room clear should request reward affix or weapon mod")
	if _affix_requests.size() >= affix_target:
		return
	var request: Dictionary = _weapon_mod_requests.back()
	var offers: Array = request.get("offers", [])
	_require(offers.size() >= 1, "Weapon mod request should include at least one offer")
	if offers.is_empty():
		return
	var mod_id := str((offers[0] as Dictionary).get("id", ""))
	_require(not mod_id.is_empty(), "Weapon mod offer should include an id")
	var previous_mod_count := RunContext.weapon_mods.size()
	EventBus.weapon_mod_choice_closed.emit(mod_id)
	await _wait_until(func() -> bool:
		return _affix_requests.size() >= affix_target
	, 2.5, "Closing weapon mod should continue into reward affix")
	_require(RunContext.weapon_mods.size() >= previous_mod_count + 1, "Weapon mod choice should be recorded in RunContext")


func _resolve_event_room_and_choose_path() -> void:
	_report("Resolving event room through real EventBus flow")
	await _wait_until(func() -> bool:
		return str(RunContext.get_current_room_def().get("type", "")) == "event"
	, 1.5, "Run should reach first event room after two combat rooms")
	await _wait_until(func() -> bool:
		return not _event_requests.is_empty()
	, 1.5, "Event room should request event panel")
	_require(RunContext.ui_blocking, "Event room should block UI")
	_require(get_tree().paused, "Event room should pause the tree")
	var event_payload: Dictionary = _event_requests.back()
	_require(not event_payload.get("event", {}).is_empty(), "Event request should include event data")
	_require((event_payload.get("choices", []) as Array).size() >= 1, "Event request should include choices")
	var path_target := _path_requests.size() + 1
	EventBus.event_closed.emit(0)
	await _wait_for_path_requests(path_target, "Closing event should request path choice")
	var branches: Array = _path_requests.back()
	_require(branches.size() == 1 and str((branches[0] as Dictionary).get("id", "")) == "continue", "Event room path should continue only")
	var previous_cleared := RunContext.rooms_cleared
	EventBus.path_choice_closed.emit("continue")
	await _wait_until(func() -> bool:
		return RunContext.rooms_cleared >= previous_cleared + 1 and str(RunContext.get_current_room_def().get("type", "")) == "boss"
	, 2.5, "Event continue should advance into first boss room")


func _force_finish_run() -> void:
	_report("Forcing run completion through RunController finish contract")
	var arena := _get_run_controller()
	_require(arena != null, "RunController should exist before forced finish")
	if arena == null:
		return
	RunContext.current_stage = RunContext.run_plan.size()
	RunContext.current_room = 0
	RunContext.run_active = false
	arena.call("_enter_current_room")
	await _wait_until(func() -> bool:
		return not _run_completed.is_empty()
	, 2.5, "RunController should emit run_completed when run plan is exhausted")
	_require(_run_completed.back() == true, "Exhausted run plan should emit victory=true")
	var latest := SaveManager.get_latest_run_record()
	_require(not latest.is_empty(), "Run completion should write a long-term run record")
	_require(bool(latest.get("victory", false)), "Long-term run record should preserve victory=true")
	_require(int(latest.get("seed", 0)) == FIXED_SEED, "Long-term run record should preserve fixed seed")
	_require(int(latest.get("rooms_cleared", 0)) == RunContext.rooms_cleared, "Long-term run record rooms should match RunContext")
	_require(str(latest.get("cultivation_path_id", "")) == RunContext.cultivation_path_id, "Long-term run record should preserve selected path")
	_require(str(latest.get("weapon_id", "")) == RunContext.weapon_id, "Long-term run record should preserve weapon id")
	_require((latest.get("affixes", []) as Array).size() >= 1, "Long-term run record should include acquired affixes")
	var result_panel := _main.get_node_or_null("RunResultPanel")
	_require(result_panel != null, "Main should add RunResultPanel")
	if result_panel:
		await _frames(4)
		var panel := result_panel.get_node_or_null("Panel") as PanelContainer
		var title := result_panel.get_node_or_null("Panel/Margin/VBox/Title") as Label
		var detail := result_panel.get_node_or_null("Panel/Margin/VBox/DetailScroll/Detail") as Label
		_require(panel != null and panel.visible, "RunResultPanel should become visible on completion")
		_require(title != null and title.text.length() >= 4, "RunResultPanel should show a title")
		_require(detail != null and detail.text.contains("前世碑"), "RunResultPanel should show the long-term epitaph summary")


func _get_run_controller() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("World/RunController")


func _get_player() -> Node:
	var arena := _get_run_controller()
	if arena == null:
		return null
	for child in arena.get_children():
		if child.is_in_group("player") or child.name == "Player":
			return child
	return get_tree().get_first_node_in_group("player")


func _affix_offer_count(index: int) -> int:
	if index < 0 or index >= _affix_requests.size():
		return 0
	var offers: Array = _affix_requests[index].get("offers", [])
	return offers.size()


func _has_branch(branches: Array, id: String) -> bool:
	for branch in branches:
		if branch is Dictionary and str(branch.get("id", "")) == id:
			return true
	return false


func _wait_for_affix_requests(count: int, message: String) -> void:
	await _wait_until(func() -> bool:
		return _affix_requests.size() >= count
	, 2.5, message)


func _wait_for_path_requests(count: int, message: String) -> void:
	await _wait_until(func() -> bool:
		return _path_requests.size() >= count
	, 2.5, message)


func _wait_for_event_requests(count: int, message: String) -> void:
	await _wait_until(func() -> bool:
		return _event_requests.size() >= count
	, 2.5, message)


func _wait_until(predicate: Callable, timeout: float, message: String) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if bool(predicate.call()):
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not bool(predicate.call()):
		_fail(message)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _restore_profile() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _profile_snapshot.is_empty():
		return
	SaveManager.profile = _profile_snapshot.duplicate(true)
	SaveManager.save_profile()


func _require(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _report(message: String) -> void:
	_report_lines.append(message)
	print(message)


func _write_report(exit_code: int) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write %s" % REPORT_PATH)
		return
	for line in _report_lines:
		file.store_line(line)
	file.store_line("Exit code: %d" % exit_code)
