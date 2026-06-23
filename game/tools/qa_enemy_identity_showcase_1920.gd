extends Node

const AssetPaths = preload("res://assets/asset_paths.gd")

const COMBAT_FLOOR_SCENE := preload("res://scenes/rooms/combat_floor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const SpriteVisual = preload("res://scenes/visual/sprite_visual.gd")
const PET_CONTROLLER_SCRIPT := preload("res://systems/pet/pet_controller.gd")

const TARGET_SIZE := Vector2i(1920, 1080)
const CAMERA_ZOOM := 1.5
const OUTPUT_PATH_TEMPLATE := "res://../output/visual_qa/enemy_identity_showcase_%s_1920.png"
const REPORT_PATH := "res://../output/visual_qa/enemy_identity_showcase_1920_report.txt"
const STYLE_CASES := ["normal", "chibi"]

const ENEMY_SPECS := [
	{"id": "wild_wolf", "name": "妖狼", "pos": Vector2(-330, -130), "status": "haste"},
	{"id": "crossbow_cultivator", "name": "弩修", "pos": Vector2(-120, -190), "status": "paralyze"},
	{"id": "shield_guard", "name": "护阵者", "pos": Vector2(130, -185), "status": "shield"},
	{"id": "sky_bat", "name": "腐翼妖蝠", "pos": Vector2(340, -112), "status": "poison"},
	{"id": "mud_serpent", "name": "泥泽游蛇", "pos": Vector2(-310, 116), "status": "slow"},
	{"id": "wind_mantis", "name": "风刃螳螂", "pos": Vector2(0, 165), "status": "windup"},
	{"id": "furnace_golem", "name": "火纹傀儡", "pos": Vector2(315, 120), "status": "burn"},
]

var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _viewport: SubViewport
var _world: Node2D
var _combat_floor: Node2D
var _player: CharacterBody2D
var _screen_points: Dictionary = {}


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	_report("Enemy identity showcase QA 1920x1080")
	_report("======================================")
	_prepare_output_dir()
	for style in STYLE_CASES:
		_report("")
		_report("Style case: %s" % style)
		_screen_points.clear()
		_prepare_run_state(style)
		_prepare_viewport(style)
		await get_tree().process_frame
		await get_tree().physics_frame
		_build_showcase()
		for _i in range(10):
			await get_tree().process_frame
		var image := _viewport.get_texture().get_image()
		_check_scene_contracts(style)
		_check_image_contracts(image, style)
		_save_image(image, style)
		_viewport.queue_free()
		_viewport = null
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		_write_report(1)
		return 1
	for style in STYLE_CASES:
		_report("Screenshot %s: %s" % [style, ProjectSettings.globalize_path(_output_path(style))])
	_report("Enemy identity showcase QA passed")
	_write_report(0)
	return 0


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/visual_qa"))


func _prepare_run_state(style: String) -> void:
	SaveManager.set_sprite_style(style)
	RunContext.seed_value = 786433
	RunContext.run_active = true
	RunContext.current_stage = 5
	RunContext.current_room = 3
	RunContext.gold = 240
	RunContext.realm_level = 5
	RunContext.pet_id = "huo_ying"
	RunContext.pet_display_name = "火萤"
	RunContext.pet_acquired = true
	RunContext.weapon_id = "lei_chi"
	RunContext.weapon_display_name = "雷池符扇"
	WeatherSystem.set_weather("thunder")


func _prepare_viewport(style: String) -> void:
	get_window().size = TARGET_SIZE
	get_tree().root.content_scale_size = TARGET_SIZE
	_viewport = SubViewport.new()
	_viewport.name = "EnemyIdentityViewport_%s" % style
	_viewport.size = TARGET_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	_world = Node2D.new()
	_world.name = "EnemyIdentityWorld_%s" % style
	_world.add_to_group("world_vfx")
	_viewport.add_child(_world)

	var camera := Camera2D.new()
	camera.name = "QACamera2D"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position = Vector2.ZERO
	camera.enabled = true
	_world.add_child(camera)


func _build_showcase() -> void:
	_combat_floor = COMBAT_FLOOR_SCENE.instantiate()
	_combat_floor.name = "QAEnemyIdentityFloor"
	_world.add_child(_combat_floor)
	await get_tree().process_frame
	_combat_floor.apply_theme(5)
	_combat_floor.apply_layout(_showcase_room(), RunRng.stage_room(5, 3, "combat_hard"), "thunder")

	_player = PLAYER_SCENE.instantiate()
	_player.name = "QAPlayer"
	_player.global_position = Vector2(0, 20)
	_world.add_child(_player)
	await get_tree().process_frame
	_player.apply_status("guard", 8.0)

	_spawn_pet()
	_spawn_boss()
	for spec in ENEMY_SPECS:
		_spawn_enemy(spec)
	await get_tree().process_frame


func _showcase_room() -> Dictionary:
	return {
		"type": "combat",
		"label": "敌阵照影 · 身份展示",
		"stage_index": 5,
		"room_index": 3,
		"weather_id": "thunder",
		"layout_profile": {
			"profile_id": "boss_clear",
			"preferred_pattern": "boss_clear",
			"terrain_feature_weights": {"thunder": 0.55, "wet": 0.2, "rock": 0.25},
			"terrain_feature_count_bias": 1,
		},
		"terrain_feature_weights": {"thunder": 0.55, "wet": 0.2, "rock": 0.25},
	}


func _spawn_pet() -> void:
	var pet := Node2D.new()
	pet.name = "QAPetHuoYing"
	pet.set_script(PET_CONTROLLER_SCRIPT)
	var visual := Sprite2D.new()
	visual.name = "BodyVisual"
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.set_script(SpriteVisual)
	visual.set("texture_path", AssetPaths.PET_HUO_YING)
	pet.add_child(visual)
	pet.global_position = _player.global_position + Vector2(-45, 26)
	_world.add_child(pet)
	_screen_points["pet_huo_ying"] = _world_to_screen(pet.global_position)


func _spawn_boss() -> void:
	var boss: CharacterBody2D = ENEMY_SCENE.instantiate()
	boss.name = "QAEnemy_boss"
	boss.global_position = Vector2(0, -230)
	_world.add_child(boss)
	await get_tree().process_frame
	boss.configure_enemy_by_id("boss", true, "boss", "关底守将")
	boss.apply_status("boss", 8.0)
	_require(_enemy_uses_expected_sprite(boss, "boss", "boss", true), "Boss did not use the dedicated boss sprite and frame route")
	_screen_points["boss"] = _world_to_screen(boss.global_position)


func _spawn_enemy(spec: Dictionary) -> void:
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.name = "QAEnemy_%s" % str(spec.get("id", "enemy"))
	enemy.global_position = spec.get("pos", Vector2.ZERO)
	_world.add_child(enemy)
	await get_tree().process_frame
	enemy.configure_enemy_by_id(str(spec.get("id", "")), false, "combat", str(spec.get("name", "")))
	enemy.apply_status(str(spec.get("status", "burn")), 8.0)
	if enemy.has_method("get_codex_id"):
		_require(enemy.get_codex_id() == str(spec.get("id", "")), "Enemy %s did not resolve expected identity; got %s" % [spec.get("id", ""), enemy.get_codex_id()])
	if enemy.has_method("is_elite_unit"):
		var enemy_row := EnemySpawnRegistry.get_enemy_row(str(spec.get("id", "")))
		var expected_elite := bool(enemy_row.get("is_elite", false))
		_require(enemy.is_elite_unit() == expected_elite, "Enemy %s elite flag expected %s, got %s" % [spec.get("id", ""), expected_elite, enemy.is_elite_unit()])
	var resolved_archetype := EnemySpawnRegistry.resolve_archetype_for_id(str(spec.get("id", "")), false, "combat")
	_require(_enemy_uses_expected_sprite(enemy, str(spec.get("id", "")), resolved_archetype, false), "Enemy %s did not use its dedicated sprite and frame route" % str(spec.get("id", "")))
	_screen_points[str(spec.get("id", ""))] = _world_to_screen(enemy.global_position)


func _world_to_screen(pos: Vector2) -> Vector2:
	return Vector2(TARGET_SIZE) * 0.5 + pos * CAMERA_ZOOM


func _check_scene_contracts(style: String) -> void:
	_require(_has_visible_sprite(_player), "Player BodyVisual has no visible texture")
	_require(get_tree().get_nodes_in_group("enemy").size() >= ENEMY_SPECS.size() + 1, "Expected boss plus seven enemy identities")
	for spec in ENEMY_SPECS:
		var suffix := "_chibi" if style == "chibi" else ""
		var dedicated := "res://assets/sprites/enemy_%s%s_64.png" % [str(spec.get("id", "")), suffix]
		_require(ResourceLoader.exists(dedicated), "Dedicated enemy asset missing: %s" % dedicated)
	var terrain_root := _combat_floor.find_child("TerrainRoot", true, false) if _combat_floor else null
	_require(terrain_root != null and terrain_root.get_child_count() >= 4, "Expected runtime terrain zones")


func _enemy_uses_expected_sprite(enemy: Node, enemy_id: String, archetype: String, is_boss: bool) -> bool:
	var sprite := enemy.get_node_or_null("BodyVisual") as Sprite2D
	if sprite == null:
		return false
	var expected := AssetPaths.enemy_sprite_for_identity(enemy_id, archetype, is_boss, SaveManager.get_sprite_style())
	var texture_path := str(sprite.get("texture_path"))
	_require(texture_path == expected, "Enemy `%s` texture path expected `%s`, got `%s`" % [enemy_id, expected, texture_path])
	if not is_boss:
		var expected_suffix := "_chibi_64.png" if SaveManager.get_sprite_style() == "chibi" else "_64.png"
		_require(texture_path.ends_with("enemy_%s%s" % [enemy_id, expected_suffix]), "Enemy `%s` style `%s` should use matching identity suffix, got `%s`" % [enemy_id, SaveManager.get_sprite_style(), texture_path])
	_report("%s | %s | %s | %s | %s" % [SaveManager.get_sprite_style(), enemy_id, archetype, texture_path, AssetPaths.animation_dir_for_texture(expected)])
	for prefix in ["idle", "walk", "combat"]:
		var frames := AssetPaths.animation_frame_paths_for_texture(expected, prefix)
		_require(frames.size() >= 4, "Enemy `%s` expected at least 4 `%s` frames, got %d" % [enemy_id, prefix, frames.size()])
		for path in frames:
			_require(ResourceLoader.exists(path), "Enemy `%s` frame path missing: %s" % [enemy_id, path])
	return texture_path == expected


func _check_image_contracts(image: Image, style: String) -> void:
	if image == null:
		_fail("Viewport image is null")
		return
	_require(image.get_width() == TARGET_SIZE.x and image.get_height() == TARGET_SIZE.y, "Screenshot must be 1920x1080")
	var stats := _sample_image_stats(image)
	_report("%s sampled non-black ratio: %.3f" % [style, stats.non_black_ratio])
	_report("%s sampled bright ratio: %.3f" % [style, stats.bright_ratio])
	_report("%s sampled unique color buckets: %d" % [style, stats.unique_color_buckets])
	_report("%s suspicious pure-color block pixels: magenta %d, red %d, max32 %d" % [
		style,
		int(stats.suspicious_magenta_pixels),
		int(stats.suspicious_red_pixels),
		int(stats.suspicious_max_bucket),
	])
	_require(stats.non_black_ratio > 0.55, "Screenshot appears mostly blank/dark")
	_require(stats.unique_color_buckets >= 28, "Screenshot has low color diversity")
	_require(int(stats.suspicious_max_bucket) < 72, "Enemy showcase contains a large saturated pure-color block, likely an unkeyed windup/weapon texture")
	for key in _screen_points.keys():
		var point: Vector2 = _screen_points[key]
		_require(_region_has_visible_pixels(image, point, 34), "No visible pixels near expected actor `%s` at %s" % [key, point])


func _region_has_visible_pixels(image: Image, center: Vector2, radius: int) -> bool:
	var hits := 0
	for y in range(int(center.y) - radius, int(center.y) + radius + 1, 4):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1, 4):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var color := image.get_pixel(x, y)
			if color.a > 0.1 and color.get_luminance() > 0.045:
				hits += 1
				if hits >= 6:
					return true
	return false


func _sample_image_stats(image: Image) -> Dictionary:
	var total := 0
	var non_black := 0
	var bright := 0
	var buckets := {}
	var suspicious_magenta_pixels := 0
	var suspicious_red_pixels := 0
	var suspicious_buckets := {}
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
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
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var color := image.get_pixel(x, y)
			var r := int(color.r * 255.0)
			var g := int(color.g * 255.0)
			var b := int(color.b * 255.0)
			var a := int(color.a * 255.0)
			var suspicious := false
			if a > 180 and r > 240 and b > 220 and g < 90:
				suspicious_magenta_pixels += 1
				suspicious = true
			elif a > 180 and r > 230 and g < 70 and b < 70:
				suspicious_red_pixels += 1
				suspicious = true
			elif a > 170 and r > 180 and b > 120 and g < 160:
				suspicious_magenta_pixels += 1
				suspicious = true
			elif a > 170 and r > 180 and g > 55 and g < 180 and b < 120:
				suspicious_red_pixels += 1
				suspicious = true
			if suspicious:
				var block_key := "%d_%d" % [int(x / 32), int(y / 32)]
				suspicious_buckets[block_key] = int(suspicious_buckets.get(block_key, 0)) + 1
	var max_suspicious_bucket := 0
	for value in suspicious_buckets.values():
		max_suspicious_bucket = maxi(max_suspicious_bucket, int(value))
	return {
		"non_black_ratio": float(non_black) / float(maxi(total, 1)),
		"bright_ratio": float(bright) / float(maxi(total, 1)),
		"unique_color_buckets": buckets.size(),
		"suspicious_magenta_pixels": suspicious_magenta_pixels,
		"suspicious_red_pixels": suspicious_red_pixels,
		"suspicious_max_bucket": max_suspicious_bucket,
	}


func _has_visible_sprite(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var sprite := node.get_node_or_null("BodyVisual") as Sprite2D
	return sprite != null and sprite.visible and sprite.texture != null


func _save_image(image: Image, style: String) -> void:
	if image == null:
		return
	var output_path := _output_path(style)
	var error := image.save_png(output_path)
	if error != OK:
		_fail("Failed to save screenshot to %s (error %d)" % [output_path, error])


func _output_path(style: String) -> String:
	return OUTPUT_PATH_TEMPLATE % style


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
