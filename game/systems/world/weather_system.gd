extends Node

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

const WEATHER_ELEMENT_LABELS := {
	"fire": "火系",
	"water": "水系",
	"thunder": "雷系",
	"wood": "木系",
	"earth": "土系",
	"soul": "魂系",
}

var current_weather_id := "clear"
var current_weather_name := "晴"
var _weather_by_id: Dictionary = {}
var _seen_synergy_hints: Dictionary = {}


func _ready() -> void:
	for row in CsvLoader.load_rows("res://data/weather/weather.csv"):
		var id := str(row.get("id", ""))
		if id.is_empty():
			continue
		_weather_by_id[id] = row


func set_weather(weather_id: String) -> void:
	var row: Dictionary = _weather_by_id.get(weather_id, _weather_by_id.get("clear", {}))
	current_weather_id = weather_id if not row.is_empty() else "clear"
	current_weather_name = str(row.get("name", "晴"))
	EventBus.weather_changed.emit(current_weather_id, current_weather_name)


func get_weather_row(weather_id: String = "") -> Dictionary:
	var id := weather_id if not weather_id.is_empty() else current_weather_id
	return (_weather_by_id.get(id, _weather_by_id.get("clear", {})) as Dictionary).duplicate()


func get_mult_b_for_element(element_key: String) -> float:
	var row: Dictionary = _weather_by_id.get(current_weather_id, {})
	var affinity := str(row.get("element_affinity", "none"))
	var base_mult := float(row.get("mult_b", 1.0))
	if affinity == "none" or element_key.is_empty():
		return 1.0
	if affinity == element_key:
		return base_mult
	return 1.0


func apply_to_context(ctx: Dictionary, element_key: String = "fire") -> Dictionary:
	var sources: Array = ctx.get("bucket_b", []).duplicate()
	var mult_b := get_mult_b_for_element(element_key)
	if mult_b != 1.0:
		sources.append(mult_b)
		ctx["weather_synergy"] = true
		ctx["weather_id"] = current_weather_id
		ctx["weather_mult"] = mult_b
		_maybe_show_synergy_hint(element_key, mult_b)
	ctx["bucket_b"] = sources
	return ctx


func get_weather_intensity(weather_id: String = "") -> float:
	var id := weather_id if not weather_id.is_empty() else current_weather_id
	match id:
		"thunder":
			return 1.35
		"rain", "snow", "sand":
			return 1.15
		"fog":
			return 0.9
		"wind", "fire":
			return 1.0
		_:
			return 0.0


func get_weather_summary(weather_id: String = "") -> String:
	var row := get_weather_row(weather_id)
	var affinity := str(row.get("element_affinity", "none"))
	var mult := float(row.get("mult_b", 1.0))
	if affinity == "none" or mult <= 1.0:
		return str(row.get("name", current_weather_name))
	return "%s · %s伤害 x%.2f" % [
		str(row.get("name", current_weather_name)),
		WEATHER_ELEMENT_LABELS.get(affinity, affinity),
		mult,
	]


func _maybe_show_synergy_hint(element_key: String, mult: float) -> void:
	var key := "%s_%s" % [current_weather_id, element_key]
	if _seen_synergy_hints.get(key, false):
		return
	_seen_synergy_hints[key] = true
	EventBus.pet_coord_feedback.emit("%s天象共鸣：%s伤害 x%.2f" % [
		current_weather_name,
		WEATHER_ELEMENT_LABELS.get(element_key, element_key),
		mult,
	])
