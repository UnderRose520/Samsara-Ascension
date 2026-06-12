class_name TargetingConfig
extends RefCounted

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _values: Dictionary = {}
static var _loaded := false


static func get_float(key: String, default_value: float = 0.0) -> float:
	_ensure_loaded()
	return float(_values.get(key, default_value))


static func reload() -> void:
	_loaded = false
	_values.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/combat/targeting_config.csv"):
		var id := str(row.get("key", "")).strip_edges()
		if id.is_empty():
			continue
		_values[id] = float(row.get("value", 0.0))
	_loaded = true
