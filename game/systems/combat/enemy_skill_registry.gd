class_name EnemySkillRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _skills: Dictionary = {}
static var _archetypes: Dictionary = {}
static var _loaded := false


static func get_archetype(name: String) -> Dictionary:
	_ensure_loaded()
	return (_archetypes.get(name, _archetypes.get("normal", {})) as Dictionary).duplicate()


static func get_skill(id: String) -> Dictionary:
	_ensure_loaded()
	return (_skills.get(id, {}) as Dictionary).duplicate()


static func get_skills_for_archetype(archetype: String) -> Array:
	var row := get_archetype(archetype)
	var ids := str(row.get("skill_ids", "melee")).split("|")
	var skills: Array = []
	for raw_id in ids:
		var skill_id := str(raw_id).strip_edges()
		if skill_id.is_empty():
			continue
		var skill := get_skill(skill_id)
		if not skill.is_empty():
			skills.append(skill)
	return skills


static func resolve_archetype(display_name: String, is_boss: bool, room_type: String) -> String:
	if is_boss:
		return "boss"
	if display_name == "精英木人" or room_type == "combat_hard":
		return "elite"
	if display_name == "投弹木人":
		return "ranged"
	if display_name == "弩手木人":
		return "sniper"
	if display_name == "狂战木人":
		return "berserker"
	if display_name == "符师木人":
		return "shaman"
	return "normal"


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/enemies/enemy_skills.csv"):
		var skill_id := str(row.get("id", ""))
		if skill_id.is_empty():
			continue
		_skills[skill_id] = row
	for row in CsvLoader.load_rows("res://data/enemies/enemy_archetypes.csv"):
		var archetype := str(row.get("archetype", ""))
		if archetype.is_empty():
			continue
		_archetypes[archetype] = row
	_loaded = true
