class_name ActiveSpellRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _spells: Dictionary = {}
static var _loaded := false


static func get_spell(id: String = "lie_yan_bolt") -> Dictionary:
	_ensure_loaded()
	return (_spells.get(id, {}) as Dictionary).duplicate()


static func get_default_spell() -> Dictionary:
	return get_spell("lie_yan_bolt")


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/spells/active_spells.csv"):
		var spell_id := str(row.get("id", ""))
		if spell_id.is_empty():
			continue
		_spells[spell_id] = row
	_loaded = true
