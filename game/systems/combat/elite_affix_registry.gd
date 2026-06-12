class_name EliteAffixRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _affixes: Dictionary = {}
static var _loaded := false


static func get_affix(affix_id: String) -> Dictionary:
	_ensure_loaded()
	return (_affixes.get(affix_id, {}) as Dictionary).duplicate()


static func get_label(affix_id: String) -> String:
	var row := get_affix(affix_id)
	var label := str(row.get("label", ""))
	return label if not label.is_empty() else affix_id


static func roll_affixes(rng: RandomNumberGenerator, count: int) -> Array:
	_ensure_loaded()
	var ids := _affixes.keys()
	if ids.is_empty() or count <= 0:
		return []
	var picked: Array = []
	var pool: Array = ids.duplicate()
	for _i in count:
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked


static func apply_to_enemy(enemy: Node, affix_ids: Array) -> void:
	if enemy == null or affix_ids.is_empty():
		return
	if enemy.has_method("apply_elite_affixes"):
		enemy.apply_elite_affixes(affix_ids)


static func format_labels(affix_ids: Array) -> String:
	var labels: PackedStringArray = []
	for affix_id in affix_ids:
		labels.append(get_label(str(affix_id)))
	return " · ".join(labels)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/enemies/elite_affixes.csv"):
		var id := str(row.get("affix_id", ""))
		if id.is_empty():
			continue
		_affixes[id] = row
	_loaded = true
