class_name DaoTraditionRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

const CATEGORY_LABELS := {
	0: "skill",
	1: "spell",
	2: "constitution",
	3: "divine",
	4: "synergy",
	5: "companion",
}

const ELEMENT_LABELS := {
	0: "none",
	1: "fire",
	2: "water",
	3: "thunder",
	4: "wood",
	5: "earth",
	6: "chaos",
	7: "soul",
}

static var _rows: Array = []
static var _slots_by_dao: Dictionary = {}
static var _loaded := false


static func try_awaken(holder: Node):
	if not RunContext.dao_tradition_awakened_this_run.is_empty():
		return null
	for row in _all_rows():
		var progress := _progress_for_row(row, holder)
		if int(progress.get("matched", 0)) < int(progress.get("total", 1)):
			continue
		return _compile(row)
	return null


static func get_best_progress(holder: Node) -> Dictionary:
	var best := {"name": "—", "matched": 0, "total": 1, "progress": 0.0, "id": "", "missing_slots": []}
	for row in _all_rows():
		var info := _progress_for_row(row, holder)
		if float(info.get("progress", 0.0)) > float(best.get("progress", 0.0)):
			best = info
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


static func _collect_affix_tags(holder: Node) -> Array:
	var entries: Array = []
	if holder == null:
		return entries
	for tag in holder.equipped:
		var tag_set := {}
		for combo_tag in tag.combo_tags:
			tag_set[str(combo_tag)] = true
		tag_set[str(CATEGORY_LABELS.get(int(tag.category), ""))] = true
		tag_set[str(ELEMENT_LABELS.get(int(tag.element), ""))] = true
		entries.append({
			"id": str(tag.id),
			"name": str(tag.name),
			"tags": tag_set,
		})
	return entries


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


static func _progress_for_row(row: Dictionary, holder: Node) -> Dictionary:
	var dao_id := str(row.get("id", ""))
	var slots: Array = _slots_by_dao.get(dao_id, [])
	if slots.is_empty():
		return _tag_progress_for_row(row, holder)
	return _slot_progress_for_row(row, holder, slots)


static func _tag_progress_for_row(row: Dictionary, holder: Node) -> Dictionary:
	var owned_tags := _collect_tags(holder)
	var required := _required_tags(row)
	var matched := 0
	var missing: Array = []
	for tag_name in required:
		if tag_name in owned_tags:
			matched += 1
		else:
			missing.append(str(tag_name))
	var total := maxi(required.size(), 1)
	return {
		"id": str(row.get("id", "")),
		"name": str(row.get("name", "")),
		"matched": matched,
		"total": total,
		"progress": float(matched) / float(total),
		"missing_slots": missing,
	}


static func _slot_progress_for_row(row: Dictionary, holder: Node, slots: Array) -> Dictionary:
	var affixes := _collect_affix_tags(holder)
	var match_slots := _expand_required_slots(slots)
	var assignment := _find_best_slot_assignment(match_slots, affixes)
	var matched_slots: Array = []
	var missing_slots: Array = []
	for slot_index in match_slots.size():
		var slot: Dictionary = match_slots[slot_index]
		var slot_name := str(slot.get("slot_name", slot.get("slot_id", "")))
		if assignment.has(slot_index):
			matched_slots.append(slot_name)
		else:
			missing_slots.append(slot_name)
	var total := maxi(match_slots.size(), 1)
	return {
		"id": str(row.get("id", "")),
		"name": str(row.get("name", "")),
		"matched": matched_slots.size(),
		"total": total,
		"progress": float(matched_slots.size()) / float(total),
		"matched_slots": matched_slots,
		"missing_slots": missing_slots,
	}


static func _expand_required_slots(slots: Array) -> Array:
	var expanded: Array = []
	for slot in slots:
		var slot_def: Dictionary = slot
		var count := maxi(int(slot_def.get("required_count", 1)), 1)
		for i in count:
			var copy := slot_def.duplicate()
			if count > 1:
				copy["slot_name"] = "%s %d/%d" % [str(slot_def.get("slot_name", slot_def.get("slot_id", ""))), i + 1, count]
			expanded.append(copy)
	return expanded


static func _find_best_slot_assignment(slots: Array, affixes: Array) -> Dictionary:
	return _match_slots_recursive(slots, affixes, 0, {}, {})


static func _match_slots_recursive(
	slots: Array,
	affixes: Array,
	slot_index: int,
	used_affixes: Dictionary,
	current: Dictionary,
) -> Dictionary:
	if slot_index >= slots.size():
		return current.duplicate()
	var best := _match_slots_recursive(slots, affixes, slot_index + 1, used_affixes, current)
	var slot: Dictionary = slots[slot_index]
	var accepted: PackedStringArray = slot.get("accepted_tags", PackedStringArray())
	for affix_index in affixes.size():
		if used_affixes.get(affix_index, false):
			continue
		var affix: Dictionary = affixes[affix_index]
		var tag_set: Dictionary = affix.get("tags", {})
		if not _slot_accepts_any(tag_set, accepted):
			continue
		var next_used := used_affixes.duplicate()
		var next_current := current.duplicate()
		next_used[affix_index] = true
		next_current[slot_index] = affix_index
		var candidate := _match_slots_recursive(slots, affixes, slot_index + 1, next_used, next_current)
		if candidate.size() > best.size():
			best = candidate
	return best


static func _slot_accepts_any(tag_set: Dictionary, accepted: PackedStringArray) -> bool:
	for tag_name in accepted:
		if tag_set.has(str(tag_name)):
			return true
	return false


static func _compile(row: Dictionary) -> Dictionary:
	return {
		"id": str(row.get("id", "")),
		"name": str(row.get("name", "")),
		"title": str(row.get("title", "")),
		"description": str(row.get("description", "")),
		"passive_dsl": str(row.get("passive_dsl", "")),
		"required_tags": _required_tags(row),
		"slots": _slots_by_dao.get(str(row.get("id", "")), []),
	}


static func _all_rows() -> Array:
	_ensure_loaded()
	return _rows


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/dao_traditions/dao_traditions.csv"):
		_rows.append(row)
	for row in CsvLoader.load_rows("res://data/dao_traditions/dao_tradition_slots.csv"):
		var dao_id := str(row.get("dao_id", ""))
		if dao_id.is_empty():
			continue
		var raw_tags := str(row.get("accepted_tags", "")).strip_edges()
		var slot := {
			"slot_id": str(row.get("slot_id", "")),
			"slot_name": str(row.get("slot_name", row.get("slot_id", ""))),
			"accepted_tags": PackedStringArray(raw_tags.split("|", false)) if not raw_tags.is_empty() else PackedStringArray(),
			"required_count": int(row.get("required_count", 1)),
		}
		if not _slots_by_dao.has(dao_id):
			_slots_by_dao[dao_id] = []
		(_slots_by_dao[dao_id] as Array).append(slot)
	_loaded = true
