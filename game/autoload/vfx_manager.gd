extends Node

const VfxLibrary = preload("res://vfx/vfx_library.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

const MAX_BURST_POOL := 40
const IMPACT_FPS := 14.0
const IMPACT_SCALE := Vector2(2.0, 2.0)
const IMPACT_TIER_SCALE := {
	1: Vector2(1.18, 1.18),
	2: Vector2(1.55, 1.55),
	3: Vector2(1.95, 1.95),
}
const GOLD_REWARD_TARGET_SCREEN := Vector2(126.0, 72.0)
const GOLD_REWARD_COLOR := Color(1.0, 0.84, 0.22, 1.0)

var _burst_pool: Array = []
var _gold_reward_mote_spawn_count := 0
var _gold_reward_mote_texture_hits := 0


class SpawnTelegraph:
	extends Node2D

	var color := Color(1.0, 0.35, 0.22, 0.0)
	var duration := 0.55
	var elapsed := 0.0
	var radius := 34.0
	var elite := false
	var reduced_motion := false
	var texture: Texture2D

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var pulse := 0.35 if reduced_motion else sin(t * PI)
		var alpha := 0.10 + pulse * 0.22
		if texture:
			var size := radius * (2.15 if elite else 1.85)
			var rect := Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size))
			draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, alpha))


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
	var texture: Texture2D
	var kind := "line"

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
		var alpha := 0.18 if reduced_motion else lerpf(0.22, 0.03, t)
		if texture:
			draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
			if kind == "melee":
				var size := maxf(66.0, length * 0.92)
				draw_texture_rect(
					texture,
					Rect2(Vector2(24.0, -size * 0.5), Vector2(size, size)),
					false,
					Color(1.0, 1.0, 1.0, alpha)
				)
			else:
				var lane_h := maxf(12.0, width * (2.6 if kind == "dash" else 2.0))
				if kind == "sniper":
					lane_h = maxf(9.0, width * 1.85)
				draw_texture_rect(
					texture,
					Rect2(Vector2(24.0, -lane_h * 0.5), Vector2(maxf(72.0, length * 0.94), lane_h)),
					false,
					Color(1.0, 1.0, 1.0, alpha)
				)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class GoldRewardMote:
	extends Sprite2D

	func _ready() -> void:
		apply_texture()

	func apply_texture() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if texture == null:
			texture = AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
		modulate = Color(1.0, 0.88, 0.42, 0.74)

	func has_texture() -> bool:
		return texture != null


class ReducedImpactMark:
	extends Sprite2D

	var color := Color.WHITE
	var duration := 0.18
	var elapsed := 0.0
	var radius := 18.0
	var tier := 1
	var element := ""
	var status := ""

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		elapsed += delta
		var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		modulate.a = 0.42 * (1.0 - t)
		scale = Vector2.ONE * (0.95 + float(tier - 1) * 0.18 + t * 0.12)
		if elapsed >= duration:
			queue_free()


func should_reduce_motion() -> bool:
	return SaveManager.get_display_setting("reduce_motion")


func spawn_world(global_pos: Vector2, preset: String, color: Color) -> void:
	if should_reduce_motion():
		return
	var parent := _world_parent()
	if parent == null:
		return
	_spawn_burst(parent, global_pos, preset, color)


func spawn_world_semantic(global_pos: Vector2, preset: String, color: Color, element: String = "", status: String = "", tier: int = 1) -> void:
	if global_pos == Vector2.INF:
		return
	var parent := _world_parent()
	if parent == null:
		return
	var resolved_tier := clampi(tier, 1, 3)
	var toned_color := VfxLibrary.ink_vfx_color(color, preset, element, status, resolved_tier)
	if preset == "hit":
		if should_reduce_motion():
			_spawn_reduced_impact(parent, global_pos, toned_color, resolved_tier, element, status)
			return
		if _spawn_impact_sequence(parent, global_pos, toned_color, false, element, status, resolved_tier):
			return
	if should_reduce_motion():
		return
	_spawn_burst(parent, global_pos, preset, color, false, element, status, resolved_tier)


func spawn_hit_feedback(global_pos: Vector2, element: String, status: String, color: Color, tier: int = 1) -> void:
	spawn_world_semantic(global_pos, "hit", color, element, status, tier)


func spawn_enemy_telegraph(global_pos: Vector2, elite := false, duration := 0.55) -> Node2D:
	var parent := _world_parent()
	if parent == null:
		return null
	var marker := SpawnTelegraph.new()
	marker.name = "EnemySpawnTelegraph"
	marker.global_position = global_pos
	marker.reduced_motion = should_reduce_motion()
	marker.duration = minf(duration, 0.38) if marker.reduced_motion else duration
	marker.elite = elite
	marker.color = Color(1.0, 0.28, 0.18, 1.0)
	marker.texture = AssetPaths.load_texture(AssetPaths.enemy_spawn_telegraph(elite))
	marker.z_index = 4
	parent.add_child(marker)
	return marker


func spawn_enemy_attack_telegraph(global_pos: Vector2, direction: Vector2, length := 180.0, duration := 0.38, width := 8.0, color := Color(1.0, 0.38, 0.24, 1.0), kind := "line") -> Node2D:
	var parent := _world_parent()
	if parent == null:
		return null
	var marker := AttackTelegraph.new()
	marker.name = "EnemyAttackTelegraph"
	marker.global_position = global_pos
	marker.direction = direction
	marker.length = length
	marker.reduced_motion = should_reduce_motion()
	marker.duration = minf(duration, 0.28) if marker.reduced_motion else duration
	marker.width = width
	marker.color = color
	marker.kind = kind
	marker.texture = AssetPaths.load_texture(AssetPaths.enemy_attack_telegraph(kind))
	marker.z_index = 5
	parent.add_child(marker)
	return marker


func spawn_gold_reward_feedback(global_pos: Vector2, amount: int, target_screen_pos := GOLD_REWARD_TARGET_SCREEN) -> void:
	if amount <= 0:
		return
	var parent := _world_parent()
	if parent == null:
		return
	var target := _screen_to_world(target_screen_pos)
	_spawn_gold_reward_text(parent, global_pos, amount)
	_gold_reward_mote_spawn_count = 0
	_gold_reward_mote_texture_hits = 0
	if should_reduce_motion():
		return
	var count := clampi(int(ceilf(float(amount) / 12.0)), 3, 5)
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
	var tier := 2 if bool(result.get("is_crit", false)) or bool(result.get("is_combo", false)) else 1
	spawn_world_semantic(pos, VfxLibrary.preset_for_damage(result), VfxLibrary.color_for_damage(result), str(result.get("element", "")), str(result.get("status", "")), tier)


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
	label.position = global_pos + Vector2(-28.0, -46.0)
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.13, 0.08, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "position", label.position + Vector2(0, -12), 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.32).set_delay(0.48)
	tween.tween_callback(label.queue_free)


func _spawn_gold_reward_mote(parent: Node, start: Vector2, target: Vector2, index: int, count: int) -> void:
	var mote := GoldRewardMote.new()
	mote.name = "GoldRewardMote"
	mote.apply_texture()
	_gold_reward_mote_spawn_count += 1
	if mote.has_texture():
		_gold_reward_mote_texture_hits += 1
	var spread := float(index) - float(count - 1) * 0.5
	var start_offset := Vector2(spread * 7.0, -14.0 - float(index % 3) * 5.0)
	mote.global_position = start + start_offset
	mote.z_index = 39
	mote.scale = Vector2.ONE * (0.42 + float(index % 2) * 0.10)
	parent.add_child(mote)
	var travel := 0.58 + float(index) * 0.035
	var tween := mote.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(float(index) * 0.025)
	tween.tween_property(mote, "global_position", target + Vector2(spread * 3.0, float(index % 2) * 4.0), travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mote, "scale", Vector2.ONE * 0.18, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mote, "modulate:a", 0.08, 0.18).set_delay(maxf(travel - 0.18, 0.0))
	tween.tween_callback(mote.queue_free)


func get_gold_reward_mote_spawn_count() -> int:
	return _gold_reward_mote_spawn_count


func get_gold_reward_mote_texture_hit_count() -> int:
	return _gold_reward_mote_texture_hits


func _spawn_burst(parent: Node, pos: Vector2, preset: String, color: Color, local := false, element: String = "", status: String = "", tier: int = 1) -> void:
	if preset == "hit" and _spawn_impact_sequence(parent, pos, color, local, element, status, tier):
		return
	var entry := _acquire_burst_entry(preset, color, element, status, tier)
	if entry.is_empty():
		return
	var holder := _entry_holder(entry)
	var particles := _entry_particles(entry)
	if holder == null or particles == null:
		return
	if local:
		holder.position = pos
	else:
		holder.global_position = pos
	parent.add_child(holder)
	particles.restart()
	particles.emitting = true
	var wait := particles.lifetime + 0.15
	var token := int(entry.get("token", 0))
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		_release_burst_entry(entry, token)
	)


func _acquire_burst_entry(preset: String, color: Color, element: String = "", status: String = "", tier: int = 1) -> Dictionary:
	_prune_invalid_burst_entries()
	for entry in _burst_pool:
		var holder := _entry_holder(entry)
		var particles := _entry_particles(entry)
		if holder == null or particles == null:
			continue
		if not bool(entry.get("in_use", false)):
			entry["in_use"] = true
			entry["token"] = int(entry.get("token", 0)) + 1
			_reconfigure_burst(particles, preset, color, element, status, tier)
			return entry
	if _burst_pool.size() >= MAX_BURST_POOL:
		return {}
	var particles := VfxLibrary.create_burst(preset, color, element, status, tier)
	var holder := Node2D.new()
	holder.name = "VfxBurst"
	holder.add_child(particles)
	var entry := {"holder": holder, "particles": particles, "in_use": true, "token": 1}
	_burst_pool.append(entry)
	return entry


func _prune_invalid_burst_entries() -> void:
	_burst_pool = _burst_pool.filter(func(entry: Dictionary) -> bool:
		return _entry_holder(entry) != null and _entry_particles(entry) != null
	)


func _entry_holder(entry: Dictionary) -> Node2D:
	var value: Variant = entry.get("holder")
	if value == null or not is_instance_valid(value):
		return null
	var holder := value as Node2D
	if holder == null or holder.is_queued_for_deletion():
		return null
	return holder


func _entry_particles(entry: Dictionary) -> CPUParticles2D:
	var value: Variant = entry.get("particles")
	if value == null or not is_instance_valid(value):
		return null
	var particles := value as CPUParticles2D
	if particles == null or particles.is_queued_for_deletion():
		return null
	return particles


func _reconfigure_burst(particles: CPUParticles2D, preset: String, color: Color, element: String = "", status: String = "", tier: int = 1) -> void:
	if particles == null or not is_instance_valid(particles):
		return
	var fresh := VfxLibrary.create_burst(preset, color, element, status, tier)
	particles.amount = fresh.amount
	particles.lifetime = fresh.lifetime
	particles.spread = fresh.spread
	particles.gravity = fresh.gravity
	particles.initial_velocity_min = fresh.initial_velocity_min
	particles.initial_velocity_max = fresh.initial_velocity_max
	particles.scale_amount_min = fresh.scale_amount_min
	particles.scale_amount_max = fresh.scale_amount_max
	particles.color = fresh.color
	particles.texture = fresh.texture
	particles.one_shot = true
	particles.explosiveness = fresh.explosiveness
	particles.direction = fresh.direction
	fresh.queue_free()


func _release_burst_entry(entry: Dictionary, token: int) -> void:
	if entry.is_empty() or not _burst_pool.has(entry):
		return
	if token != int(entry.get("token", -1)) or not bool(entry.get("in_use", false)):
		return
	entry["in_use"] = false
	var holder := _entry_holder(entry)
	if holder == null:
		_burst_pool.erase(entry)
		entry.erase("holder")
		entry.erase("particles")
		return
	if holder.get_parent():
		holder.get_parent().remove_child(holder)


func _spawn_reduced_impact(parent: Node, pos: Vector2, color: Color, tier: int, element: String = "", status: String = "") -> void:
	var mark := ReducedImpactMark.new()
	mark.name = "ReducedImpactMark"
	mark.global_position = pos
	mark.color = color
	mark.tier = clampi(tier, 1, 3)
	mark.element = element
	mark.status = status
	var frames := _load_impact_frames(color, element, status)
	if frames.is_empty():
		return
	mark.texture = frames[0]
	mark.modulate = Color(color.r, color.g, color.b, 0.44)
	mark.z_index = 6
	parent.add_child(mark)


func _spawn_impact_sequence(parent: Node, pos: Vector2, color: Color, local := false, element: String = "", status: String = "", tier: int = 1) -> bool:
	var frames := _load_impact_frames(color, element, status)
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
	sprite.scale = IMPACT_TIER_SCALE.get(clampi(tier, 1, 3), IMPACT_SCALE)
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


func _load_impact_frames(color: Color, element: String = "", status: String = "") -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for path in AssetPaths.impact_frame_paths_for_semantics(element, status, color):
		var tex := AssetPaths.load_texture(path)
		if tex:
			frames.append(tex)
	return frames


func _set_sprite_texture(sprite: Sprite2D, tex: Texture2D) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.texture = tex
