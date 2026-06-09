class_name DaoTraditionRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _rows: Array = []
static var _loaded := false


static func try_awaken(holder: Node):
	if not RunContext.dao_tradition_awakened_this_run.is_empty():
		return null
	var owned_tags := _collect_tags(holder)
	for row in _all_rows():
		if not _matches(row, owned_tags):
			continue
		return _compile(row)
	return null


static func get_best_progress(holder: Node) -> Dictionary:
	var owned_tags := _collect_tags(holder)
	var best := {"name": "—", "matched": 0, "total": 1, "progress": 0.0, "id": ""}
	for row in _all_rows():
		var required := _required_tags(row)
		if required.is_empty():
			continue
		var matched := 0
		for tag_name in required:
			if tag_name in owned_tags:
				matched += 1
		var total := required.size()
		var progress := float(matched) / float(total)
		if progress > float(best.get("progress", 0.0)):
			best = {
				"id": str(row.get("id", "")),
				"name": str(row.get("name", "")),
				"matched": matched,
				"total": total,
				"progress": progress,
			}
	return best


static func get_tradition(id: String) -> Dictionary:
	for row in _all_rows():
		if str(row.get("id", "")) == id:
			return _compile(row)
	return {}


static func _collect_tags(holder: Node) -> Dictionary:
	var tags := {}
	if holder == null:
		return tags
	for tag in holder.equipped:
		for combo_tag in tag.combo_tags:
			tags[str(combo_tag)] = true
	return tags


static func _required_tags(row: Dictionary) -> PackedStringArray:
	var raw := str(row.get("required_tags", "")).strip_edges()
	if raw.is_empty():
		return PackedStringArray()
	return PackedStringArray(raw.split("|", false))


static func _matches(row: Dictionary, owned_tags: Dictionary) -> bool:
	for tag_name in _required_tags(row):
		if not owned_tags.has(tag_name):
			return false
	return true


static func _compile(row: Dictionary) -> Dictionary:
	return {
		"id": str(row.get("id", "")),
		"name": str(row.get("name", "")),
		"title": str(row.get("title", "")),
		"description": str(row.get("description", "")),
		"passive_dsl": str(row.get("passive_dsl", "")),
		"required_tags": _required_tags(row),
	}


static func _all_rows() -> Array:
	_ensure_loaded()
	return _rows


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/dao_traditions/dao_traditions.csv"):
		_rows.append(row)
	_loaded = true
