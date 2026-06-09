class_name StageGenerator

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

static var _stage_rows: Array = []
static var _room_templates: Dictionary = {}
static var _loaded := false
const EventSelector = preload("res://systems/world/event_selector.gd")


static func generate(seed_value: int, dao_heart: int = 1, events_seen: Dictionary = {}) -> Array:
	_ensure_loaded()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var plan: Array = []
	var heart_demon_assigned := false
	for row in _stage_rows:
		var stage_index: int = int(row.get("stage_index", 1))
		var combat_count: int = int(row.get("combat_rooms", 2))
		var weather_id := str(row.get("weather_id", "clear"))
		var rooms: Array = []
		for i in combat_count:
			var hard := i == combat_count - 1 and stage_index >= 2
			rooms.append(_make_room("combat_hard" if hard else "combat", rng, stage_index, row))
		var event_room := _make_room("event", rng, stage_index, row)
		var event_id := EventSelector.pick_event_id(
			weather_id,
			dao_heart,
			rng,
			events_seen,
			heart_demon_assigned
		)
		if event_id == "M01":
			heart_demon_assigned = true
		event_room["event_id"] = event_id
		rooms.append(event_room)
		rooms.append(_make_room("boss", rng, stage_index, row))
		plan.append({
			"stage_index": stage_index,
			"name": str(row.get("name", "")),
			"weather_id": weather_id,
			"rooms": rooms,
		})
	return plan


static func _make_room(template_id: String, rng: RandomNumberGenerator, stage_index: int, stage_row: Dictionary = {}) -> Dictionary:
	var tpl: Dictionary = _room_templates.get(template_id, {})
	var enemy_count: int = int(tpl.get("enemy_count", 3))
	if template_id == "combat":
		enemy_count = mini(2 + stage_index, 5)
	elif template_id == "combat_hard":
		enemy_count = maxi(int(tpl.get("enemy_count", 4)), mini(2 + stage_index, 5))
	var room := {
		"type": template_id,
		"label": str(tpl.get("label", template_id)),
		"enemy_count": enemy_count,
		"hp_mult": float(tpl.get("hp_mult", 1.0)),
		"is_boss": template_id == "boss",
		"stage_index": stage_index,
	}
	if template_id == "boss":
		var boss_name := str(stage_row.get("boss_name", "关底守将"))
		room["boss_name"] = boss_name
		room["label"] = boss_name
	return room


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/stages/stages.csv"):
		_stage_rows.append(row)
	for row in CsvLoader.load_rows("res://data/rooms/room_templates.csv"):
		_room_templates[str(row.get("room_type", ""))] = row
	_loaded = true
