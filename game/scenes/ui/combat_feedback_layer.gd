extends CanvasLayer

const GameConstants = preload("res://core/constants/game_constants.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	EventBus.damage_dealt.connect(_on_damage_dealt)


func _on_damage_dealt(result: Dictionary) -> void:
	if not SaveManager.get_display_setting("show_damage_numbers"):
		return
	var world_pos: Vector2 = result.get("world_position", Vector2.ZERO)
	if world_pos == Vector2.ZERO:
		return
	_spawn_floater(world_pos, result)


func _spawn_floater(world_pos: Vector2, result: Dictionary) -> void:
	var amount: float = float(result.get("final_damage", 0.0))
	if amount <= 0.0:
		return
	var is_crit: bool = bool(result.get("is_crit", false))
	var is_combo: bool = bool(result.get("is_combo", false))
	var to_player: bool = bool(result.get("target_is_player", false))

	var label := Label.new()
	if is_combo:
		label.text = "爆燃 %.0f" % amount
		label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.15))
		label.add_theme_font_size_override("font_size", 20)
	elif is_crit:
		label.text = "天机 %.0f" % amount
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
		label.add_theme_font_size_override("font_size", 18)
	elif to_player:
		label.text = "-%.0f" % amount
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		label.add_theme_font_size_override("font_size", 16)
	else:
		label.text = "%.0f" % amount
		label.add_theme_color_override("font_color", GameConstants.COLOR_UI)
		label.add_theme_font_size_override("font_size", 15)

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	label.position = screen_pos + Vector2(-24.0, -52.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 42.0, 0.65).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tween.finished.connect(label.queue_free)
