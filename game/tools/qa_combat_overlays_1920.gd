extends Node

const AssetPaths = preload("res://assets/asset_paths.gd")

const TOP_ANNOUNCEMENT_SCENE := preload("res://scenes/ui/top_announcement_overlay.tscn")
const DAO_TRADITION_SCENE := preload("res://scenes/ui/dao_tradition_overlay.tscn")
const CRIT_MOMENT_SCENE := preload("res://scenes/ui/crit_moment_overlay.tscn")
const COMBAT_FEEDBACK_SCENE := preload("res://scenes/ui/combat_feedback_layer.tscn")

const TARGET_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://../output/visual_qa/combat_overlays_1920.png"
const REPORT_PATH := "res://../output/visual_qa/combat_overlays_1920_report.txt"

var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _viewport: SubViewport
var _world: Node2D
var _top: CanvasLayer
var _dao: CanvasLayer
var _crit: CanvasLayer
var _feedback: CanvasLayer
var _enemy: Node2D
var _player: Node2D


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	_report("Combat overlays visual QA 1920x1080")
	_report("====================================")
	_prepare_output_dir()
	_prepare_state()
	_prepare_viewport()
	await _build_showcase()
	await _trigger_overlays()
	for _i in range(12):
		await get_tree().process_frame
	_check_overlay_contracts()
	var image := _viewport.get_texture().get_image()
	_check_image_contracts(image)
	_save_image(image)
	Engine.time_scale = 1.0
	get_tree().paused = false
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		_write_report(1)
		return 1
	_report("Screenshot: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	_report("Combat overlays visual QA passed")
	_write_report(0)
	return 0


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/visual_qa"))


func _prepare_state() -> void:
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.gold = 240
	SaveManager.set_display_setting("show_damage_numbers", true)
	SaveManager.set_display_setting("reduce_motion", true)
	WeatherSystem.set_weather("thunder")


func _prepare_viewport() -> void:
	get_window().size = TARGET_SIZE
	get_tree().root.content_scale_size = TARGET_SIZE
	_viewport = SubViewport.new()
	_viewport.name = "CombatOverlaysViewport"
	_viewport.size = TARGET_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	_world = Node2D.new()
	_world.name = "OverlayWorld"
	_viewport.add_child(_world)
	var camera := Camera2D.new()
	camera.name = "OverlayCamera"
	camera.enabled = true
	camera.zoom = Vector2(1.0, 1.0)
	_world.add_child(camera)


func _build_showcase() -> void:
	var bg := ColorRect.new()
	bg.name = "InkBackdrop"
	bg.color = Color(0.006, 0.010, 0.014, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(TARGET_SIZE)
	bg.custom_minimum_size = Vector2(TARGET_SIZE)
	_viewport.add_child(bg)
	_viewport.move_child(bg, 0)

	_enemy = _make_marker("QAOverlayEnemy", Vector2(-90, 70), Color(0.94, 0.32, 0.18, 0.92))
	_player = _make_marker("QAOverlayPlayer", Vector2(90, 118), Color(0.42, 0.94, 0.82, 0.92))

	_top = TOP_ANNOUNCEMENT_SCENE.instantiate()
	_dao = DAO_TRADITION_SCENE.instantiate()
	_crit = CRIT_MOMENT_SCENE.instantiate()
	_feedback = COMBAT_FEEDBACK_SCENE.instantiate()
	_viewport.add_child(_top)
	_viewport.add_child(_feedback)
	_viewport.add_child(_crit)
	_viewport.add_child(_dao)
	await get_tree().process_frame
	_check_idle_overlay_contracts()


func _make_marker(name: String, pos: Vector2, color: Color) -> Node2D:
	var marker := Node2D.new()
	marker.name = name
	marker.global_position = pos
	_world.add_child(marker)
	var sprite := Sprite2D.new()
	sprite.name = "MarkerSprite"
	sprite.texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("actor_presence_shadow"))
	sprite.modulate = color
	sprite.scale = Vector2(1.35, 0.72)
	marker.add_child(sprite)
	return marker


func _trigger_overlays() -> void:
	EventBus.pet_coord_feedback.emit("道统觉醒 · 雷火法修")
	EventBus.dao_tradition_awakened.emit({
		"id": "dao_thunder_fire",
		"name": "雷火法修道统",
		"title": "劫火引雷",
		"description": "雷火共鸣成道，暴击与燃烧互相抬升。",
	})
	EventBus.crit_moment_requested.emit("道之极致", 1.8)
	EventBus.unity_burst_visual_requested.emit({"color": Color(0.72, 0.95, 1.0, 1.0)})
	_emit_damage(Vector2(-120, 50), 128.0, {"is_crit": true, "status": "counter"})
	_emit_damage(Vector2(110, 115), 62.0, {"target_is_player": true, "status": "bleed"})
	_emit_damage(Vector2(-20, -18), 286.0, {"is_combo": true, "status": "burn"})
	_emit_damage(Vector2(58, -66), 520.0, {"is_unity": true, "unity_hit_index": 4, "status": "dao", "color": Color(0.72, 0.95, 1.0)})
	EventBus.weather_kill.emit(_enemy, "thunder", {})
	EventBus.pet_guardian_triggered.emit(_enemy, _player)


func _check_idle_overlay_contracts() -> void:
	var dao_banner := _dao.get_node_or_null("Banner") as Label
	var dao_subtitle := _dao.get_node_or_null("Subtitle") as Label
	var dao_frame := _dao.get_node_or_null("Frame") as TextureRect
	var dao_patterns := _dao.get_node_or_null("Patterns") as Control
	var top_bar := _top.get_node_or_null("Bar") as PanelContainer
	_require(dao_banner != null and not dao_banner.visible, "DaoTraditionOverlay banner must stay hidden before awaken trigger")
	_require(dao_subtitle != null and not dao_subtitle.visible, "DaoTraditionOverlay subtitle must stay hidden before awaken trigger")
	_require(dao_frame != null and not dao_frame.visible, "DaoTraditionOverlay title frame must not leak as a center combat banner before awaken trigger")
	_require(dao_patterns != null and not dao_patterns.visible, "DaoTraditionOverlay patterns must stay hidden before awaken trigger")
	_require(top_bar != null and not top_bar.visible, "TopAnnouncementOverlay bar must stay hidden before critical announcement")


func _emit_damage(screen_pos: Vector2, amount: float, extra: Dictionary) -> void:
	var result := extra.duplicate(true)
	result["world_position"] = screen_pos
	result["final_damage"] = amount
	EventBus.damage_dealt.emit(result)


func _check_overlay_contracts() -> void:
	var top_bar := _top.get_node_or_null("Bar") as PanelContainer
	var top_label := _top.get_node_or_null("Bar/Margin/Label") as Label
	_require(top_bar != null and top_bar.visible, "TopAnnouncementOverlay should show critical announcement")
	_require(top_label != null and top_label.text.contains("道统觉醒"), "TopAnnouncementOverlay text missing critical announcement")
	_require(_top.has_method("get_texture_hit_count") and int(_top.call("get_texture_hit_count")) > 0, "TopAnnouncementOverlay should use image2 scroll texture backing")

	var dao_banner := _dao.get_node_or_null("Banner") as Label
	var dao_frame := _dao.get_node_or_null("Frame") as TextureRect
	var dao_patterns := _dao.get_node_or_null("Patterns") as Control
	_require(dao_banner != null and dao_banner.visible and dao_banner.text.contains("雷火"), "DaoTraditionOverlay banner should be visible")
	_require(dao_frame != null and dao_frame.visible and dao_frame.texture != null, "DaoTraditionOverlay divider should only show during awaken and use a compact gold line")
	if dao_frame != null:
		var dao_frame_rect := Rect2(dao_frame.global_position, dao_frame.size * dao_frame.scale)
		var combat_center_safe := Rect2(Vector2(420.0, 320.0), Vector2(1080.0, 300.0))
		_require(dao_frame_rect.position.y >= 188.0 and dao_frame_rect.position.y <= 204.0, "DaoTraditionOverlay divider should be explicitly anchored under the top title")
		_require(not dao_frame_rect.intersects(combat_center_safe), "DaoTraditionOverlay divider must not overlap the center combat safe area")
		_require(dao_frame_rect.size.x <= 430.0 and dao_frame_rect.size.y <= 8.0, "DaoTraditionOverlay divider must not become a wide combat-center banner")
		_require(dao_frame.modulate.a <= 0.80, "DaoTraditionOverlay divider should stay decorative so text/FX own the moment")
	_require(dao_patterns != null and dao_patterns.visible, "DaoTraditionOverlay patterns should be visible")
	_require(_dao.has_method("get_pattern_texture_hit_count") and int(_dao.call("get_pattern_texture_hit_count")) >= 4, "DaoTraditionOverlay corner patterns should use image2 ornament textures")

	var crit_banner := _crit.get_node_or_null("Banner") as Label
	var slash := _crit.get_node_or_null("Slash") as Control
	_require(crit_banner != null and (crit_banner.visible or crit_banner.text.length() > 0), "CritMomentOverlay banner should be visible or retain the latest moment text")
	_require(slash != null and slash.has_method("get_slash_texture_hit_count"), "CritMomentOverlay slash should expose texture hit count")
	_require(slash != null and (int(slash.call("get_slash_texture_hit_count")) > 0 or not slash.visible), "CritMomentOverlay slash should use image2 crit slash texture while active")
	_require(_crit.has_method("get_edge_texture_hit_count") and int(_crit.call("get_edge_texture_hit_count")) >= 8, "CritMomentOverlay edge glow should use image2 edge textures")

	_require(_feedback.has_method("get_floater_spawn_count"), "CombatFeedbackLayer should expose floater spawn count")
	var floater_count := int(_feedback.call("get_floater_spawn_count"))
	var backing_hits := int(_feedback.call("get_floater_backing_texture_hit_count"))
	var icon_hits := int(_feedback.call("get_floater_icon_texture_hit_count"))
	_report("Combat feedback floaters: %d, backing hits %d, icon hits %d" % [floater_count, backing_hits, icon_hits])
	_require(floater_count >= 6, "CombatFeedbackLayer should show damage/weather/pet feedback floaters")
	_require(backing_hits >= floater_count, "CombatFeedbackLayer floaters should use image2 backing textures")
	_require(icon_hits >= floater_count, "CombatFeedbackLayer floaters should use semantic icon textures")
	for node in _feedback.get_children():
		if not (node is Control):
			continue
		var backing := node.get_node_or_null("FloaterBacking") as TextureRect
		if backing == null:
			continue
		_require(backing.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Combat feedback backing must preserve aspect instead of stretching into a horizontal banner")
		_require(backing.custom_minimum_size.x <= 32.0 and backing.custom_minimum_size.y <= 32.0, "Combat feedback backing must stay an icon badge, not a stretched horizontal banner")


func _count_crit_edge_textures() -> int:
	var edge_glow := _crit.get_node_or_null("EdgeGlow") if _crit != null else null
	if edge_glow == null:
		return 0
	var count := 0
	for child in edge_glow.get_children():
		var texture_node := child as TextureRect
		if texture_node != null and texture_node.texture != null:
			count += 1
	return count


func _check_image_contracts(image: Image) -> void:
	if image == null:
		_fail("Viewport image is null")
		return
	_require(image.get_width() == TARGET_SIZE.x and image.get_height() == TARGET_SIZE.y, "Screenshot must be 1920x1080")
	var stats := _sample_image_stats(image)
	_report("Sampled non-black ratio: %.3f" % stats.non_black_ratio)
	_report("Sampled bright ratio: %.3f" % stats.bright_ratio)
	_report("Sampled unique color buckets: %d" % stats.unique_color_buckets)
	_require(stats.non_black_ratio > 0.15, "Combat overlay screenshot appears blank")
	_require(stats.bright_ratio > 0.002, "Combat overlay screenshot has too few highlights")
	_require(stats.bright_ratio < 0.24, "Combat overlay screenshot is too bright")
	_require(stats.unique_color_buckets >= 18, "Combat overlay screenshot has low color diversity")
	_require(_center_modal_bar_score(image) < 0.10, "Combat overlay center contains a wide modal-title-like black/gold banner")


func _center_modal_bar_score(image: Image) -> float:
	var rect := Rect2i(Vector2i(380, 300), Vector2i(1160, 360))
	var suspicious_rows := 0
	var sampled_rows := 0
	for y in range(rect.position.y, rect.end.y, 4):
		var longest := 0
		var run := 0
		var edge_hits := 0
		for x in range(rect.position.x, rect.end.x, 4):
			var c := image.get_pixel(x, y)
			var luma := c.get_luminance()
			var max_channel := maxf(c.r, maxf(c.g, c.b))
			var min_channel := minf(c.r, minf(c.g, c.b))
			var saturation := 0.0 if max_channel <= 0.001 else (max_channel - min_channel) / max_channel
			var is_ink_strip := luma < 0.12 and saturation < 0.38 and c.a > 0.25
			var is_gold_edge := c.r > c.b * 1.16 and c.g > c.b * 1.08 and luma > 0.14 and luma < 0.68
			var is_jade_edge := c.g >= c.r * 0.86 and c.b >= c.r * 0.70 and saturation > 0.10 and luma > 0.12 and luma < 0.58
			if is_gold_edge or is_jade_edge:
				edge_hits += 1
			if is_ink_strip or is_gold_edge:
				run += 1
				longest = maxi(longest, run)
			else:
				run = 0
		sampled_rows += 1
		if longest >= 176 and edge_hits >= 10:
			suspicious_rows += 1
	return float(suspicious_rows) / float(maxi(sampled_rows, 1))


func _sample_image_stats(image: Image) -> Dictionary:
	var total := 0
	var non_black := 0
	var bright := 0
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
	}


func _save_image(image: Image) -> void:
	if image == null:
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Failed to save screenshot to %s (error %d)" % [OUTPUT_PATH, error])


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
