extends Node

const StageGenerator = preload("res://systems/world/stage_generator.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")
const SpriteVisual = preload("res://scenes/visual/sprite_visual.gd")

const COMBAT_FLOOR_SCENE := preload("res://scenes/rooms/combat_floor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/combat/enemy_projectile.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const PET_CONTROLLER_SCRIPT := preload("res://systems/pet/pet_controller.gd")
const CRIT_SLASH_DRAW_SCRIPT := preload("res://vfx/crit_slash_draw.gd")

const TARGET_SIZE := Vector2i(1920, 1080)
const CAMERA_ZOOM := 1.5
const OUTPUT_PATH := "res://../output/visual_qa/combat_visual_integration_1920.png"
const REPORT_PATH := "res://../output/visual_qa/combat_visual_integration_1920_report.txt"
const SAMPLE_SEED := 786433
const SAMPLE_STAGE_INDEX := 5
const SAMPLE_WEATHER_ID := "thunder"
const MAP_MATRIX_CAPTURES := [
	{"stage": 1, "theme": "qi_refining_verdant", "weather": "clear"},
	{"stage": 1, "theme": "qi_refining_verdant", "weather": "rain"},
	{"stage": 1, "theme": "qi_refining_verdant", "weather": "fog"},
	{"stage": 2, "theme": "foundation_cavern", "weather": "rain"},
	{"stage": 2, "theme": "foundation_cavern", "weather": "fog"},
	{"stage": 2, "theme": "foundation_cavern", "weather": "thunder"},
	{"stage": 3, "theme": "golden_core_demon", "weather": "fire"},
	{"stage": 3, "theme": "golden_core_demon", "weather": "thunder"},
	{"stage": 3, "theme": "golden_core_demon", "weather": "sand"},
	{"stage": 4, "theme": "nascent_soul_ruins", "weather": "fire"},
	{"stage": 4, "theme": "nascent_soul_ruins", "weather": "fog"},
	{"stage": 4, "theme": "nascent_soul_ruins", "weather": "snow"},
	{"stage": 5, "theme": "tribulation_thunder", "weather": "thunder"},
	{"stage": 5, "theme": "tribulation_thunder", "weather": "rain"},
	{"stage": 5, "theme": "tribulation_thunder", "weather": "wind"},
]
const MIN_BRIGHT_RATIO := 0.008
const MAX_BRIGHT_RATIO := 0.24
const MAX_MEAN_LUMINANCE := 0.34
const MAX_FLOOR_DETAIL_ALPHA := 0.18

var _failures: Array[String] = []
var _report_lines: Array[String] = []
var _viewport: SubViewport
var _world: Node2D
var _hud: CanvasLayer
var _combat_floor: Node2D
var _player: CharacterBody2D
var _boss_enemy: CharacterBody2D
var _pet_controller: Node2D
var _captured_image: Image
var _spawn_telegraph_markers: Array[Node2D] = []
var _attack_telegraph_markers: Array[Node2D] = []
var _player_projectiles: Array[Area2D] = []
var _enemy_projectiles: Array[Area2D] = []
var _crit_slash_draw: Control
var _reduced_impact_mark: Node


func _init() -> void:
	call_deferred("_run_and_quit")


func _run_and_quit() -> void:
	var code := await _run()
	get_tree().quit(code)


func _run() -> int:
	_report("Visual integration QA 1920x1080")
	_report("=================================")
	_prepare_output_dir()
	_prepare_run_state()
	_prepare_viewport()
	await get_tree().process_frame
	await get_tree().physics_frame
	await _build_combat_showcase()
	await get_tree().process_frame
	await get_tree().physics_frame
	_feed_hud_signals()
	_spawn_showcase_vfx()
	for _i in range(8):
		await get_tree().process_frame
	_feed_hud_feedback_signals()
	await get_tree().process_frame
	await _check_image2_fx_texture_contracts()
	_captured_image = _viewport.get_texture().get_image()
	_check_scene_contracts()
	_check_image_contracts(_captured_image)
	_save_image(_captured_image)
	await _capture_map_weather_matrix()
	if not _failures.is_empty():
		_report("Failures: %d" % _failures.size())
		for failure in _failures:
			_report("- %s" % failure)
		_write_report(1)
		return 1
	_report("Screenshot: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	_report("Visual integration QA passed")
	_write_report(0)
	return 0


func _capture_map_weather_matrix() -> void:
	for spec in MAP_MATRIX_CAPTURES:
		await _capture_map_weather_case(spec)


func _capture_map_weather_case(spec: Dictionary) -> void:
	_reset_viewport_world()
	var stage_index := int(spec.get("stage", 1))
	var theme_id := str(spec.get("theme", "stage_%d" % stage_index))
	var weather_id := str(spec.get("weather", "clear"))
	_prepare_matrix_run_state(stage_index, weather_id)
	var plan: Array = StageGenerator.generate(1, {})
	var stage: Dictionary = _stage_by_index(plan, stage_index)
	var room: Dictionary = _first_room_of_type(stage, "combat_hard")
	if room.is_empty():
		room = _first_room_of_type(stage, "combat")
	if room.is_empty():
		_fail("Map matrix stage %d has no combat room" % stage_index)
		return
	room["weather_id"] = weather_id
	room["label"] = "地图矩阵 · %s · %s" % [theme_id, weather_id]

	_combat_floor = COMBAT_FLOOR_SCENE.instantiate()
	_combat_floor.name = "QAMatrixCombatFloor_%d_%s" % [stage_index, weather_id]
	_world.add_child(_combat_floor)
	await get_tree().process_frame
	_combat_floor.apply_theme(stage_index)
	var rng := RunRng.stage_room(stage_index, int(room.get("room_index", 0)), str(room.get("type", "combat")))
	_combat_floor.apply_layout(room, rng, weather_id)

	_player = PLAYER_SCENE.instantiate()
	_player.name = "QAMatrixPlayer_%d_%s" % [stage_index, weather_id]
	_player.global_position = Vector2(0, 110)
	_world.add_child(_player)
	await get_tree().process_frame
	_player.velocity = Vector2(80, -20)

	await _spawn_matrix_enemies(stage_index, weather_id)
	for _i in range(8):
		await get_tree().process_frame
	if weather_id == "thunder" and _combat_floor != null:
		_combat_floor.call("_spawn_thunder_strike_batch")
		for _i in range(3):
			await get_tree().process_frame
	var image := _viewport.get_texture().get_image()
	_check_map_weather_case_contracts(spec, room, image)
	_save_matrix_image(image, stage_index, theme_id, weather_id)


func _reset_viewport_world() -> void:
	for child in _viewport.get_children():
		_viewport.remove_child(child)
		child.queue_free()
	_world = Node2D.new()
	_world.name = "VisualIntegrationMatrixWorld"
	_world.add_to_group("world_vfx")
	_viewport.add_child(_world)
	var camera := Camera2D.new()
	camera.name = "QAMatrixCamera2D"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position = Vector2.ZERO
	camera.enabled = true
	_world.add_child(camera)
	_hud = null
	_combat_floor = null
	_player = null
	_boss_enemy = null
	_spawn_telegraph_markers.clear()
	_attack_telegraph_markers.clear()
	_player_projectiles.clear()
	_enemy_projectiles.clear()
	_crit_slash_draw = null
	_reduced_impact_mark = null


func _prepare_matrix_run_state(stage_index: int, weather_id: String) -> void:
	RunContext.seed_value = SAMPLE_SEED
	RunContext.run_active = true
	RunContext.current_stage = stage_index
	RunContext.current_room = 1
	RunContext.rooms_cleared = maxi(stage_index - 1, 0) * 4
	RunContext.gold = 120 + stage_index * 40
	RunContext.realm_level = stage_index
	RunContext.affix_slot_cap = 5 + stage_index
	RunContext.ui_blocking = false
	RunContext.pet_id = "huo_ying"
	RunContext.pet_display_name = "火萤"
	RunContext.pet_acquired = true
	SaveManager.set_display_setting("reduce_motion", false)
	WeatherSystem.set_weather(weather_id)


func _spawn_matrix_enemies(stage_index: int, weather_id: String) -> void:
	var statuses := {
		"clear": "haste",
		"rain": "wet",
		"fog": "slow",
		"thunder": "paralyze",
		"fire": "burn",
		"sand": "slow",
		"snow": "freeze",
		"wind": "haste",
	}
	var status := str(statuses.get(weather_id, "burn"))
	var positions := [Vector2(-220, -80), Vector2(210, -60), Vector2(0, -190)]
	for i in range(positions.size()):
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
		enemy.name = "QAMatrixEnemy_%d_%s_%d" % [stage_index, weather_id, i]
		enemy.global_position = positions[i]
		_world.add_child(enemy)
		await get_tree().process_frame
		enemy.configure_enemy("矩阵妖影%d" % (i + 1), false, "combat_hard")
		enemy.apply_status(status, 5.0)
		enemy.set("_steer_velocity", Vector2(90.0, -25.0))
		enemy.queue_redraw()


func _check_map_weather_case_contracts(spec: Dictionary, room: Dictionary, image: Image) -> void:
	var stage_index := int(spec.get("stage", 1))
	var theme_id := str(spec.get("theme", ""))
	var weather_id := str(spec.get("weather", "clear"))
	_require(image != null, "Map matrix %s/%s viewport image is null" % [theme_id, weather_id])
	if image != null:
		_require(image.get_width() == TARGET_SIZE.x and image.get_height() == TARGET_SIZE.y, "Map matrix %s/%s screenshot must be 1920x1080" % [theme_id, weather_id])
		var stats := _sample_image_stats(image)
		_report("Matrix stage %d %s/%s non-black %.3f bright %.3f mean %.3f colors %d" % [
			stage_index,
			theme_id,
			weather_id,
			stats.non_black_ratio,
			stats.bright_ratio,
			stats.mean_luminance,
			stats.unique_color_buckets,
		])
		_require(stats.non_black_ratio > 0.55, "Map matrix %s/%s appears mostly blank/dark" % [theme_id, weather_id])
		_require(stats.bright_ratio < _matrix_max_bright_ratio(weather_id), "Map matrix %s/%s is too globally bright" % [theme_id, weather_id])
		_require(stats.mean_luminance < _matrix_max_mean_luminance(weather_id), "Map matrix %s/%s mean luminance is too high" % [theme_id, weather_id])
		_require(stats.unique_color_buckets >= 24, "Map matrix %s/%s has low color diversity" % [theme_id, weather_id])
		if theme_id == "golden_core_demon" and weather_id in ["fire", "sand"]:
			var palette := _sample_center_palette_stats(image)
			_report("Matrix %s/%s palette warm %.3f jade %.3f cold_gold %.3f neutral %.3f" % [
				theme_id,
				weather_id,
				palette.warm_ratio,
				palette.jade_ratio,
				palette.cold_gold_ratio,
				palette.neutral_dark_ratio,
			])
			_require(palette.warm_ratio <= 0.10, "Map matrix %s/%s regressed toward warm Diablo-like red/brown wash" % [theme_id, weather_id])
			_require(palette.jade_ratio >= 0.025, "Map matrix %s/%s should retain black-jade/cool ink signal" % [theme_id, weather_id])
			var neutral_floor := 0.012 if weather_id == "fire" else 0.42
			_require(palette.neutral_dark_ratio >= neutral_floor, "Map matrix %s/%s should keep a dark neutral ink foundation" % [theme_id, weather_id])
			_require(palette.jade_ratio + palette.neutral_dark_ratio >= 0.58, "Map matrix %s/%s should keep a dark ink or black-jade foundation" % [theme_id, weather_id])
			_require(palette.jade_ratio + palette.cold_gold_ratio >= 0.055, "Map matrix %s/%s should read as black-jade/cold-gold, not earth/brown" % [theme_id, weather_id])
	_require(_combat_floor != null and is_instance_valid(_combat_floor), "Map matrix %s/%s CombatFloor missing" % [theme_id, weather_id])
	if _combat_floor == null:
		return
	var background := _combat_floor.find_child("Background", true, false) as Sprite2D
	_require(background != null and background.texture != null, "Map matrix %s/%s missing background texture" % [theme_id, weather_id])
	if background != null and background.texture != null:
		_require(background.texture.resource_path == str(room.get("room_background", "")), "Map matrix %s/%s background does not match manifest room_background" % [theme_id, weather_id])
	var terrain_root := _combat_floor.find_child("TerrainRoot", true, false)
	_require(terrain_root != null and terrain_root.get_child_count() >= 2, "Map matrix %s/%s expected terrain zones" % [theme_id, weather_id])
	if terrain_root != null:
		_require(_count_textured_sprites_recursive(terrain_root) >= 2, "Map matrix %s/%s terrain zones should render image2 texture sprites" % [theme_id, weather_id])
	var used_cells := int(_combat_floor.call("get_floor_detail_used_cell_count"))
	var max_cells := int(_combat_floor.call("get_floor_detail_max_cell_count"))
	var alpha := float(_combat_floor.call("get_floor_detail_alpha"))
	_require(used_cells > 0 and used_cells <= max_cells, "Map matrix %s/%s floor detail cells invalid" % [theme_id, weather_id])
	_require(alpha <= MAX_FLOOR_DETAIL_ALPHA, "Map matrix %s/%s floor detail alpha too high" % [theme_id, weather_id])
	var weather_overlay := _combat_floor.find_child("WeatherOverlay", true, false) if _combat_floor else null
	_require(weather_overlay != null, "Map matrix %s/%s missing WeatherOverlay" % [theme_id, weather_id])
	if weather_id == "clear":
		if weather_overlay != null and weather_overlay.has_method("get_weather_particle_count"):
			_require(int(weather_overlay.call("get_weather_particle_count")) == 0, "Map matrix clear weather should not spawn weather particles")
	else:
		_require(weather_overlay != null and weather_overlay.visible, "Map matrix %s/%s WeatherOverlay should be visible" % [theme_id, weather_id])
		if weather_overlay != null:
			_require(int(weather_overlay.call("get_weather_particle_count")) > 0, "Map matrix %s/%s expected weather particles" % [theme_id, weather_id])
			_require(int(weather_overlay.call("get_weather_particle_texture_hit_count")) > 0, "Map matrix %s/%s expected image2 weather particle texture hit" % [theme_id, weather_id])
		var weather_root := _combat_floor.find_child("WeatherGroundRoot", true, false)
		_require(weather_root != null and _count_textured_sprites(weather_root) >= 1, "Map matrix %s/%s expected image2 weather ground decals" % [theme_id, weather_id])
	if weather_id == "thunder":
		var thunder_root := _combat_floor.find_child("ThunderStrikeRoot", true, false)
		var thunder_markers := thunder_root.find_children("ThunderStrikeMarker*", "", true, false) if thunder_root else []
		_require(thunder_markers.size() >= 2, "Map matrix %s/%s expected thunder strike markers" % [theme_id, weather_id])
		for marker in thunder_markers:
			_require(_node_texture(marker, "warning_texture") != null, "Map matrix thunder marker missing warning texture")
			_require(_node_texture(marker, "impact_texture") != null, "Map matrix thunder marker missing impact texture")
			_require(_node_texture(marker, "bolt_texture") != null, "Map matrix thunder marker missing bolt texture")
			_require(_node_texture(marker, "scorch_texture") != null, "Map matrix thunder marker missing scorch texture")


func _matrix_max_bright_ratio(weather_id: String) -> float:
	match weather_id:
		"snow", "fog":
			return 0.18
		"fire", "sand":
			return 0.20
		_:
			return 0.16


func _matrix_max_mean_luminance(weather_id: String) -> float:
	match weather_id:
		"snow", "fog":
			return 0.38
		"fire", "sand":
			return 0.36
		_:
			return 0.34


func _matrix_output_path(stage_index: int, theme_id: String, weather_id: String) -> String:
	return "res://../output/visual_qa/map_matrix_stage%d_%s_%s_1920.png" % [stage_index, theme_id, weather_id]


func _save_matrix_image(image: Image, stage_index: int, theme_id: String, weather_id: String) -> void:
	if image == null:
		return
	var path := _matrix_output_path(stage_index, theme_id, weather_id)
	var error := image.save_png(path)
	if error != OK:
		_fail("Failed to save map matrix screenshot to %s (error %d)" % [path, error])
	else:
		_report("Matrix screenshot: %s" % ProjectSettings.globalize_path(path))


func _prepare_output_dir() -> void:
	var global_dir := ProjectSettings.globalize_path("res://../output/visual_qa")
	DirAccess.make_dir_recursive_absolute(global_dir)


func _prepare_run_state() -> void:
	RunContext.seed_value = SAMPLE_SEED
	RunContext.run_active = true
	RunContext.current_stage = SAMPLE_STAGE_INDEX
	RunContext.current_room = 2
	RunContext.rooms_cleared = 12
	RunContext.gold = 240
	RunContext.realm_level = 5
	RunContext.affix_slot_cap = 11
	RunContext.ui_blocking = false
	RunContext.dao_momentum = 72.0
	RunContext.dao_momentum_max = 100.0
	RunContext.dao_momentum_state = "idle"
	RunContext.dao_momentum_state_time = 0.0
	RunContext.pet_id = "huo_ying"
	RunContext.pet_display_name = "火萤"
	RunContext.pet_acquired = true
	RunContext.weapon_id = "lei_chi"
	RunContext.weapon_display_name = "雷池符扇"
	SaveManager.set_display_setting("reduce_motion", false)
	WeatherSystem.set_weather(SAMPLE_WEATHER_ID)


func _prepare_viewport() -> void:
	get_window().size = TARGET_SIZE
	get_tree().root.content_scale_size = TARGET_SIZE
	_viewport = SubViewport.new()
	_viewport.name = "VisualIntegrationViewport"
	_viewport.size = TARGET_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	_world = Node2D.new()
	_world.name = "VisualIntegrationWorld"
	_world.add_to_group("world_vfx")
	_viewport.add_child(_world)

	var camera := Camera2D.new()
	camera.name = "QACamera2D"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position = Vector2.ZERO
	camera.enabled = true
	_world.add_child(camera)


func _build_combat_showcase() -> void:
	var plan: Array = StageGenerator.generate(1, {})
	var stage: Dictionary = _stage_by_index(plan, SAMPLE_STAGE_INDEX)
	var room: Dictionary = _first_room_of_type(stage, "boss")
	if room.is_empty():
		_fail("No boss room found for stage %d" % SAMPLE_STAGE_INDEX)
		return
	room["weather_id"] = SAMPLE_WEATHER_ID
	room["label"] = "雷劫终局 · 截图 QA"

	_combat_floor = COMBAT_FLOOR_SCENE.instantiate()
	_combat_floor.name = "QACombatFloor"
	_world.add_child(_combat_floor)
	await get_tree().process_frame
	_combat_floor.apply_theme(SAMPLE_STAGE_INDEX)
	var rng := RunRng.stage_room(SAMPLE_STAGE_INDEX, int(room.get("room_index", 0)), str(room.get("type", "boss")))
	_combat_floor.apply_layout(room, rng, SAMPLE_WEATHER_ID)

	_player = PLAYER_SCENE.instantiate()
	_player.name = "QAPlayer"
	_player.global_position = Vector2(0, 120)
	_world.add_child(_player)
	await get_tree().process_frame
	_player.velocity = Vector2(160, -40)
	_player.apply_status("burn", 4.0)
	_player.apply_status("poison", 4.0)
	_player.grant_guardian_invuln(4.0)

	await _spawn_enemies()
	await _spawn_pet()
	await _spawn_projectiles()
	await _spawn_enemy_projectiles()
	await _spawn_combat_action_fx_showcase()
	_add_hud()


func _spawn_enemies() -> void:
	var specs := [
		{"name": "雷劫守将", "boss": true, "pos": Vector2(0, -170), "status": "burn"},
		{"name": "劫雷剑修", "boss": false, "pos": Vector2(-230, -45), "status": "freeze"},
		{"name": "魔化符师", "boss": false, "pos": Vector2(250, -28), "status": "poison"},
		{"name": "越阶雷卫", "boss": false, "pos": Vector2(-320, 190), "status": "paralyze"},
		{"name": "渡劫残影", "boss": false, "pos": Vector2(330, 180), "status": "slow"},
	]
	for spec in specs:
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
		enemy.name = "QAEnemy_%s" % str(spec.get("name", "enemy"))
		enemy.global_position = spec.get("pos", Vector2.ZERO)
		_world.add_child(enemy)
		await get_tree().process_frame
		enemy.configure_enemy(str(spec.get("name", "妖魔")), bool(spec.get("boss", false)), "boss" if bool(spec.get("boss", false)) else "combat_hard")
		enemy.apply_status(str(spec.get("status", "burn")), 6.0)
		enemy.set("_steer_velocity", Vector2(180.0, -42.0))
		enemy.queue_redraw()
		if bool(spec.get("boss", false)):
			_boss_enemy = enemy
			if enemy.has_node("HealthComponent"):
				var health := enemy.get_node("HealthComponent")
				health.set("max_hp", 800.0)
				health.set("current_hp", 480.0)


func _spawn_pet() -> void:
	var pet := Node2D.new()
	pet.name = "QAPetHuoYing"
	pet.set_script(PET_CONTROLLER_SCRIPT)
	_pet_controller = pet
	var visual := Sprite2D.new()
	visual.name = "BodyVisual"
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.set_script(SpriteVisual)
	visual.set("texture_path", AssetPaths.PET_HUO_YING)
	pet.add_child(visual)
	pet.global_position = _player.global_position + Vector2(-32, -12)
	_world.add_child(pet)
	await get_tree().process_frame
	if pet.has_method("bind_player"):
		pet.bind_player(_player)
	if pet.has_method("try_coordinated_skill"):
		pet.try_coordinated_skill(Vector2.RIGHT)


func _spawn_projectiles() -> void:
	var specs := [
		{"element": "fire", "status": "burn", "color": Color(1.0, 0.22, 0.08), "pos": Vector2(-145, 70), "dir": Vector2.RIGHT},
		{"element": "thunder", "status": "paralyze", "color": Color(0.48, 0.42, 1.0), "pos": Vector2(130, 60), "dir": Vector2(-1, -0.2)},
		{"element": "wood", "status": "poison", "color": Color(0.18, 0.95, 0.38), "pos": Vector2(-80, -45), "dir": Vector2(0.8, -0.15)},
		{"element": "earth", "status": "slow", "color": Color(0.88, 0.68, 0.25), "pos": Vector2(75, -82), "dir": Vector2(-0.9, 0.1)},
	]
	for spec in specs:
		var projectile: Area2D = PROJECTILE_SCENE.instantiate()
		projectile.name = "QAProjectile_%s" % str(spec.get("element", "element"))
		projectile.global_position = spec.get("pos", Vector2.ZERO)
		_world.add_child(projectile)
		await get_tree().process_frame
		projectile.setup(
			spec.get("dir", Vector2.RIGHT),
			18.0,
			_player,
			220.0,
			8.0,
			spec.get("color", Color.WHITE),
			2,
			str(spec.get("element", "fire")),
			420.0,
			"visual_qa",
			str(spec.get("status", "")),
			2.0,
			3,
			"base",
			2
		)
		_player_projectiles.append(projectile)


func _spawn_enemy_projectiles() -> void:
	var specs := [
		{"element": "fire", "status": "burn", "color": Color(1.0, 0.32, 0.12), "pos": Vector2(18, 40), "dir": Vector2(-1.0, 0.05)},
		{"element": "thunder", "status": "paralyze", "color": Color(0.58, 0.82, 1.0), "pos": Vector2(180, -118), "dir": Vector2(-0.7, 0.25)},
		{"element": "wood", "status": "poison", "color": Color(0.42, 1.0, 0.36), "pos": Vector2(-210, 125), "dir": Vector2(0.85, -0.1)},
		{"element": "earth", "status": "slow", "color": Color(0.82, 0.66, 0.28), "pos": Vector2(300, 112), "dir": Vector2(-0.95, -0.25)},
	]
	for spec in specs:
		var projectile: Area2D = ENEMY_PROJECTILE_SCENE.instantiate()
		projectile.name = "QAEnemyProjectile_%s" % str(spec.get("element", "element"))
		projectile.global_position = spec.get("pos", Vector2.ZERO)
		_world.add_child(projectile)
		await get_tree().process_frame
		projectile.setup(
			spec.get("dir", Vector2.LEFT),
			12.0,
			170.0,
			6.0,
			spec.get("color", Color.WHITE),
			str(spec.get("element", "")),
			str(spec.get("status", "")),
			2.0,
			"visual_qa_enemy_projectile"
		)
		_enemy_projectiles.append(projectile)


func _spawn_combat_action_fx_showcase() -> void:
	if _player != null and is_instance_valid(_player):
		_player.call("_spawn_slash_arc", Vector2(1.0, -0.18).normalized(), 106.0, 92.0)
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == null or not is_instance_valid(node):
			continue
		node.set("_steer_velocity", Vector2(180.0, -55.0))
		if node.has_method("queue_redraw"):
			node.queue_redraw()
		if node.has_method("set_enemy_weapon_id"):
			node.call("set_enemy_weapon_id", "soul_banner")
		if node.has_method("debug_force_windup"):
			node.call("debug_force_windup", "melee", 0.68)
			break
	_crit_slash_draw = Control.new()
	_crit_slash_draw.name = "QACritSlashDraw"
	_crit_slash_draw.set_script(CRIT_SLASH_DRAW_SCRIPT)
	_crit_slash_draw.size = Vector2(760, 260)
	_crit_slash_draw.position = Vector2(-380, -315)
	_world.add_child(_crit_slash_draw)
	await get_tree().process_frame
	if _crit_slash_draw.has_method("play"):
		_crit_slash_draw.call("play", 0.8, Color(0.72, 0.95, 1.0, 1.0))


func _add_hud() -> void:
	_hud = HUD_SCENE.instantiate()
	_hud.name = "QAHUD"
	_viewport.add_child(_hud)


func _feed_hud_signals() -> void:
	var stage := {
		"stage_index": SAMPLE_STAGE_INDEX,
		"name": "天劫试场",
		"theme_id": "tribulation_thunder",
	}
	var room := {
		"type": "boss",
		"label": "雷劫终局",
		"stage_index": SAMPLE_STAGE_INDEX,
		"room_index": 2,
		"weather_id": SAMPLE_WEATHER_ID,
	}
	EventBus.run_started.emit(SAMPLE_SEED)
	EventBus.room_entered.emit(room, stage)
	EventBus.player_hp_changed.emit(82.0, 120.0)
	EventBus.realm_changed.emit(5, 11)
	EventBus.gold_changed.emit(RunContext.gold)
	EventBus.combo_updated.emit(128)
	EventBus.horde_updated.emit(12, 30, 91.0, 2, 8.0)
	EventBus.dao_momentum_changed.emit(72.0, 100.0, "idle", 0.0)
	EventBus.pet_acquired.emit("huo_ying")
	WeatherSystem.set_weather(SAMPLE_WEATHER_ID)
	_force_hud_spell_slot_showcase()
	_force_hud_combat_rail_showcase()
	_feed_hud_feedback_signals()


func _force_hud_spell_slot_showcase() -> void:
	var skill_dock := _hud.get_node_or_null("Root/SkillDock") if _hud != null else null
	if skill_dock == null or not skill_dock.has_method("apply_spell_states"):
		_fail("HUD SkillDock missing apply_spell_states for SpellQ/E/R texture QA")
		return
	skill_dock.apply_spell_states({
		"q": {
			"name": "烈焰符",
			"unlocked": true,
			"cd_remaining": 1.6,
			"cd_total": 4.0,
			"casting": false,
			"spell_id": "lie_yan_bolt",
			"element": "fire",
		},
		"e": {
			"name": "玉剑阵",
			"unlocked": true,
			"cd_remaining": 2.4,
			"cd_total": 6.0,
			"casting": false,
			"spell_id": "yu_jian_thrust",
			"element": "thunder",
		},
		"r": {
			"name": "雷池扇",
			"unlocked": true,
			"cd_remaining": 3.8,
			"cd_total": 8.0,
			"casting": false,
			"spell_id": "lei_chi_chain",
			"element": "thunder",
		},
	})


func _force_hud_combat_rail_showcase() -> void:
	var rail := _hud.get_node_or_null("Root/RightCombatRail") if _hud != null else null
	if rail == null or not rail.has_method("push_action"):
		_fail("HUD RightCombatRail missing push_action for texture QA")
		return
	rail.call("push_action", "破势 +128", UiTokens.ACCENT_GOLD)


func _feed_hud_feedback_signals() -> void:
	EventBus.boss_health_changed.emit("QA劫主", 600.0, 900.0, 1, 3, "劫火四起")
	EventBus.learn_feedback.emit("道统觉醒\n雷火法修", "skill")


func _spawn_showcase_vfx() -> void:
	if VfxManager == null:
		return
	_spawn_telegraph_markers.clear()
	_attack_telegraph_markers.clear()
	VfxManager.spawn_world_semantic(Vector2(-115, -70), "hit", Color(1.0, 0.25, 0.08), "fire", "burn", 3)
	VfxManager.spawn_world_semantic(Vector2(88, -95), "hit", Color(0.52, 0.38, 1.0), "thunder", "paralyze", 3)
	SaveManager.set_display_setting("reduce_motion", true)
	VfxManager.spawn_world_semantic(Vector2(190, 20), "hit", Color(0.42, 1.0, 0.36), "wood", "poison", 2)
	SaveManager.set_display_setting("reduce_motion", false)
	var reduced_marks := _find_named_nodes("*ReducedImpactMark*")
	_reduced_impact_mark = reduced_marks.front() if not reduced_marks.is_empty() else null
	if _reduced_impact_mark != null and is_instance_valid(_reduced_impact_mark):
		_reduced_impact_mark.set("duration", 2.5)
	_track_spawn_telegraph(VfxManager.spawn_enemy_telegraph(Vector2(0, -170), true, 2.5))
	_track_spawn_telegraph(VfxManager.spawn_enemy_telegraph(Vector2(-235, -45), false, 2.5))
	_track_attack_telegraph(VfxManager.spawn_enemy_attack_telegraph(Vector2(0, -170), Vector2(0, 1), 260.0, 2.5, 16.0, Color(1.0, 0.32, 0.18, 0.95), "melee"))
	_track_attack_telegraph(VfxManager.spawn_enemy_attack_telegraph(Vector2(-230, -45), Vector2(1, 0.20), 220.0, 2.5, 8.0, Color(1.0, 0.40, 0.20, 0.95), "line"))
	_track_attack_telegraph(VfxManager.spawn_enemy_attack_telegraph(Vector2(-320, 190), Vector2(1, -0.18), 260.0, 2.5, 13.0, Color(1.0, 0.46, 0.18, 0.95), "dash"))
	_track_attack_telegraph(VfxManager.spawn_enemy_attack_telegraph(Vector2(330, 180), Vector2(-1, -0.35), 300.0, 2.5, 5.0, Color(1.0, 0.28, 0.22, 0.95), "sniper"))
	VfxManager.spawn_gold_reward_feedback(Vector2(-72, 16), 32)


func _check_scene_contracts() -> void:
	_require(_viewport != null and _viewport.size == TARGET_SIZE, "SubViewport must be 1920x1080")
	_require(_combat_floor != null and is_instance_valid(_combat_floor), "CombatFloor instance missing")
	_require(_player != null and is_instance_valid(_player), "Player instance missing")
	_require(_hud != null and is_instance_valid(_hud), "HUD instance missing")
	_check_hud_feedback_contracts()
	_check_hud_skill_dock_texture_contracts()
	_check_hud_resource_bar_texture_contracts()
	_check_hud_status_orb_texture_contracts()
	_check_hud_companion_artifact_texture_contracts()
	_check_hud_combat_rail_texture_contracts()
	_require(get_tree().get_nodes_in_group("enemy").size() >= 5, "Expected at least five enemies in rendered showcase")
	_require(get_tree().get_nodes_in_group("pet").size() >= 1, "Expected pet controller in rendered showcase")
	_require(_has_visible_sprite(_player), "Player BodyVisual has no visible texture")
	_check_world_pet_texture_contracts()
	_require(_has_visible_sprite(_boss_enemy), "Boss enemy BodyVisual has no visible texture")
	_check_enemy_world_plate_texture_contracts()
	_check_status_icon_texture_contracts()
	var terrain_root := _combat_floor.find_child("TerrainRoot", true, false) if _combat_floor else null
	_require(terrain_root != null and terrain_root.get_child_count() >= 5, "Expected runtime terrain zones from CombatFloor/TerrainSystem")
	var weather_overlay := _combat_floor.find_child("WeatherOverlay", true, false) if _combat_floor else null
	_require(weather_overlay != null, "Expected CombatFloor weather overlay")
	_check_floor_layer_contract()


func _check_hud_feedback_contracts() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var top_anchor := _hud.get_node_or_null("Root/TopObjectiveAnchor") as Control
	var objective_text := _hud.get_node_or_null("Root/TopObjectiveAnchor/VBox/ObjectiveText") as Label
	var ticks := _hud.get_node_or_null("Root/TopObjectiveAnchor/VBox/ObjectiveProgress/BossPhaseTicks") as Control
	if objective_text != null:
		_report("HUD objective text: %s" % objective_text.text)
	_require(_hud.get_node_or_null("Root/LearnToastPanel") == null, "HUD must not keep legacy LearnToastPanel; learn feedback belongs in the rail")
	_require(_hud.get_node_or_null("Root/LearnToastPanel/Margin/Body/ScrollBg") == null, "HUD must not keep legacy scroll toast backing that can leak as a center banner")
	_check_no_center_banner_controls(_hud)
	_require(top_anchor != null and top_anchor.visible, "HUD Boss top objective should be visible after boss_health_changed")
	_require(objective_text != null and objective_text.text.contains("BOSS") and objective_text.text.contains("劫火四起"), "HUD Boss objective text missing boss label or phase")
	_require(ticks != null and ticks.visible, "HUD Boss phase ticks should be visible for multi-phase boss")
	if ticks != null:
		_require(ticks.get_child_count() == 2, "HUD Boss phase tick count should be phase_count - 1")


func _check_no_center_banner_controls(root: Node) -> void:
	var combat_center_safe := Rect2(Vector2(420.0, 320.0), Vector2(1080.0, 300.0))
	var offenders: Array[String] = []
	_collect_center_banner_controls(root, combat_center_safe, offenders)
	_require(offenders.is_empty(), "No wide HUD banner control should overlap center combat safe area: %s" % ", ".join(offenders))


func _collect_center_banner_controls(node: Node, safe_rect: Rect2, offenders: Array[String]) -> void:
	for child in node.get_children():
		var control := child as Control
		if control != null and control.visible:
			var rect := Rect2(control.global_position, control.size * control.scale)
			var is_wide_banner := rect.size.x >= 520.0 and rect.size.y >= 24.0 and rect.size.y <= 120.0
			if is_wide_banner and rect.intersects(safe_rect) and _is_hud_banner_candidate(control):
				offenders.append(control.get_path())
		_collect_center_banner_controls(child, safe_rect, offenders)


func _is_hud_banner_candidate(control: Control) -> bool:
	var name_text := String(control.name).to_lower()
	if name_text.find("objective") >= 0 or name_text.find("skilldock") >= 0 or name_text.find("codex") >= 0:
		return false
	if control is PanelContainer or control is TextureRect:
		return true
	for child in control.get_children():
		if child is TextureRect or child is PanelContainer:
			return true
	return false


func _check_hud_skill_dock_texture_contracts() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var skill_dock := _hud.get_node_or_null("Root/SkillDock")
	_require(skill_dock != null and skill_dock.visible, "HUD SkillDock should be visible in combat showcase")
	if skill_dock == null:
		return
	var slot_nodes := {
		"q": "SpellQ",
		"e": "SpellE",
		"r": "SpellR",
	}
	var checked := 0
	for slot_key in slot_nodes.keys():
		var slot_node := skill_dock.get_node_or_null("Margin/HBox/%s" % str(slot_nodes[slot_key]))
		if slot_node == null and skill_dock.has_method("get_spell_slot_node"):
			slot_node = skill_dock.call("get_spell_slot_node", slot_key)
		_require(slot_node != null, "HUD SkillDock missing %s node" % str(slot_nodes[slot_key]))
		if slot_node == null:
			continue
		_require(slot_node.has_method("get_slot_frame_texture_hit_count"), "HUD %s should expose slot frame texture hit count" % str(slot_nodes[slot_key]))
		_require(slot_node.has_method("get_shortcut_badge_texture_hit_count"), "HUD %s should expose shortcut badge texture hit count" % str(slot_nodes[slot_key]))
		_require(slot_node.has_method("get_cooldown_texture_hit_count"), "HUD %s should expose cooldown texture hit count" % str(slot_nodes[slot_key]))
		var frame_hits := int(slot_node.call("get_slot_frame_texture_hit_count")) if slot_node.has_method("get_slot_frame_texture_hit_count") else 0
		var key_hits := int(slot_node.call("get_shortcut_badge_texture_hit_count")) if slot_node.has_method("get_shortcut_badge_texture_hit_count") else 0
		var cooldown_hits := int(slot_node.call("get_cooldown_texture_hit_count")) if slot_node.has_method("get_cooldown_texture_hit_count") else 0
		_report("HUD %s texture hits: slot=%d shortcut=%d cooldown=%d" % [str(slot_nodes[slot_key]), frame_hits, key_hits, cooldown_hits])
		_require(frame_hits > 0, "HUD %s should render image2 spell slot frame texture" % str(slot_nodes[slot_key]))
		_require(key_hits > 0, "HUD %s should render image2 shortcut badge texture" % str(slot_nodes[slot_key]))
		_require(cooldown_hits > 0, "HUD %s should render image2 cooldown texture" % str(slot_nodes[slot_key]))
		checked += 1
	_require(checked == 3, "HUD SkillDock should verify all three SpellQ/E/R texture-backed slots")


func _check_hud_resource_bar_texture_contracts() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var character_panel := _hud.get_node_or_null("Root/CharacterAnchor/CharacterPanel")
	_require(character_panel != null and character_panel.visible, "HUD CharacterPanel should be visible for resource bar texture QA")
	if character_panel == null:
		return
	var hp_bar := character_panel.get_node_or_null("Margin/VBox/VitalsRow/VitalsCol/HpBar")
	var mana_bar := character_panel.get_node_or_null("Margin/VBox/VitalsRow/VitalsCol/ManaBar")
	for pair in [["HpBar", hp_bar], ["ManaBar", mana_bar]]:
		var label := str(pair[0])
		var bar := pair[1] as Node
		_require(bar != null and (bar as CanvasItem).visible, "HUD %s should be visible in character panel" % label)
		if bar == null:
			continue
		_require(bar.has_method("get_track_texture_hit_count"), "HUD %s should expose track texture hit count" % label)
		_require(bar.has_method("get_fill_texture_hit_count"), "HUD %s should expose fill texture hit count" % label)
		var track_hits := int(bar.call("get_track_texture_hit_count")) if bar.has_method("get_track_texture_hit_count") else 0
		var fill_hits := int(bar.call("get_fill_texture_hit_count")) if bar.has_method("get_fill_texture_hit_count") else 0
		_report("HUD %s resource texture hits: track=%d fill=%d" % [label, track_hits, fill_hits])
		_require(track_hits > 0, "HUD %s should draw image2 resource track texture" % label)
		_require(fill_hits > 0, "HUD %s should draw image2 resource fill texture" % label)


func _check_hud_status_orb_texture_contracts() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var skill_dock := _hud.get_node_or_null("Root/SkillDock")
	_require(skill_dock != null, "HUD SkillDock missing for status orb texture QA")
	if skill_dock == null:
		return
	for node_name in ["LeftOrbs", "RightOrbs"]:
		var orbs := skill_dock.get_node_or_null("Margin/HBox/%s" % node_name)
		_require(orbs != null and orbs.visible, "HUD %s should be visible in combat showcase" % node_name)
		if orbs == null:
			continue
		_require(orbs.has_method("get_base_texture_hit_count"), "HUD %s should expose base seal texture hit count" % node_name)
		_require(orbs.has_method("get_seal_texture_hit_count"), "HUD %s should expose seal icon texture hit count" % node_name)
		_require(orbs.has_method("get_key_badge_texture_hit_count"), "HUD %s should expose key badge texture hit count" % node_name)
		var base_hits := int(orbs.call("get_base_texture_hit_count")) if orbs.has_method("get_base_texture_hit_count") else 0
		var seal_hits := int(orbs.call("get_seal_texture_hit_count")) if orbs.has_method("get_seal_texture_hit_count") else 0
		var key_hits := int(orbs.call("get_key_badge_texture_hit_count")) if orbs.has_method("get_key_badge_texture_hit_count") else 0
		_report("HUD %s orb texture hits: base=%d seal=%d key=%d" % [node_name, base_hits, seal_hits, key_hits])
		_require(base_hits >= 2, "HUD %s should draw image2 base seal textures" % node_name)
		_require(seal_hits >= 2, "HUD %s should draw image2 auto seal icon textures" % node_name)
		if node_name == "RightOrbs":
			_require(key_hits >= 2, "HUD RightOrbs should draw image2 shortcut badge textures for ready pet/artifact keys")


func _check_hud_companion_artifact_texture_contracts() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var panel := _hud.get_node_or_null("Root/CompanionArtifactPanel")
	_require(panel != null and panel.visible, "HUD CompanionArtifactPanel should be visible in combat showcase")
	if panel == null:
		return
	for method_name in [
		"get_pet_texture_hit_count",
		"get_artifact_texture_hit_count",
		"get_base_texture_hit_count",
		"get_charge_texture_hit_count",
	]:
		_require(panel.has_method(method_name), "CompanionArtifactPanel should expose `%s`" % method_name)
	var pet_hits := int(panel.call("get_pet_texture_hit_count")) if panel.has_method("get_pet_texture_hit_count") else 0
	var artifact_hits := int(panel.call("get_artifact_texture_hit_count")) if panel.has_method("get_artifact_texture_hit_count") else 0
	var base_hits := int(panel.call("get_base_texture_hit_count")) if panel.has_method("get_base_texture_hit_count") else 0
	var charge_hits := int(panel.call("get_charge_texture_hit_count")) if panel.has_method("get_charge_texture_hit_count") else 0
	_report("HUD CompanionArtifactPanel texture hits: pet=%d artifact=%d base=%d charge=%d" % [pet_hits, artifact_hits, base_hits, charge_hits])
	_require(pet_hits > 0, "CompanionArtifactPanel should draw image2 pet avatar")
	_require(artifact_hits > 0, "CompanionArtifactPanel should draw image2 artifact avatar")
	_require(base_hits >= 2, "CompanionArtifactPanel should draw image2 base textures for pet/artifact")
	_require(charge_hits > 0, "CompanionArtifactPanel should draw image2 charge/ready sweep texture")
	var skill_dock := _hud.get_node_or_null("Root/SkillDock") as Control
	if panel is Control and skill_dock != null:
		var panel_control := panel as Control
		var panel_rect := Rect2(panel_control.global_position, panel_control.size)
		var dock_rect := Rect2(skill_dock.global_position, skill_dock.size)
		_require(panel_control.size.y >= 220.0, "CompanionArtifactPanel should be tall enough to keep pet text inside the panel")
		_require(not panel_rect.intersects(dock_rect), "CompanionArtifactPanel should not overlap the bottom SkillDock")


func _check_world_pet_texture_contracts() -> void:
	_require(_pet_controller != null and is_instance_valid(_pet_controller), "World pet controller should exist in combat showcase")
	if _pet_controller == null or not is_instance_valid(_pet_controller):
		return
	for method_name in [
		"get_pet_aura_texture_hit_count",
		"get_pet_shadow_texture_hit_count",
		"get_pet_fallback_texture_hit_count",
	]:
		_require(_pet_controller.has_method(method_name), "PetController should expose `%s`" % method_name)
	var aura_hits := int(_pet_controller.call("get_pet_aura_texture_hit_count")) if _pet_controller.has_method("get_pet_aura_texture_hit_count") else 0
	var shadow_hits := int(_pet_controller.call("get_pet_shadow_texture_hit_count")) if _pet_controller.has_method("get_pet_shadow_texture_hit_count") else 0
	var fallback_hits := int(_pet_controller.call("get_pet_fallback_texture_hit_count")) if _pet_controller.has_method("get_pet_fallback_texture_hit_count") else 0
	_report("World pet texture hits: aura=%d shadow=%d fallback=%d" % [aura_hits, shadow_hits, fallback_hits])
	_require(aura_hits > 0, "World pet ready/coord aura should use image2 dao aura texture")
	_require(shadow_hits > 0, "World pet grounding shadow should use image2 actor presence texture")
	_require(fallback_hits > 0, "World pet fallback should have an image2 pet avatar available")
	if _player != null and is_instance_valid(_player):
		var dist := _pet_controller.global_position.distance_to(_player.global_position)
		_report("World pet distance from player: %.1f" % dist)
		_require(dist >= 52.0 and dist <= 90.0, "World pet should trail near the player without sticking to the player sprite")


func _check_hud_combat_rail_texture_contracts() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var rail := _hud.get_node_or_null("Root/RightCombatRail")
	_require(rail != null and rail.visible, "HUD RightCombatRail should be visible in combat showcase")
	if rail == null:
		return
	for method_name in [
		"get_rail_texture_hit_count",
		"get_tick_texture_hit_count",
		"get_action_texture_hit_count",
		"get_combo_number_font_size",
		"get_action_font_size",
	]:
		_require(rail.has_method(method_name), "RightCombatRail should expose `%s`" % method_name)
	var rail_hits := int(rail.call("get_rail_texture_hit_count")) if rail.has_method("get_rail_texture_hit_count") else 0
	var tick_hits := int(rail.call("get_tick_texture_hit_count")) if rail.has_method("get_tick_texture_hit_count") else 0
	var action_hits := int(rail.call("get_action_texture_hit_count")) if rail.has_method("get_action_texture_hit_count") else 0
	_report("HUD RightCombatRail texture hits: rail=%d tick=%d action=%d" % [rail_hits, tick_hits, action_hits])
	_require(rail_hits > 0, "RightCombatRail should draw image2 combo rail texture")
	_require(tick_hits >= 6, "RightCombatRail should draw image2 tick textures")
	_require(action_hits > 0, "RightCombatRail should draw image2 action marker textures")
	if rail.has_method("get_combo_number_font_size"):
		_require(int(rail.call("get_combo_number_font_size")) <= 36, "RightCombatRail combo number should stay compact, not a debug-sized counter")
	if rail.has_method("get_action_font_size"):
		_require(int(rail.call("get_action_font_size")) <= 12, "RightCombatRail action feed should stay secondary and compact")
	var rail_control := rail as Control
	if rail_control != null:
		_require(rail_control.custom_minimum_size.x <= 150.0 and rail_control.custom_minimum_size.y <= 320.0, "RightCombatRail should stay narrow and not dominate the right edge")
		var rail_rect := Rect2(rail_control.global_position, rail_control.size)
		_require(rail_rect.position.x >= 1720.0, "RightCombatRail should hug the right edge instead of entering the center combat field")


func _check_floor_layer_contract() -> void:
	if _combat_floor == null or not is_instance_valid(_combat_floor):
		return
	var background := _combat_floor.find_child("Background", true, false) as Sprite2D
	_require(background != null and background.texture != null, "CombatFloor background image2 room texture missing")
	var used_cells := int(_combat_floor.call("get_floor_detail_used_cell_count"))
	var max_cells := int(_combat_floor.call("get_floor_detail_max_cell_count"))
	var alpha := float(_combat_floor.call("get_floor_detail_alpha"))
	_report("Floor detail cells: %d/%d, alpha %.3f" % [used_cells, max_cells, alpha])
	_require(used_cells > 0, "Expected sparse FloorLayer ink detail cells")
	_require(used_cells <= max_cells, "FloorLayer should stay sparse so room_background remains primary ground")
	_require(alpha <= MAX_FLOOR_DETAIL_ALPHA, "FloorLayer alpha too high; it should not overpower image2 room background")


func _check_image_contracts(image: Image) -> void:
	if image == null:
		_fail("Viewport image is null")
		return
	_require(image.get_width() == TARGET_SIZE.x and image.get_height() == TARGET_SIZE.y, "Screenshot must be 1920x1080, got %dx%d" % [image.get_width(), image.get_height()])
	var stats := _sample_image_stats(image)
	_report("Sampled non-black ratio: %.3f" % stats.non_black_ratio)
	_report("Sampled bright ratio: %.3f" % stats.bright_ratio)
	_report("Sampled mean luminance: %.3f" % stats.mean_luminance)
	_report("Sampled unique color buckets: %d" % stats.unique_color_buckets)
	_require(stats.non_black_ratio > 0.55, "Screenshot appears mostly blank/dark")
	_require(stats.bright_ratio > MIN_BRIGHT_RATIO, "Screenshot has too few readable highlights/particles")
	_require(stats.bright_ratio < MAX_BRIGHT_RATIO, "Screenshot is too globally bright for dark ink combat")
	_require(stats.mean_luminance < MAX_MEAN_LUMINANCE, "Screenshot mean luminance is too high for dark ink combat")
	_require(stats.unique_color_buckets >= 28, "Screenshot has low color diversity; expected map + UI + VFX")
	_require(_center_modal_bar_score(image) < 0.10, "Combat screenshot center contains a wide modal-title-like black/gold banner")


func _save_image(image: Image) -> void:
	if image == null:
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Failed to save screenshot to %s (error %d)" % [OUTPUT_PATH, error])


func _sample_image_stats(image: Image) -> Dictionary:
	var total := 0
	var non_black := 0
	var bright := 0
	var luminance_sum := 0.0
	var buckets := {}
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
	}


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


func _sample_center_palette_stats(image: Image) -> Dictionary:
	var total := 0
	var warm := 0
	var jade := 0
	var cold_gold := 0
	var neutral_dark := 0
	var rect := Rect2i(Vector2i(int(image.get_width() * 0.18), int(image.get_height() * 0.14)), Vector2i(int(image.get_width() * 0.64), int(image.get_height() * 0.72)))
	var step := 10
	for y in range(rect.position.y, rect.end.y, step):
		for x in range(rect.position.x, rect.end.x, step):
			var color := image.get_pixel(x, y)
			if color.a <= 0.1:
				continue
			var luminance := color.get_luminance()
			if luminance <= 0.025:
				continue
			total += 1
			var max_channel := maxf(color.r, maxf(color.g, color.b))
			var min_channel := minf(color.r, minf(color.g, color.b))
			var saturation := 0.0 if max_channel <= 0.001 else (max_channel - min_channel) / max_channel
			if color.r > color.g * 1.08 and color.r > color.b * 1.18 and saturation > 0.22:
				warm += 1
			if color.g >= color.r * 0.92 and color.g > color.b * 0.72 and color.b >= color.r * 0.68 and saturation > 0.08:
				jade += 1
			if color.r <= color.g * 1.08 and color.r >= color.b * 1.10 and color.g >= color.b * 1.16 and saturation > 0.10 and luminance > 0.10 and luminance < 0.58:
				cold_gold += 1
			if luminance < 0.22 and saturation < 0.24:
				neutral_dark += 1
	return {
		"warm_ratio": float(warm) / float(maxi(total, 1)),
		"jade_ratio": float(jade) / float(maxi(total, 1)),
		"cold_gold_ratio": float(cold_gold) / float(maxi(total, 1)),
		"neutral_dark_ratio": float(neutral_dark) / float(maxi(total, 1)),
	}


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


func _has_visible_sprite(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var sprite := node.get_node_or_null("BodyVisual") as Sprite2D
	return sprite != null and sprite.visible and sprite.texture != null


func _check_enemy_world_plate_texture_contracts() -> void:
	var checked_non_boss := 0
	var checked_nameplates := 0
	var visible_nameplates := 0
	var visible_ordinary_nameplates := 0
	var visible_action_labels := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == null or not is_instance_valid(node):
			continue
		var enemy := node as Node
		var name_label := enemy.get_node_or_null("NameLabel") as Label
		var nameplate_bg := enemy.get_node_or_null("NameplateBg") as TextureRect
		var hp_bar := enemy.get_node_or_null("WorldEnemyHealthBar") as Control
		var action_label := enemy.get_node_or_null("ActionLabel") as Label
		var is_boss := enemy == _boss_enemy
		_require(name_label != null and not name_label.text.is_empty(), "Enemy `%s` should expose a world name label" % str(enemy.name))
		_require(nameplate_bg != null and nameplate_bg.texture != null, "Enemy `%s` nameplate should keep image2 backing texture loaded" % str(enemy.name))
		if enemy.has_method("get_nameplate_texture_hit_count"):
			_require(int(enemy.call("get_nameplate_texture_hit_count")) >= 1, "Enemy `%s` nameplate texture hit count missing" % str(enemy.name))
		checked_nameplates += 1
		if nameplate_bg != null and nameplate_bg.visible:
			visible_nameplates += 1
		if is_boss:
			_require(nameplate_bg == null or not nameplate_bg.visible, "Boss `%s` should not show a redundant world nameplate when the top boss objective is active" % str(enemy.name))
			_require(name_label == null or not name_label.visible, "Boss `%s` world name label should stay hidden because the top boss bar owns that text" % str(enemy.name))
			_require(hp_bar == null or not hp_bar.visible, "Boss `%s` should not show small world HP bar when top boss bar is active" % str(enemy.name))
			continue
		var strong_nameplate := bool(enemy.get("_has_persistent_nameplate")) or bool(enemy.get("_is_promoted_realm"))
		if nameplate_bg != null and nameplate_bg.visible and not strong_nameplate:
			visible_ordinary_nameplates += 1
		if nameplate_bg != null and not strong_nameplate:
			_require(nameplate_bg.modulate.a <= 0.30, "Ordinary enemy `%s` nameplate should stay low-alpha" % str(enemy.name))
			_require(nameplate_bg.size.x <= 112.0, "Ordinary enemy `%s` nameplate should stay compact, got %.1f px" % [str(enemy.name), nameplate_bg.size.x])
			_require(not nameplate_bg.visible or bool(enemy.call("_should_show_world_plate")), "Ordinary enemy `%s` nameplate should not be always-on unless runtime visibility rules allow it" % str(enemy.name))
		if name_label != null and not strong_nameplate:
			var font_color := name_label.get_theme_color("font_color")
			_require(font_color.a <= 0.70, "Ordinary enemy `%s` name text should stay secondary" % str(enemy.name))
		if action_label != null and action_label.visible:
			visible_action_labels += 1
			var action_text := action_label.text
			_require(not action_text in ["僵直", "缓行"], "Enemy action label should not duplicate status icon text `%s`" % action_text)
		_require(hp_bar != null, "Enemy `%s` should have a texture-backed world HP bar node" % str(enemy.name))
		if nameplate_bg != null and nameplate_bg.visible and hp_bar != null and hp_bar.visible:
			var spacing := hp_bar.position.y - (nameplate_bg.position.y + nameplate_bg.size.y)
			_require(spacing >= 4.0, "Enemy `%s` nameplate and HP bar should keep readable spacing, got %.1f px" % [str(enemy.name), spacing])
		if enemy.has_method("get_world_hp_texture_hit_count"):
			_require(int(enemy.call("get_world_hp_texture_hit_count")) >= 2, "Enemy `%s` world HP should use image2 texture styles" % str(enemy.name))
		checked_non_boss += 1
	_require(checked_nameplates >= 5, "Expected at least five enemies with image2-backed world nameplates")
	_require(checked_non_boss >= 4, "Expected at least four non-boss enemies with texture-backed world HP bars")
	_require(visible_nameplates <= 3, "Total enemy nameplates should stay bounded so center combat stays readable")
	_require(visible_ordinary_nameplates <= 1, "Ordinary enemy nameplates should be sparse so center combat stays readable")
	_require(visible_action_labels <= 2, "Enemy action labels should be reserved for dangerous intent, not general status chatter")


func _check_status_icon_texture_contracts() -> void:
	var player_visible := _status_icon_count(_player)
	var player_hits := _status_icon_texture_hits(_player)
	_require(player_visible >= 2, "Expected player to expose at least two world status icons in 1920 showcase")
	_require(player_hits >= player_visible, "Player world status icons should render image2 status textures, got %d/%d" % [player_hits, player_visible])
	var checked_enemies := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == null or not is_instance_valid(node):
			continue
		var visible := _status_icon_count(node as Node)
		if visible <= 0:
			continue
		_require(visible <= 6, "Enemy `%s` should cap visible status icons" % str((node as Node).name))
		var hits := _status_icon_texture_hits(node as Node)
		_require(hits >= visible, "Enemy `%s` world status icons should render image2 status textures, got %d/%d" % [str((node as Node).name), hits, visible])
		checked_enemies += 1
	_require(checked_enemies >= 5, "Expected at least five enemies with image2-backed world status icons")


func _status_icon_count(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not node.has_method("get_visible_status_icon_count"):
		return 0
	return int(node.call("get_visible_status_icon_count"))


func _status_icon_texture_hits(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not node.has_method("get_status_icon_texture_hit_count"):
		return 0
	return int(node.call("get_status_icon_texture_hit_count"))


func _check_image2_fx_texture_contracts() -> void:
	_check_all_combat_action_fx_paths_load()
	_check_all_weather_decal_paths_load()
	_check_all_weather_overlay_particle_paths_load()
	_check_all_player_projectile_trail_paths_load()
	_check_all_enemy_projectile_trail_paths_load()
	var weather_overlay := _combat_floor.find_child("WeatherOverlay", true, false) if _combat_floor else null
	_require(weather_overlay != null, "Expected WeatherOverlay for image2 weather particles")
	if weather_overlay != null:
		_require(weather_overlay.has_method("get_weather_particle_texture_hit_count"), "WeatherOverlay should expose image2 particle texture hit count")
		_require(weather_overlay.has_method("get_weather_particle_count"), "WeatherOverlay should expose runtime weather particle count")
		_require(int(weather_overlay.call("get_weather_particle_count")) > 0, "Expected weather overlay to spawn texture particles")
		_require(int(weather_overlay.call("get_weather_particle_texture_hit_count")) > 0, "WeatherOverlay should render image2 particle textures")

	var weather_root := _combat_floor.find_child("WeatherGroundRoot", true, false) if _combat_floor else null
	_require(weather_root != null, "Expected WeatherGroundRoot for image2 weather decals")
	_require(_count_textured_sprites(weather_root) >= 2, "Expected weather ground decals to render as textured Sprite2D nodes")

	var thunder_root := _combat_floor.find_child("ThunderStrikeRoot", true, false) if _combat_floor else null
	_require(thunder_root != null, "Expected ThunderStrikeRoot for image2 thunder decals")
	if _combat_floor != null:
		_combat_floor.call("_spawn_thunder_strike_batch")
		await get_tree().process_frame
		await get_tree().process_frame
	var thunder_markers := thunder_root.find_children("ThunderStrikeMarker*", "", true, false) if thunder_root else []
	if thunder_markers.is_empty() and _combat_floor != null:
		_combat_floor.call("_spawn_thunder_strike_batch")
		await get_tree().process_frame
		thunder_markers = thunder_root.find_children("ThunderStrikeMarker*", "", true, false) if thunder_root else []
	_require(thunder_markers.size() >= 2, "Expected thunder strike markers in visual integration scene")
	for marker in thunder_markers:
		_require(_node_texture(marker, "warning_texture") != null, "Thunder strike marker missing warning image2 texture")
		_require(_node_texture(marker, "impact_texture") != null, "Thunder strike marker missing impact image2 texture")
		_require(_node_texture(marker, "bolt_texture") != null, "Thunder strike marker missing bolt image2 texture")
		_require(_node_texture(marker, "scorch_texture") != null, "Thunder strike marker missing scorch image2 texture")

	_require(_spawn_telegraph_markers.size() >= 2, "Expected image2 enemy spawn telegraph markers")
	for marker in _spawn_telegraph_markers:
		_require(marker != null and is_instance_valid(marker), "Tracked enemy spawn telegraph marker was freed before texture contract check")
		_require(_node_texture(marker, "texture") != null, "Enemy spawn telegraph missing image2 texture")

	_require(_attack_telegraph_markers.size() >= 4, "Expected image2 enemy attack telegraph markers for melee/line/dash/sniper")
	var seen_kinds := {}
	for marker in _attack_telegraph_markers:
		if marker == null or not is_instance_valid(marker):
			_fail("Tracked enemy attack telegraph marker was freed before texture contract check")
			continue
		var kind := str(marker.get("kind"))
		seen_kinds[kind] = true
		_require(_node_texture(marker, "texture") != null, "Enemy attack telegraph `%s` missing image2 texture" % kind)
	for required_kind in ["melee", "line", "dash", "sniper"]:
		_require(seen_kinds.has(required_kind), "Missing enemy attack telegraph kind `%s` in 1920 showcase" % required_kind)

	_require(_player_projectiles.size() >= 4, "Expected player projectile showcase entries")
	for projectile in _player_projectiles:
		_require(projectile != null and is_instance_valid(projectile), "Tracked player projectile was freed before trail texture contract check")
		if projectile == null or not is_instance_valid(projectile):
			continue
		_require(projectile.has_method("get_trail_texture_hit_count"), "Player projectile should expose image2 trail texture hit count")
		_require(int(projectile.call("get_trail_texture_hit_count")) > 0, "Player projectile `%s` missing image2 trail texture" % str(projectile.name))
		_require(projectile.has_method("get_core_texture_hit_count"), "Player projectile should expose image2 core texture hit count")
		_require(int(projectile.call("get_core_texture_hit_count")) > 0, "Player projectile `%s` missing image2 core texture" % str(projectile.name))

	_require(_enemy_projectiles.size() >= 4, "Expected enemy projectile showcase entries")
	for projectile in _enemy_projectiles:
		_require(projectile != null and is_instance_valid(projectile), "Tracked enemy projectile was freed before trail texture contract check")
		if projectile == null or not is_instance_valid(projectile):
			continue
		_require(projectile.has_method("get_trail_texture_hit_count"), "Enemy projectile should expose image2 trail texture hit count")
		_require(int(projectile.call("get_trail_texture_hit_count")) > 0, "Enemy projectile `%s` missing image2 trail texture" % str(projectile.name))
		_require(projectile.has_method("get_core_texture_hit_count"), "Enemy projectile should expose image2 core texture hit count")
		_require(int(projectile.call("get_core_texture_hit_count")) > 0, "Enemy projectile `%s` missing image2 core texture" % str(projectile.name))

	_require(VfxManager.has_method("get_gold_reward_mote_spawn_count"), "VfxManager should expose spirit-stone mote spawn count")
	_require(VfxManager.has_method("get_gold_reward_mote_texture_hit_count"), "VfxManager should expose spirit-stone mote texture hit count")
	var mote_count := int(VfxManager.call("get_gold_reward_mote_spawn_count")) if VfxManager.has_method("get_gold_reward_mote_spawn_count") else 0
	var mote_texture_hits := int(VfxManager.call("get_gold_reward_mote_texture_hit_count")) if VfxManager.has_method("get_gold_reward_mote_texture_hit_count") else 0
	_require(mote_count >= 3, "Expected spirit-stone reward motes in 1920 showcase")
	_require(mote_texture_hits >= mote_count, "Gold reward motes should use image2 spirit-stone texture, got %d/%d" % [mote_texture_hits, mote_count])
	var gold_motes := _find_named_nodes("*GoldRewardMote*")
	for mote in gold_motes:
		var sprite := mote as Sprite2D
		_require(sprite != null and sprite.texture != null, "GoldRewardMote should render image2 spirit-stone texture")

	_require(_player != null and _player.has_method("get_combat_fx_texture_hit_count"), "Player should expose combat FX texture hit count")
	var player_fx_hits := int(_player.call("get_combat_fx_texture_hit_count")) if _player != null and _player.has_method("get_combat_fx_texture_hit_count") else 0
	_require(player_fx_hits >= 4, "Player combat FX should use image2 textures for slash/presence/dao/status, got %d hits" % player_fx_hits)
	var windup_hits := 0
	var movement_trail_hits := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node != null and is_instance_valid(node) and node.has_method("get_windup_weapon_texture_hit_count"):
			windup_hits += int(node.call("get_windup_weapon_texture_hit_count"))
		if node != null and is_instance_valid(node) and node.has_method("get_movement_trail_texture_hit_count"):
			movement_trail_hits += int(node.call("get_movement_trail_texture_hit_count"))
	_require(windup_hits > 0, "Enemy windup weapon glyph should render image2 texture in 1920 showcase")
	_require(movement_trail_hits > 0, "Moving enemies should render image2 ink trail textures instead of procedural streak lines")
	_require(_crit_slash_draw != null and is_instance_valid(_crit_slash_draw), "Crit slash draw showcase missing")
	_require(_crit_slash_draw != null and _crit_slash_draw.has_method("get_slash_texture_hit_count"), "CritSlashDraw should expose image2 slash texture hit count")
	var crit_hits := int(_crit_slash_draw.call("get_slash_texture_hit_count")) if _crit_slash_draw != null and _crit_slash_draw.has_method("get_slash_texture_hit_count") else 0
	_require(crit_hits > 0, "Crit screen slash should render image2 texture")
	_require(_reduced_impact_mark != null and is_instance_valid(_reduced_impact_mark), "Reduced-motion hit impact showcase missing")
	var reduced_sprite := _reduced_impact_mark as Sprite2D
	_require(reduced_sprite != null and reduced_sprite.texture != null, "Reduced-motion hit impact should render image2 impact texture")


func _check_all_combat_action_fx_paths_load() -> void:
	for key in [
		"player_slash_arc",
		"crit_screen_slash",
		"enemy_windup_seal",
		"actor_presence_shadow",
		"player_dao_aura",
		"player_counter_aura",
		"enemy_identity_ring_elite",
		"enemy_identity_ring_boss",
		"enemy_guard_aura",
		"status_badge_backing",
	]:
		var path := AssetPaths.combat_action_fx(key)
		_require(not path.is_empty(), "AssetPaths.combat_action_fx(`%s`) returned empty path" % key)
		_require(AssetPaths.load_texture(path) != null, "Combat action FX `%s` did not load as Texture2D: %s" % [key, path])
	for weapon_id in ["claw", "wind_blade", "mud_bow", "cloud_crossbow", "furnace_core", "xuanwu_shield", "soul_banner", "poison_spit"]:
		var weapon_path := AssetPaths.enemy_windup_weapon(weapon_id)
		_require(not weapon_path.is_empty(), "AssetPaths.enemy_windup_weapon(`%s`) returned empty path" % weapon_id)
		_require(AssetPaths.load_texture(weapon_path) != null, "Enemy windup weapon `%s` did not load as Texture2D: %s" % [weapon_id, weapon_path])


func _check_all_weather_decal_paths_load() -> void:
	for weather_id in ["clear", "rain", "thunder", "storm", "thunderstorm", "fire", "wind", "fog", "snow", "sand"]:
		var path := AssetPaths.weather_decal(weather_id)
		_require(not path.is_empty(), "AssetPaths.weather_decal(`%s`) returned empty path" % weather_id)
		_require(AssetPaths.load_texture(path) != null, "Weather decal `%s` did not load as Texture2D: %s" % [weather_id, path])


func _check_all_weather_overlay_particle_paths_load() -> void:
	for weather_id in ["clear", "rain", "thunder", "storm", "thunderstorm", "fire", "wind", "fog", "snow", "sand"]:
		var path := AssetPaths.weather_overlay_particle(weather_id)
		_require(not path.is_empty(), "AssetPaths.weather_overlay_particle(`%s`) returned empty path" % weather_id)
		_require(AssetPaths.load_texture(path) != null, "Weather overlay particle `%s` did not load as Texture2D: %s" % [weather_id, path])


func _check_all_player_projectile_trail_paths_load() -> void:
	for element in ["generic", "fire", "thunder", "lightning", "ice", "water", "wood", "earth", "chaos", "soul", "void"]:
		var path := AssetPaths.projectile_trail(element, "")
		_require(not path.is_empty(), "AssetPaths.projectile_trail(`%s`) returned empty path" % element)
		_require(AssetPaths.load_texture(path) != null, "Player projectile trail `%s` did not load as Texture2D: %s" % [element, path])


func _check_all_enemy_projectile_trail_paths_load() -> void:
	for element in ["generic", "fire", "thunder", "lightning", "ice", "water", "wood", "earth", "chaos", "soul", "void"]:
		var path := AssetPaths.enemy_projectile_trail(element, "")
		_require(not path.is_empty(), "AssetPaths.enemy_projectile_trail(`%s`) returned empty path" % element)
		_require(AssetPaths.load_texture(path) != null, "Enemy projectile trail `%s` did not load as Texture2D: %s" % [element, path])


func _count_textured_sprites(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	for child in root.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			count += 1
	return count


func _count_textured_sprites_recursive(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	if root is Sprite2D and (root as Sprite2D).texture != null:
		count += 1
	for child in root.get_children():
		count += _count_textured_sprites_recursive(child)
	return count


func _node_texture(node: Variant, property_name: String) -> Texture2D:
	if node == null or not is_instance_valid(node):
		return null
	if not node is Object:
		return null
	return (node as Object).get(property_name) as Texture2D


func _track_spawn_telegraph(marker: Node2D) -> void:
	if marker != null:
		_spawn_telegraph_markers.append(marker)


func _track_attack_telegraph(marker: Node2D) -> void:
	if marker != null:
		_attack_telegraph_markers.append(marker)


func _find_named_nodes(pattern: String) -> Array[Node]:
	var found: Array[Node] = []
	_collect_named_nodes(self, pattern, found)
	if _viewport != null:
		_collect_named_nodes(_viewport, pattern, found)
	return found


func _collect_named_nodes(root: Node, pattern: String, found: Array[Node]) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child.name.match(pattern) and not found.has(child):
			found.append(child)
		_collect_named_nodes(child, pattern, found)


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
