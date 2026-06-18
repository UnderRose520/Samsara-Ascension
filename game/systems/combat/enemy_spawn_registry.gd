class_name EnemySpawnRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

static var _enemies_by_id: Dictionary = {}
static var _enemies_by_name: Dictionary = {}
static var _stage_pools: Dictionary = {}
static var _realms: Array = []
static var _loaded := false


static func get_display_name(enemy_id: String) -> String:
	var row := get_enemy_row(enemy_id)
	var name: String = str(row.get("display_name", ""))
	return name if not name.is_empty() else enemy_id


static func get_enemy_row(enemy_id: String) -> Dictionary:
	_ensure_loaded()
	return (_enemies_by_id.get(enemy_id, {}) as Dictionary).duplicate()


static func get_stat_mults(enemy_id: String) -> Dictionary:
	var row := get_enemy_row(enemy_id)
	return {
		"hp": float(row.get("hp_mult", 1.0)),
		"atk": float(row.get("atk_mult", 1.0)),
		"def": float(row.get("def_mult", 1.0)),
		"speed": float(row.get("speed_mult", 1.0)),
	}


static func get_weapon_id(enemy_id: String, display_name: String = "") -> String:
	_ensure_loaded()
	var row := get_enemy_row(enemy_id)
	if row.is_empty() and not display_name.is_empty():
		row = (_enemies_by_name.get(display_name, {}) as Dictionary).duplicate()
	var weapon_id := str(row.get("weapon_id", ""))
	return weapon_id if not weapon_id.is_empty() else "claw"


static func roll_instance_stats(enemy_id: String, stage_index: int, rng: RandomNumberGenerator, is_boss: bool = false) -> Dictionary:
	_ensure_loaded()
	var base := get_stat_mults(enemy_id)
	var realm := _realm_for_stage(stage_index)
	var realm_level := int(realm.get("realm_level", maxi(stage_index, 1)))
	var promoted := false
	var hp_roll := _range_roll(rng, realm, "hp")
	var atk_roll := _range_roll(rng, realm, "atk")
	var def_roll := _range_roll(rng, realm, "def")
	var speed_roll := _range_roll(rng, realm, "speed")
	if not is_boss and rng.randf() < float(realm.get("overroll_chance", 0.0)):
		var over := float(realm.get("overroll_mult", 1.0))
		hp_roll *= over
		atk_roll *= over
		def_roll *= over
	var score := hp_roll + atk_roll + def_roll
	if not is_boss and score >= float(realm.get("promote_score", INF)):
		var next_realm := _realm_by_level(realm_level + 1)
		if not next_realm.is_empty():
			realm = next_realm
			realm_level = int(realm.get("realm_level", realm_level + 1))
			promoted = true
			hp_roll = maxf(hp_roll, float(realm.get("hp_min", hp_roll)))
			atk_roll = maxf(atk_roll, float(realm.get("atk_min", atk_roll)))
			def_roll = maxf(def_roll, float(realm.get("def_min", def_roll)))
			speed_roll = maxf(speed_roll, float(realm.get("speed_min", speed_roll)))
	return {
		"hp": float(base.get("hp", 1.0)) * hp_roll,
		"atk": float(base.get("atk", 1.0)) * atk_roll,
		"def": float(base.get("def", 1.0)) * def_roll,
		"speed": float(base.get("speed", 1.0)) * speed_roll,
		"realm_level": realm_level,
		"realm_name": str(realm.get("realm_name", "")),
		"prefix": str(realm.get("prefix", "")),
		"promoted": promoted,
	}


static func is_elite_display_name(display_name: String) -> bool:
	var row: Dictionary = _enemies_by_name.get(display_name, {})
	return row.get("is_elite", false)


static func pick_for_stage(stage_index: int, rng: RandomNumberGenerator, exclude_elite: bool = false) -> String:
	var pool: PackedStringArray = _get_stage_pool(stage_index)
	var candidates: Array = []
	for enemy_id in pool:
		var row: Dictionary = _enemies_by_id.get(enemy_id, {})
		if row.is_empty():
			continue
		if exclude_elite and row.get("is_elite", false):
			continue
		candidates.append(enemy_id)
	if candidates.is_empty():
		return pool[0] if not pool.is_empty() else "wild_wolf"
	return str(candidates[rng.randi_range(0, candidates.size() - 1)])


static func resolve_archetype(display_name: String, is_boss: bool, room_type: String) -> String:
	_ensure_loaded()
	if is_boss:
		return "boss"
	var row: Dictionary = _enemies_by_name.get(display_name, {})
	if not row.is_empty():
		if row.get("is_elite", false) or room_type == "combat_hard":
			return "elite"
		return str(row.get("archetype", "normal"))
	if room_type == "combat_hard":
		return "elite"
	return "normal"


static func resolve_archetype_for_id(enemy_id: String, is_boss: bool, room_type: String) -> String:
	return resolve_archetype(get_display_name(enemy_id), is_boss, room_type)


static func resolve_spawn_name(index: int, count: int, room: Dictionary, is_boss: bool) -> String:
	if is_boss:
		var boss_name := str(room.get("boss_name", ""))
		return boss_name if not boss_name.is_empty() else get_display_name("boss")
	var stage_index := int(room.get("stage_index", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = RunContext.derive_rng_seed("spawn_name_%d_%d" % [stage_index, index])
	return get_display_name(pick_for_stage(stage_index, rng))


static func _get_stage_pool(stage_index: int) -> PackedStringArray:
	_ensure_loaded()
	var pool: PackedStringArray = _stage_pools.get(stage_index, PackedStringArray())
	if not pool.is_empty():
		return pool
	return PackedStringArray(["wild_wolf", "sky_bat", "mud_serpent"])


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/enemies/enemies.csv"):
		var enemy_id := str(row.get("enemy_id", ""))
		if enemy_id.is_empty():
			continue
		row["is_elite"] = VariantUtils.as_bool(row.get("is_elite", false))
		_enemies_by_id[enemy_id] = row
		var display_name := str(row.get("display_name", ""))
		if not display_name.is_empty():
			_enemies_by_name[display_name] = row
	for row in CsvLoader.load_rows("res://data/enemies/stage_enemy_pools.csv"):
		var stage_index := int(row.get("stage_index", 0))
		if stage_index <= 0:
			continue
		var ids := str(row.get("enemy_ids", "")).split("|")
		var pool := PackedStringArray()
		for raw_id in ids:
			var id := str(raw_id).strip_edges()
			if not id.is_empty():
				pool.append(id)
		_stage_pools[stage_index] = pool
	for row in CsvLoader.load_rows("res://data/enemies/enemy_realms.csv"):
		row["realm_level"] = int(row.get("realm_level", 1))
		row["min_stage"] = int(row.get("min_stage", 1))
		row["max_stage"] = int(row.get("max_stage", 99))
		_realms.append(row)
	_loaded = true


static func _range_roll(rng: RandomNumberGenerator, realm: Dictionary, key: String) -> float:
	var low := float(realm.get("%s_min" % key, 1.0))
	var high := float(realm.get("%s_max" % key, low))
	if not is_finite(low):
		low = 1.0
	if not is_finite(high):
		high = low
	if low > high:
		var tmp := low
		low = high
		high = tmp
	return rng.randf_range(low, high)


static func _realm_for_stage(stage_index: int) -> Dictionary:
	for realm in _realms:
		if stage_index >= int(realm.get("min_stage", 1)) and stage_index <= int(realm.get("max_stage", 99)):
			return (realm as Dictionary).duplicate()
	return _realm_by_level(clampi(stage_index, 1, 5))


static func _realm_by_level(level: int) -> Dictionary:
	for realm in _realms:
		if int((realm as Dictionary).get("realm_level", 0)) == level:
			return (realm as Dictionary).duplicate()
	return {}
