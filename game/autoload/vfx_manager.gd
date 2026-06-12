extends Node

const VfxLibrary = preload("res://vfx/vfx_library.gd")

const MAX_BURST_POOL := 40

var _burst_pool: Array = []


func should_reduce_motion() -> bool:
	return SaveManager.get_display_setting("reduce_motion")


func spawn_world(global_pos: Vector2, preset: String, color: Color) -> void:
	if should_reduce_motion():
		return
	var parent := _world_parent()
	if parent == null:
		return
	_spawn_burst(parent, global_pos, preset, color)


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


func _spawn_burst(parent: Node, pos: Vector2, preset: String, color: Color, local := false) -> void:
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
