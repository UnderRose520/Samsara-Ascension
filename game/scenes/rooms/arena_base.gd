extends Node2D
class_name ArenaBase

## 战斗房共用逻辑：地形层、涌潮控制器、刷怪环、敌人清理与计数。

const GameConstants = preload("res://core/constants/game_constants.gd")
const WaveComposer = preload("res://systems/world/wave_composer.gd")
const HordeController = preload("res://systems/world/horde_controller.gd")
const EnemySpawnRegistry = preload("res://systems/combat/enemy_spawn_registry.gd")
const EliteAffixRegistry = preload("res://systems/combat/elite_affix_registry.gd")
const COMBAT_FLOOR_SCENE = preload("res://scenes/rooms/combat_floor.tscn")
const DUMMY_SCENE = preload("res://scenes/enemies/training_dummy.tscn")
const SPAWN_TELEGRAPH_DELAY := 0.55

var _combat_floor: Node2D
var _horde: HordeController
var _player: CharacterBody2D
var _pending_enemy_spawns := 0
var _spawn_generation := 0
var _horde_room_snapshot: Dictionary = {}


func setup_combat_floor() -> Node2D:
	_combat_floor = COMBAT_FLOOR_SCENE.instantiate()
	add_child(_combat_floor)
	move_child(_combat_floor, 0)
	return _combat_floor


func setup_horde_controller() -> HordeController:
	_horde = HordeController.new()
	_horde.name = "HordeController"
	_horde.spawn_batch_requested.connect(_on_horde_spawn_batch)
	_horde.horde_finished.connect(_on_horde_finished)
	add_child(_horde)
	return _horde


func bind_arena_player(player: CharacterBody2D) -> void:
	_player = player


func get_combat_floor() -> Node2D:
	return _combat_floor


func get_horde() -> HordeController:
	return _horde


func _arena_flow_rng(context: String) -> RandomNumberGenerator:
	return RunRng.run_controller(context)


func _arena_ring_layer(index: int) -> int:
	return index % 3


func _horde_should_tick(extra_block: bool = false) -> bool:
	return _horde.active and not _horde.finishing and not extra_block


func _horde_tick_paused() -> bool:
	return get_tree().paused or RunContext.ui_blocking


func _enemy_kill_blocked() -> bool:
	return false


func _get_horde_room_def() -> Dictionary:
	if not _horde_room_snapshot.is_empty():
		return _horde_room_snapshot.duplicate(true)
	return RunContext.get_current_room_def()


func _get_horde_heart_hp(_room: Dictionary, _is_boss: bool = false) -> float:
	return RunContext.get_enemy_hp_mult(false)


func _horde_room_type_id(_room: Dictionary) -> String:
	return GameEnums.room_type_id(_arena_room_type(_room))


func _arena_room_type(room: Dictionary) -> GameEnums.RoomType:
	return GameEnums.parse_room_type(str(room.get("type", "combat")))


func _horde_spawn_pos(index: int, total: int) -> Vector2:
	return _spawn_pos_on_ring(index, total)


func _clear_enemies() -> void:
	_spawn_generation += 1
	_horde_room_snapshot.clear()
	_pending_enemy_spawns = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	TerrainSystem.clear()


func _count_living_enemies() -> int:
	var count := _pending_enemy_spawns
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_node("HealthComponent") and node.get_node("HealthComponent").is_alive():
			count += 1
	return count


func _spawn_pos_on_ring(index: int, total: int) -> Vector2:
	var count := maxi(total, 1)
	var rng := _arena_flow_rng(_spawn_rng_context(index))
	var zone_pos := _spawn_pos_from_floor_zones(index, count, rng)
	if zone_pos != Vector2.INF:
		return zone_pos
	var angle := TAU * float(index) / float(count) - PI * 0.5
	angle += rng.randf_range(-0.06, 0.06)
	var ring_layer := _arena_ring_layer(index)
	var ring := GameConstants.ENEMY_SPAWN_RING + float(ring_layer) * GameConstants.ENEMY_SPAWN_RING_EXTRA
	var pos := GameConstants.ENEMY_SPAWN_CENTER + Vector2.from_angle(angle) * ring
	pos += Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	return _clamp_and_clear_spawn(pos)


func _spawn_pos_from_floor_zones(index: int, count: int, rng: RandomNumberGenerator) -> Vector2:
	if _combat_floor == null or not _combat_floor.has_method("get_spawn_zones"):
		return Vector2.INF
	var zones: Array = _combat_floor.call("get_spawn_zones")
	if zones.is_empty():
		return Vector2.INF
	var start := index % zones.size()
	for zone_offset in zones.size():
		var zone: Dictionary = zones[(start + zone_offset) % zones.size()]
		for _attempt in 6:
			var pos := _random_point_in_zone(zone, rng)
			pos += Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
			pos = GameConstants.clamp_to_arena(pos, 18.0)
			if not _is_spawn_safe_from_player(pos):
				continue
			if _combat_floor.has_method("is_spawn_position_clear") and not _combat_floor.call("is_spawn_position_clear", pos, 20.0):
				continue
			return pos
	return Vector2.INF


func _random_point_in_zone(zone: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var raw_center: Array = zone.get("center", [0, 0])
	var raw_size: Array = zone.get("size", [220, 120])
	var center := Vector2.ZERO
	var size := Vector2(220, 120)
	if raw_center.size() >= 2:
		center = Vector2(float(raw_center[0]), float(raw_center[1]))
	if raw_size.size() >= 2:
		size = Vector2(float(raw_size[0]), float(raw_size[1]))
	var angle := rng.randf_range(0.0, TAU)
	var radius := sqrt(rng.randf())
	return center + Vector2(cos(angle) * size.x * 0.5 * radius, sin(angle) * size.y * 0.5 * radius)


func _clamp_and_clear_spawn(pos: Vector2) -> Vector2:
	pos = GameConstants.clamp_to_arena(pos, 16.0)
	if not _is_spawn_safe_from_player(pos):
		pos = _push_spawn_away_from_player(pos)
	if _combat_floor == null or not _combat_floor.has_method("is_spawn_position_clear"):
		return pos
	if _combat_floor.call("is_spawn_position_clear", pos, 20.0):
		return pos
	var fallback_dirs := [
		Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
		Vector2(-1, -1).normalized(), Vector2(1, -1).normalized(),
		Vector2(-1, 1).normalized(), Vector2(1, 1).normalized(),
	]
	for dir in fallback_dirs:
		var candidate := GameConstants.clamp_to_arena(pos + dir * 72.0, 16.0)
		if not _is_spawn_safe_from_player(candidate):
			continue
		if _combat_floor.call("is_spawn_position_clear", candidate, 20.0):
			return candidate
	return pos


func _is_spawn_safe_from_player(pos: Vector2) -> bool:
	if _player == null or not is_instance_valid(_player):
		return true
	return pos.distance_to(_player.global_position) >= 150.0


func _push_spawn_away_from_player(pos: Vector2) -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return pos
	var dir := (pos - _player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return GameConstants.clamp_to_arena(_player.global_position + dir * 170.0, 16.0)


func _spawn_rng_context(index: int) -> String:
	return "spawn_%d_%d_%d" % [RunContext.current_stage, RunContext.current_room, index]


func _on_horde_spawn_batch(count: int) -> void:
	var room := _get_horde_room_def()
	var room_type_id := _horde_room_type_id(room)
	var hp_mult := float(room.get("hp_mult", 1.0))
	var heart_hp := _get_horde_heart_hp(room, false)
	var damage_mult := float(room.get("damage_mult", 1.0))
	var speed_mult := float(room.get("speed_mult", 1.0))
	var force_elite_pressure := bool(room.get("elite_pressure", false))
	var rng := _arena_flow_rng("horde_%d_%d" % [_horde.stage_idx, _horde.wave])
	var spawns: Array = WaveComposer.compose_horde_batch(
		_horde.room_type,
		count,
		_horde.stage_idx,
		_horde.wave,
		rng,
	)
	var announced_affix := false
	for spawn in spawns:
		var enemy_id := str(spawn.get("enemy_id", "normal"))
		var batch_count := int(spawn.get("count", 1))
		var affixes: Array = spawn.get("affixes", [])
		if force_elite_pressure and affixes.is_empty():
			affixes = EliteAffixRegistry.roll_affixes(rng, 1)
		if not announced_affix and affixes.size() > 0:
			EventBus.pet_coord_feedback.emit("精英词缀 · %s" % EliteAffixRegistry.format_labels(affixes))
			announced_affix = true
		for _i in batch_count:
			_spawn_horde_enemy({
				"enemy_id": enemy_id,
				"index": _horde.spawn_seq,
				"total": int(_horde.cfg.get("max_alive", 10)),
				"is_boss": false,
				"hp_mult": hp_mult,
				"heart_hp": heart_hp,
				"damage_mult": damage_mult,
				"speed_mult": speed_mult,
				"affixes": affixes,
				"room_type_id": room_type_id,
				"room_stage_index": int(room.get("stage_index", RunContext.current_stage)),
				"display_name_override": "",
			}, room)
			_horde.spawn_seq += 1


func _spawn_horde_enemy(spawn_def: Dictionary, room: Dictionary) -> void:
	_spawn_enemy_with_telegraph(spawn_def, room)


func _resolve_enemy_spawn_pos(spawn_def: Dictionary) -> Vector2:
	var index := int(spawn_def.get("index", 0))
	var total := int(spawn_def.get("total", 1))
	var is_boss := bool(spawn_def.get("is_boss", false))
	if is_boss:
		return GameConstants.ENEMY_BOSS_SPAWN
	return _horde_spawn_pos(index, total)


func _spawn_enemy_with_telegraph(spawn_def: Dictionary, room: Dictionary) -> void:
	var pos := _resolve_enemy_spawn_pos(spawn_def)
	spawn_def["spawn_pos"] = pos
	var affixes: Array = spawn_def.get("affixes", [])
	var is_elite_warning := bool(spawn_def.get("is_boss", false)) or affixes.size() > 0
	VfxManager.spawn_enemy_telegraph(pos, is_elite_warning, SPAWN_TELEGRAPH_DELAY)
	_pending_enemy_spawns += 1
	var generation := _spawn_generation
	get_tree().create_timer(SPAWN_TELEGRAPH_DELAY, false).timeout.connect(func() -> void:
		_finish_enemy_spawn(spawn_def, room, generation)
	)


func _finish_enemy_spawn(spawn_def: Dictionary, room: Dictionary, generation: int) -> void:
	if generation != _spawn_generation or not RunContext.run_active or not is_inside_tree():
		_pending_enemy_spawns = maxi(_pending_enemy_spawns - 1, 0)
		return
	if get_tree().paused or RunContext.ui_blocking:
		var tree := get_tree()
		if tree == null:
			_pending_enemy_spawns = maxi(_pending_enemy_spawns - 1, 0)
			return
		tree.create_timer(0.2, true).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_finish_enemy_spawn(spawn_def, room, generation)
		)
		return
	_pending_enemy_spawns = maxi(_pending_enemy_spawns - 1, 0)
	_spawn_enemy_dummy(spawn_def, room)


func _spawn_enemy_dummy(spawn_def: Dictionary, room: Dictionary) -> void:
	var enemy_id := str(spawn_def.get("enemy_id", "normal"))
	var index := int(spawn_def.get("index", 0))
	var total := int(spawn_def.get("total", 1))
	var is_boss := bool(spawn_def.get("is_boss", false))
	var hp_mult := float(spawn_def.get("hp_mult", 1.0))
	var heart_hp := float(spawn_def.get("heart_hp", 1.0))
	var affixes: Array = spawn_def.get("affixes", [])
	var room_type_id := str(spawn_def.get("room_type_id", "combat"))
	var dummy: CharacterBody2D = DUMMY_SCENE.instantiate()
	add_child(dummy)
	var spawn_pos: Vector2 = spawn_def.get("spawn_pos", _resolve_enemy_spawn_pos(spawn_def))
	dummy.global_position = spawn_pos
	var display_name := str(spawn_def.get("display_name_override", ""))
	if display_name.is_empty():
		display_name = EnemySpawnRegistry.get_display_name(enemy_id)
	if is_boss:
		display_name = str(room.get("boss_name", display_name))
	var stat_rng := _arena_flow_rng("enemy_stats_%d_%d_%s" % [RunContext.current_stage, index, enemy_id])
	var stage_index := int(spawn_def.get("room_stage_index", room.get("stage_index", RunContext.current_stage)))
	var enemy_stats := EnemySpawnRegistry.roll_instance_stats(enemy_id, stage_index, stat_rng, is_boss)
	var final_display_name := display_name
	if bool(enemy_stats.get("promoted", false)) and not is_boss:
		final_display_name = "%s%s" % [str(enemy_stats.get("prefix", "")), display_name]
	if dummy.has_method("configure_enemy_by_id"):
		dummy.configure_enemy_by_id(enemy_id, is_boss, room_type_id, display_name)
	elif dummy.has_method("configure_enemy"):
		dummy.configure_enemy(display_name, is_boss, room_type_id)
	elif is_boss and dummy.has_method("configure_as_boss"):
		dummy.configure_as_boss()
	if final_display_name != display_name and dummy.has_method("set_display_name_override"):
		dummy.set_display_name_override(final_display_name)
	if dummy.has_method("set_enemy_weapon_id"):
		dummy.set_enemy_weapon_id(EnemySpawnRegistry.get_weapon_id(enemy_id, display_name))
	if dummy.has_method("scale_contact_damage"):
		dummy.scale_contact_damage(float(enemy_stats.get("atk", 1.0)) * float(spawn_def.get("damage_mult", 1.0)))
	if dummy.has_method("scale_move_speed"):
		dummy.scale_move_speed(float(spawn_def.get("speed_mult", 1.0)))
	if dummy.has_method("apply_instance_stats"):
		dummy.apply_instance_stats(enemy_stats)
	if dummy.has_method("init_combat_slot") and _player:
		dummy.init_combat_slot(spawn_pos, _player.global_position, index, total, is_boss)
	if dummy.has_node("HealthComponent"):
		var health: Node = dummy.get_node("HealthComponent")
		if is_boss:
			health.max_hp = GameConstants.ENEMY_BOSS_HP * heart_hp * float(enemy_stats.get("hp", 1.0))
		else:
			health.max_hp = GameConstants.ENEMY_HP * hp_mult * heart_hp * float(enemy_stats.get("hp", 1.0))
		health.current_hp = health.max_hp
		health.changed.emit(health.current_hp, health.max_hp)
	EliteAffixRegistry.apply_to_enemy(dummy, affixes)


func _tick_horde(delta: float, extra_block: bool = false) -> void:
	if not _horde_should_tick(extra_block):
		return
	_horde.tick(delta, _count_living_enemies(), _horde_tick_paused())


func _on_enemy_killed(_enemy: Node) -> void:
	if _enemy_kill_blocked() or _horde.finishing:
		return
	if _horde.active:
		_horde.on_enemy_killed()
		return
	_on_enemy_killed_after_horde()


func _on_enemy_killed_after_horde() -> void:
	pass


func _on_horde_finished(_reason: String, _kills: int, _quota: int) -> void:
	_clear_enemies()
	_on_horde_cleared()


func _on_horde_cleared() -> void:
	pass
