class_name UiFlyEffects
extends RefCounted

const AssetPaths = preload("res://assets/asset_paths.gd")

static func fly_control(from_global: Vector2, to_global: Vector2, size: Vector2, color: Color, host: CanvasLayer, on_done: Callable = Callable()) -> void:
	fly_icon(from_global, to_global, AssetPaths.ICON_SPIRIT_STONE, host, on_done, size, color)


static func fly_icon(
	from_global: Vector2,
	to_global: Vector2,
	icon_path: String,
	host: CanvasLayer,
	on_done: Callable = Callable(),
	size: Vector2 = Vector2(32, 32),
	tint: Color = Color.WHITE
) -> void:
	if host == null:
		if on_done.is_valid():
			on_done.call()
		return
	if VfxManager.should_reduce_motion():
		if on_done.is_valid():
			on_done.call()
		return
	if not ResourceLoader.exists(icon_path):
		icon_path = AssetPaths.ICON_SPIRIT_STONE
	var ghost := TextureRect.new()
	ghost.custom_minimum_size = size
	ghost.size = size
	ghost.texture = load(icon_path)
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(ghost)
	ghost.global_position = from_global - size * 0.5
	ghost.scale = Vector2(1.2, 1.2)
	ghost.pivot_offset = size * 0.5
	ghost.modulate = tint
	var tw := ghost.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "global_position", to_global - size * 0.5, 0.42)
	tw.parallel().tween_property(ghost, "scale", Vector2(0.5, 0.5), 0.42)
	tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.35).set_delay(0.15)
	tw.finished.connect(func() -> void:
		ghost.queue_free()
		if on_done.is_valid():
			on_done.call()
	)
