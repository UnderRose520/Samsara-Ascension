extends Node

const StageGenerator = preload("res://systems/world/stage_generator.gd")
const RunRng = preload("res://core/utils/run_rng.gd")

const COMBAT_FLOOR_SCENE := preload("res://scenes/rooms/combat_floor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const AFFIX_CHOICE_SCENE := preload("res://scenes/ui/affix_choice_panel.tscn")

const TARGET_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://../output/visual_qa/reward_cards_1920.png"
const FULL_SLOT_OUTPUT_PATH := "res://../output/visual_qa/reward_full_slot_actions_1920.png"
const REPORT_PATH := "res://../output/visual_qa/reward_cards_1920_report.txt"
const SAMPLE_SEED := 524309
const SAMPLE_STAGE_INDEX := 3
const SAMPLE_WEATHER_ID := "fire"

var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _viewport: SubViewport
var _world: Node2D
var _panel: CanvasLayer
var _combat_floor: Node2D
var _player: CharacterBody2D


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	_report("Reward card visual QA 1920x1080")
	_report("=================================")
	_prepare_output_dir()
	_prepare_run_state()
	_prepare_viewport()
	await get_tree().process_frame
	await get_tree().physics_frame
	_build_background_scene()
	await get_tree().process_frame
	_show_reward_cards()
	for _i in range(12):
		await get_tree().process_frame
	_arm_temptation_confirmation()
	for _i in range(8):
		await get_tree().process_frame
	var image := _viewport.get_texture().get_image()
	_check_reward_card_contracts()
	_check_image_contracts(image, "reward_cards")
	_save_image(image, OUTPUT_PATH)
	await _show_full_slot_actions()
	for _i in range(8):
		await get_tree().process_frame
	var full_slot_image := _viewport.get_texture().get_image()
	_check_full_slot_contracts()
	_check_image_contracts(full_slot_image, "reward_full_slot")
	_save_image(full_slot_image, FULL_SLOT_OUTPUT_PATH)
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		_write_report(1)
		return 1
	_report("Screenshot: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	_report("Full-slot screenshot: %s" % ProjectSettings.globalize_path(FULL_SLOT_OUTPUT_PATH))
	_report("Reward card visual QA passed")
	_write_report(0)
	return 0


func _prepare_output_dir() -> void:
	var global_dir := ProjectSettings.globalize_path("res://../output/visual_qa")
	DirAccess.make_dir_recursive_absolute(global_dir)


func _prepare_run_state() -> void:
	RunContext.seed_value = SAMPLE_SEED
	RunContext.run_active = true
	RunContext.current_stage = SAMPLE_STAGE_INDEX
	RunContext.current_room = 1
	RunContext.gold = 240
	RunContext.realm_level = 3
	RunContext.affix_slot_cap = 8
	RunContext.ui_blocking = true
	WeatherSystem.set_weather(SAMPLE_WEATHER_ID)


func _prepare_viewport() -> void:
	get_window().size = TARGET_SIZE
	get_tree().root.content_scale_size = TARGET_SIZE
	_viewport = SubViewport.new()
	_viewport.name = "RewardCardsViewport"
	_viewport.size = TARGET_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	_world = Node2D.new()
	_world.name = "RewardCardsWorld"
	_world.add_to_group("world_vfx")
	_viewport.add_child(_world)

	var camera := Camera2D.new()
	camera.name = "QACamera2D"
	camera.zoom = Vector2(2.0 / 3.0, 2.0 / 3.0)
	camera.enabled = true
	_world.add_child(camera)


func _build_background_scene() -> void:
	var plan: Array = StageGenerator.generate(1, {})
	var stage: Dictionary = _stage_by_index(plan, SAMPLE_STAGE_INDEX)
	var room: Dictionary = _first_room_of_type(stage, "combat_hard")
	if room.is_empty():
		room = _first_room_of_type(stage, "combat")
	if room.is_empty():
		_fail("No combat room found for reward card background")
		return
	room["weather_id"] = SAMPLE_WEATHER_ID
	_combat_floor = COMBAT_FLOOR_SCENE.instantiate()
	_world.add_child(_combat_floor)
	await get_tree().process_frame
	_combat_floor.apply_theme(SAMPLE_STAGE_INDEX)
	var rng := RunRng.stage_room(SAMPLE_STAGE_INDEX, int(room.get("room_index", 0)), str(room.get("type", "combat")))
	_combat_floor.apply_layout(room, rng, SAMPLE_WEATHER_ID)

	_player = PLAYER_SCENE.instantiate()
	_player.global_position = Vector2(0, 120)
	_world.add_child(_player)
	await get_tree().process_frame


func _show_reward_cards() -> void:
	_panel = AFFIX_CHOICE_SCENE.instantiate()
	_panel.name = "QARewardAffixChoicePanel"
	_viewport.add_child(_panel)
	await get_tree().process_frame
	var offers := _reward_offers()
	var context := {
		"gold": 240,
		"elite": true,
		"affix_slots": 8,
		"director_reason": "天劫余响 · 高品质机缘",
		"build_archetype_hint": "雷火法修 / 禁忌试炼",
	}
	EventBus.affix_choice_requested.emit(offers, context)


func _show_full_slot_actions() -> void:
	if _panel != null and is_instance_valid(_panel):
		_viewport.remove_child(_panel)
		_panel.free()
	_panel = null
	_fill_player_affix_slots()
	_panel = AFFIX_CHOICE_SCENE.instantiate()
	_panel.name = "QARewardFullSlotPanel"
	_viewport.add_child(_panel)
	await get_tree().process_frame
	var context := {
		"gold": 240,
		"elite": true,
		"affix_slots": RunContext.affix_slot_max(),
		"director_reason": "满槽抉择 · 处理新机缘",
		"build_archetype_hint": "替换 / 封印 / 分解",
	}
	EventBus.affix_choice_requested.emit(_full_slot_offers(), context)
	for _i in range(8):
		await get_tree().process_frame
	var cards := _card_nodes()
	if cards.is_empty():
		_fail("Full-slot reward cards missing before selecting offer")
		return
	var select_button := cards[0].get_node_or_null("Margin/VBox/SelectButton") as Button
	if select_button == null:
		_fail("Full-slot reward card select button missing")
		return
	select_button.pressed.emit()


func _fill_player_affix_slots() -> void:
	RunContext.realm_level = 1
	RunContext.affix_slot_cap = 3
	RunContext.gold = 240
	if _player == null or not _player.has_node("AffixHolder"):
		_fail("Player AffixHolder missing for full-slot reward QA")
		return
	var holder: Node = _player.get_node("AffixHolder")
	holder.equipped.clear()
	holder.sealed_affixes.clear()
	for id in ["F001", "F003", "F008"]:
		var tag: Variant = ConfigRegistry.compile_affix(id, 0)
		if tag == null or not holder.add_affix(tag):
			_fail("Failed to seed full-slot affix %s" % id)


func _full_slot_offers() -> Array:
	var legendary: Variant = ConfigRegistry.compile_affix("F022", 0)
	var thunder: Variant = ConfigRegistry.compile_affix("F017", 0)
	var water: Variant = ConfigRegistry.compile_affix("F030", 0)
	return [
		{
			"tag": legendary,
			"preview_tag": legendary,
			"offer_type": "elite",
			"badge": "道契",
		},
		{
			"tag": thunder,
			"preview_tag": thunder,
			"offer_type": "elite",
			"badge": "雷纹",
		},
		{
			"tag": water,
			"preview_tag": water,
			"offer_type": "elite",
			"badge": "寒印",
		},
	]


func _reward_offers() -> Array:
	var legendary: Variant = ConfigRegistry.compile_affix("F022", 0)
	var temptation_base: Variant = ConfigRegistry.compile_affix("F015", 0)
	var temptation_preview: Variant = ConfigRegistry.compile_affix("F015", 1)
	var locked: Variant = ConfigRegistry.compile_affix("F034", 0)
	return [
		{
			"tag": legendary,
			"preview_tag": legendary,
			"offer_type": "elite",
			"badge": "天赐",
		},
		{
			"tag": temptation_base,
			"preview_tag": temptation_preview,
			"offer_type": "temptation",
			"badge": "禁忌",
			"benefit_text": "品质上浮 · 立即点亮火系核心",
			"cost_text": "代价：心魔劫火随房间增强",
			"temptation_id": "heart_fire_oath",
			"bonus_shift": 1,
		},
		{
			"tag": locked,
			"preview_tag": locked,
			"offer_type": "gray",
			"locked": true,
			"badge": "缺口",
			"lock_reason": "需先悟得木系续航",
			"preview_text": "展示灰态与锁定覆盖，不可选择",
		},
	]


func _arm_temptation_confirmation() -> void:
	var cards := _card_nodes()
	if cards.size() < 2:
		return
	var temptation_card: Node = cards[1]
	var select_button := temptation_card.get_node_or_null("Margin/VBox/SelectButton") as Button
	if select_button == null:
		return
	select_button.pressed.emit()


func _check_reward_card_contracts() -> void:
	_require(_viewport != null and _viewport.size == TARGET_SIZE, "SubViewport must be 1920x1080")
	_require(_panel != null and is_instance_valid(_panel), "AffixChoicePanel instance missing")
	var cards := _card_nodes()
	_require(cards.size() == 3, "Expected exactly three reward cards")
	var glow_count := 0
	var forbidden_count := 0
	var locked_count := 0
	var confirm_armed_count := 0
	var glow_texture_hits := 0
	var glow_particle_hits := 0
	var forbidden_texture_hits := 0
	for card in cards:
		var glow: Node = _quality_glow_for_card(card)
		if glow != null and glow.visible:
			glow_count += 1
			_require(glow.has_method("get_texture_hit_count"), "Reward quality glow should expose texture hit count")
			_require(glow.has_method("get_particle_texture_count"), "Reward quality glow should expose particle texture count")
			_require(glow.has_method("get_forbidden_texture_count"), "Reward quality glow should expose forbidden texture count")
			if glow.has_method("get_texture_hit_count"):
				glow_texture_hits += int(glow.call("get_texture_hit_count"))
			if glow.has_method("get_particle_texture_count"):
				glow_particle_hits += int(glow.call("get_particle_texture_count"))
			if bool(glow.get("forbidden")):
				forbidden_count += 1
				if glow.has_method("get_forbidden_texture_count"):
					forbidden_texture_hits += int(glow.call("get_forbidden_texture_count"))
			if bool(glow.get("confirm_armed")):
				confirm_armed_count += 1
		var overlay := card.get_node_or_null("StateOverlay") as TextureRect
		if overlay != null and overlay.visible and overlay.texture != null:
			if bool(card.get_offer_payload().get("locked", false)):
				locked_count += 1
		var icon := card.get_node_or_null("Margin/VBox/Icon") as TextureRect
		_require(icon != null and icon.texture != null, "Reward card missing large element icon")
		var desc := card.get_node_or_null("Margin/VBox/DescLabel") as Label
		_require(desc != null and not desc.text.strip_edges().is_empty(), "Reward card missing readable description")
		var tag_strip := card.get_node_or_null("Margin/VBox/TagStrip") as HBoxContainer
		_require(tag_strip != null and tag_strip.get_child_count() >= 3, "Reward card missing assetized tag chips")
		if tag_strip != null:
			for tag in tag_strip.get_children():
				var tag_panel := tag as PanelContainer
				_require(tag_panel != null, "Reward tag chip should be a PanelContainer")
				if tag_panel == null:
					continue
				var tag_style := tag_panel.get_theme_stylebox("panel")
				_require(tag_style is StyleBoxTexture and (tag_style as StyleBoxTexture).texture != null, "Reward tag chip should use image2 texture backing")
	_require(glow_count >= 2, "Expected quality glow on high quality / forbidden cards")
	_require(glow_texture_hits >= glow_count * 8, "Reward quality glows should be image2 texture-backed")
	_require(glow_particle_hits >= 8, "Reward quality glows should show texture-backed restrained particles")
	_require(forbidden_count == 1, "Expected one forbidden temptation glow")
	_require(forbidden_texture_hits >= 4, "Forbidden reward glow should show texture-backed reverse marks")
	_require(confirm_armed_count == 1, "Expected temptation card to enter confirm-armed state")
	_require(locked_count == 1, "Expected one locked/gray overlay card")


func _check_full_slot_contracts() -> void:
	_require(_viewport != null and _viewport.size == TARGET_SIZE, "SubViewport must be 1920x1080")
	_require(_panel != null and is_instance_valid(_panel), "AffixChoicePanel full-slot instance missing")
	var actions_panel := _panel.get_node_or_null("Panel/Margin/VBox/Cards/FullSlotActionsPanel") as PanelContainer
	_require(actions_panel != null and actions_panel.visible, "Reward full-slot actions panel missing")
	if actions_panel != null:
		var panel_style := actions_panel.get_theme_stylebox("panel")
		_require(panel_style is StyleBoxTexture and (panel_style as StyleBoxTexture).texture != null, "Reward full-slot panel should use image2 ninepatch")
	var actions := _panel.get_node_or_null("Panel/Margin/VBox/Cards/FullSlotActionsPanel/FullSlotMargin/FullSlotActions") as VBoxContainer
	_require(actions != null, "Reward full-slot actions container missing")
	var reroll := _panel.get_node_or_null("Panel/Margin/VBox/Actions/RerollButton") as Button
	var skip := _panel.get_node_or_null("Panel/Margin/VBox/Actions/SkipButton") as Button
	_require(reroll != null and not reroll.visible, "Reward reroll button should hide while full-slot actions are open")
	_require(skip != null and not skip.visible, "Reward skip button should hide while full-slot actions are open")
	var expected := [
		"ReplaceAffixButton_0",
		"SealAffixButton",
		"DissolveAffixButton",
		"RewardBackButton",
	]
	for name in expected:
		var action := _panel.get_node_or_null("Panel/Margin/VBox/Cards/FullSlotActionsPanel/FullSlotMargin/FullSlotActions/%s" % name) as Button
		_require(action != null, "Reward full-slot action missing: %s" % name)
		if action == null:
			continue
		_require(action.visible, "Reward full-slot action should be visible: %s" % name)
		_require(action.icon != null, "Reward full-slot action should use an icon asset: %s" % name)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := action.get_theme_stylebox(state)
			_require(style is StyleBoxTexture and (style as StyleBoxTexture).texture != null, "Reward full-slot action %s should use image2 %s button asset" % [name, state])


func _check_image_contracts(image: Image, label: String) -> void:
	if image == null:
		_fail("%s viewport image is null" % label)
		return
	_require(image.get_width() == TARGET_SIZE.x and image.get_height() == TARGET_SIZE.y, "%s screenshot must be 1920x1080, got %dx%d" % [label, image.get_width(), image.get_height()])
	var stats := _sample_image_stats(image)
	_report("%s sampled non-black ratio: %.3f" % [label, stats.non_black_ratio])
	_report("%s sampled bright ratio: %.3f" % [label, stats.bright_ratio])
	_report("%s sampled mean luminance: %.3f" % [label, stats.mean_luminance])
	_report("%s sampled unique color buckets: %d" % [label, stats.unique_color_buckets])
	_report("%s sampled center UI ratio: %.3f" % [label, stats.center_ui_ratio])
	_require(stats.non_black_ratio > 0.62, "%s screenshot appears mostly blank/dark" % label)
	_require(stats.bright_ratio > 0.008, "%s screenshot has too few readable highlights" % label)
	_require(stats.mean_luminance < 0.30, "%s screenshot is too bright for dark ink UI" % label)
	_require(stats.unique_color_buckets >= 34, "%s screenshot has low color diversity" % label)
	_require(stats.center_ui_ratio > 0.18, "%s UI does not occupy enough center area" % label)


func _save_image(image: Image, path: String) -> void:
	if image == null:
		return
	var error := image.save_png(path)
	if error != OK:
		_fail("Failed to save screenshot to %s (error %d)" % [path, error])


func _sample_image_stats(image: Image) -> Dictionary:
	var total := 0
	var non_black := 0
	var bright := 0
	var center_total := 0
	var center_ui := 0
	var luminance_sum := 0.0
	var buckets := {}
	var center_rect := Rect2(Vector2(360, 150), Vector2(1200, 780))
	var step := 12
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			luminance_sum += luminance
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
		"mean_luminance": luminance_sum / float(maxi(total, 1)),
		"unique_color_buckets": buckets.size(),
		"center_ui_ratio": float(center_ui) / float(maxi(center_total, 1)),
	}


func _card_nodes() -> Array:
	if _panel == null:
		return []
	var cards_box := _panel.get_node_or_null("Panel/Margin/VBox/Cards")
	if cards_box == null:
		return []
	var out := []
	for child in cards_box.get_children():
		if child.visible and child.has_method("get_offer_payload"):
			out.append(child)
	return out


func _quality_glow_for_card(card: Node) -> Node:
	for child in card.get_children():
		if child is QualityGlow:
			return child
	return null


func _stage_by_index(plan: Array, stage_index: int) -> Dictionary:
	for item in plan:
		if item is Dictionary and int(item.get("stage_index", 0)) == stage_index:
			return item
	return {}


func _first_room_of_type(stage: Dictionary, room_type: String) -> Dictionary:
	var rooms: Array = stage.get("rooms", [])
	for item in rooms:
		if item is Dictionary and str(item.get("type", "")) == room_type:
			return (item as Dictionary).duplicate(true)
	return {}


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
