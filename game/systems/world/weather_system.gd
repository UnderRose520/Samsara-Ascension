extends Node

const CsvLoader = preload("res://systems/affix/csv_loader.gd")

var current_weather_id := "clear"
var current_weather_name := "晴"
var _weather_by_id: Dictionary = {}


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
	ctx["bucket_b"] = sources
	return ctx
