class_name WaveComposer

const EnemySpawnRegistry = preload("res://systems/combat/enemy_spawn_registry.gd")
const EliteAffixRegistry = preload("res://systems/combat/elite_affix_registry.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")


static func compose_horde_batch(
	template_id: String,
	count: int,
	stage_index: int,
	wave_num: int,
	rng: RandomNumberGenerator,
) -> Array:
	count = maxi(count, 1)
	if template_id == "combat_hard" and wave_num > 0 and wave_num % 3 == 0:
		var elite_affixes := EliteAffixRegistry.roll_affixes(rng, 1)
		var elite_id := "elite" if stage_index <= 2 else "furnace_golem"
		var minions := maxi(count - 1, 1)
		return [
			{"enemy_id": elite_id, "count": 1, "affixes": elite_affixes},
		] + _stage_spawns(minions, stage_index, rng, true)
	return _stage_spawns(count, stage_index, rng, template_id != "combat_hard")


static func compose(template_id: String, enemy_count: int, stage_index: int, rng: RandomNumberGenerator) -> Array:
	enemy_count = clampi(enemy_count, 1, GameConstants.MAX_ROOM_ENEMIES)
	if template_id == "boss":
		return [{"delay_after": 0.0, "spawns": [{"enemy_id": "boss", "count": 1}]}]
	if template_id == "combat_hard":
		return _compose_hard(enemy_count, stage_index, rng)
	return _compose_normal(enemy_count, stage_index, rng)


static func wave_count(room: Dictionary) -> int:
	return (room.get("waves", []) as Array).size()


static func _compose_normal(enemy_count: int, stage_index: int, rng: RandomNumberGenerator) -> Array:
	# 普通战房：同屏一次性刷满，制造群怪压力
	return [{
		"delay_after": 0.0,
		"spawns": _stage_spawns(enemy_count, stage_index, rng, true),
	}]


static func _compose_hard(enemy_count: int, stage_index: int, rng: RandomNumberGenerator) -> Array:
	var elite_affixes := EliteAffixRegistry.roll_affixes(rng, 1)
	var elite_id := "elite" if stage_index <= 2 else "furnace_golem"
	var minion_count := maxi(enemy_count - 1, 1)
	# 精英与杂兵同波入场；人数过多时再补一小波增援
	if enemy_count <= 10:
		return [{
			"delay_after": 0.0,
			"spawns": [
				{"enemy_id": elite_id, "count": 1, "affixes": elite_affixes},
			] + _stage_spawns(minion_count, stage_index, rng, true),
		}]
	var first_minions := maxi(minion_count / 2, 4)
	var second_minions := minion_count - first_minions
	return [
		{
			"delay_after": 0.0,
			"spawns": [
				{"enemy_id": elite_id, "count": 1, "affixes": elite_affixes},
			] + _stage_spawns(first_minions, stage_index, rng, true),
		},
		{
			"delay_after": 2.0,
			"spawns": _stage_spawns(second_minions, stage_index, rng, false),
		},
	]


static func _stage_spawns(count: int, stage_index: int, rng: RandomNumberGenerator, exclude_elite: bool) -> Array:
	if count <= 0:
		return []
	var spawns: Array = []
	var remaining := count
	while remaining > 0:
		var enemy_id := EnemySpawnRegistry.pick_for_stage(stage_index, rng, exclude_elite)
		var batch := mini(remaining, 1 + rng.randi_range(0, 2))
		spawns.append({"enemy_id": enemy_id, "count": batch})
		remaining -= batch
	return spawns
