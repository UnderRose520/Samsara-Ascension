class_name ComboGraph

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _definitions: Array = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/combos/combos.csv"):
		var required_raw := str(row.get("required_tags", ""))
		var required: Array = []
		if not required_raw.is_empty():
			required = required_raw.split("|", false)
		_definitions.append({
			"id": str(row.get("combo_id", "")),
			"name": str(row.get("name", "")),
			"required": required,
			"hint": str(row.get("hint_missing", "")),
		})
	_loaded = true


static func evaluate(owned_tags: PackedStringArray) -> Array:
	_ensure_loaded()
	var results: Array = []
	for def in _definitions:
		var matched: Array = []
		var missing: Array = []
		for req in def.required:
			if req in owned_tags:
				matched.append(req)
			else:
				missing.append(req)
		var total: int = def.required.size()
		results.append({
			"id": def.id,
			"name": def.name,
			"matched": matched,
			"missing": missing,
			"total": total,
			"complete": missing.is_empty(),
			"progress": float(matched.size()) / maxf(float(total), 1.0),
			"hint": def.hint,
		})
	return results


static func collect_tags_from_affixes(equipped: Array) -> PackedStringArray:
	var set := {}
	for tag in equipped:
		for combo_tag in tag.combo_tags:
			set[combo_tag] = true
	return PackedStringArray(set.keys())
