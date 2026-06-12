extends Node

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 1
const VariantUtils = preload("res://core/utils/variant_utils.gd")

var profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		profile = _default_profile()
	else:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
			profile = _default_profile()
		else:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			profile = parsed if typeof(parsed) == TYPE_DICTIONARY else _default_profile()
	_migrate_legacy_auto_target_once()
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
	return VariantUtils.as_bool(profile.get(key, defaults.get(key, false)))


func _migrate_legacy_auto_target_once() -> void:
	var changed := false
	if not profile.has("auto_target"):
		# Old profiles without auto_target may also lack auto_aim/auto_attack.
		# Old get_display_setting defaulted to true; preserve that for migrating players.
		if not profile.has("auto_aim"):
			profile["auto_aim"] = true
			changed = true
		if not profile.has("auto_attack"):
			profile["auto_attack"] = true
			changed = true
		if changed:
			save_profile()
		return
	var legacy := VariantUtils.as_bool(profile.get("auto_target", false))
	if not profile.has("auto_aim"):
		profile["auto_aim"] = legacy
		changed = true
	if not profile.has("auto_attack"):
		profile["auto_attack"] = legacy
		changed = true
	if changed:
		save_profile()


func set_display_setting(key: String, value: bool) -> void:
	profile[key] = value
	save_profile()
	EventBus.display_settings_changed.emit()


func has_seen_terrain_demo(demo_key: String) -> bool:
	var seen: Dictionary = profile.get("terrain_demos_seen", {})
	return VariantUtils.as_bool(seen.get(demo_key, false))


func mark_terrain_demo(demo_key: String) -> void:
	var seen: Dictionary = profile.get("terrain_demos_seen", {})
	seen[demo_key] = true
	profile["terrain_demos_seen"] = seen
	save_profile()


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
		"reduce_motion": false,
		"auto_aim": false,
		"auto_attack": false,
		"heart_demon_shards": 0,
		"awakened_dao_traditions": [],
		"terrain_demos_seen": {},
		"last_run_seed": 0,
	}


func set_last_run_seed(seed: int) -> void:
	profile["last_run_seed"] = seed
	save_profile()


func get_last_run_seed() -> int:
	return int(profile.get("last_run_seed", 0))
