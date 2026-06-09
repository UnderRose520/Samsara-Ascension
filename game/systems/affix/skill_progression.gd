extends Node

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const AffixCompiler = preload("res://systems/affix/affix_compiler.gd")

signal changed

var active_skill_id := "lie_yan_zhang"
var layers: Dictionary = {}      # layer -> compiled effects
var progress: Dictionary = {}    # layer -> 0..1
var counters: Dictionary = {}    # layer -> int threshold progress
var unlocked_layers: Array = [1]

var _discovered_combos: Dictionary = {}


func _ready() -> void:
	_load_skill(active_skill_id)
	if layers.has(1):
		_apply_layer_to_holder(layers[1])
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _load_skill(skill_id: String) -> void:
	layers.clear()
	progress.clear()
	counters.clear()
	unlocked_layers = [1]
	for row in CsvLoader.load_rows("res://data/skills/skills.csv"):
		if str(row.get("skill_id", "")) != skill_id:
			continue
		var layer: int = int(row.get("layer", 1))
		layers[layer] = row
		progress[layer] = 0.0
		counters[layer] = 0
		if str(row.get("unlock_type", "")).strip_edges() == "initial":
			if layer not in unlocked_layers:
				unlocked_layers.append(layer)


func register_hit() -> void:
	_advance_layer(2, "hit_count", 1)
	_advance_layer(3, "hit_count", 1)


func _on_enemy_killed(_enemy: Node) -> void:
	_advance_layer(3, "kill_count", 1)


func register_status_kill() -> void:
	_advance_layer(3, "kill_status", 1)


func _advance_layer(layer: int, unlock_type: String, amount: int) -> void:
	if not layers.has(layer):
		return
	var row: Dictionary = layers[layer]
	if str(row.get("unlock_type", "")).strip_edges() != unlock_type:
		return
	if layer in unlocked_layers:
		return
	var need: int = int(row.get("unlock_value", 1))
	counters[layer] = int(counters.get(layer, 0)) + amount
	progress[layer] = clampf(float(counters[layer]) / maxf(float(need), 1.0), 0.0, 1.0)
	changed.emit()
	if counters[layer] >= need:
		_unlock_layer(layer)


func _unlock_layer(layer: int) -> void:
	if layer in unlocked_layers:
		return
	unlocked_layers.append(layer)
	unlocked_layers.sort()
	var row: Dictionary = layers[layer]
	var skill_name := str(row.get("name", active_skill_id))
	EventBus.skill_layer_unlocked.emit(active_skill_id, layer)
	EventBus.learn_feedback.emit("功法精进 · %s 第%d层" % [skill_name, layer], "skill")
	_apply_layer_to_holder(row)
	changed.emit()


func _apply_layer_to_holder(row: Dictionary) -> void:
	var player := get_parent()
	if player == null or not player.has_node("AffixHolder"):
		return
	var holder: Node = player.get_node("AffixHolder")
	for key in ["effect1", "effect2"]:
		var dsl := str(row.get(key, "")).strip_edges()
		if dsl.is_empty():
			continue
		holder.apply_skill_effect(dsl)


func get_display_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for layer in [1, 2, 3]:
		if not layers.has(layer):
			continue
		var row: Dictionary = layers[layer]
		var name: String = str(row.get("name", ""))
		if layer in unlocked_layers:
			lines.append("%s Lv.%d ✓" % [name, layer])
		else:
			var pct: int = int(progress.get(layer, 0.0) * 100.0)
			lines.append("%s Lv.%d %d%%" % [name, layer, pct])
	return lines
