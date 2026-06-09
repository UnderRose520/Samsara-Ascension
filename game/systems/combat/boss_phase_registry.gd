class_name BossPhaseRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const EnemySkillRegistry = preload("res://systems/combat/enemy_skill_registry.gd")

static var _phases: Dictionary = {}
static var _loaded := false


static func get_phases(archetype: String = "boss") -> Array:
	_ensure_loaded()
	var rows: Array = _phases.get(archetype, [])
	var phases: Array = []
	for row in rows:
		phases.append((row as Dictionary).duplicate())
	phases.sort_custom(func(a, b): return int(a.get("phase", 0)) < int(b.get("phase", 0)))
	return phases


static func get_skills_for_phase(phase_row: Dictionary) -> Array:
	var ids := str(phase_row.get("skill_ids", "")).split("|")
	var skills: Array = []
	for raw_id in ids:
		var skill_id := str(raw_id).strip_edges()
		if skill_id.is_empty():
			continue
		var skill := EnemySkillRegistry.get_skill(skill_id)
		if not skill.is_empty():
			skills.append(skill)
	return skills


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/enemies/boss_phases.csv"):
		var archetype := str(row.get("archetype", "boss"))
		if not _phases.has(archetype):
			_phases[archetype] = []
		(_phases[archetype] as Array).append(row)
	_loaded = true
