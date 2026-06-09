extends Node

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 1

var profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		profile = _default_profile()
		return profile
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		profile = _default_profile()
		return profile
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	profile = parsed if typeof(parsed) == TYPE_DICTIONARY else _default_profile()
	return profile


func save_profile() -> void:
	profile["version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "\t"))
		file.close()


func set_legacy_affix(affix_id: String) -> void:
	profile["legacy_affix_id"] = affix_id
	save_profile()


func consume_legacy_affix() -> String:
	var id := str(profile.get("legacy_affix_id", ""))
	if not id.is_empty():
		profile["legacy_affix_id"] = ""
		save_profile()
	return id


func has_legacy_pending() -> bool:
	return not str(profile.get("legacy_affix_id", "")).is_empty()


func get_display_setting(key: String) -> bool:
	var defaults := _default_profile()
	return bool(profile.get(key, defaults.get(key, true)))


func set_display_setting(key: String, value: bool) -> void:
	profile[key] = value
	save_profile()
	EventBus.display_settings_changed.emit()


func get_heart_demon_shards() -> int:
	return int(profile.get("heart_demon_shards", 0))


func add_heart_demon_shards(amount: int) -> void:
	if amount <= 0:
		return
	profile["heart_demon_shards"] = get_heart_demon_shards() + amount
	save_profile()


func consume_heart_demon_shards(amount: int) -> bool:
	if get_heart_demon_shards() < amount:
		return false
	profile["heart_demon_shards"] = get_heart_demon_shards() - amount
	save_profile()
	return true


func record_dao_tradition(tradition_id: String) -> void:
	if tradition_id.is_empty():
		return
	var list: Array = profile.get("awakened_dao_traditions", [])
	if tradition_id in list:
		return
	list.append(tradition_id)
	profile["awakened_dao_traditions"] = list
	save_profile()


func get_awakened_dao_traditions() -> Array:
	return profile.get("awakened_dao_traditions", [])


func add_reincarnation_points(amount: int) -> void:
	if amount <= 0:
		return
	profile["reincarnation_points"] = get_reincarnation_points() + amount
	save_profile()


func get_reincarnation_points() -> int:
	return int(profile.get("reincarnation_points", 0))


func get_meta_level(upgrade_id: String) -> int:
	var levels: Dictionary = profile.get("meta_levels", {})
	return int(levels.get(upgrade_id, 0))


func try_upgrade_meta(upgrade_id: String) -> bool:
	const MetaUpgradeRegistry = preload("res://systems/meta/meta_upgrade_registry.gd")
	var row := MetaUpgradeRegistry.get_upgrade(upgrade_id)
	if row.is_empty():
		return false
	var level := get_meta_level(upgrade_id)
	if level >= int(row.get("max_level", 0)):
		return false
	var cost := MetaUpgradeRegistry.next_cost(upgrade_id)
	if cost < 0 or get_reincarnation_points() < cost:
		return false
	profile["reincarnation_points"] = get_reincarnation_points() - cost
	var levels: Dictionary = profile.get("meta_levels", {})
	levels[upgrade_id] = level + 1
	profile["meta_levels"] = levels
	save_profile()
	return true


func _default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"reincarnation_points": 0,
		"meta_levels": {},
		"ascension_count": 0,
		"lifetime_kills": 0,
		"legacy_affix_id": "",
		"show_enemy_hp": true,
		"show_damage_numbers": true,
		"heart_demon_shards": 0,
		"awakened_dao_traditions": [],
	}
