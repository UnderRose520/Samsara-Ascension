class_name MetaUpgradeRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _rows: Array = []
static var _by_id: Dictionary = {}
static var _loaded := false


static func get_all() -> Array:
	_ensure_loaded()
	return _rows.duplicate()


static func get_upgrade(id: String) -> Dictionary:
	_ensure_loaded()
	return (_by_id.get(id, {}) as Dictionary).duplicate()


static func get_total(effect_key: String) -> float:
	var total := 0.0
	for row in get_all():
		if str(row.get("effect_key", "")) != effect_key:
			continue
		var level := SaveManager.get_meta_level(str(row.get("id", "")))
		total += float(row.get("effect_value", 0)) * level
	return total


static func next_cost(id: String) -> int:
	var row := get_upgrade(id)
	if row.is_empty():
		return 0
	var level := SaveManager.get_meta_level(id)
	var max_level := int(row.get("max_level", 0))
	if level >= max_level:
		return -1
	return int(row.get("cost_per_level", 0)) * (level + 1)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/meta/meta_upgrades.csv"):
		var id := str(row.get("id", ""))
		if id.is_empty():
			continue
		_rows.append(row)
		_by_id[id] = row
	_loaded = true
