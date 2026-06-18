class_name CultivationPathRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")

const DEFAULT_PATH_ID := "caster"

static var _paths: Dictionary = {}
static var _starting_paths: Dictionary = {}
static var _loaded := false


static func get_all_paths() -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in _paths.keys():
		result.append((_paths[id] as Dictionary).duplicate())
	var order := [DEFAULT_PATH_ID, "sword", "talisman", "body", "alchemy", "soul"]
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := str(a.get("path_id", ""))
		var b_id := str(b.get("path_id", ""))
		var a_index := order.find(a_id)
		var b_index := order.find(b_id)
		if a_index == -1:
			a_index = 999
		if b_index == -1:
			b_index = 999
		if a_index == b_index:
			return a_id < b_id
		return a_index < b_index
	)
	return result


static func get_path_def(id: String) -> Dictionary:
	_ensure_loaded()
	var key := id if not id.is_empty() else DEFAULT_PATH_ID
	if not _paths.has(key):
		key = DEFAULT_PATH_ID
	return (_paths.get(key, {}) as Dictionary).duplicate()


static func get_path_name(id: String) -> String:
	var row := get_path_def(id)
	var label := str(row.get("name", ""))
	return label if not label.is_empty() else id


static func get_weapon_id(path_id: String) -> String:
	var row := get_path_def(path_id)
	var weapon_id := str(row.get("weapon_id", ""))
	return weapon_id if not weapon_id.is_empty() else WeaponRegistry.DEFAULT_WEAPON_ID


static func get_focus_tags(path_id: String) -> Array:
	var row := get_path_def(path_id)
	var tags: Array = []
	for tag in str(row.get("focus_tags", "")).split("|", false):
		var cleaned := str(tag).strip_edges()
		if not cleaned.is_empty():
			tags.append(cleaned)
	return tags


static func get_starting_path_def(path_id: String) -> Dictionary:
	_ensure_loaded()
	var key := path_id if not path_id.is_empty() else DEFAULT_PATH_ID
	return (_starting_paths.get(key, {}) as Dictionary).duplicate()


static func get_first_minutes_goal(path_id: String, room_number: int) -> String:
	var row := get_starting_path_def(path_id)
	match room_number:
		1:
			return str(row.get("first_room_goal", ""))
		2:
			return str(row.get("second_room_synergy", ""))
		3:
			return str(row.get("third_room_choice", ""))
	return ""


static func format_summary(path_id: String) -> String:
	var row := get_path_def(path_id)
	var weapon_id := str(row.get("weapon_id", ""))
	return "%s / %s / %s" % [
		str(row.get("name", path_id)),
		str(row.get("subtitle", "")),
		WeaponRegistry.get_weapon_name(weapon_id),
	]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_paths.clear()
	for row in CsvLoader.load_rows("res://data/paths/cultivation_paths.csv"):
		var id := str(row.get("path_id", ""))
		if id.is_empty():
			continue
		_paths[id] = row
	_starting_paths.clear()
	for row in CsvLoader.load_rows("res://data/design/starting_paths.csv"):
		var id := str(row.get("path_id", ""))
		if id.is_empty():
			continue
		_starting_paths[id] = row
	_loaded = true
