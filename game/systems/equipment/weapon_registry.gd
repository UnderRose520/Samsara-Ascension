class_name WeaponRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

const DEFAULT_WEAPON_ID := "starter_orb"

static var _weapons: Dictionary = {}
static var _loaded := false


static func get_weapon(id: String) -> Dictionary:
	_ensure_loaded()
	var key := id if not id.is_empty() else DEFAULT_WEAPON_ID
	if not _weapons.has(key):
		key = DEFAULT_WEAPON_ID
	return (_weapons.get(key, {}) as Dictionary).duplicate()


static func get_default_weapon() -> Dictionary:
	return get_weapon(DEFAULT_WEAPON_ID)


static func get_weapon_name(id: String) -> String:
	var row := get_weapon(id)
	var label := str(row.get("name", ""))
	return label if not label.is_empty() else id


static func get_attack_shape(id: String) -> String:
	return str(get_weapon(id).get("attack_shape", "projectile"))


static func format_hud_summary(id: String) -> String:
	var row := get_weapon(id)
	var name := str(row.get("name", id))
	var family := str(row.get("family", "weapon"))
	var shape := str(row.get("attack_shape", "projectile"))
	match shape:
		"short_arc":
			return "%s / %s / 近斩" % [name, family]
		"projectile":
			return "%s / %s / 远击" % [name, family]
	return "%s / %s" % [name, family]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_weapons.clear()
	for row in CsvLoader.load_rows("res://data/weapons/weapons.csv"):
		var id := str(row.get("weapon_id", ""))
		if id.is_empty():
			continue
		_weapons[id] = row
	_loaded = true
