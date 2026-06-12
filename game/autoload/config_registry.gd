extends Node

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const AffixCompiler = preload("res://systems/affix/affix_compiler.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")

const DEFAULT_PLAYER_STATS := {
	"hp": 100.0,
	"attack": GameConstants.PLAYER_ATTACK,
	"defense": 5.0,
	"move_speed": 300.0,
	"crit_rate": 0.05,
	"crit_mult": 1.5,
	"dodge_cooldown": 1.0,
}

var is_ready := false
var compiled_affixes: Array = []
var affix_by_id: Dictionary = {}
var pets_by_id: Dictionary = {}


func _ready() -> void:
	_load_affixes()
	_load_pets()
	is_ready = true


func get_default_player_stats() -> Dictionary:
	return DEFAULT_PLAYER_STATS.duplicate()


func get_all_affixes() -> Array:
	return compiled_affixes


func get_affix(id: String):
	return affix_by_id.get(id)


func get_pet(id: String) -> Dictionary:
	return pets_by_id.get(id, {})


## Positive shift upgrades tier (心魔试炼/证道); negative shift downgrades (前世遗泽).
func compile_affix(id: String, quality_shift: int = 0):
	var base = affix_by_id.get(id)
	if base == null:
		return null
	var tag = base.duplicate_tag()
	if quality_shift != 0:
		tag.quality = clampi(int(tag.quality) + quality_shift, 0, AffixCompiler.MAX_QUALITY)
	return tag


func get_pet_display_name(id: String) -> String:
	var row: Dictionary = get_pet(id)
	var name: String = str(row.get("name", ""))
	return name if not name.is_empty() else id


func _load_affixes() -> void:
	compiled_affixes.clear()
	affix_by_id.clear()
	for row in CsvLoader.load_rows("res://data/affixes/affixes.csv"):
		var tag = AffixCompiler.compile_row(row)
		if tag.id.is_empty():
			continue
		compiled_affixes.append(tag)
		affix_by_id[tag.id] = tag


func _load_pets() -> void:
	pets_by_id.clear()
	for row in CsvLoader.load_rows("res://data/pets/pets.csv"):
		var id := str(row.get("pet_id", ""))
		if id.is_empty():
			continue
		pets_by_id[id] = row
