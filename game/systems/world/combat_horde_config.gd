class_name CombatHordeConfig

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _rows: Dictionary = {}
static var _loaded := false

## 默认：第 N 重天 ≈ 10 + N*10 只（第3重天 50）
static func default_for(stage_index: int, room_type: String) -> Dictionary:
	var quota := 10 + stage_index * 10
	if room_type == "combat_hard":
		quota = int(roundf(float(quota) * 1.25))
	return {
		"kill_quota": quota,
		"time_limit_sec": 100.0 + stage_index * 20.0,
		"wave_interval_sec": maxf(4.0 - stage_index * 0.3, 2.5),
		"spawn_per_wave": mini(3 + stage_index, 7),
		"max_alive": mini(8 + stage_index, 14),
	}


static func get_for_stage(stage_index: int, room_type: String) -> Dictionary:
	_ensure_loaded()
	var key := "%s_%d" % [room_type, stage_index]
	if _rows.has(key):
		return _rows[key].duplicate()
	return default_for(stage_index, room_type)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/combat/combat_hordes.csv"):
		var room_type := str(row.get("room_type", "combat"))
		var stage_index := int(row.get("stage_index", 1))
		var key := "%s_%d" % [room_type, stage_index]
		_rows[key] = {
			"kill_quota": int(row.get("kill_quota", 20)),
			"time_limit_sec": float(row.get("time_limit_sec", 120.0)),
			"wave_interval_sec": float(row.get("wave_interval_sec", 4.0)),
			"spawn_per_wave": int(row.get("spawn_per_wave", 4)),
			"max_alive": int(row.get("max_alive", 10)),
		}
	_loaded = true
