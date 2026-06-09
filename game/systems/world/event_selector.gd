class_name EventSelector

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")

static var _rows: Array = []
static var _by_id: Dictionary = {}
static var _loaded := false


static func pick_event_id(
	weather_id: String,
	dao_heart: int,
	rng: RandomNumberGenerator,
	events_seen: Dictionary,
	heart_demon_assigned: bool
) -> String:
	_ensure_loaded()
	if dao_heart == DaoHeartConfig.DaoHeart.PROVE_DAO and not heart_demon_assigned:
		return "M01"
	if dao_heart == DaoHeartConfig.DaoHeart.ENLIGHTEN and not heart_demon_assigned and rng.randf() < 0.2:
		return "M01"

	var pool: Array = []
	for row in _rows:
		if str(row.get("category", "")) == "heart_demon":
			continue
		if not _passes_karma_gate(row):
			continue
		if not _can_pick(row, weather_id, events_seen):
			continue
		pool.append(row)
	if pool.is_empty():
		for row in _rows:
			if str(row.get("category", "")) == "regular" and _can_pick(row, "", events_seen):
				pool.append(row)
	if pool.is_empty():
		return "E01"
	var total := 0
	for row in pool:
		total += int(row.get("weight", 1))
	var roll := rng.randi_range(1, maxi(total, 1))
	var acc := 0
	for row in pool:
		acc += int(row.get("weight", 1))
		if roll <= acc:
			return str(row.get("id", "E01"))
	return str(pool[0].get("id", "E01"))


static func get_event(event_id: String) -> Dictionary:
	_ensure_loaded()
	return (_by_id.get(event_id, {}) as Dictionary).duplicate(true)


static func build_choices(event: Dictionary) -> Array:
	var choices: Array = []
	for i in 3:
		var label := str(event.get("choice%d" % (i + 1), ""))
		var effect := str(event.get("effect%d" % (i + 1), "none"))
		if label.is_empty() and effect == "none":
			continue
		choices.append({"label": label, "effect": effect})
	return choices


static func _can_pick(row: Dictionary, weather_id: String, events_seen: Dictionary) -> bool:
	var event_id := str(row.get("id", ""))
	var max_per_run := int(row.get("max_per_run", 99))
	if int(events_seen.get(event_id, 0)) >= max_per_run:
		return false
	var weather_req := str(row.get("weather", "")).strip_edges()
	if not weather_req.is_empty() and weather_req != weather_id:
		return false
	return true


static func _passes_karma_gate(row: Dictionary) -> bool:
	var gate := str(row.get("karma_gate", "")).strip_edges()
	if gate.is_empty():
		return true
	var parts := gate.split(":")
	if parts.size() < 2:
		return true
	var kind := str(parts[0])
	var need := int(parts[1])
	return int(RunContext.karma.get(kind, 0)) >= need


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for row in CsvLoader.load_rows("res://data/events/events.csv"):
		_rows.append(row)
		_by_id[str(row.get("id", ""))] = row
	_loaded = true
