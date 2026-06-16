extends Node

const VfxLibrary = preload("res://vfx/vfx_library.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

const MAX_BURST_POOL := 40
const IMPACT_FPS := 14.0
const IMPACT_SCALE := Vector2(2.0, 2.0)
const GOLD_REWARD_TARGET_SCREEN := Vector2(126.0, 72.0)
const GOLD_REWARD_COLOR := Color(1.0, 0.84, 0.22, 1.0)

var _burst_pool: Array = []


class SpawnTelegraph:
	extends Node2D

	var color := Color(1.0, 0.35, 0.22, 0.0)
	var duration := 0.55
	var elapsed := 0.0
	var radius := 34.0
	var elite := false
	var reduced_motion := false

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var pulse := 0.35 if reduced_motion else sin(t * PI)
		var alpha := 0.22 + pulse * 0.55
		var inset := 10.0 if reduced_motion else lerpf(20.0, 6.0, t)
		var half := radius - inset
		var line_color := Color(color.r, color.g, color.b, alpha)
		var hot_color := Color(1.0, 0.88, 0.38, alpha * 0.85) if elite else line_color
		var corner := 10.0
		var points := [
			Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half),
		]
		for p in points:
			var sx := 1.0 if p.x < 0.0 else -1.0
			var sy := 1.0 if p.y < 0.0 else -1.0
			draw_line(p, p + Vector2(sx * corner, 0), line_color, 2.0)
			draw_line(p, p + Vector2(0, sy * corner), line_color, 2.0)
		draw_line(Vector2(-5, -half - 7), Vector2(5, -half - 7), hot_color, 1.5)
		draw_line(Vector2(-5, half + 7), Vector2(5, half + 7), hot_color, 1.5)
		draw_line(Vector2(-half - 7, -5), Vector2(-half - 7, 5), hot_color, 1.5)
		draw_line(Vector2(half + 7, -5), Vector2(half + 7, 5), hot_color, 1.5)


class AttackTelegraph:
	extends Node2D

	var direction := Vector2.RIGHT
	var color := Color(1.0, 0.38, 0.24, 1.0)
	var duration := 0.38
	var elapsed := 0.0
	var length := 180.0
	var width := 10.0
	var label := ""
	var reduced_motion := false

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var dir := direction.normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var alpha := 0.48 if reduced_motion else lerpf(0.72, 0.08, t)
		var side := dir.orthogonal()
		var start := dir * 18.0
		var end := dir * length
		var line_color := Color(color.r, color.g, color.b, alpha)
		var hot_color := Color(1.0, 0.82, 0.36, alpha)
		draw_line(start, end, line_color, width)
		draw_line(start + side * (width * 0.9), end + side * (width * 0.9), hot_color, 1.8)
		draw_line(start - side * (width * 0.9), end - side * (width * 0.9), hot_color, 1.8)
		for i in 3:
			var p := start.lerp(end, 0.38 + float(i) * 0.18)
			draw_line(p - dir * 10.0 + side * 6.0, p + dir * 10.0, hot_color, 2.0)
			draw_line(p - dir * 10.0 - side * 6.0, p + dir * 10.0, hot_color, 2.0)


class GoldRewardMote:
	extends Node2D

	var color := GOLD_REWARD_COLOR

	func _draw() -> void:
		var points := PackedVector2Array([
			Vector2(0, -7),
			Vector2(6, 0),
			Vector2(0, 8),
			Vector2(-6, 0),
		])
		draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.86))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(1.0, 0.96, 0.62, 0.95), 1.4)
		draw_line(Vector2(-3, 0), Vector2(4, 0), Color(1.0, 0.96, 0.62, 0.75), 1.2)


func should_reduce_motion() -> bool:
	return SaveManager.get_display_setting("reduce_motion")


func spawn_world(global_pos: Vector2, preset: String, color: Color) -> void:
	if should_reduce_motion():
		return
	var parent := _world_parent()
	if parent == null:
		return
	_spawn_burst(parent, global_pos, preset, color)


func spawn_enemy_telegraph(global_pos: Vector2, elite := false, duration := 0.55) -> void:
	var parent := _world_parent()
	if parent == null:
		return
	var marker := SpawnTelegraph.new()
	marker.name = "EnemySpawnTelegraph"
	marker.global_position = global_pos
	marker.reduced_motion = should_reduce_motion()
	marker.duration = minf(duration, 0.38) if marker.reduced_motion else duration
	marker.elite = elite
	marker.color = Color(1.0, 0.28, 0.18, 1.0)
	marker.z_index = 4
	parent.add_child(marker)


func spawn_enemy_attack_telegraph(global_pos: Vector2, direction: Vector2, length := 180.0, duration := 0.38, width := 8.0, color := Color(1.0, 0.38, 0.24, 1.0)) -> void:
	var parent := _world_parent()
	if parent == null:
		return
	var marker := AttackTelegraph.new()
	marker.name = "EnemyAttackTelegraph"
	marker.global_position = global_pos
	marker.direction = direction
	marker.length = length
	marker.reduced_motion = should_reduce_motion()
	marker.duration = minf(duration, 0.28) if marker.reduced_motion else duration
	marker.width = width
	marker.color = color
	marker.z_index = 5
	parent.add_child(marker)


func spawn_gold_reward_feedback(global_pos: Vector2, amount: int, target_screen_pos := GOLD_REWARD_TARGET_SCREEN) -> void:
	if amount <= 0:
		return
	var parent := _world_parent()
	if parent == null:
		return
	var target := _screen_to_world(target_screen_pos)
	_spawn_gold_reward_text(parent, global_pos, amount)
	if should_reduce_motion():
		return
	var count := clampi(int(ceilf(float(amount) / 8.0)), 3, 7)
	for i in range(count):
		_spawn_gold_reward_mote(parent, global_pos, target, i, count)


func spawn_screen(host: Node, local_pos: Vector2, preset: String, color: Color) -> void:
	if should_reduce_motion():
		return
	if host == null:
		return
	var anchor := Node2D.new()
	anchor.position = local_pos
	host.add_child(anchor)
	_spawn_burst(anchor, Vector2.ZERO, preset, color, true)


func spawn_damage(result: Dictionary) -> void:
	var pos: Vector2 = result.get("world_position", Vector2.ZERO)
	if pos == Vector2.ZERO:
		return
	spawn_world(pos, VfxLibrary.preset_for_damage(result), VfxLibrary.color_for_damage(result))


func flash_control(control: CanvasItem, color: Color, duration: float = 0.12) -> void:
	if control == null:
		return
	var base := control.modulate
	var tw := create_tween()
	tw.tween_property(control, "modulate", color, duration * 0.45)
	tw.tween_property(control, "modulate", base, duration * 0.55)


func _world_parent() -> Node:
	var world := get_tree().get_first_node_in_group("world_vfx")
	if world:
		return world
	var current := get_tree().current_scene
	return current


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return screen_pos
	return viewport.get_canvas_transform().affine_inverse() * screen_pos


func _spawn_gold_reward_text(parent: Node, global_pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.name = "GoldRewardText"
	label.text = "+%d 灵石" % amount
	label.position = global_pos + Vector2(-34.0, -54.0)
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.36, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.13, 0.08, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "position", label.position + Vector2(0, -18), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.72)
	tween.tween_callback(label.queue_free)


func _spawn_gold_reward_mote(parent: Node, start: Vector2, target: Vector2, index: int, count: int) -> void:
	var mote := GoldRewardMote.new()
	mote.name = "GoldRewardMote"
	var spread := float(index) - float(count - 1) * 0.5
	var start_offset := Vector2(spread * 10.0, -18.0 - float(index % 3) * 8.0)
	mote.global_position = start + start_offset
	mote.z_index = 39
	mote.scale = Vector2.ONE * (0.75 + float(index % 2) * 0.16)
	parent.add_child(mote)
	var travel := 0.58 + float(index) * 0.035
	var tween := mote.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(float(index) * 0.025)
	tween.tween_property(mote, "global_position", target + Vector2(spread * 3.0, float(index % 2) * 4.0), travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mote, "scale", Vector2.ONE * 0.28, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mote, "modulate:a", 0.08, 0.18).set_delay(maxf(travel - 0.18, 0.0))
	tween.tween_callback(mote.queue_free)


func _spawn_burst(parent: Node, pos: Vector2, preset: String, color: Color, local := false) -> void:
	if preset == "hit" and _spawn_impact_sequence(parent, pos, color, local):
		return
	var entry := _acquire_burst_entry(preset, color)
	var holder: Node2D = entry["holder"]
	var particles: CPUParticles2D = entry["particles"]
	if local:
		holder.position = pos
	else:
		holder.global_position = pos
	parent.add_child(holder)
	particles.restart()
	particles.emitting = true
	var wait := particles.lifetime + 0.15
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		_release_burst_entry(entry)
	)


func _acquire_burst_entry(preset: String, color: Color) -> Dictionary:
	for entry in _burst_pool:
		if not entry.get("in_use", false):
			entry["in_use"] = true
			_reconfigure_burst(entry["particles"], preset, color)
			return entry
	if _burst_pool.size() >= MAX_BURST_POOL:
		var oldest: Dictionary = _burst_pool[0]
		if oldest.get("holder") and is_instance_valid(oldest["holder"]):
			oldest["holder"].queue_free()
		_burst_pool.remove_at(0)
	var particles := VfxLibrary.create_burst(preset, color)
	var holder := Node2D.new()
	holder.name = "VfxBurst"
	holder.add_child(particles)
	var entry := {"holder": holder, "particles": particles, "in_use": true}
	_burst_pool.append(entry)
	return entry


func _reconfigure_burst(particles: CPUParticles2D, preset: String, color: Color) -> void:
	var fresh := VfxLibrary.create_burst(preset, color)
	particles.amount = fresh.amount
	particles.lifetime = fresh.lifetime
	particles.spread = fresh.spread
	particles.gravity = fresh.gravity
	particles.initial_velocity_min = fresh.initial_velocity_min
	particles.initial_velocity_max = fresh.initial_velocity_max
	particles.scale_amount_min = fresh.scale_amount_min
	particles.scale_amount_max = fresh.scale_amount_max
	particles.color = fresh.color
	particles.one_shot = true
	particles.explosiveness = fresh.explosiveness
	particles.direction = fresh.direction
	fresh.queue_free()


func _release_burst_entry(entry: Dictionary) -> void:
	entry["in_use"] = false
	var holder: Node2D = entry.get("holder")
	if holder and is_instance_valid(holder) and holder.get_parent():
		holder.get_parent().remove_child(holder)


func _spawn_impact_sequence(parent: Node, pos: Vector2, color: Color, local := false) -> bool:
	var frames := _load_impact_frames(color)
	if frames.is_empty():
		return false
	var holder := Node2D.new()
	holder.name = "ImpactSequence"
	if local:
		holder.position = pos
	else:
		holder.global_position = pos
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 6
	sprite.scale = IMPACT_SCALE
	sprite.texture = frames[0]
	holder.add_child(sprite)
	parent.add_child(holder)
	var frame_time := 1.0 / IMPACT_FPS
	var tween := holder.create_tween()
	for i in range(1, frames.size()):
		tween.tween_interval(frame_time)
		tween.tween_callback(_set_sprite_texture.bind(sprite, frames[i]))
	tween.tween_interval(frame_time)
	tween.tween_callback(holder.queue_free)
	return true


func _load_impact_frames(color: Color) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for path in AssetPaths.impact_frame_paths_for_color(color):
		var tex := AssetPaths.load_texture(path)
		if tex:
			frames.append(tex)
	return frames


func _set_sprite_texture(sprite: Sprite2D, tex: Texture2D) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.texture = tex
