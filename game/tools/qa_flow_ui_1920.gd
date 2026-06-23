extends Node

const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const TalentSelector = preload("res://systems/realm/talent_selector.gd")
const WeaponModCatalog = preload("res://systems/equipment/weapon_mod_catalog.gd")
const RUN_SETUP_SCENE := preload("res://scenes/ui/run_setup_panel.tscn")
const EVENT_PANEL_SCENE := preload("res://scenes/ui/event_panel.tscn")
const RUN_RESULT_SCENE := preload("res://scenes/ui/run_result_panel.tscn")
const PAUSE_OVERLAY_SCENE := preload("res://scenes/ui/pause_overlay.tscn")
const PATH_CHOICE_SCENE := preload("res://scenes/ui/path_choice_panel.tscn")
const SHOP_PANEL_SCENE := preload("res://scenes/ui/shop_panel.tscn")
const DEATH_MOMENT_SCENE := preload("res://scenes/ui/death_moment_overlay.tscn")
const LEGACY_SELECT_SCENE := preload("res://scenes/ui/legacy_select_panel.tscn")
const META_UPGRADE_SCENE := preload("res://scenes/ui/meta_upgrade_panel.tscn")
const BREAKTHROUGH_SCENE := preload("res://scenes/ui/breakthrough_panel.tscn")
const WEAPON_MOD_SCENE := preload("res://scenes/ui/weapon_mod_choice_panel.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const JADE_CODEX_OVERLAY_SCRIPT := preload("res://ui/components/hud_jade_codex_overlay.gd")

const TARGET_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR := "res://../output/visual_qa"
const REPORT_PATH := "res://../output/visual_qa/flow_ui_1920_report.txt"

const SHOTS := {
	"run_setup": "res://../output/visual_qa/flow_run_setup_1920.png",
	"run_setup_heart_demon": "res://../output/visual_qa/flow_run_setup_heart_demon_1920.png",
	"event_panel": "res://../output/visual_qa/flow_event_panel_1920.png",
	"event_regular": "res://../output/visual_qa/flow_event_regular_1920.png",
	"event_weather": "res://../output/visual_qa/flow_event_weather_1920.png",
	"event_karma": "res://../output/visual_qa/flow_event_karma_1920.png",
	"run_result": "res://../output/visual_qa/flow_run_result_1920.png",
	"run_result_failure": "res://../output/visual_qa/flow_run_result_failure_1920.png",
	"pause_overlay": "res://../output/visual_qa/flow_pause_overlay_1920.png",
	"pause_confirm": "res://../output/visual_qa/flow_pause_confirm_1920.png",
	"path_choice": "res://../output/visual_qa/flow_path_choice_1920.png",
	"shop_panel": "res://../output/visual_qa/flow_shop_panel_1920.png",
	"shop_full_slots": "res://../output/visual_qa/flow_shop_full_slots_1920.png",
	"death_moment": "res://../output/visual_qa/flow_death_moment_1920.png",
	"legacy_select": "res://../output/visual_qa/flow_legacy_select_1920.png",
	"meta_upgrade": "res://../output/visual_qa/flow_meta_upgrade_1920.png",
	"breakthrough": "res://../output/visual_qa/flow_breakthrough_1920.png",
	"weapon_mod_choice": "res://../output/visual_qa/flow_weapon_mod_choice_1920.png",
	"jade_codex": "res://../output/visual_qa/flow_jade_codex_1920.png",
}

var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _viewport: SubViewport


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	_report("Flow UI visual QA 1920x1080")
	_report("=============================")
	_prepare_output_dir()
	_prepare_viewport()
	await _capture_run_setup()
	await _capture_run_setup_heart_demon()
	await _capture_event_panel()
	await _capture_event_regular()
	await _capture_event_weather()
	await _capture_event_karma()
	await _capture_run_result()
	await _capture_run_result_failure()
	await _capture_pause_overlay()
	await _capture_pause_confirm()
	await _capture_path_choice()
	await _capture_shop_panel()
	await _capture_shop_full_slots()
	await _capture_death_moment()
	await _capture_legacy_select()
	await _capture_meta_upgrade()
	await _capture_breakthrough()
	await _capture_weapon_mod_choice()
	await _capture_jade_codex()
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		_write_report(1)
		return 1
	for key in SHOTS.keys():
		_report("%s screenshot: %s" % [str(key), ProjectSettings.globalize_path(str(SHOTS[key]))])
	_report("Flow UI visual QA passed")
	_write_report(0)
	return 0


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _prepare_viewport() -> void:
	get_window().size = TARGET_SIZE
	get_tree().root.content_scale_size = TARGET_SIZE
	_viewport = SubViewport.new()
	_viewport.name = "FlowUIViewport"
	_viewport.size = TARGET_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)


func _capture_run_setup() -> void:
	_clear_viewport()
	_prepare_run_setup_state()
	var setup := RUN_SETUP_SCENE.instantiate()
	setup.name = "QAFlowRunSetupPanel"
	_viewport.add_child(setup)
	for _i in range(18):
		await get_tree().process_frame
	_check_run_setup_contracts(setup)
	_capture_and_check("run_setup", str(SHOTS["run_setup"]), Rect2(Vector2(420, 130), Vector2(1080, 820)))


func _capture_run_setup_heart_demon() -> void:
	_clear_viewport()
	_prepare_run_setup_heart_demon_state()
	var setup := RUN_SETUP_SCENE.instantiate()
	setup.name = "QAFlowRunSetupHeartDemon"
	_viewport.add_child(setup)
	for _i in range(18):
		await get_tree().process_frame
	var heart_demon := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/HeartDemonCheck") as Button
	if heart_demon != null:
		heart_demon.set_pressed_no_signal(true)
		if setup.has_method("_apply_heart_demon_button_state"):
			setup.call("_apply_heart_demon_button_state")
	var random_seed := setup.get_node_or_null("Panel/Margin/Root/Footer/SeedRow/RandomSeedButton") as Button
	if random_seed != null:
		random_seed.pressed.emit()
	for _i in range(12):
		await get_tree().process_frame
	_check_run_setup_contracts(setup)
	_check_run_setup_heart_demon_contracts(setup)
	_capture_and_check("run_setup_heart_demon", str(SHOTS["run_setup_heart_demon"]), Rect2(Vector2(420, 130), Vector2(1080, 820)))


func _capture_event_panel() -> void:
	_clear_viewport()
	var event_panel := EVENT_PANEL_SCENE.instantiate()
	event_panel.name = "QAFlowEventPanel"
	_viewport.add_child(event_panel)
	await get_tree().process_frame
	EventBus.event_requested.emit(_sample_event(), _sample_event_choices())
	for _i in range(18):
		await get_tree().process_frame
	_check_event_contracts(event_panel, "heart_demon")
	_capture_and_check("event_panel", str(SHOTS["event_panel"]), Rect2(Vector2(460, 170), Vector2(1000, 740)))


func _capture_event_regular() -> void:
	await _capture_event_variant("event_regular", _sample_regular_event(), _sample_regular_event_choices(), "regular")


func _capture_event_weather() -> void:
	await _capture_event_variant("event_weather", _sample_weather_event(), _sample_weather_event_choices(), "weather")


func _capture_event_karma() -> void:
	await _capture_event_variant("event_karma", _sample_karma_event(), _sample_karma_event_choices(), "karma")


func _capture_event_variant(label: String, event: Dictionary, choices: Array, expected_category: String) -> void:
	_clear_viewport()
	var event_panel := EVENT_PANEL_SCENE.instantiate()
	event_panel.name = "QAFlow%s" % label.capitalize().replace("_", "")
	_viewport.add_child(event_panel)
	await get_tree().process_frame
	EventBus.event_requested.emit(event, choices)
	for _i in range(18):
		await get_tree().process_frame
	_check_event_contracts(event_panel, expected_category)
	_capture_and_check(label, str(SHOTS[label]), Rect2(Vector2(460, 170), Vector2(1000, 740)))


func _capture_run_result() -> void:
	_clear_viewport()
	_prepare_run_result_state()
	var result_panel := RUN_RESULT_SCENE.instantiate()
	result_panel.name = "QAFlowRunResultPanel"
	_viewport.add_child(result_panel)
	await get_tree().process_frame
	EventBus.run_completed.emit(true)
	for _i in range(18):
		await get_tree().process_frame
	_check_run_result_contracts(result_panel, true)
	_capture_and_check("run_result", str(SHOTS["run_result"]), Rect2(Vector2(530, 210), Vector2(860, 640)))


func _capture_run_result_failure() -> void:
	_clear_viewport()
	_prepare_run_result_failure_state()
	var result_panel := RUN_RESULT_SCENE.instantiate()
	result_panel.name = "QAFlowRunResultFailure"
	_viewport.add_child(result_panel)
	await get_tree().process_frame
	EventBus.run_completed.emit(false)
	for _i in range(18):
		await get_tree().process_frame
	_check_run_result_contracts(result_panel, false)
	_capture_and_check("run_result_failure", str(SHOTS["run_result_failure"]), Rect2(Vector2(500, 170), Vector2(920, 740)))


func _capture_pause_overlay() -> void:
	_clear_viewport()
	_prepare_pause_state()
	var pause_overlay := PAUSE_OVERLAY_SCENE.instantiate()
	pause_overlay.name = "QAFlowPauseOverlay"
	_viewport.add_child(pause_overlay)
	await get_tree().process_frame
	if pause_overlay.has_method("set_visible_pause"):
		pause_overlay.call("set_visible_pause", true)
	for _i in range(18):
		await get_tree().process_frame
	_check_pause_overlay_contracts(pause_overlay)
	_capture_and_check("pause_overlay", str(SHOTS["pause_overlay"]), Rect2(Vector2(640, 180), Vector2(640, 720)))


func _capture_pause_confirm() -> void:
	_clear_viewport()
	_prepare_pause_state()
	var pause_overlay := PAUSE_OVERLAY_SCENE.instantiate()
	pause_overlay.name = "QAFlowPauseConfirm"
	_viewport.add_child(pause_overlay)
	await get_tree().process_frame
	if pause_overlay.has_method("set_visible_pause"):
		pause_overlay.call("set_visible_pause", true)
	for _i in range(12):
		await get_tree().process_frame
	var end_button := pause_overlay.get_node_or_null("Panel/Margin/VBox/EndRunButton") as Button
	if end_button != null:
		end_button.pressed.emit()
	for _i in range(12):
		await get_tree().process_frame
	_check_pause_confirm_contracts(pause_overlay)
	_capture_and_check("pause_confirm", str(SHOTS["pause_confirm"]), Rect2(Vector2(640, 180), Vector2(640, 720)))
	var cancel := pause_overlay.get_node_or_null("Panel/Margin/VBox/ConfirmBox/ConfirmRow/CancelRestartButton") as Button
	if cancel != null:
		cancel.pressed.emit()
	for _i in range(6):
		await get_tree().process_frame
	var confirm_box := pause_overlay.get_node_or_null("Panel/Margin/VBox/ConfirmBox") as VBoxContainer
	_require(confirm_box != null and not confirm_box.visible, "Pause confirm cancel should hide ConfirmBox")


func _capture_path_choice() -> void:
	_clear_viewport()
	var path_choice := PATH_CHOICE_SCENE.instantiate()
	path_choice.name = "QAFlowPathChoicePanel"
	_viewport.add_child(path_choice)
	await get_tree().process_frame
	EventBus.path_choice_requested.emit(_sample_path_branches())
	for _i in range(18):
		await get_tree().process_frame
	_check_path_choice_contracts(path_choice)
	_capture_and_check("path_choice", str(SHOTS["path_choice"]), Rect2(Vector2(260, 250), Vector2(1400, 560)))


func _capture_shop_panel() -> void:
	_clear_viewport()
	_prepare_shop_state()
	_add_qa_player(false)
	var shop := SHOP_PANEL_SCENE.instantiate()
	shop.name = "QAFlowShopPanel"
	_viewport.add_child(shop)
	await get_tree().process_frame
	EventBus.shop_requested.emit(_sample_shop_offers(), {"gold": RunContext.gold})
	for _i in range(18):
		await get_tree().process_frame
	_check_shop_panel_contracts(shop, false)
	_capture_and_check("shop_panel", str(SHOTS["shop_panel"]), Rect2(Vector2(620, 210), Vector2(680, 680)))


func _capture_shop_full_slots() -> void:
	_clear_viewport()
	_prepare_shop_state()
	var player := _add_qa_player(true)
	var shop := SHOP_PANEL_SCENE.instantiate()
	shop.name = "QAFlowShopFullSlots"
	_viewport.add_child(shop)
	await get_tree().process_frame
	_fill_qa_player_affixes(player)
	var offers := _sample_shop_offers()
	EventBus.shop_requested.emit(offers, {"gold": RunContext.gold})
	for _i in range(8):
		await get_tree().process_frame
	var first_affix_button := _first_shop_buy_button(shop, "affix")
	if first_affix_button != null:
		first_affix_button.pressed.emit()
	for _i in range(18):
		await get_tree().process_frame
	_check_shop_panel_contracts(shop, true)
	_require(player != null, "Shop full-slot QA player missing")
	_capture_and_check("shop_full_slots", str(SHOTS["shop_full_slots"]), Rect2(Vector2(620, 190), Vector2(680, 720)))


func _capture_death_moment() -> void:
	_clear_viewport()
	_prepare_death_state()
	var player := _add_qa_player(false)
	EntityCache.invalidate_player()
	var overlay := DEATH_MOMENT_SCENE.instantiate()
	overlay.name = "QAFlowDeathMoment"
	_viewport.add_child(overlay)
	await get_tree().process_frame
	EventBus.death_moment_requested.emit(_sample_death_summary())
	await _wait_for_death_moment_capture_phase(overlay)
	_check_death_moment_contracts(overlay)
	_require(player != null, "Death moment QA player missing")
	_capture_and_check("death_moment", str(SHOTS["death_moment"]), Rect2(Vector2(520, 260), Vector2(880, 600)), 0.08)
	Engine.time_scale = 1.0
	get_tree().paused = false


func _capture_legacy_select() -> void:
	_clear_viewport()
	_prepare_death_state()
	var legacy := LEGACY_SELECT_SCENE.instantiate()
	legacy.name = "QAFlowLegacySelect"
	_viewport.add_child(legacy)
	await get_tree().process_frame
	EventBus.legacy_choice_requested.emit(_sample_legacy_affixes())
	for _i in range(18):
		await get_tree().process_frame
	_check_legacy_select_contracts(legacy)
	_capture_and_check("legacy_select", str(SHOTS["legacy_select"]), Rect2(Vector2(480, 180), Vector2(960, 760)))


func _capture_meta_upgrade() -> void:
	_clear_viewport()
	_prepare_meta_upgrade_state()
	var meta := META_UPGRADE_SCENE.instantiate()
	meta.name = "QAFlowMetaUpgrade"
	_viewport.add_child(meta)
	await get_tree().process_frame
	if meta.has_method("open_panel"):
		meta.call("open_panel")
	for _i in range(18):
		await get_tree().process_frame
	_check_meta_upgrade_contracts(meta)
	_capture_and_check("meta_upgrade", str(SHOTS["meta_upgrade"]), Rect2(Vector2(520, 230), Vector2(880, 620)))
	get_tree().paused = false
	RunContext.ui_blocking = false


func _capture_breakthrough() -> void:
	_clear_viewport()
	_prepare_breakthrough_state()
	var breakthrough := BREAKTHROUGH_SCENE.instantiate()
	breakthrough.name = "QAFlowBreakthroughPanel"
	_viewport.add_child(breakthrough)
	await get_tree().process_frame
	EventBus.breakthrough_requested.emit(_sample_breakthrough_offers(), {
		"realm": RunContext.realm_name(),
		"slots_before": 8,
		"slots_after": 10,
	})
	for _i in range(24):
		await get_tree().process_frame
	_check_breakthrough_contracts(breakthrough)
	_capture_and_check("breakthrough", str(SHOTS["breakthrough"]), Rect2(Vector2(520, 230), Vector2(880, 620)))
	get_tree().paused = false
	RunContext.ui_blocking = false


func _capture_weapon_mod_choice() -> void:
	_clear_viewport()
	_prepare_weapon_mod_state()
	var weapon_mod := WEAPON_MOD_SCENE.instantiate()
	weapon_mod.name = "QAFlowWeaponModChoice"
	_viewport.add_child(weapon_mod)
	await get_tree().process_frame
	EventBus.weapon_mod_choice_requested.emit(_sample_weapon_mod_offers(), _sample_weapon_mod_context())
	for _i in range(18):
		await get_tree().process_frame
	_check_weapon_mod_choice_contracts(weapon_mod)
	_capture_and_check("weapon_mod_choice", str(SHOTS["weapon_mod_choice"]), Rect2(Vector2(380, 210), Vector2(1160, 660)))
	get_tree().paused = false
	RunContext.ui_blocking = false


func _capture_jade_codex() -> void:
	_clear_viewport()
	_prepare_pause_state()
	var codex := JADE_CODEX_OVERLAY_SCRIPT.new()
	codex.name = "QAFlowJadeCodexOverlay"
	codex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(codex)
	await get_tree().process_frame
	codex.set_snapshot(_sample_jade_codex_snapshot())
	codex.open()
	for _i in range(18):
		await get_tree().process_frame
	_check_jade_codex_contracts(codex)
	_capture_and_check("jade_codex", str(SHOTS["jade_codex"]), Rect2(Vector2(70, 70), Vector2(1780, 920)))
	get_tree().paused = false
	RunContext.ui_blocking = false


func _clear_viewport() -> void:
	if _viewport == null:
		return
	for child in _viewport.get_children():
		child.queue_free()


func _prepare_run_setup_state() -> void:
	RunContext.seed_value = 0
	RunContext.run_active = false
	RunContext.gold = 240
	RunContext.realm_level = 1
	RunContext.affix_slot_cap = 5
	RunContext.ui_blocking = true
	SaveManager.profile["heart_demon_shards"] = 0
	SaveManager.profile["last_run_seed"] = 0


func _prepare_run_setup_heart_demon_state() -> void:
	_prepare_run_setup_state()
	SaveManager.profile["heart_demon_shards"] = 4
	SaveManager.profile["last_run_seed"] = 11235813
	SaveManager.profile["awakened_dao_traditions"] = ["雷火法修", "玄冰剑修"]


func _prepare_run_result_state() -> void:
	if RunContext.has_method("reset_run_recording"):
		RunContext.call("reset_run_recording")
	RunContext.current_run_id = "qa_result_victory_%d" % Time.get_ticks_msec()
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.current_stage = 5
	RunContext.current_room = 4
	RunContext.rooms_cleared = 18
	RunContext.gold = 368
	RunContext.realm_level = 5
	RunContext.heart_demon_shards_earned = 2
	RunContext.dao_tradition_awakened_this_run = "雷火法修"


func _prepare_run_result_failure_state() -> void:
	if RunContext.has_method("reset_run_recording"):
		RunContext.call("reset_run_recording")
	RunContext.current_run_id = "qa_result_failure_%d" % Time.get_ticks_msec()
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.current_stage = 3
	RunContext.current_room = 2
	RunContext.rooms_cleared = 11
	RunContext.gold = 126
	RunContext.realm_level = 4
	RunContext.heart_demon_shards_earned = 1
	RunContext.dao_tradition_awakened_this_run = ""
	RunContext.peak_dao_momentum = 86.0
	RunContext.dao_momentum_max = 100.0
	RunContext.peak_combo_count = 73
	RunContext.last_boss_hp_ratio = 0.11
	RunContext.last_boss_name = "雷劫化身"
	RunContext.record_horde_progress(17, 20)
	RunContext.build_death_summary()


func _prepare_pause_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.training_mode = false
	RunContext.gold = 360
	RunContext.realm_level = 4
	SaveManager.set_display_setting("show_enemy_hp", true)
	SaveManager.set_display_setting("show_damage_numbers", true)
	SaveManager.set_display_setting("reduce_motion", false)
	SaveManager.set_display_setting("auto_aim", true)
	SaveManager.set_display_setting("auto_attack", true)
	SaveManager.set_sprite_style("normal")


func _prepare_shop_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.gold = 240
	RunContext.realm_level = 3
	RunContext.affix_slot_cap = 5
	RunContext.ui_blocking = true


func _prepare_death_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.gold = 126
	RunContext.realm_level = 4
	RunContext.rooms_cleared = 11
	RunContext.current_stage = 3
	RunContext.current_room = 2
	RunContext.ui_blocking = true
	get_tree().paused = false
	Engine.time_scale = 1.0


func _prepare_meta_upgrade_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = false
	RunContext.ui_blocking = false
	get_tree().paused = false
	SaveManager.profile["reincarnation_points"] = 140
	SaveManager.profile["meta_levels"] = {
		"vitality": 2,
		"fortune": 1,
		"insight": 0,
	}


func _prepare_breakthrough_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.gold = 240
	RunContext.realm_level = 3
	RunContext.affix_slot_cap = 8
	RunContext.ui_blocking = true
	get_tree().paused = false


func _prepare_weapon_mod_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.gold = 240
	RunContext.realm_level = 3
	RunContext.weapon_mods = ["tempered_edge"]
	RunContext.ui_blocking = true
	get_tree().paused = false


func _add_qa_player(fill_affixes: bool) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = "QAFlowShopPlayer"
	player.position = Vector2(-900, -900)
	_viewport.add_child(player)
	return player


func _fill_qa_player_affixes(player: Node) -> void:
	if player == null:
		return
	var holder := player.get_node_or_null("AffixHolder")
	if holder == null:
		return
	for id in ["F001", "F003", "F008", "F009", "F010"]:
		var tag = ConfigRegistry.compile_affix(id)
		if tag != null:
			holder.add_affix(tag)


func _first_shop_buy_button(shop: Node, kind: String) -> Button:
	var buttons := shop.get_node_or_null("Panel/Margin/VBox/ContentScroll/Buttons") as VBoxContainer
	if buttons == null:
		return null
	var offers := _sample_shop_offers()
	var target_index := -1
	for i in offers.size():
		if str((offers[i] as Dictionary).get("kind", "")) == kind:
			target_index = i
			break
	if target_index < 0:
		return null
	var row_index := 0
	for row in buttons.get_children():
		var card := row as PanelContainer
		if card == null:
			continue
		if row_index == target_index:
			return card.get_node_or_null("OfferMargin/OfferRow/OfferBuyButton") as Button
		row_index += 1
	return null


func _wait_for_death_moment_capture_phase(overlay: Node) -> void:
	for _i in range(300):
		await get_tree().process_frame
		if overlay == null or not overlay.visible:
			_fail("Death moment overlay closed before capture phase")
			return
		var phase := overlay.get_node_or_null("Phase") as Label
		var body := overlay.get_node_or_null("BodyFall") as Control
		var totem := overlay.get_node_or_null("Totem") as Control
		var player_echo := overlay.get_node_or_null("BodyFall/PlayerEcho") as TextureRect
		var soul_seal := overlay.get_node_or_null("Totem/SoulSeal") as TextureRect
		var phase_text := phase.text if phase != null else ""
		var phase_ready := phase_text == "魂魄离身" or phase_text == "遗言留世"
		var texture_ready := player_echo != null and player_echo.texture != null and soul_seal != null and soul_seal.texture != null
		var alpha_ready := body != null and body.modulate.a > 0.18 and totem != null and totem.modulate.a > 0.25
		if phase_ready and texture_ready and alpha_ready:
			return
	_fail("Death moment did not reach textured capture phase")


func _sample_event() -> Dictionary:
	return {
		"id": "M99",
		"title": "心魔照影",
		"category": "heart_demon",
		"body": "一面玄墨镜浮在雷火之间，映出上一世未竟的执念。你可以借它立誓，换取更锋利的机缘，也可以稳住道心，保留下一次选择。",
	}


func _sample_event_choices() -> Array:
	return [
		{
			"label": "接纳心魔 · 下次机缘品质上浮",
			"karma": "heart_demon",
		},
		{
			"label": "以雷火镇心 · 获得灵石与道势",
			"karma": "dao_heart",
		},
		{
			"label": "观而不取 · 保持当前构筑",
			"karma": "mercy",
		},
	]


func _sample_regular_event() -> Dictionary:
	return {
		"id": "E01",
		"title": "神秘老者",
		"category": "regular",
		"body": "白发老者递来一盏灵茶，杯沿有冷玉光纹。你能察觉其中灵力温和，却也听见远处魔潮正在逼近。",
	}


func _sample_regular_event_choices() -> Array:
	return [
		{"label": "接茶 · 灵石入袋", "effect": "gold:30"},
		{"label": "求教 · 回气调息", "effect": "heal_pct:0.2"},
		{"label": "拱手谢绝", "effect": "none"},
	]


func _sample_weather_event() -> Dictionary:
	return {
		"id": "E07",
		"title": "雷云悟道",
		"category": "weather",
		"weather": "thunder",
		"body": "雷云压低，青白电纹在墨色天幕里游走。若引雷入体，下一战的雷系机缘会更锋利。",
	}


func _sample_weather_event_choices() -> Array:
	return [
		{"label": "引雷入体 · 雷系机缘", "effect": "bias:thunder"},
		{"label": "避退取石 · 稳住节奏", "effect": "gold:20"},
		{"label": "静观云势", "effect": "none"},
	]


func _sample_karma_event() -> Dictionary:
	return {
		"id": "E15",
		"title": "路遇争执",
		"category": "karma",
		"body": "两名修士在断桥前争夺灵石。你可以调解因果，也可以趁乱夺取，或旁观这场业力落定。",
	}


func _sample_karma_event_choices() -> Array:
	return [
		{"label": "调解争执 · 善缘浮现", "effect": "gold:10;karma:good"},
		{"label": "趁乱夺石 · 恶业入账", "effect": "gold:40;karma:evil"},
		{"label": "尽取藏石 · 贪念成痕", "effect": "gold:60;karma:greed"},
	]


func _sample_path_branches() -> Array:
	return [
		{
			"id": "combat",
			"label": "魔潮续战",
			"desc": "继续压进劫潮，获得一次常规词条与少量灵石。",
		},
		{
			"id": "rest",
			"label": "灵泉调息",
			"desc": "回气养伤，稳住道心，降低下一战风险。",
		},
		{
			"id": "shop",
			"label": "玄市换宝",
			"desc": "以灵石换取法宝、宠契或一次命运重掷。",
		},
		{
			"id": "event",
			"label": "因果奇遇",
			"desc": "触碰未知因果，可能得到稀有机缘，也可能背负代价。",
		},
		{
			"id": "elite",
			"label": "精英劫影",
			"desc": "挑战异化强敌，危险更高，奖励品质也更锋利。",
		},
	]


func _sample_shop_offers() -> Array:
	var fire_tag = ConfigRegistry.compile_affix("F001")
	var thunder_tag = ConfigRegistry.compile_affix("F009")
	return [
		{
			"kind": "heal",
			"cost": 18,
			"label": "调息丹 · 18 灵石",
			"desc": "恢复 35% 真元，稳住下一战前的气息。",
		},
		{
			"kind": "affix",
			"cost": 30,
			"label": "机缘词条 · 30 灵石",
			"desc": "%s [%s]" % [fire_tag.name, fire_tag.description],
			"tag": fire_tag,
		},
		{
			"kind": "rare_affix",
			"cost": 55,
			"label": "仙品机缘 · 55 灵石",
			"desc": "%s [%s]" % [thunder_tag.name, thunder_tag.description],
			"tag": thunder_tag,
		},
	]


func _sample_death_summary() -> Dictionary:
	return {
		"title": "本局遗憾 · 雷劫未渡",
		"detail": "你在第 11 间房前被劫火截断气脉，雷火法修只差一缕道势便可成型。",
		"line": "此身虽灭，道痕仍入轮回。",
	}


func _sample_legacy_affixes() -> Array:
	return [
		ConfigRegistry.compile_affix("F001"),
		ConfigRegistry.compile_affix("F009"),
		ConfigRegistry.compile_affix("F011"),
	]


func _sample_weapon_mod_offers() -> Array:
	return [
		WeaponModCatalog.get_mod("fire_inscription"),
		WeaponModCatalog.get_mod("thunder_wood_inscription"),
		WeaponModCatalog.get_mod("soul_lantern_core"),
	]


func _sample_breakthrough_offers() -> Array:
	return [
		TalentSelector.get_talent("T301"),
		TalentSelector.get_talent("T302"),
		TalentSelector.get_talent("T303"),
	]


func _sample_weapon_mod_context() -> Dictionary:
	return {
		"source": "Boss传承 · 本命器祭炼",
		"stage_index": 3,
		"room_type": "boss",
		"path_hint": "banner",
		"element_hint": "thunder",
		"focus_tags": ["banner", "soul", "core", "damage"],
	}


func _sample_jade_codex_snapshot() -> Dictionary:
	return {
		"realm": "金丹",
		"build": "雷火法修 · 劫焰连爆",
		"dao": "雷火法修 4/5 · 缺 雷体",
		"pet": "火萤 · 护主就绪",
		"artifact": "玄玉葫 · 器灵醒",
		"stats": "房间 11 · 击杀 286 · 最高连击 47",
		"strategy": "自动普攻 开 / 自动护体 开 / 灵宠自动 开 / 器灵半自动",
		"affixes": PackedStringArray(["烈焰符骨", "雷池引", "剑阵回响", "燃魂余烬", "劫火反噬"]),
		"sealed_affixes": PackedStringArray(["旧怨封存"]),
		"slot_summary": {"core_max": 3, "active_used": 5, "active_max": 5},
		"dao_progress": {
			"name": "雷火法修",
			"matched": 4,
			"total": 5,
			"progress": 0.8,
			"missing_slots": ["雷体"],
		},
		"dao_detail": {
			"title": "雷火词条已入命，补齐雷体后进入觉醒链。",
			"description": "奖励页优先选择雷体、护体与短冷却触发类词条。",
			"passive_dsl": "雷击命中燃烧目标时，追加一次小范围劫火。",
		},
		"combo_display": {"name": "劫焰连爆", "matched": ["火", "雷", "术"], "total": 4, "missing": ["体"]},
		"pet_state": {"acquired": true, "ready": true, "name": "火萤", "detail": "每隔数秒协同点燃近身敌人，护主时留下一圈火萤屏障。", "cooldown_text": "就绪"},
		"artifact_state": {"name": "玄玉葫", "state_text": "器灵醒", "charge_pct": 0.82, "current": 82, "maximum": 100, "hint": "击杀精英或触发雷火共鸣时额外充能。"},
		"weapon_mods": PackedStringArray(["葫中雷火", "纳灵回响", "器灵护主"]),
		"lifetime_items": [
			{"label": "轮回次数", "value": "18"},
			{"label": "最高境界", "value": "元婴"},
			{"label": "累计击杀", "value": "4832"},
			{"label": "隐藏连锁", "value": "7"},
		],
		"last_life": {"victory": false, "seed": 786433, "rooms_cleared": 11, "best_combo": 47, "dao_peak": 82, "dao_max": 100, "death_summary": {"line": "差一缕雷体便可成局。"}},
		"build_record": {"path_name": "雷火法修", "weapon_name": "玄玉葫", "weapon_mods": ["葫中雷火", "器灵护主"]},
		"highlight": {"title": "雷火三连引爆"},
		"lifetime_summary": "前世碑：18 次轮回，最高元婴，雷火流派最稳定。",
		"strategy_items": [
			{"name": "自动普攻", "enabled": true, "detail": "保持最近目标压力", "accent": UiTokens.ACCENT_JADE},
			{"name": "自动护体", "enabled": true, "detail": "低血量时优先保命", "accent": UiTokens.ACCENT_GOLD},
			{"name": "灵宠协同", "enabled": true, "detail": "火萤就绪后自动护主", "accent": UiTokens.ELEM_FIRE},
			{"name": "器灵触发", "enabled": false, "detail": "等待手动归一", "accent": UiTokens.ELEM_CHAOS},
		],
		"weather": "雷雨 · 可借势",
	}


func _check_run_setup_contracts(setup: Node) -> void:
	var panel := setup.get_node_or_null("Panel") as PanelContainer
	var backdrop := setup.get_node_or_null("Backdrop") as TextureRect
	var dimmer := setup.get_node_or_null("Dimmer") as TextureRect
	var start_button := setup.get_node_or_null("Panel/Margin/Root/Footer/ButtonRow/StartButton") as Button
	var hearts_box := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/Hearts") as HBoxContainer
	var run_preview := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/RunPreview") as PanelContainer
	var preview_icon := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/RunPreview/Margin/Row/PreviewSealWrap/PreviewSealIcon") as TextureRect
	var preview_stats := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/RunPreview/Margin/Row/PreviewText/PreviewStats") as HBoxContainer
	var seed_input := setup.get_node_or_null("Panel/Margin/Root/Footer/SeedRow/SeedInput") as LineEdit
	var heart_demon := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/HeartDemonCheck") as Button
	_require(panel != null and panel.visible, "RunSetup panel is not visible")
	_require(backdrop != null and backdrop.texture != null, "RunSetup backdrop texture missing")
	_require(dimmer != null and dimmer.texture != null and dimmer.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "RunSetup should use shared image2 modal veil")
	_require(start_button != null and start_button.text.length() > 2 and start_button.visible, "RunSetup start button missing")
	_require(seed_input != null, "RunSetup seed input missing")
	if seed_input != null:
		var seed_style := seed_input.get_theme_stylebox("normal")
		_require(seed_style is StyleBoxTexture and (seed_style as StyleBoxTexture).texture != null, "RunSetup seed input should use image2 asset style")
	_require(hearts_box != null and hearts_box.get_child_count() >= 3, "RunSetup Dao-heart cards missing")
	_require(run_preview != null and run_preview.visible and run_preview.custom_minimum_size.y >= 120.0, "RunSetup should include a visible run preview panel")
	_require(preview_icon != null and preview_icon.texture != null, "RunSetup run preview should use selected Dao-heart image2 icon")
	_require(preview_stats != null and preview_stats.get_child_count() >= 3, "RunSetup run preview should include three summary stats")
	_require(heart_demon != null and heart_demon.toggle_mode, "RunSetup heart-demon option should be asset toggle Button")
	_require(_count_native_check_buttons(setup) == 0, "RunSetup should not use Godot-native CheckButton controls")
	_require(_count_path_buttons_with_icons(setup) >= 3, "RunSetup path picker should use path icon asset buttons")


func _check_run_setup_heart_demon_contracts(setup: Node) -> void:
	var seed_input := setup.get_node_or_null("Panel/Margin/Root/Footer/SeedRow/SeedInput") as LineEdit
	var heart_demon := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/HeartDemonCheck") as Button
	var shard_label := setup.get_node_or_null("Panel/Margin/Root/Scroll/VBox/ShardLabel") as Label
	_require(heart_demon != null and heart_demon.visible and not heart_demon.disabled, "RunSetup heart-demon boost should be visible when shards >= 3")
	_require(heart_demon != null and heart_demon.button_pressed and heart_demon.text.begins_with("开"), "RunSetup heart-demon boost should show enabled state")
	_require(seed_input != null and seed_input.placeholder_text.contains("上局 11235813"), "RunSetup seed placeholder should show last run seed")
	_require(seed_input != null and seed_input.text.is_valid_int(), "RunSetup random seed button should fill a numeric seed")
	_require(shard_label != null and shard_label.text.contains("4/3"), "RunSetup shard label should reflect QA heart-demon shards")


func _check_event_contracts(event_panel: Node, expected_category: String = "heart_demon") -> void:
	var panel := event_panel.get_node_or_null("Panel") as PanelContainer
	_check_modal_veil_contract(event_panel, "EventPanel", 0.76, 0.86)
	var art_frame := event_panel.get_node_or_null("Panel/Margin/VBox/ArtFrame") as Control
	var art := event_panel.get_node_or_null("Panel/Margin/VBox/ArtFrame/ArtBanner") as TextureRect
	var art_icon_backing := event_panel.get_node_or_null("Panel/Margin/VBox/ArtFrame/ArtIconBacking") as TextureRect
	var art_icon := event_panel.get_node_or_null("Panel/Margin/VBox/ArtFrame/ArtIcon") as TextureRect
	var title := event_panel.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var body := event_panel.get_node_or_null("Panel/Margin/VBox/Body") as Label
	var buttons := event_panel.get_node_or_null("Panel/Margin/VBox/Buttons") as VBoxContainer
	_require(panel != null and panel.visible, "Event panel is not visible")
	_require(art != null and art.texture != null, "Event illustration missing")
	_require(title != null and title.text.length() >= 4, "Event title missing")
	_require(body != null and body.text.length() >= 20, "Event body missing")
	_require(buttons != null and buttons.get_child_count() >= 3, "Event choices missing")
	_require(art_frame != null and art_frame.custom_minimum_size.y >= 150.0, "Event art frame missing")
	_require(art_icon != null and art_icon.texture != null, "Event art should include semantic icon overlay")
	_require(art_icon_backing != null and art_icon_backing.texture != null, "Event art icon should sit on an image2 dark backing")
	if art_frame != null and body != null and buttons != null:
		var art_rect := Rect2(art_frame.global_position, art_frame.size)
		var body_rect := Rect2(body.global_position, body.size)
		var buttons_rect := Rect2(buttons.global_position, buttons.size)
		_require(art_frame.custom_minimum_size.y >= 210.0 and art_frame.custom_minimum_size.y <= 250.0, "Event art frame should feel illustrative but not dominate the modal")
		_require(body.custom_minimum_size.y >= 88.0, "Event body should have a protected text band")
		_require(body_rect.position.y - art_rect.end.y >= 16.0, "Event body should have enough breathing room below art")
		_require(buttons_rect.position.y - body_rect.end.y >= 12.0, "Event choices should not crowd the body text")
	if art_icon_backing != null and art_icon != null:
		_require(art_icon_backing.custom_minimum_size.x <= 56.0 and art_icon_backing.custom_minimum_size.y <= 56.0, "Event icon backing should stay compact")
		_require(art_icon.custom_minimum_size.x <= 44.0 and art_icon.custom_minimum_size.y <= 44.0, "Event semantic icon should stay compact")
		_require(art_icon_backing.offset_right <= -24.0 and art_icon_backing.offset_top >= 24.0, "Event icon backing needs corner protection margin")
		_require(art_icon_backing.modulate.a <= 0.66, "Event icon backing should not overpower the illustration")
		_require(art_icon.modulate.a <= 0.86, "Event semantic icon should not overpower the illustration")
	if art != null and art.texture != null:
		var path := str(art.texture.resource_path)
		if expected_category == "regular":
			_require(path.ends_with("event_banner_640x160.png"), "Regular event should use event banner asset")
			_require(art_frame != null and is_equal_approx(art_frame.custom_minimum_size.y, 210.0), "Regular event banner height should be 210")
		elif expected_category == "weather" or expected_category == "karma":
			_require(path.ends_with("event_illustration_560x96.png"), "%s event should use weather/karma illustration asset" % expected_category)
			_require(art_frame != null and is_equal_approx(art_frame.custom_minimum_size.y, 230.0), "%s event illustration height should be 230" % expected_category)
		else:
			_require(path.ends_with("event_illustration_secret_encounter.png"), "Heart demon event should use secret illustration asset")
			_require(art_frame != null and is_equal_approx(art_frame.custom_minimum_size.y, 250.0), "Heart demon event illustration height should be 250")
	if buttons != null:
		var icon_paths := {}
		for row_node in buttons.get_children():
			var row := row_node as HBoxContainer
			_require(row != null, "Event choice should be icon + button row")
			if row == null:
				continue
			var icon: TextureRect = null
			var button: Button = null
			if row.get_child_count() >= 1:
				icon = row.get_child(0) as TextureRect
			if row.get_child_count() >= 2:
				button = row.get_child(1) as Button
			_require(icon != null and icon.texture != null, "Event choice missing karma/effect icon texture")
			_require(button != null and _button_uses_asset_style(button), "Event choice button should use image2 asset style")
			if icon != null and icon.texture != null:
				icon_paths[str(icon.texture.resource_path)] = true
		var min_icon_count := 3 if expected_category == "karma" else 2
		_require(icon_paths.size() >= min_icon_count, "%s event choices should show distinct semantic icons" % expected_category)


func _check_run_result_contracts(result_panel: Node, victory: bool = true) -> void:
	var panel := result_panel.get_node_or_null("Panel") as PanelContainer
	var dimmer := result_panel.get_node_or_null("Dimmer") as TextureRect
	var backdrop := result_panel.get_node_or_null("Backdrop") as TextureRect
	var title := result_panel.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var seal_wrap := result_panel.get_node_or_null("Panel/Margin/VBox/ResultSealWrap") as Control
	var seal_icon := result_panel.get_node_or_null("Panel/Margin/VBox/ResultSealWrap/SealIcon") as TextureRect
	var seal_caption := result_panel.get_node_or_null("Panel/Margin/VBox/ResultSealWrap/SealCaption") as Label
	var stats_row := result_panel.get_node_or_null("Panel/Margin/VBox/StatsRow") as HBoxContainer
	var detail_scroll := result_panel.get_node_or_null("Panel/Margin/VBox/DetailScroll") as ScrollContainer
	var detail := result_panel.get_node_or_null("Panel/Margin/VBox/DetailScroll/Detail") as Label
	var restart := result_panel.get_node_or_null("Panel/Margin/VBox/RestartButton") as Button
	_require(panel != null and panel.visible, "RunResult panel is not visible")
	_require(dimmer != null and dimmer.visible and dimmer.texture != null, "RunResult should use shared image2 modal veil instead of pure ColorRect dimmer")
	_require(dimmer != null and dimmer.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "RunResult modal veil should cover 1920x1080 without distortion gaps")
	_require(backdrop != null and backdrop.visible and backdrop.texture != null, "RunResult backdrop texture missing")
	_require(title != null and title.text.length() >= 4, "RunResult title missing")
	_require(seal_wrap != null and seal_wrap.visible and seal_wrap.custom_minimum_size.y >= 140.0, "RunResult should include a visible result seal block")
	_require(seal_icon != null and seal_icon.texture != null, "RunResult result seal icon texture missing")
	_require(seal_caption != null and seal_caption.text.length() >= 4, "RunResult result seal caption missing")
	_require(stats_row != null and stats_row.get_child_count() >= 3 and stats_row.visible, "RunResult should include a three-stat summary row")
	_require(detail != null and detail.text.length() >= 20, "RunResult detail missing")
	_require(detail_scroll != null and detail_scroll.visible, "RunResult detail should be scrollable for long victory/failure summaries")
	_require(restart != null and restart.text.length() > 2 and restart.icon != null, "RunResult restart button missing icon asset")
	_require(restart != null and _button_uses_asset_style(restart), "RunResult restart button should use image2 button asset")
	if victory:
		_require(title != null and title.text.contains("飞升"), "RunResult victory title should contain 飞升")
	else:
		_require(title != null and title.text.contains("道消"), "RunResult failure title should contain 道消")
		_require(detail != null and detail.text.contains("遗言"), "RunResult failure detail should include death last words")
		_require(detail != null and detail.text.contains("本局名场面"), "RunResult failure detail should include highlight block")


func _check_pause_overlay_contracts(pause_overlay: Node) -> void:
	var panel := pause_overlay.get_node_or_null("Panel") as PanelContainer
	var enemy_hp := pause_overlay.get_node_or_null("Panel/Margin/VBox/EnemyHpCheck") as Button
	var auto_aim := pause_overlay.get_node_or_null("Panel/Margin/VBox/AutoAimCheck") as Button
	var normal_style := pause_overlay.get_node_or_null("Panel/Margin/VBox/SpriteStyleRow/SpriteStyleSegment/NormalStyleButton") as Button
	var chibi_style := pause_overlay.get_node_or_null("Panel/Margin/VBox/SpriteStyleRow/SpriteStyleSegment/ChibiStyleButton") as Button
	var legacy_option := pause_overlay.get_node_or_null("Panel/Margin/VBox/SpriteStyleRow/SpriteStyleOption")
	_require(panel != null and panel.visible, "Pause overlay panel is not visible")
	_check_modal_veil_contract(pause_overlay, "PauseOverlay", 0.66, 0.76)
	_require(enemy_hp != null and enemy_hp.toggle_mode and enemy_hp.text.begins_with("开"), "Pause enemy HP setting should be asset toggle button")
	_require(auto_aim != null and auto_aim.toggle_mode and auto_aim.text.begins_with("开"), "Pause auto aim setting should be asset toggle button")
	_require(normal_style != null and normal_style.toggle_mode and normal_style.button_pressed, "Pause normal sprite style segment missing")
	_require(chibi_style != null and chibi_style.toggle_mode, "Pause chibi sprite style segment missing")
	_require(enemy_hp != null and _button_uses_asset_style(enemy_hp), "Pause enemy HP setting should use image2 button asset")
	_require(normal_style != null and _button_uses_asset_style(normal_style), "Pause sprite style segment should use image2 button asset")
	_require(legacy_option == null, "Pause overlay should not use Godot-native OptionButton")
	_require(_count_native_check_buttons(pause_overlay) == 0, "Pause overlay should not use Godot-native CheckButton controls")


func _check_pause_confirm_contracts(pause_overlay: Node) -> void:
	_check_pause_overlay_contracts(pause_overlay)
	var confirm_box := pause_overlay.get_node_or_null("Panel/Margin/VBox/ConfirmBox") as VBoxContainer
	var confirm_label := pause_overlay.get_node_or_null("Panel/Margin/VBox/ConfirmBox/ConfirmLabel") as Label
	var confirm := pause_overlay.get_node_or_null("Panel/Margin/VBox/ConfirmBox/ConfirmRow/ConfirmRestartButton") as Button
	var cancel := pause_overlay.get_node_or_null("Panel/Margin/VBox/ConfirmBox/ConfirmRow/CancelRestartButton") as Button
	var end_button := pause_overlay.get_node_or_null("Panel/Margin/VBox/EndRunButton") as Button
	var quit_button := pause_overlay.get_node_or_null("Panel/Margin/VBox/QuitGameButton") as Button
	_require(confirm_box != null and confirm_box.visible, "Pause confirm box should be visible after ending current run")
	_require(confirm_label != null and confirm_label.text.contains("确认结束"), "Pause confirm label missing")
	_require(confirm != null and confirm.visible and _button_uses_asset_style(confirm), "Pause confirm button should use image2 primary asset")
	_require(cancel != null and cancel.visible and _button_uses_asset_style(cancel), "Pause cancel button should use image2 secondary asset")
	_require(end_button != null and not end_button.visible, "Pause end-run button should hide while confirm is open")
	_require(quit_button != null and not quit_button.visible, "Pause quit button should hide while confirm is open")


func _check_path_choice_contracts(path_choice: Node) -> void:
	var panel := path_choice.get_node_or_null("Panel") as PanelContainer
	var buttons := path_choice.get_node_or_null("Panel/Margin/VBox/Buttons") as GridContainer
	_require(panel != null and panel.visible, "PathChoice panel is not visible")
	_check_modal_veil_contract(path_choice, "PathChoice", 0.66, 0.76)
	_require(buttons != null and buttons.columns == 3, "PathChoice should use a centered 3-column grid, not a long horizontal shelf")
	_require(buttons != null and buttons.get_child_count() >= 5, "PathChoice should show five sample branch cards")
	if buttons == null:
		return
	_require(buttons.get_theme_constant("h_separation") >= 20, "PathChoice card horizontal spacing should leave enough air")
	_require(buttons.get_theme_constant("v_separation") >= 16, "PathChoice card vertical spacing should leave enough air")
	var center_safe := Rect2(Vector2(360, 170), Vector2(1200, 740))
	for child in buttons.get_children():
		var card := child as PanelContainer
		_require(card != null, "PathChoice branch should be a PanelContainer card")
		if card == null:
			continue
		var card_rect := Rect2(card.global_position, card.size)
		_require(card.size.x >= 300.0 and card.size.y >= 170.0, "PathChoice cards should be large enough for icon/text/button spacing")
		_require(center_safe.encloses(card_rect), "PathChoice cards should stay inside the centered 1920-safe panel area")
		var panel_style := card.get_theme_stylebox("panel")
		_require(panel_style is StyleBoxTexture and (panel_style as StyleBoxTexture).texture != null, "PathChoice card should use image2 ninepatch panel style")
		var icon := card.get_node_or_null("CardMargin/CardVBox/PathHeader/PathIcon") as TextureRect
		var tag := card.get_node_or_null("CardMargin/CardVBox/PathRiskTag") as Label
		var button := card.get_node_or_null("CardMargin/CardVBox/PathEnterButton") as Button
		_require(icon != null and icon.texture != null, "PathChoice card is missing a path icon texture")
		_require(tag != null and tag.text.length() >= 4, "PathChoice card is missing a risk tag")
		_require(button != null and button.text.length() >= 2, "PathChoice card is missing an enter button")
		if button != null:
			var normal_style := button.get_theme_stylebox("normal")
			_require(normal_style is StyleBoxTexture and (normal_style as StyleBoxTexture).texture != null, "PathChoice enter button should use image2 button texture")


func _check_shop_panel_contracts(shop: Node, full_slot: bool) -> void:
	var panel := shop.get_node_or_null("Panel") as PanelContainer
	_check_modal_veil_contract(shop, "ShopPanel", 0.68, 0.76)
	var content_scroll := shop.get_node_or_null("Panel/Margin/VBox/ContentScroll") as ScrollContainer
	var buttons := shop.get_node_or_null("Panel/Margin/VBox/ContentScroll/Buttons") as VBoxContainer
	var footer := shop.get_node_or_null("Panel/Margin/VBox/FooterActions") as HBoxContainer
	_require(panel != null and panel.visible, "Shop panel is not visible")
	_require(content_scroll != null and content_scroll.visible, "Shop panel should use a stable scrollable content region")
	_require(footer != null and footer.visible, "Shop panel should use a stable footer action region")
	_require(buttons != null and buttons.get_child_count() >= 3, "Shop panel content missing")
	if buttons == null:
		return
	if not full_slot:
		var icon_paths: Dictionary = {}
		for row in buttons.get_children():
			var card := row as PanelContainer
			if card == null:
				continue
			var style := card.get_theme_stylebox("panel")
			_require(style is StyleBoxTexture and (style as StyleBoxTexture).texture != null, "Shop offer row should use image2 ninepatch panel")
			var offer_icon := card.get_node_or_null("OfferMargin/OfferRow/OfferIcon") as TextureRect
			var cost_icon := card.get_node_or_null("OfferMargin/OfferRow/OfferText/CostRow/CostIcon") as TextureRect
			var buy := card.get_node_or_null("OfferMargin/OfferRow/OfferBuyButton") as Button
			_require(offer_icon != null and offer_icon.texture != null, "Shop offer row missing semantic icon")
			_require(cost_icon != null and cost_icon.texture != null, "Shop offer row missing spirit-stone cost icon")
			_require(buy != null and buy.icon != null, "Shop buy button should include spirit-stone icon")
			if buy != null:
				var normal := buy.get_theme_stylebox("normal")
				_require(normal is StyleBoxTexture and (normal as StyleBoxTexture).texture != null, "Shop buy button should use image2 asset style")
			if offer_icon != null and offer_icon.texture != null:
				icon_paths[str(offer_icon.texture.resource_path)] = true
		_require(icon_paths.size() >= 3, "Shop offers should not all reuse one fallback icon")
		var leave := shop.get_node_or_null("Panel/Margin/VBox/FooterActions/ShopLeaveButton") as Button
		_require(leave != null, "Shop leave button missing")
		if leave != null:
			var leave_style := leave.get_theme_stylebox("normal")
			_require(leave_style is StyleBoxTexture and (leave_style as StyleBoxTexture).texture != null, "Shop leave button should use image2 asset style")
	else:
		var hint := shop.get_node_or_null("Panel/Margin/VBox/ContentScroll/Buttons/FullSlotHintPanel") as PanelContainer
		var replace := shop.get_node_or_null("Panel/Margin/VBox/ContentScroll/Buttons/ReplaceAffixButton_0") as Button
		_require(hint != null, "Shop full-slot should show a dedicated hint panel")
		_require(content_scroll != null and content_scroll.custom_minimum_size.y >= 360.0, "Shop full-slot replacement list should be scrollable")
		_require(replace != null, "Shop full-slot replace action missing from scroll content")
		_require(footer != null and footer.get_child_count() == 3, "Shop full-slot footer should hold exactly three fixed actions")
		_require(shop.get_node_or_null("Panel/Margin/VBox/FooterActions/SealAffixButton") is Button, "Shop full-slot seal action missing")
		_require(shop.get_node_or_null("Panel/Margin/VBox/FooterActions/DissolveAffixButton") is Button, "Shop full-slot dissolve action missing")
		_require(shop.get_node_or_null("Panel/Margin/VBox/FooterActions/ShopBackButton") is Button, "Shop full-slot back action missing")
		if footer != null:
			_require(footer.get_theme_constant("separation") >= 8, "Shop full-slot footer actions should have breathing room")
		if content_scroll != null and footer != null and panel != null:
			var scroll_rect := Rect2(content_scroll.global_position, content_scroll.size)
			var footer_rect := Rect2(footer.global_position, footer.size)
			var panel_rect := Rect2(panel.global_position, panel.size)
			_require(panel_rect.encloses(footer_rect), "Shop full-slot footer should stay inside the panel")
			_require(footer_rect.position.y - scroll_rect.end.y >= 8.0, "Shop full-slot footer should not crowd the replacement list")
		var action_nodes: Array = []
		if buttons != null:
			action_nodes.append_array(buttons.get_children())
		if footer != null:
			action_nodes.append_array(footer.get_children())
		for node in action_nodes:
			var action := node as Button
			if action == null:
				continue
			_require(action.icon != null, "Shop full-slot action should use an icon asset")
			var style := action.get_theme_stylebox("normal")
			_require(style is StyleBoxTexture and (style as StyleBoxTexture).texture != null, "Shop full-slot action should use image2 button asset")


func _check_death_moment_contracts(overlay: Node) -> void:
	_require(overlay.visible, "Death moment overlay is not visible")
	var dimmer := overlay.get_node_or_null("Dimmer") as TextureRect
	var vignette := overlay.get_node_or_null("Vignette") as TextureRect
	var soul_field := overlay.get_node_or_null("SoulField") as PanelContainer
	var metric_row := overlay.get_node_or_null("SoulField/Margin/VBox/MetricRow") as HBoxContainer
	var player_echo := overlay.get_node_or_null("BodyFall/PlayerEcho") as TextureRect
	var totem_disc := overlay.get_node_or_null("Totem/TotemDisc") as TextureRect
	var soul_seal := overlay.get_node_or_null("Totem/SoulSeal") as TextureRect
	var regret := overlay.get_node_or_null("Regret") as Label
	var line := overlay.get_node_or_null("Line") as Label
	_require(dimmer != null and dimmer.visible and dimmer.texture != null, "Death moment should use shared image2 modal veil")
	_require(dimmer != null and dimmer.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Death moment modal veil should cover 1920x1080")
	_require(vignette != null and vignette.visible and vignette.texture != null, "Death moment should render dedicated image2 full-screen vignette")
	_require(soul_field != null and soul_field.visible and soul_field.modulate.a >= 0.65, "Death moment should include a readable soul-field summary panel")
	_require(metric_row != null and metric_row.get_child_count() >= 3, "Death moment soul-field should include three metric cards")
	_require(player_echo != null and player_echo.texture != null, "Death moment should use player sprite texture for fallen body")
	_require(totem_disc != null and totem_disc.texture != null, "Death moment should use texture backdrop for soul totem")
	if totem_disc != null and totem_disc.texture != null:
		_require(totem_disc.texture.resource_path.ends_with("death_soul_totem_disc_512.png"), "Death soul totem should use dedicated image2 disc, got `%s`" % totem_disc.texture.resource_path)
	_require(soul_seal != null and soul_seal.texture != null, "Death moment should use image2 status seal texture")
	if soul_seal != null and soul_seal.texture != null:
		_require(not soul_seal.texture.resource_path.ends_with("status_dao_32.png"), "Death moment soul seal must not upscale 32px status icon")
	_require(regret != null and regret.text.length() >= 4, "Death moment regret title missing")
	_require(line != null and line.text.length() >= 6, "Death moment final line missing")


func _check_legacy_select_contracts(legacy: Node) -> void:
	var panel := legacy.get_node_or_null("Panel") as PanelContainer
	_check_modal_veil_contract(legacy, "LegacySelect", 0.76, 0.84)
	var buttons := legacy.get_node_or_null("Panel/Margin/VBox/Buttons") as HBoxContainer
	var skip := legacy.get_node_or_null("Panel/Margin/VBox/SkipButton") as Button
	_require(panel != null and panel.visible, "Legacy select panel is not visible")
	_require(buttons != null and buttons.get_child_count() >= 3, "Legacy select should show three cards")
	_require(skip != null and skip.icon != null, "Legacy skip button should use icon asset")
	if skip != null:
		var skip_style := skip.get_theme_stylebox("normal")
		_require(skip_style is StyleBoxTexture and (skip_style as StyleBoxTexture).texture != null, "Legacy skip button should use image2 button asset")
	if buttons == null:
		return
	for card_node in buttons.get_children():
		var card := card_node as PanelContainer
		_require(card != null, "Legacy card should be PanelContainer")
		if card == null:
			continue
		var frame := card.get_node_or_null("LegacyCardMargin/LegacyRewardFrame") as TextureRect
		var type_icon := card.get_node_or_null("LegacyCardMargin/LegacyCardVBox/LegacyIconRow/LegacyTypeIcon") as TextureRect
		var elem_icon := card.get_node_or_null("LegacyCardMargin/LegacyCardVBox/LegacyIconRow/LegacyElementIcon") as TextureRect
		var pick := card.get_node_or_null("LegacyCardMargin/LegacyCardVBox/LegacyPickButton") as Button
		_require(frame != null and frame.texture != null, "Legacy card should use reward frame texture")
		_require(type_icon != null and type_icon.texture != null, "Legacy card should use legacy type icon")
		_require(elem_icon != null and elem_icon.texture != null, "Legacy card should use element icon")
		_require(pick != null and pick.icon != null, "Legacy pick button should use icon asset")
		if pick != null:
			var pick_style := pick.get_theme_stylebox("normal")
			_require(pick_style is StyleBoxTexture and (pick_style as StyleBoxTexture).texture != null, "Legacy pick button should use image2 button asset")


func _check_meta_upgrade_contracts(meta: Node) -> void:
	var panel := meta.get_node_or_null("Panel") as PanelContainer
	var dimmer := meta.get_node_or_null("Dimmer") as ColorRect
	var title := meta.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var points_icon := meta.get_node_or_null("Panel/Margin/VBox/PointsRow/PointsIcon") as TextureRect
	var points_label := meta.get_node_or_null("Panel/Margin/VBox/PointsRow/PointsLabel") as Label
	var scroll := meta.get_node_or_null("Panel/Margin/VBox/ListScroll") as ScrollContainer
	var list := meta.get_node_or_null("Panel/Margin/VBox/ListScroll/List") as VBoxContainer
	var close := meta.get_node_or_null("Panel/Margin/VBox/CloseButton") as Button
	_require(panel != null and panel.visible, "MetaUpgrade panel is not visible")
	_require(dimmer != null and dimmer.visible, "MetaUpgrade dimmer is not visible")
	_require(title != null and title.text == "轮回成长", "MetaUpgrade title missing")
	_require(points_icon != null and points_icon.texture != null, "MetaUpgrade points icon missing")
	_require(points_label != null and points_label.text.contains("轮回点"), "MetaUpgrade points label missing")
	_require(scroll != null, "MetaUpgrade list should be inside a ScrollContainer")
	_require(list != null and list.get_child_count() >= 3, "MetaUpgrade upgrade rows missing")
	_require(close != null and close.icon != null, "MetaUpgrade close button should use icon asset")
	if close != null:
		var close_style := close.get_theme_stylebox("normal")
		_require(close_style is StyleBoxTexture and (close_style as StyleBoxTexture).texture != null, "MetaUpgrade close button should use image2 button asset")
	if list == null:
		return
	for row_node in list.get_children():
		var row := row_node as PanelContainer
		_require(row != null, "MetaUpgrade row should be PanelContainer")
		if row == null:
			continue
		var style := row.get_theme_stylebox("panel")
		_require(style is StyleBoxTexture and (style as StyleBoxTexture).texture != null, "MetaUpgrade row should use image2 ninepatch panel")
		var icon := row.get_node_or_null("MetaUpgradeMargin/MetaUpgradeRow/MetaUpgradeIcon") as TextureRect
		var pips := row.get_node_or_null("MetaUpgradeMargin/MetaUpgradeRow/MetaUpgradeText/MetaUpgradePips") as HBoxContainer
		var cost_icon := row.get_node_or_null("MetaUpgradeMargin/MetaUpgradeRow/MetaUpgradeAction/CostRow/CostIcon") as TextureRect
		var button := row.get_node_or_null("MetaUpgradeMargin/MetaUpgradeRow/MetaUpgradeAction/MetaUpgradeButton") as Button
		_require(icon != null and icon.texture != null, "MetaUpgrade row missing semantic icon")
		_require(pips != null and pips.get_child_count() >= 1, "MetaUpgrade row missing level pips")
		_require(cost_icon != null and cost_icon.texture != null, "MetaUpgrade row missing cost icon")
		_require(button != null and button.icon != null, "MetaUpgrade upgrade button should use icon asset")
		if button != null:
			var button_style := button.get_theme_stylebox("normal")
			_require(button_style is StyleBoxTexture and (button_style as StyleBoxTexture).texture != null, "MetaUpgrade upgrade button should use image2 button asset")


func _check_breakthrough_contracts(breakthrough: Node) -> void:
	var panel := breakthrough.get_node_or_null("Panel") as PanelContainer
	var dimmer := breakthrough.get_node_or_null("Dimmer") as ColorRect
	var backdrop := breakthrough.get_node_or_null("Backdrop") as TextureRect
	var title := breakthrough.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var before := breakthrough.get_node_or_null("Panel/Margin/VBox/SlotRow/BeforeLabel") as Label
	var after := breakthrough.get_node_or_null("Panel/Margin/VBox/SlotRow/AfterLabel") as Label
	var realm_gate := breakthrough.get_node_or_null("Panel/Margin/RealmGateHeader") as TextureRect
	var forbidden_card_bg := breakthrough.get_node_or_null("Panel/Margin/RealmGate") as TextureRect
	var cards := breakthrough.get_node_or_null("Panel/Margin/VBox/Cards") as HBoxContainer
	_require(panel != null and panel.visible, "Breakthrough panel is not visible")
	_require(dimmer != null and dimmer.visible, "Breakthrough dimmer is not visible")
	_require(backdrop != null and backdrop.visible and backdrop.texture != null, "Breakthrough should render dedicated image2 full-screen backdrop")
	if backdrop != null and backdrop.texture != null:
		_require(backdrop.texture.resource_path.ends_with("breakthrough_backdrop_no_emblem_v3_1920x1080.png"), "Breakthrough backdrop should use v3 no-emblem image2 asset, got `%s`" % backdrop.texture.resource_path)
	_require(title != null and title.text.contains("破境"), "Breakthrough title should contain 破境")
	_require(before != null and before.text == "8", "Breakthrough before slot label missing")
	_require(after != null and after.text == "10", "Breakthrough after slot label missing")
	_require(realm_gate != null and realm_gate.texture != null, "Breakthrough should render image2 realm gate as a header ornament")
	if realm_gate != null and realm_gate.texture != null:
		_require(realm_gate.texture.resource_path.ends_with("realm_gate_panel_760x360.png"), "Breakthrough realm gate should use dedicated image2 asset, got `%s`" % realm_gate.texture.resource_path)
		_require(realm_gate.get_parent() == breakthrough.get_node_or_null("Panel/Margin"), "Breakthrough realm gate must be a Margin header ornament, not a card-area background")
		_require(realm_gate.modulate.a <= 0.01 or realm_gate.get_global_rect().end.y < cards.get_global_rect().position.y, "Breakthrough realm gate must not visibly overlap the talent card row")
	_require(forbidden_card_bg == null, "Breakthrough card area must not contain RealmGate because its large icons sit behind cards")
	_require(cards != null and cards.get_child_count() >= 3, "Breakthrough should show three talent cards")
	if panel != null and cards != null:
		var card_center_y := cards.get_global_rect().get_center().y
		var panel_center_y := panel.get_global_rect().get_center().y
		_require(absf(card_center_y - panel_center_y) <= 95.0, "Breakthrough talent cards are pushed too low; realm gate may be occupying layout space")
	var bg := panel.get_node_or_null("Margin/PanelTextureBg") as TextureRect
	_require(bg != null and bg.texture != null, "Breakthrough panel should keep image2 overlay texture")
	if cards == null:
		return
	for card_node in cards.get_children():
		var card := card_node as PanelContainer
		_require(card != null and card.visible, "Breakthrough talent card should be visible PanelContainer")
		if card == null:
			continue
		var frame := card.get_node_or_null("FrameBg") as TextureRect
		var badge := card.get_node_or_null("BadgeIcon") as TextureRect
		var icon := card.get_node_or_null("Margin/VBox/IconRow/Icon") as TextureRect
		var button := card.get_node_or_null("Margin/VBox/SelectButton") as Button
		if frame != null:
			_require(frame.texture == null, "Breakthrough hidden talent scroll frame should not load a texture that can flash or be stretched")
			_require(not frame.visible, "Breakthrough talent scroll texture should stay hidden until a non-blurry replacement is generated")
		if badge != null:
			_require(badge.texture == null, "Breakthrough hidden talent badge should not load a texture that can flash or be stretched")
			_require(not badge.visible, "Breakthrough talent badge should stay hidden until layout no longer stretches it behind text")
		_require(icon != null and icon.texture != null, "Breakthrough talent card missing realm icon texture")
		if icon != null:
			_require(icon.custom_minimum_size.x <= 32.0 and icon.custom_minimum_size.y <= 32.0, "Breakthrough realm icon should not upscale low-resolution talent icons")
			_require(icon.size.x <= 36.0 and icon.size.y <= 36.0, "Breakthrough realm icon runtime size should stay compact")
		_require(button != null and button.text.length() >= 2, "Breakthrough talent card missing select button")
		if button != null:
			var button_style := button.get_theme_stylebox("normal")
			_require(button_style is StyleBoxTexture and (button_style as StyleBoxTexture).texture != null, "Breakthrough select button should use image2 button asset")


func _check_weapon_mod_choice_contracts(weapon_mod: Node) -> void:
	var panel := weapon_mod.get_node_or_null("Panel") as PanelContainer
	var title := weapon_mod.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var summary := weapon_mod.get_node_or_null("Panel/Margin/VBox/Summary") as Label
	var cards := weapon_mod.get_node_or_null("Panel/Margin/VBox/Cards") as HBoxContainer
	_require(panel != null and panel.visible, "WeaponModChoice panel is not visible")
	_check_modal_veil_contract(weapon_mod, "WeaponModChoice", 0.68, 0.76)
	_require(title != null and title.text == "本命器祭炼", "WeaponModChoice title missing")
	_require(summary != null and summary.text.contains("已祭炼"), "WeaponModChoice summary missing")
	_require(cards != null and cards.get_child_count() >= 3, "WeaponModChoice should show three mod cards")
	if cards == null:
		return
	for card_node in cards.get_children():
		var card := card_node as PanelContainer
		_require(card != null, "WeaponModChoice card should be PanelContainer")
		if card == null:
			continue
		var style := card.get_theme_stylebox("panel")
		_require(style is StyleBoxTexture and (style as StyleBoxTexture).texture != null, "WeaponModChoice card should use image2 ninepatch style")
		var artifact_icon := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModIconRow/WeaponModArtifactIcon") as TextureRect
		var semantic_icon := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModIconRow/WeaponModSemanticIcon") as TextureRect
		var tags := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModTags") as HBoxContainer
		var name := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModName") as Label
		var desc := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModDesc") as Label
		var effect := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModEffect") as Label
		var button := card.get_node_or_null("WeaponModCardMargin/WeaponModCardVBox/WeaponModSelectButton") as Button
		_require(artifact_icon != null and artifact_icon.texture != null, "WeaponModChoice card missing artifact icon texture")
		_require(semantic_icon != null and semantic_icon.texture != null, "WeaponModChoice card missing semantic icon texture")
		_require(tags != null and tags.get_child_count() >= 2, "WeaponModChoice card missing tag chips")
		_require(name != null and name.text.length() >= 4, "WeaponModChoice card missing name")
		_require(desc != null and desc.text.length() >= 8, "WeaponModChoice card missing description")
		_require(effect != null and effect.text.length() >= 4, "WeaponModChoice card missing effect summary")
		_require(button != null and button.icon != null, "WeaponModChoice select button should include semantic icon")
		if button != null:
			var button_style := button.get_theme_stylebox("normal")
			_require(button_style is StyleBoxTexture and (button_style as StyleBoxTexture).texture != null, "WeaponModChoice select button should use image2 button asset")


func _check_jade_codex_contracts(codex: Node) -> void:
	_require(codex != null and codex.visible, "Jade codex overlay is not visible")
	_require(codex.get("_panel_texture") != null, "Jade codex should load PANEL_NINEPATCH texture")
	_require(codex.get("_divider_texture") != null, "Jade codex should load DIVIDER_GOLD texture")
	_require(codex.get("_tab_texture") != null, "Jade codex should load BTN_SECONDARY texture")
	_require(codex.get("_section_texture") != null, "Jade codex should load HUD section/card texture")
	_require(codex.get("_dao_pattern_texture") != null, "Jade codex should load dao pattern image2 texture")
	_require(codex.get("_status_badge_texture") != null, "Jade codex should load status badge image2 texture")
	_require(codex.get("_cooldown_sweep_texture") != null, "Jade codex should load cooldown sweep image2 texture")
	_require(codex.get("_resource_track_texture") != null, "Jade codex should load resource track image2 texture")
	_require(codex.has_method("get_pattern_texture_hit_count"), "Jade codex should expose pattern texture hit count")
	_require(codex.has_method("get_badge_texture_hit_count"), "Jade codex should expose badge texture hit count")
	_require(codex.has_method("get_progress_texture_hit_count"), "Jade codex should expose progress texture hit count")
	_require(int(codex.call("get_pattern_texture_hit_count")) >= 1, "Jade codex should draw dao pattern image2 textures")
	_require(int(codex.call("get_badge_texture_hit_count")) >= 5, "Jade codex should draw badge/rune image2 textures")
	_require(int(codex.call("get_progress_texture_hit_count")) >= 1, "Jade codex should draw progress/sweep image2 textures")


func _count_native_check_buttons(root: Node) -> int:
	var count := 0
	if root is CheckButton:
		count += 1
	for child in root.get_children():
		count += _count_native_check_buttons(child)
	return count


func _count_path_buttons_with_icons(root: Node) -> int:
	var count := 0
	for child in root.find_children("PathButtonContent", "HBoxContainer", true, false):
		var icon := child.get_node_or_null("PathIcon") as TextureRect
		if icon != null and icon.texture != null:
			count += 1
	return count


func _button_uses_asset_style(button: Button) -> bool:
	if button == null:
		return false
	var normal := button.get_theme_stylebox("normal")
	return normal is StyleBoxTexture and (normal as StyleBoxTexture).texture != null


func _check_modal_veil_contract(root: Node, label: String, min_alpha: float, max_alpha: float) -> void:
	var veil := root.get_node_or_null("Dimmer") as TextureRect
	var panel := root.get_node_or_null("Panel") as Control
	_require(veil != null, "%s dimmer should be a TextureRect shared modal veil" % label)
	if veil == null:
		return
	_require(veil.visible, "%s modal veil is not visible" % label)
	_require(veil.texture != null, "%s modal veil texture missing" % label)
	if veil.texture != null:
		_require(veil.texture.resource_path.ends_with("modal_ink_veil_1920x1080.png"), "%s modal veil should use shared image2 texture, got `%s`" % [label, veil.texture.resource_path])
	_require(veil.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "%s modal veil should keep aspect covered instead of non-uniform stretching" % label)
	_require(veil.modulate.a >= min_alpha and veil.modulate.a <= max_alpha, "%s modal veil alpha %.2f outside %.2f..%.2f" % [label, veil.modulate.a, min_alpha, max_alpha])
	_require(veil.get_rect().size.x >= 1918.0 and veil.get_rect().size.y >= 1078.0, "%s modal veil should cover the full 1920x1080 viewport" % label)
	if panel != null:
		_require(veil.get_index() < panel.get_index(), "%s modal veil should render behind the panel" % label)


func _capture_and_check(label: String, path: String, center_rect: Rect2, min_center_ui_ratio: float = 0.16) -> void:
	var image := _viewport.get_texture().get_image()
	if image == null:
		_fail("%s viewport image is null" % label)
		return
	_require(image.get_width() == TARGET_SIZE.x and image.get_height() == TARGET_SIZE.y, "%s screenshot must be 1920x1080, got %dx%d" % [label, image.get_width(), image.get_height()])
	var stats := _sample_image_stats(image, center_rect)
	_report("%s non-black ratio: %.3f" % [label, stats.non_black_ratio])
	_report("%s bright ratio: %.3f" % [label, stats.bright_ratio])
	_report("%s unique color buckets: %d" % [label, stats.unique_color_buckets])
	_report("%s center UI ratio: %.3f" % [label, stats.center_ui_ratio])
	_require(stats.non_black_ratio > 0.55, "%s appears mostly blank/dark" % label)
	_require(stats.bright_ratio > 0.004, "%s has too few readable highlights" % label)
	_require(stats.unique_color_buckets >= 18, "%s has low color diversity" % label)
	_require(stats.center_ui_ratio > min_center_ui_ratio, "%s center UI coverage is too low" % label)
	var error := image.save_png(path)
	if error != OK:
		_fail("Failed to save %s screenshot to %s (error %d)" % [label, path, error])


func _sample_image_stats(image: Image, center_rect: Rect2) -> Dictionary:
	var total := 0
	var non_black := 0
	var bright := 0
	var center_total := 0
	var center_ui := 0
	var buckets := {}
	var step := 12
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			total += 1
			if luminance > 0.025 and color.a > 0.1:
				non_black += 1
			if luminance > 0.42:
				bright += 1
			if center_rect.has_point(Vector2(x, y)):
				center_total += 1
				if luminance > 0.075:
					center_ui += 1
			var key := "%d_%d_%d" % [
				int(clampf(color.r, 0.0, 1.0) * 7.0),
				int(clampf(color.g, 0.0, 1.0) * 7.0),
				int(clampf(color.b, 0.0, 1.0) * 7.0),
			]
			buckets[key] = true
	return {
		"non_black_ratio": float(non_black) / float(maxi(total, 1)),
		"bright_ratio": float(bright) / float(maxi(total, 1)),
		"unique_color_buckets": buckets.size(),
		"center_ui_ratio": float(center_ui) / float(maxi(center_total, 1)),
	}


func _require(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)


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
