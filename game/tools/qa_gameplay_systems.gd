extends Node

const EventSelector = preload("res://systems/world/event_selector.gd")
const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")
const BossPhaseRegistry = preload("res://systems/combat/boss_phase_registry.gd")
const CultivationPathRegistry = preload("res://systems/realm/cultivation_path_registry.gd")
const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const EnemySpawnRegistry = preload("res://systems/combat/enemy_spawn_registry.gd")
const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")
const EnemySkillRegistry = preload("res://systems/combat/enemy_skill_registry.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/combat/enemy_projectile.tscn")

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TRAINING_DUMMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const REPORT_PATH := "res://tools/gameplay_systems_qa_report.txt"

const EPS := 0.01

class FakeEnemy:
	extends Node2D

	var elite := false
	var terrain_damage_total := 0.0
	var terrain_types: Array[String] = []
	var statuses: Array[String] = []
	var mutation_triggered := false
	var mutation_duration := 0.0
	var mutation_element := ""

	func receive_terrain_damage(amount: float, terrain_type: String = "") -> void:
		terrain_damage_total += amount
		terrain_types.append(terrain_type)

	func apply_status(status_name: String, _duration: float) -> void:
		statuses.append(status_name)

	func is_elite_unit() -> bool:
		return elite

	func trigger_spirit_mutation(duration: float = 5.0, element_key: String = "fire") -> void:
		mutation_triggered = true
		mutation_duration = duration
		mutation_element = element_key


var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _profile_snapshot: Dictionary = {}
var _temp_nodes: Array[Node] = []

var _hidden_chain_events: Array[Dictionary] = []
var _feedback_events: Array[Dictionary] = []
var _pet_feedback: Array[String] = []
var _boss_health_events: Array[Dictionary] = []
var _damage_events: Array[Dictionary] = []
var _enemy_killed_events: Array[Node] = []
var _weather_kill_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code: int = await _run()
	_restore_profile()
	_write_report(code)
	get_tree().quit(code)


func _run() -> int:
	_report("Gameplay systems QA")
	_report("===================")
	_profile_snapshot = SaveManager.profile.duplicate(true)
	_assert_true(SaveManager.is_using_profile_path_override(), "Gameplay QA should use --qa-save-path profile isolation")
	_connect_signal_recorders()
	_prepare_runtime_state()

	await _check_long_term_records()
	await _check_event_selector()
	await _check_battle_event_director()
	await _check_hidden_chain_discovery()
	await _check_boss_phase_gates()
	await _check_run_context_summary()
	await _check_identity_and_weapon_routes()
	await _check_enemy_projectile_semantics()
	await _check_enemy_projectile_runtime_hit()

	_cleanup_temp_nodes()
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		return 1
	_report("Gameplay systems QA passed")
	return 0


func _connect_signal_recorders() -> void:
	EventBus.hidden_chain_discovered.connect(func(chain_id: String, display_name: String, payload: Dictionary) -> void:
		_hidden_chain_events.append({
			"chain_id": chain_id,
			"display_name": display_name,
			"payload": payload.duplicate(true),
		})
	)
	EventBus.feedback_anchor_requested.connect(func(anchor_id: String, payload: Dictionary) -> void:
		_feedback_events.append({
			"anchor_id": anchor_id,
			"payload": payload.duplicate(true),
		})
	)
	EventBus.pet_coord_feedback.connect(func(text: String) -> void:
		_pet_feedback.append(text)
	)
	EventBus.boss_health_changed.connect(func(display_name: String, current: float, maximum: float, phase_index: int, phase_count: int, phase_name: String) -> void:
		_boss_health_events.append({
			"display_name": display_name,
			"current": current,
			"maximum": maximum,
			"phase_index": phase_index,
			"phase_count": phase_count,
			"phase_name": phase_name,
		})
	)
	EventBus.damage_dealt.connect(func(result: Dictionary) -> void:
		_damage_events.append(result.duplicate(true))
	)
	EventBus.enemy_killed.connect(func(enemy: Node) -> void:
		_enemy_killed_events.append(enemy)
	)
	EventBus.weather_kill.connect(func(enemy: Node, weather_id: String, payload: Dictionary) -> void:
		_weather_kill_events.append({
			"enemy": enemy,
			"weather_id": weather_id,
			"payload": payload.duplicate(true),
		})
	)


func _prepare_runtime_state() -> void:
	RunContext.run_active = true
	RunContext.seed_value = 880301
	RunContext.current_stage = 0
	RunContext.current_room = 0
	RunContext.rooms_cleared = 0
	RunContext.cultivation_path_id = "sword"
	RunContext.pet_acquired = true
	RunContext.pending_weather_opportunity.clear()
	RunContext.reset_run_highlights()
	RunContext.reset_dao_momentum()
	KarmaTracker.reset()
	CombatRngService.reset()
	WeatherSystem.set_weather("clear")
	SaveManager.profile = _profile_snapshot.duplicate(true)
	SaveManager.profile["hidden_chains_discovered"] = []
	SaveManager.profile["recent_death_line_ids"] = []
	SaveManager.save_profile()
	EventBus.run_started.emit(RunContext.seed_value)


func _check_long_term_records() -> void:
	_report("Checking long-term run records and codex")
	SaveManager.profile = {
		"version": 1,
		"reincarnation_points": 0,
		"hidden_chains_discovered": [],
		"awakened_dao_traditions": [],
	}
	SaveManager.save_profile()
	_assert_true(SaveManager.profile.has("run_history"), "SaveManager schema should backfill run_history")
	_assert_true(SaveManager.profile.has("build_records"), "SaveManager schema should backfill build_records")
	_assert_true(SaveManager.profile.has("codex"), "SaveManager schema should backfill codex")
	_assert_true(SaveManager.profile.has("stats"), "SaveManager schema should backfill stats")

	var first_enemy := SaveManager.record_enemy_kill("shield_guard", 2, {"run_id": "qa_run", "seed": 11})
	var second_enemy := SaveManager.record_enemy_kill("shield_guard", 1, {"run_id": "qa_run", "seed": 11})
	_assert_true(first_enemy and second_enemy, "Enemy codex kill records should report changes")
	SaveManager.record_codex_seen("enemies", "", {})
	var codex: Dictionary = SaveManager.profile.get("codex", {})
	var enemies: Dictionary = codex.get("enemies", {})
	_assert_true(enemies.has("shield_guard"), "Enemy codex should use stable enemy id")
	_assert_true(not enemies.has(""), "Enemy codex should reject empty ids")
	var guard: Dictionary = enemies.get("shield_guard", {})
	_assert_equal(int(guard.get("kill_count", 0)), 3, "Enemy codex kill_count should accumulate")

	RunContext.seed_value = 99123
	RunContext.current_run_id = "qa_long_term"
	RunContext.run_active = true
	RunContext.rooms_cleared = 4
	RunContext.gold = 128
	RunContext.realm_level = 2
	RunContext.dao_heart = DaoHeartConfig.DaoHeart.ENLIGHTEN
	RunContext.set_cultivation_path("sword", false)
	RunContext.weapon_mods = ["thunder_edge"]
	RunContext.peak_combo_count = 77
	RunContext.peak_dao_momentum = 88.0
	RunContext.last_boss_hp_ratio = 0.13
	RunContext.last_boss_name = "QA劫主"
	RunContext.reset_run_recording()
	RunContext.current_run_id = "qa_long_term"
	RunContext.record_room_for_codex(
		{"weather_id": "thunder", "terrain_feature_weights": {"water": 2.0, "rock": 1.0}},
		{"id": "qa_stage", "name": "QA秘境"}
	)
	RunContext.record_affix_for_codex("F001")
	RunContext.record_hidden_chain_for_codex("C01")
	RunContext.record_run_highlight("qa_peak", "QA名场面", "长期记录应保存高光。", 99)
	var enemy := TRAINING_DUMMY_SCENE.instantiate()
	add_child(enemy)
	_temp_nodes.append(enemy)
	await get_tree().process_frame
	enemy.configure_enemy("护阵者", false, "combat")
	RunContext.record_enemy_kill_for_codex(enemy)
	_cleanup_node(enemy)

	var reincarnation_before := SaveManager.get_reincarnation_points()
	RunContext.finalize_run_meta(false)
	var latest := SaveManager.get_latest_run_record()
	_assert_equal(str(latest.get("run_id", "")), "qa_long_term", "Finalize should write latest run id")
	_assert_equal(int(latest.get("rooms_cleared", 0)), 4, "Run record should preserve rooms cleared")
	_assert_equal(int(latest.get("best_combo", 0)), 77, "Run record should preserve best combo")
	_assert_true((latest.get("weather_seen", []) as Array).has("thunder"), "Run record should include weather ids")
	_assert_true((latest.get("terrain_seen", []) as Array).has("water"), "Run record should include terrain ids")
	_assert_equal(int((latest.get("enemy_kills", {}) as Dictionary).get("shield_guard", 0)), 1, "Run record should include enemy kills by id")
	_assert_equal(SaveManager.get_reincarnation_points(), reincarnation_before + 28, "Failed run should grant expected reincarnation points")
	var size_after_first := SaveManager.get_run_records().size()
	var points_after_first := SaveManager.get_reincarnation_points()
	RunContext.finalize_run_meta(false)
	_assert_equal(SaveManager.get_run_records().size(), size_after_first, "Finalize should not double-write one run")
	_assert_equal(SaveManager.get_reincarnation_points(), points_after_first, "Duplicate finalize should not double-grant points")

	for i in range(SaveManager.RUN_HISTORY_LIMIT + 3):
		SaveManager.record_run_result({
			"run_id": "qa_cap_%d" % i,
			"seed": i,
			"victory": i % 2 == 0,
			"rooms_cleared": i,
			"best_combo": i * 2,
		})
	_assert_equal(SaveManager.get_run_records().size(), SaveManager.RUN_HISTORY_LIMIT, "Run history should be capped")
	var json_text := JSON.stringify(SaveManager.profile)
	var parsed = JSON.parse_string(json_text)
	_assert_true(parsed is Dictionary, "Long-term profile should JSON round-trip")
	_prepare_runtime_state()


func _check_event_selector() -> void:
	_report("Checking EventSelector")
	KarmaTracker.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	var prove_event := EventSelector.pick_event_id("clear", DaoHeartConfig.DaoHeart.PROVE_DAO, rng, {}, false)
	_assert_equal(prove_event, "M01", "PROVE_DAO should force first heart demon event")

	var seen_for_thunder := _events_seen_except("E07", 99)
	rng.seed = 1202
	var thunder_event := EventSelector.pick_event_id("thunder", DaoHeartConfig.DaoHeart.ENLIGHTEN, rng, seen_for_thunder, true)
	_assert_equal(thunder_event, "E07", "Thunder-only weather event should be selectable when other events are exhausted")
	var event := EventSelector.get_event("E07")
	var choices := EventSelector.build_choices(event)
	_assert_equal(choices.size(), 3, "E07 should expose three choices")
	_assert_equal(str(choices[0].get("effect", "")), "bias:thunder", "E07 first choice should bias thunder rewards")

	KarmaTracker.reset()
	var seen_for_karma := _events_seen_except("E17", 99)
	rng.seed = 1203
	var blocked_event := EventSelector.pick_event_id("", DaoHeartConfig.DaoHeart.ENLIGHTEN, rng, seen_for_karma, true)
	_assert_true(blocked_event != "E17", "Karma-gated E17 should not appear without good karma")
	KarmaTracker.add_karma("good", 1)
	var e17 := EventSelector.get_event("E17")
	_assert_true(EventSelector._passes_karma_gate(e17), "Karma-gated E17 should pass after good karma reaches gate")
	var e17_choices := EventSelector.build_choices(e17)
	_assert_equal(str(e17_choices[0].get("label", "")), "接受馈赠(+25)", "E17 first choice label should match CSV")


func _check_battle_event_director() -> void:
	_report("Checking BattleEventDirector")
	RunContext.pending_weather_opportunity.clear()
	RunContext.reset_run_highlights()
	RunContext.rooms_without_weather_kill = 2
	RunContext.cultivation_path_id = "sword"
	WeatherSystem.set_weather("clear")
	EventBus.run_started.emit(RunContext.seed_value + 1)
	EventBus.room_entered.emit({"type": "combat", "room_index": 2}, {"stage_index": 1})
	await get_tree().process_frame
	var opportunity := RunContext.pending_weather_opportunity.duplicate(true)
	_assert_equal(str(opportunity.get("weather_id", "")), "thunder", "Dao-heart stir should queue thunder weather for sword path")
	_assert_equal(str(opportunity.get("layout_id", "")), "edge_pockets", "Thunder opportunity should use edge_pockets layout")
	var highlight := RunContext.get_best_run_highlight()
	_assert_equal(str(highlight.get("id", "")), "dao_heart_stir_0", "Dao-heart stir should record a run highlight")

	EventBus.run_started.emit(RunContext.seed_value + 2)
	RunContext.run_active = true
	RunContext.pet_acquired = true
	WeatherSystem.set_weather("thunder")
	EventBus.room_entered.emit({"type": "elite", "room_index": 3}, {"stage_index": 1})
	var elite := _spawn_fake_enemy(Vector2(-80, 0), true)
	var mutable := _spawn_fake_enemy(Vector2(60, 0), false)
	EventBus.enemy_killed.emit(elite)
	await get_tree().create_timer(3.25, false).timeout
	_assert_true(mutable.mutation_triggered, "Elite kill in elite room should trigger one enemy mutation")
	_assert_equal(mutable.mutation_element, "thunder", "Thunder weather should route mutation element to thunder")
	_cleanup_node(elite)
	_cleanup_node(mutable)


func _check_hidden_chain_discovery() -> void:
	_report("Checking HiddenChainDetector")
	_hidden_chain_events.clear()
	_feedback_events.clear()
	_pet_feedback.clear()
	RunContext.reset_run_highlights()
	RunContext.run_active = true
	WeatherSystem.set_weather("thunder")
	SaveManager.profile["hidden_chains_discovered"] = []
	SaveManager.save_profile()

	var target := _spawn_fake_enemy(Vector2(96, 48), false)
	var discovered := false
	for attempt in range(80):
		RunContext.seed_value = 930001 + attempt
		CombatRngService.reset()
		HiddenChainDetector.set("_recent_attempts", {})
		EventBus.damage_dealt.emit({
			"target": target,
			"target_is_player": false,
			"element_key": "thunder",
			"source_tag": "qa_projectile",
			"target_status": {"paralyzed": true},
			"target_killed": false,
		})
		await get_tree().process_frame
		if _has_hidden_chain_event("C01"):
			discovered = true
			break
	_assert_true(discovered, "Thunder/paralyze damage should discover hidden chain C01 within deterministic seed window")
	_assert_true(SaveManager.has_discovered_hidden_chain("C01"), "Hidden chain discovery should persist through SaveManager")
	_assert_true(_has_feedback_anchor("chain_trigger"), "Hidden chain effect should request chain_trigger feedback anchor")
	_assert_true(target.terrain_damage_total > 0.0, "Hidden chain C01 should apply area terrain damage")
	_assert_true("paralyze" in target.statuses, "Hidden chain C01 should apply paralyze status")
	var best := RunContext.get_best_run_highlight()
	_assert_equal(str(best.get("id", "")), "hidden_C01", "Hidden chain discovery should become the best run highlight")
	_cleanup_node(target)


func _check_boss_phase_gates() -> void:
	_report("Checking boss phase gates")
	_boss_health_events.clear()
	_feedback_events.clear()
	_pet_feedback.clear()
	_damage_events.clear()
	_enemy_killed_events.clear()
	RunContext.reset_run_highlights()
	RunContext.run_active = true
	WeatherSystem.set_weather("clear")

	var phases := BossPhaseRegistry.get_phases("boss")
	_assert_equal(phases.size(), 3, "Boss phase registry should load three boss phases")
	_assert_equal(str((phases[1] as Dictionary).get("phase_name", "")), "劫火四起", "Boss phase 1 name should match CSV")

	var boss := TRAINING_DUMMY_SCENE.instantiate()
	add_child(boss)
	_temp_nodes.append(boss)
	await get_tree().process_frame
	boss.configure_enemy("QA劫主", true, "boss")
	var health: Node = boss.get_node("HealthComponent")
	health.max_hp = 1000.0
	health.current_hp = 1000.0
	health.defense = 0.0
	health.changed.emit(health.current_hp, health.max_hp)
	await get_tree().process_frame

	var gates: Array = boss.get("_boss_phase_gates")
	_assert_equal(gates.size(), 2, "Boss should build two HP gates from three phase rows")
	_assert_true(_float_eq(float(gates[0]), 0.6), "First boss HP gate should be 60%")
	_assert_true(_float_eq(float(gates[1]), 0.3), "Second boss HP gate should be 30%")

	boss.receive_terrain_damage(500.0, "fire")
	await get_tree().process_frame
	_assert_true(_float_eq(float(health.current_hp), 600.0), "Boss over-damage should clip at first phase gate")
	_assert_equal(int(boss.get("_boss_phase_gate_index")), 1, "Boss should advance to phase gate index 1")
	_assert_true(_latest_boss_phase_index() == 1, "Boss health signal should report phase index 1")
	_assert_true(_has_feedback_anchor("boss_phase_break"), "Boss phase break should request feedback anchor")
	_assert_true(_contains_pet_feedback("守势崩裂"), "Boss phase break should emit readable pet feedback")

	var hp_after_gate := float(health.current_hp)
	_damage_events.clear()
	boss.receive_terrain_damage(200.0, "fire")
	await get_tree().process_frame
	_assert_true(_float_eq(float(health.current_hp), hp_after_gate), "Boss gate lock should prevent immediate follow-up damage")
	_assert_true(_latest_damage_is_zero(), "Damage event during boss gate lock should report zero final damage")

	await get_tree().create_timer(0.45, false).timeout
	_feedback_events.clear()
	boss.receive_terrain_damage(400.0, "fire")
	await get_tree().process_frame
	_assert_true(_float_eq(float(health.current_hp), 300.0), "Boss should clip at second phase gate after lock expires")
	_assert_equal(int(boss.get("_boss_phase_gate_index")), 2, "Boss should advance to final phase gate index")
	_assert_true(_has_feedback_anchor("boss_phase_break"), "Second boss phase break should also request feedback anchor")

	await get_tree().create_timer(0.45, false).timeout
	_feedback_events.clear()
	boss.receive_terrain_damage(500.0, "fire")
	await get_tree().process_frame
	_assert_true(not _enemy_killed_events.is_empty(), "Boss should emit enemy_killed after all gates are spent")
	_assert_true(_has_feedback_anchor("boss_inheritance"), "Boss death should request inheritance feedback anchor")
	_cleanup_node(boss)


func _check_run_context_summary() -> void:
	_report("Checking RunContext summaries and highlights")
	RunContext.reset_run_highlights()
	RunContext.record_boss_hp_ratio("QA劫主", 0.14)
	var summary := RunContext.build_death_summary()
	_assert_equal(str(summary.get("regret", "")), "boss_low_hp", "Low boss HP should produce boss_low_hp death regret")
	_assert_equal(str(summary.get("progress_level", "")), "high", "Low boss HP should be high progress")
	_assert_true(str(summary.get("detail", "")).contains("QA劫主"), "Boss-low-HP summary should name the boss")

	RunContext.reset_run_highlights()
	EventBus.combo_milestone.emit(100)
	EventBus.unity_burst_requested.emit({"source": "qa"})
	EventBus.hidden_chain_discovered.emit("QA", "测试连锁", {
		"hint": "QA hint",
		"effect_anchor_handled": true,
	})
	await get_tree().process_frame
	var best := RunContext.get_best_run_highlight()
	_assert_equal(str(best.get("id", "")), "hidden_QA", "Hidden-chain highlight should outrank combo and unity highlights")

	RunContext.reset_run_highlights()
	_weather_kill_events.clear()
	WeatherSystem.set_weather("clear")
	var clear_enemy := _spawn_fake_enemy(Vector2.ZERO, false)
	RunContext.record_weather_kill(clear_enemy, "clear", {})
	_assert_true(_weather_kill_events.is_empty(), "Clear weather kill should not emit weather_kill")
	WeatherSystem.set_weather("thunder")
	RunContext.record_weather_kill(clear_enemy, "thunder", {"source": "qa"})
	_assert_equal(_weather_kill_events.size(), 1, "Non-clear weather kill should emit weather_kill once")
	best = RunContext.get_best_run_highlight()
	_assert_true(str(best.get("id", "")).begins_with("weather_kill_"), "First weather kill should record a weather highlight")
	_cleanup_node(clear_enemy)


func _check_identity_and_weapon_routes() -> void:
	_report("Checking identity and weapon routes")
	RunContext.run_active = true
	RunContext.reset_run_highlights()
	_assert_identity_path("caster", "starter_orb", "projectile", "lie_yan_bolt")
	_assert_identity_path("sword", "qing_feng_sword", "short_arc", "yu_jian_thrust")
	_assert_identity_path("talisman", "san_cai_flag", "projectile", "qi_fu")
	_assert_identity_path("body", "iron_gauntlet", "short_arc", "beng_shan_jin")
	_assert_identity_path("alchemy", "alchemy_furnace", "projectile", "lian_dan_fire")
	_assert_identity_path("soul", "soul_banner", "projectile", "summon_soul")

	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	_temp_nodes.append(player)
	await get_tree().process_frame
	RunContext.set_cultivation_path("sword", true)
	await get_tree().process_frame
	_assert_equal(str(player.get("_weapon_id")), "qing_feng_sword", "Player runtime weapon id should follow sword path")
	_assert_equal(str(player.get("debug_weapon_shape")), "short_arc", "Player runtime attack shape should follow sword path")
	RunContext.set_cultivation_path("caster", true)
	await get_tree().process_frame
	_assert_equal(str(player.get("_weapon_id")), "starter_orb", "Player runtime weapon id should follow caster path")
	_assert_equal(str(player.get("debug_weapon_shape")), "projectile", "Player runtime attack shape should follow caster path")
	_cleanup_node(player)

	await _assert_enemy_weapon_route("wild_wolf", "妖狼", "claw", "爪", "berserker")
	await _assert_enemy_weapon_route("crossbow_cultivator", "弩修", "cloud_crossbow", "弩", "sniper")
	await _assert_enemy_weapon_route("shield_guard", "护阵者", "xuanwu_shield", "盾", "elite")
	await _assert_enemy_weapon_route("mud_serpent", "泥泽游蛇", "mud_bow", "弩", "sniper")
	await _assert_enemy_weapon_route("furnace_golem", "火纹傀儡", "furnace_core", "炉心", "elite")
	await _assert_enemy_weapon_route("boss", "关底守将", "soul_banner", "魂幡", "boss")
	await _assert_boss_inheritance_label("soul_banner", "魂幡传承")
	await _assert_boss_inheritance_label("xuanwu_shield", "玄甲传承")
	await _assert_guardian_priority_mechanic()


func _assert_identity_path(path_id: String, weapon_id: String, shape: String, start_q: String) -> void:
	var path := CultivationPathRegistry.get_path_def(path_id)
	_assert_equal(str(path.get("weapon_id", "")), weapon_id, "Path %s should map to expected weapon" % path_id)
	var weapon := WeaponRegistry.get_weapon(weapon_id)
	_assert_equal(str(weapon.get("attack_shape", "")), shape, "Weapon %s should expose expected attack shape" % weapon_id)
	_assert_equal(str(weapon.get("start_q", "")), start_q, "Weapon %s should map to expected starting Q spell" % weapon_id)
	_assert_true(str(weapon.get("summary", "")).length() >= 8, "Weapon %s should have readable identity summary" % weapon_id)


func _assert_enemy_weapon_route(enemy_id: String, display_name: String, weapon_id: String, label: String, expected_archetype: String) -> void:
	_assert_equal(EnemySpawnRegistry.get_weapon_id(enemy_id, display_name), weapon_id, "Enemy %s should route to expected weapon id" % enemy_id)
	_assert_equal(EnemySpawnRegistry.resolve_archetype(display_name, enemy_id == "boss", "boss" if enemy_id == "boss" else "combat"), expected_archetype, "Enemy %s should route to expected archetype" % enemy_id)
	var enemy := TRAINING_DUMMY_SCENE.instantiate()
	add_child(enemy)
	_temp_nodes.append(enemy)
	await get_tree().process_frame
	enemy.configure_enemy(display_name, enemy_id == "boss", "boss" if enemy_id == "boss" else "combat")
	enemy.set_enemy_weapon_id(weapon_id)
	_assert_equal(str(enemy.get("_weapon_id")), weapon_id, "Runtime enemy %s should receive CSV weapon id" % enemy_id)
	_assert_equal(enemy.call("_weapon_label"), label, "Runtime enemy %s should expose readable weapon label" % enemy_id)
	_cleanup_node(enemy)


func _assert_boss_inheritance_label(weapon_id: String, expected_fragment: String) -> void:
	var boss := TRAINING_DUMMY_SCENE.instantiate()
	add_child(boss)
	_temp_nodes.append(boss)
	await get_tree().process_frame
	boss.configure_enemy("QA传承守将", true, "boss")
	boss.set_enemy_weapon_id(weapon_id)
	var label := str(boss.call("_boss_inheritance_label"))
	_assert_true(label.contains(expected_fragment), "Boss inheritance for %s should include %s" % [weapon_id, expected_fragment])
	_cleanup_node(boss)


func _assert_guardian_priority_mechanic() -> void:
	_pet_feedback.clear()
	var guardian := TRAINING_DUMMY_SCENE.instantiate()
	var protected := TRAINING_DUMMY_SCENE.instantiate()
	add_child(guardian)
	add_child(protected)
	_temp_nodes.append(guardian)
	_temp_nodes.append(protected)
	await get_tree().process_frame
	guardian.global_position = Vector2.ZERO
	protected.global_position = Vector2(64, 0)
	guardian.configure_enemy("护阵者", false, "combat")
	guardian.set_enemy_weapon_id("xuanwu_shield")
	protected.configure_enemy("妖狼", false, "combat")
	protected.set_enemy_weapon_id("claw")
	var protected_health: Node = protected.get_node("HealthComponent")
	protected_health.max_hp = 100.0
	protected_health.current_hp = 100.0
	protected_health.defense = 0.0
	protected_health.changed.emit(protected_health.current_hp, protected_health.max_hp)
	protected.receive_terrain_damage(40.0, "fire")
	await get_tree().process_frame
	_assert_true(float(protected_health.current_hp) > 60.0, "Shield guard should reduce nearby ally damage")
	_assert_true(protected.call("_is_guarded_by_ally"), "Nearby ally should report guard protection")
	guardian.receive_terrain_damage(999.0, "fire")
	await get_tree().process_frame
	var hp_before := float(protected_health.current_hp)
	protected.receive_terrain_damage(20.0, "fire")
	await get_tree().process_frame
	_assert_true(_float_eq(float(protected_health.current_hp), hp_before - 20.0), "Ally should take full damage after shield guard dies")
	_assert_true(_contains_pet_feedback("护阵崩解"), "Shield guard death should explain priority-kill payoff")
	_cleanup_node(guardian)
	_cleanup_node(protected)


func _check_enemy_projectile_semantics() -> void:
	_report("Checking enemy projectile semantics")
	await _assert_enemy_projectile_semantics("crossbow_cultivator", "弩修", "cloud_crossbow", "sniper_shot", "thunder", "")
	await _assert_enemy_projectile_semantics("sky_bat", "腐翼妖蝠", "poison_spit", "projectile", "wood", "poison")
	await _assert_enemy_projectile_semantics("mud_serpent", "泥泽游蛇", "mud_bow", "sniper_shot", "earth", "slow")
	await _assert_enemy_projectile_semantics("wind_mantis", "风刃螳螂", "wind_blade", "blade_arc", "thunder", "")
	await _assert_enemy_projectile_semantics("furnace_golem", "火纹傀儡", "furnace_core", "burst", "fire", "burn")
	await _assert_enemy_projectile_semantics("boss", "关底守将", "soul_banner", "burst", "fire", "burn")


func _assert_enemy_projectile_semantics(enemy_id: String, display_name: String, weapon_id: String, skill_id: String, element: String, status_name: String) -> void:
	var enemy := TRAINING_DUMMY_SCENE.instantiate()
	add_child(enemy)
	_temp_nodes.append(enemy)
	await get_tree().process_frame
	enemy.configure_enemy(display_name, enemy_id == "boss", "boss" if enemy_id == "boss" else "combat")
	enemy.set_enemy_weapon_id(weapon_id)
	var skill := EnemySkillRegistry.get_skill(skill_id)
	var semantics: Dictionary = enemy.get_enemy_projectile_semantics(skill)
	_assert_equal(str(semantics.get("element", "")), element, "Enemy projectile %s should route element" % enemy_id)
	_assert_equal(str(semantics.get("status", "")), status_name, "Enemy projectile %s should route status" % enemy_id)
	if status_name.is_empty():
		_assert_true(float(semantics.get("status_duration", 0.0)) <= 0.0, "Enemy projectile %s should not fake status duration without gameplay status" % enemy_id)
	else:
		_assert_true(float(semantics.get("status_duration", 0.0)) > 0.0, "Enemy projectile %s should provide status duration" % enemy_id)
	_assert_equal(str(semantics.get("weapon_id", "")), weapon_id, "Enemy projectile %s should preserve weapon id source" % enemy_id)
	_cleanup_node(enemy)


func _check_enemy_projectile_runtime_hit() -> void:
	_report("Checking enemy projectile runtime hit route")
	_feedback_events.clear()
	_damage_events.clear()
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	add_child(projectile)
	_temp_nodes.append(projectile)
	await get_tree().process_frame
	projectile.setup(Vector2.RIGHT, 9.0, 240.0, 5.0, Color(0.45, 1.0, 0.36), "wood", "poison", 1.25, "qa_enemy_poison_spit")
	_assert_equal(str(projectile.element_key), "wood", "Enemy projectile should store element key")
	_assert_equal(str(projectile.status_on_hit), "poison", "Enemy projectile should store status key")
	_assert_equal(str(projectile.source_tag), "qa_enemy_poison_spit", "Enemy projectile should store source tag")
	_cleanup_node(projectile)

	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	_temp_nodes.append(player)
	await get_tree().process_frame
	var health: Node = player.get_node("HealthComponent")
	var hp_before := float(health.current_hp)
	var hit_applied := bool(player.receive_enemy_projectile(9.0, "wood", "poison", 1.25, "qa_enemy_poison_spit"))
	await get_tree().process_frame
	_assert_true(hit_applied, "Enemy projectile should report applied hit when player is vulnerable")
	_assert_true(float(health.current_hp) < hp_before, "Enemy projectile should damage player")
	_assert_true(player.get_node("StatusComponent").is_poisoned(), "Enemy projectile should apply status to player")
	_assert_true(_has_feedback_anchor("enemy_projectile_hit"), "Enemy projectile hit should emit semantic feedback anchor")
	_assert_true(not _damage_events.is_empty(), "Enemy projectile hit should emit damage event")
	if not _damage_events.is_empty():
		var damage_event: Dictionary = _damage_events.back()
		_assert_equal(str(damage_event.get("element", "")), "wood", "Enemy projectile damage event should carry element")
		_assert_equal(str(damage_event.get("status", "")), "poison", "Enemy projectile damage event should carry status")
		_assert_equal(str(damage_event.get("source_tag", "")), "qa_enemy_poison_spit", "Enemy projectile damage event should carry source tag")
	_cleanup_node(player)

	var dodging_player := PLAYER_SCENE.instantiate()
	add_child(dodging_player)
	_temp_nodes.append(dodging_player)
	await get_tree().process_frame
	dodging_player.set("_iframe", 0.4)
	var dodged := bool(dodging_player.receive_enemy_projectile(9.0, "thunder", "paralyze", 0.8, "qa_enemy_dodge"))
	await get_tree().process_frame
	_assert_true(not dodged, "Enemy projectile should not apply hit during dodge iframe")
	_assert_true(not dodging_player.get_node("StatusComponent").is_paralyzed(), "Dodged enemy projectile should not apply status")
	_cleanup_node(dodging_player)


func _events_seen_except(excluded_event_id: String, seen_count: int) -> Dictionary:
	var seen := {}
	for row in CsvLoader.load_rows("res://data/events/events.csv"):
		var event_id := str(row.get("id", ""))
		if event_id.is_empty() or event_id == excluded_event_id:
			continue
		seen[event_id] = seen_count
	return seen


func _spawn_fake_enemy(pos: Vector2, elite := false) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	enemy.elite = elite
	enemy.global_position = pos
	add_child(enemy)
	enemy.add_to_group("enemy")
	_temp_nodes.append(enemy)
	return enemy


func _cleanup_temp_nodes() -> void:
	for node in _temp_nodes.duplicate():
		if is_instance_valid(node):
			_cleanup_node(node)
	_temp_nodes.clear()


func _cleanup_node(node: Variant) -> void:
	if node == null:
		return
	_temp_nodes.erase(node)
	if is_instance_valid(node):
		if node.is_in_group("enemy"):
			node.remove_from_group("enemy")
		node.queue_free()


func _restore_profile() -> void:
	if _profile_snapshot.is_empty():
		return
	SaveManager.profile = _profile_snapshot.duplicate(true)
	SaveManager.save_profile()


func _has_hidden_chain_event(chain_id: String) -> bool:
	for event in _hidden_chain_events:
		if str(event.get("chain_id", "")) == chain_id:
			return true
	return false


func _has_feedback_anchor(anchor_id: String) -> bool:
	for event in _feedback_events:
		if str(event.get("anchor_id", "")) == anchor_id:
			return true
	return false


func _contains_pet_feedback(fragment: String) -> bool:
	for line in _pet_feedback:
		if line.contains(fragment):
			return true
	return false


func _latest_boss_phase_index() -> int:
	if _boss_health_events.is_empty():
		return -1
	return int(_boss_health_events.back().get("phase_index", -1))


func _latest_damage_is_zero() -> bool:
	if _damage_events.is_empty():
		return false
	return _float_eq(float(_damage_events.back().get("final_damage", -1.0)), 0.0)


func _float_eq(a: float, b: float, eps := EPS) -> bool:
	return absf(a - b) <= eps


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, str(expected), str(actual)])


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
