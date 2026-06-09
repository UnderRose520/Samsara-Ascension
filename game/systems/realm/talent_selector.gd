class_name TalentSelector

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const AffixCompiler = preload("res://systems/affix/affix_compiler.gd")

static var _rows: Array = []
static var _loaded := false


static func roll_talents(realm_level: int, count: int, owned_ids: Array, rng: RandomNumberGenerator) -> Array:
	_ensure_loaded()
	var pool: Array = []
	for row in _rows:
		if int(row.get("realm_level", 0)) != realm_level:
			continue
		var id := str(row.get("id", ""))
		if id in owned_ids:
			continue
		pool.append(_compile_talent(row))
	var offers: Array = []
	var working := pool.duplicate()
	for _i in count:
		if working.is_empty():
			break
		var idx := rng.randi_range(0, working.size() - 1)
		offers.append(working[idx])
		working.remove_at(idx)
	return offers


static func get_talent(id: String):
	_ensure_loaded()
	for row in _rows:
		if str(row.get("id", "")) == id:
			return _compile_talent(row)
	return null


static func _compile_talent(row: Dictionary):
	return {
		"id": str(row.get("id", "")),
		"name": str(row.get("name", "")),
		"realm_level": int(row.get("realm_level", 1)),
		"effect1": str(row.get("effect1", "")),
		"description": str(row.get("description", "")),
	}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/talents/breakthrough_talents.csv"):
		_rows.append(row)
	_loaded = true
