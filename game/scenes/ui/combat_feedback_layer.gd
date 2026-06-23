extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

var _active_tweens: Array = []
var _floater_spawn_count := 0
var _floater_backing_texture_hits := 0
var _floater_icon_texture_hits := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.weather_kill.connect(_on_weather_kill)
	EventBus.pet_guardian_triggered.connect(_on_pet_guardian_triggered)


func _exit_tree() -> void:
	for tween in _active_tweens:
		if tween and tween.is_valid() and tween.is_running():
			tween.kill()
	_active_tweens.clear()


func _on_damage_dealt(result: Dictionary) -> void:
	var world_pos: Vector2 = result.get("world_position", Vector2.ZERO)
	if world_pos == Vector2.ZERO:
		return
	if SaveManager.get_display_setting("show_damage_numbers"):
		_spawn_floater(world_pos, result)
		VfxManager.spawn_damage(result)


func _on_weather_kill(enemy: Node, weather_id: String, _payload: Dictionary) -> void:
	if not SaveManager.get_display_setting("show_damage_numbers"):
		return
	var body := enemy as Node2D
	if body == null or not is_instance_valid(body):
		return
	_spawn_text(body.global_position, "%s天象击杀" % _weather_label(weather_id), UiTokens.ACCENT_GOLD, 19)


func _on_pet_guardian_triggered(enemy: Node, player: Node) -> void:
	var body := player as Node2D
	if body == null or not is_instance_valid(body):
		body = enemy as Node2D
	if body == null or not is_instance_valid(body):
		return
	_spawn_text(body.global_position, "灵兽护主", Color(1.0, 0.82, 0.28), 22)


func _spawn_floater(world_pos: Vector2, result: Dictionary) -> void:
	if not SaveManager.get_display_setting("show_damage_numbers"):
		return
	var amount: float = float(result.get("final_damage", 0.0))
	if amount <= 0.0:
		return
	var is_crit: bool = VariantUtils.as_bool(result.get("is_crit", false))
	var is_combo: bool = VariantUtils.as_bool(result.get("is_combo", false))
	var is_unity: bool = VariantUtils.as_bool(result.get("is_unity", false))
	var to_player: bool = VariantUtils.as_bool(result.get("target_is_player", false))

	var root := Control.new()
	root.name = "DamageFloater"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(118, 32)
	_add_floater_chrome(root, _floater_icon_path(result), Color(1, 1, 1, 0.60))
	var label := Label.new()
	label.position = Vector2(26, 0)
	label.size = Vector2(88, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)

	var font_size := 15
	var text_color := UiTokens.TEXT_PRIMARY
	var outline := Color(0, 0, 0, 0.55)
	if is_unity:
		var hit_index := clampi(int(result.get("unity_hit_index", 1)), 1, 9)
		label.text = "归一 %.0f" % amount
		text_color = result.get("color", UiTokens.ACCENT_GOLD)
		font_size = mini(22, 17 + hit_index)
		outline = Color(0.2, 0.12, 0.0, 0.9)
	elif is_combo:
		label.text = "爆燃 %.0f!" % amount
		text_color = UiTokens.ELEM_FIRE
		font_size = 19
		outline = Color(0.35, 0.08, 0.0, 0.7)
	elif is_crit:
		label.text = "天机 %.0f!" % amount
		text_color = UiTokens.ACCENT_GOLD
		font_size = 18
		outline = Color(0.25, 0.18, 0.0, 0.75)
	elif to_player:
		label.text = "-%.0f" % amount
		text_color = UiTokens.STATE_DEBUFF
		font_size = 17
	else:
		label.text = "%.0f" % amount

	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", outline)

	add_child(root)
	_floater_spawn_count += 1
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	root.position = screen_pos + Vector2(-32.0, -56.0)
	var pop_scale := 1.15 if is_unity else (1.10 if is_crit else (1.04 if is_combo else 0.82))
	root.scale = Vector2(pop_scale, pop_scale) * 0.65
	root.modulate.a = 0.0
	root.pivot_offset = Vector2(32, 16)

	var tween := create_tween()
	_active_tweens.append(tween)
	tween.finished.connect(_active_tweens.erase.bind(tween))
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.08)
	tween.tween_property(root, "scale", Vector2(pop_scale, pop_scale), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position:y", root.position.y - 38.0, 0.66).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, 0.72).set_delay(0.18)
	tween.finished.connect(root.queue_free)


func _spawn_text(world_pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var root := Control.new()
	root.name = "FeedbackFloater"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(138, 32)
	_add_floater_chrome(root, _text_icon_path(text), Color(1, 1, 1, 0.62))
	var label := Label.new()
	label.position = Vector2(30, 0)
	label.size = Vector2(104, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", mini(font_size, 19))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.11, 0.0, 0.8))
	root.add_child(label)
	add_child(root)
	_floater_spawn_count += 1
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	root.position = screen_pos + Vector2(-56.0, -72.0)
	root.scale = Vector2(0.75, 0.75)
	root.modulate.a = 0.0
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.finished.connect(_active_tweens.erase.bind(tween))
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.08)
	tween.tween_property(root, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position:y", root.position.y - 34.0, 0.72)
	tween.tween_property(root, "modulate:a", 0.0, 0.8).set_delay(0.22)
	tween.finished.connect(root.queue_free)


func _weather_label(weather_id: String) -> String:
	match weather_id:
		"thunder": return "雷"
		"rain": return "雨"
		"fire": return "烈阳"
		"wind": return "妖风"
		"snow": return "霜雪"
		"sand": return "沙暴"
	return "天"


func _add_floater_chrome(root: Control, icon_path: String, tint: Color) -> void:
	var backing := TextureRect.new()
	backing.name = "FloaterBacking"
	backing.texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("status_badge_backing"))
	backing.position = Vector2(-2, -2)
	backing.size = Vector2(28, 28)
	backing.custom_minimum_size = Vector2(28, 28)
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	backing.modulate = tint
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backing)
	if backing.texture != null:
		_floater_backing_texture_hits += 1

	var icon := TextureRect.new()
	icon.name = "FloaterIcon"
	icon.texture = AssetPaths.load_texture(icon_path)
	icon.position = Vector2(3, 3)
	icon.size = Vector2(20, 20)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	if icon.texture != null:
		_floater_icon_texture_hits += 1


func _floater_icon_path(result: Dictionary) -> String:
	if VariantUtils.as_bool(result.get("target_is_player", false)):
		return AssetPaths.status_icon("bleed")
	if VariantUtils.as_bool(result.get("is_unity", false)):
		return AssetPaths.status_icon("dao")
	if VariantUtils.as_bool(result.get("is_combo", false)):
		return AssetPaths.status_icon("burn")
	if VariantUtils.as_bool(result.get("is_crit", false)):
		return AssetPaths.status_icon("counter")
	return AssetPaths.status_icon(str(result.get("status", "windup")))


func _text_icon_path(text: String) -> String:
	if text.contains("灵兽"):
		return AssetPaths.PET_AVATAR_RING
	if text.contains("天象"):
		return AssetPaths.weather_icon(WeatherSystem.current_weather_id)
	return AssetPaths.status_icon("dao")


func get_floater_spawn_count() -> int:
	return _floater_spawn_count


func get_floater_backing_texture_hit_count() -> int:
	return _floater_backing_texture_hits


func get_floater_icon_texture_hit_count() -> int:
	return _floater_icon_texture_hits
