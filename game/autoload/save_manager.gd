extends Node

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 1
const RUN_HISTORY_LIMIT := 20
const BUILD_RECORD_LIMIT := 20
const VariantUtils = preload("res://core/utils/variant_utils.gd")

var profile: Dictionary = {}
var _profile_path_override := ""


func _ready() -> void:
	_resolve_profile_path_override()
	load_profile()


func load_profile() -> Dictionary:
	var path := _profile_path()
	if not FileAccess.file_exists(path):
		profile = _default_profile()
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			profile = _default_profile()
		else:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			profile = parsed if typeof(parsed) == TYPE_DICTIONARY else _default_profile()
	var schema_changed := _ensure_profile_schema()
	_migrate_legacy_auto_target_once()
	if schema_changed:
		save_profile()
	return profile


func save_profile() -> void:
	_ensure_profile_schema()
	profile["version"] = SAVE_VERSION
	var path := _profile_path()
	var base_dir := path.get_base_dir()
	if not base_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(base_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "\t"))
		file.close()


func get_profile_path() -> String:
	return _profile_path()


func is_using_profile_path_override() -> bool:
	return not _profile_path_override.is_empty()


func _profile_path() -> String:
	return _profile_path_override if not _profile_path_override.is_empty() else SAVE_PATH


func _resolve_profile_path_override() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--qa-save-path="):
			_profile_path_override = text.trim_prefix("--qa-save-path=").strip_edges()
			return


func set_legacy_affix(affix_id: String) -> void:
	profile["legacy_affix_id"] = affix_id
	save_profile()


func get_recent_death_line_ids() -> Array:
	return profile.get("recent_death_line_ids", [])


func record_death_line(line_id: String) -> void:
	if line_id.is_empty():
		return
	var recent := get_recent_death_line_ids()
	recent.append(line_id)
	while recent.size() > 3:
		recent.pop_front()
	profile["recent_death_line_ids"] = recent
	save_profile()


func consume_legacy_affix() -> String:
	var id: String = str(profile.get("legacy_affix_id", ""))
	if not id.is_empty():
		profile["legacy_affix_id"] = ""
		save_profile()
	return id


func has_legacy_pending() -> bool:
	return not str(profile.get("legacy_affix_id", "")).is_empty()


func get_display_setting(key: String) -> bool:
	var defaults: Dictionary = _default_profile()
	return VariantUtils.as_bool(profile.get(key, defaults.get(key, false)))


func get_sprite_style() -> String:
	var defaults: Dictionary = _default_profile()
	var style: String = str(profile.get("sprite_style", defaults.get("sprite_style", "normal"))).strip_edges().to_lower()
	if style != "chibi":
		return "normal"
	return style


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
	var legacy: bool = VariantUtils.as_bool(profile.get("auto_target", false))
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


func set_sprite_style(style: String) -> void:
	var normalized: String = str(style).strip_edges().to_lower()
	if normalized != "chibi":
		normalized = "normal"
	if get_sprite_style() == normalized:
		return
	profile["sprite_style"] = normalized
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


func get_discovered_hidden_chains() -> Array:
	return profile.get("hidden_chains_discovered", [])


func has_discovered_hidden_chain(chain_id: String) -> bool:
	return chain_id in get_discovered_hidden_chains()


func record_hidden_chain(chain_id: String) -> bool:
	if chain_id.is_empty():
		return false
	var discovered := get_discovered_hidden_chains()
	if chain_id in discovered:
		return false
	discovered.append(chain_id)
	profile["hidden_chains_discovered"] = discovered
	_record_codex_seen("hidden_chains", chain_id, {"seen_count": 1}, false)
	save_profile()
	return true


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
	_record_codex_seen("dao_traditions", tradition_id, {"seen_count": 1}, false)
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


func record_run_result(summary: Dictionary) -> Dictionary:
	_ensure_profile_schema()
	var record := _sanitize_run_record(summary)
	var run_id := str(record.get("run_id", ""))
	if run_id.is_empty():
		run_id = "%d_%d" % [int(record.get("seed", 0)), Time.get_unix_time_from_system()]
		record["run_id"] = run_id
	if str(profile.get("last_recorded_run_id", "")) == run_id:
		return get_latest_run_record()

	var history: Array = profile.get("run_history", [])
	history.append(record)
	while history.size() > RUN_HISTORY_LIMIT:
		history.pop_front()
	profile["run_history"] = history
	profile["last_recorded_run_id"] = run_id

	_record_build_snapshot_from_run(record)
	_update_stats_from_run(record)
	_record_codex_from_run(record)
	save_profile()
	return record.duplicate(true)


func record_run_summary(summary: Dictionary) -> Dictionary:
	return record_run_result(summary)


func get_run_records(limit: int = RUN_HISTORY_LIMIT) -> Array:
	_ensure_profile_schema()
	var history: Array = profile.get("run_history", [])
	var capped := maxi(limit, 0)
	if capped <= 0 or history.size() <= capped:
		return history.duplicate(true)
	return history.slice(history.size() - capped, history.size()).duplicate(true)


func get_recent_run_history(limit: int = 5) -> Array:
	return get_run_records(limit)


func get_latest_run_record() -> Dictionary:
	var history := get_run_records(1)
	if history.is_empty():
		return {}
	return (history[0] as Dictionary).duplicate(true)


func get_best_run_record() -> Dictionary:
	_ensure_profile_schema()
	var best: Dictionary = {}
	var best_score := -1
	for raw in profile.get("run_history", []):
		if not (raw is Dictionary):
			continue
		var record: Dictionary = raw
		var score := int(record.get("rooms_cleared", 0)) * 1000 + int(record.get("best_combo", 0))
		if bool(record.get("victory", false)):
			score += 100000
		if score > best_score:
			best_score = score
			best = record
	return best.duplicate(true)


func record_build_snapshot(snapshot: Dictionary) -> Dictionary:
	_ensure_profile_schema()
	var record := _sanitize_build_snapshot(snapshot)
	if record.is_empty():
		return {}
	var records: Array = profile.get("build_records", [])
	records.append(record)
	while records.size() > BUILD_RECORD_LIMIT:
		records.pop_front()
	profile["build_records"] = records
	save_profile()
	return record.duplicate(true)


func get_build_records(limit: int = BUILD_RECORD_LIMIT) -> Array:
	_ensure_profile_schema()
	var records: Array = profile.get("build_records", [])
	var capped := maxi(limit, 0)
	if capped <= 0 or records.size() <= capped:
		return records.duplicate(true)
	return records.slice(records.size() - capped, records.size()).duplicate(true)


func record_codex_seen(kind: String, id: String, payload: Dictionary = {}) -> bool:
	var changed := _record_codex_seen(kind, id, payload, false)
	if changed:
		save_profile()
	return changed


func record_enemy_seen(enemy_id: String, payload: Dictionary = {}) -> bool:
	return record_codex_seen("enemies", enemy_id, payload)


func record_enemy_kill(enemy_id: String, count: int = 1, payload: Dictionary = {}) -> bool:
	var data := payload.duplicate(true)
	data["kill_count"] = maxi(count, 0)
	data["seen_count"] = 1
	return record_codex_seen("enemies", enemy_id, data)


func record_affix_seen(affix_id: String, payload: Dictionary = {}) -> bool:
	return record_codex_seen("affixes", affix_id, payload)


func record_weapon_seen(weapon_id: String, payload: Dictionary = {}) -> bool:
	return record_codex_seen("weapons", weapon_id, payload)


func record_weapon_mod_seen(mod_id: String, payload: Dictionary = {}) -> bool:
	return record_codex_seen("weapon_mods", mod_id, payload)


func record_weather_seen(weather_id: String, payload: Dictionary = {}) -> bool:
	return record_codex_seen("weather", weather_id, payload)


func record_terrain_seen(terrain_id: String, payload: Dictionary = {}) -> bool:
	return record_codex_seen("terrain", terrain_id, payload)


func get_codex_summary() -> Dictionary:
	_ensure_profile_schema()
	var codex: Dictionary = profile.get("codex", {})
	var stats: Dictionary = profile.get("stats", {})
	return {
		"runs_total": int(stats.get("runs_total", 0)),
		"victories": int(stats.get("victories", 0)),
		"lifetime_kills": int(stats.get("lifetime_kills", profile.get("lifetime_kills", 0))),
		"best_rooms_cleared": int(stats.get("best_rooms_cleared", 0)),
		"best_combo": int(stats.get("best_combo", 0)),
		"best_dao_peak": int(stats.get("best_dao_peak", 0)),
		"reincarnation_points": get_reincarnation_points(),
		"hidden_chain_count": _codex_bucket_count(codex, "hidden_chains", get_discovered_hidden_chains().size()),
		"dao_tradition_count": _codex_bucket_count(codex, "dao_traditions", get_awakened_dao_traditions().size()),
		"enemy_count": _codex_bucket_count(codex, "enemies"),
		"weather_count": _codex_bucket_count(codex, "weather"),
		"terrain_count": _codex_bucket_count(codex, "terrain"),
		"weapon_count": _codex_bucket_count(codex, "weapons"),
		"weapon_mod_count": _codex_bucket_count(codex, "weapon_mods"),
		"affix_count": _codex_bucket_count(codex, "affixes"),
	}


func get_lifetime_summary() -> Dictionary:
	var summary := get_codex_summary()
	summary["latest_run"] = get_latest_run_record()
	summary["best_run"] = get_best_run_record()
	return summary


func format_lifetime_summary() -> String:
	var summary := get_codex_summary()
	return "前世碑 %d 世 · 连锁札记 %d 条 · 道统 %d 脉" % [
		int(summary.get("runs_total", 0)),
		int(summary.get("hidden_chain_count", 0)),
		int(summary.get("dao_tradition_count", 0)),
	]


func _default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"reincarnation_points": 0,
		"meta_levels": {},
		"ascension_count": 0,
		"lifetime_kills": 0,
		"stats": {
			"runs_total": 0,
			"victories": 0,
			"lifetime_kills": 0,
			"best_rooms_cleared": 0,
			"best_combo": 0,
			"best_dao_peak": 0,
		},
		"run_history": [],
		"build_records": [],
		"last_recorded_run_id": "",
		"codex": {
			"enemies": {},
			"weather": {},
			"terrain": {},
			"weapons": {},
			"weapon_mods": {},
			"affixes": {},
			"paths": {},
			"stages": {},
			"dao_traditions": {},
			"hidden_chains": {},
		},
		"legacy_affix_id": "",
		"show_enemy_hp": true,
		"show_damage_numbers": true,
		"reduce_motion": false,
		"auto_aim": false,
		"auto_attack": false,
		"sprite_style": "normal",
		"heart_demon_shards": 0,
		"awakened_dao_traditions": [],
		"terrain_demos_seen": {},
		"hidden_chains_discovered": [],
		"last_run_seed": 0,
	}


func set_last_run_seed(seed: int) -> void:
	profile["last_run_seed"] = seed
	save_profile()


func get_last_run_seed() -> int:
	return int(profile.get("last_run_seed", 0))


func _ensure_profile_schema() -> bool:
	var changed := false
	var defaults := _default_profile()
	for key in defaults.keys():
		if not profile.has(key):
			profile[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
			changed = true

	if not (profile.get("stats", {}) is Dictionary):
		profile["stats"] = defaults["stats"].duplicate(true)
		changed = true
	else:
		var stats: Dictionary = profile.get("stats", {})
		for key in (defaults["stats"] as Dictionary).keys():
			if not stats.has(key):
				stats[key] = int(profile.get(key, 0)) if key == "lifetime_kills" else int((defaults["stats"] as Dictionary).get(key, 0))
				changed = true
		profile["stats"] = stats

	if not (profile.get("codex", {}) is Dictionary):
		profile["codex"] = defaults["codex"].duplicate(true)
		changed = true
	else:
		var codex: Dictionary = profile.get("codex", {})
		for key in (defaults["codex"] as Dictionary).keys():
			if not (codex.get(key, {}) is Dictionary):
				codex[key] = {}
				changed = true
		profile["codex"] = codex

	if not (profile.get("run_history", []) is Array):
		profile["run_history"] = []
		changed = true
	if not (profile.get("build_records", []) is Array):
		profile["build_records"] = []
		changed = true

	for chain_id in get_discovered_hidden_chains():
		if _record_codex_seen("hidden_chains", str(chain_id), {"seen_count": 0}, false):
			changed = true
	for tradition_id in get_awakened_dao_traditions():
		if _record_codex_seen("dao_traditions", str(tradition_id), {"seen_count": 0}, false):
			changed = true
	return changed


func _sanitize_run_record(summary: Dictionary) -> Dictionary:
	var record := {
		"run_id": str(summary.get("run_id", "")),
		"timestamp_unix": int(summary.get("timestamp_unix", Time.get_unix_time_from_system())),
		"seed": int(summary.get("seed", 0)),
		"victory": VariantUtils.as_bool(summary.get("victory", false)),
		"rooms_cleared": int(summary.get("rooms_cleared", 0)),
		"gold": int(summary.get("gold", 0)),
		"realm_level": int(summary.get("realm_level", 1)),
		"realm_name": str(summary.get("realm_name", "")),
		"dao_heart": int(summary.get("dao_heart", 0)),
		"cultivation_path_id": str(summary.get("cultivation_path_id", "")),
		"cultivation_path_name": str(summary.get("cultivation_path_name", "")),
		"weapon_id": str(summary.get("weapon_id", "")),
		"weapon_name": str(summary.get("weapon_name", "")),
		"weapon_mods": _string_array(summary.get("weapon_mods", [])),
		"affixes": _sanitize_affix_snapshots(summary.get("affixes", [])),
		"best_combo": int(summary.get("best_combo", 0)),
		"dao_peak": int(summary.get("dao_peak", 0)),
		"dao_max": int(summary.get("dao_max", 100)),
		"weather_seen": _string_array(summary.get("weather_seen", [])),
		"terrain_seen": _string_array(summary.get("terrain_seen", [])),
		"stages_seen": _string_array(summary.get("stages_seen", [])),
		"enemy_kills": _sanitize_count_dict(summary.get("enemy_kills", {})),
		"hidden_chains": _string_array(summary.get("hidden_chains", [])),
		"dao_tradition_id": str(summary.get("dao_tradition_id", "")),
		"highlight": _sanitize_plain_dict(summary.get("highlight", {})),
		"death_summary": _sanitize_plain_dict(summary.get("death_summary", {})),
	}
	record["build"] = _sanitize_build_snapshot(summary.get("build", record))
	return record


func _sanitize_build_snapshot(snapshot: Dictionary) -> Dictionary:
	var build := {
		"run_id": str(snapshot.get("run_id", "")),
		"timestamp_unix": int(snapshot.get("timestamp_unix", Time.get_unix_time_from_system())),
		"seed": int(snapshot.get("seed", 0)),
		"path_id": str(snapshot.get("path_id", snapshot.get("cultivation_path_id", ""))),
		"path_name": str(snapshot.get("path_name", snapshot.get("cultivation_path_name", ""))),
		"weapon_id": str(snapshot.get("weapon_id", "")),
		"weapon_name": str(snapshot.get("weapon_name", "")),
		"weapon_mods": _string_array(snapshot.get("weapon_mods", [])),
		"affixes": _sanitize_affix_snapshots(snapshot.get("affixes", [])),
		"realm_level": int(snapshot.get("realm_level", 1)),
	}
	if str(build.get("path_id", "")).is_empty() and str(build.get("weapon_id", "")).is_empty() and (build.get("affixes", []) as Array).is_empty():
		return {}
	return build


func _sanitize_affix_snapshots(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				var row: Dictionary = item
				var id := str(row.get("id", ""))
				if id.is_empty():
					continue
				out.append({
					"id": id,
					"quality": int(row.get("quality", 0)),
					"sealed": VariantUtils.as_bool(row.get("sealed", false)),
				})
			else:
				var id := str(item)
				if not id.is_empty():
					out.append({"id": id, "quality": 0, "sealed": false})
	return out


func _sanitize_count_dict(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key in (raw as Dictionary).keys():
			var id := str(key)
			var count := int((raw as Dictionary).get(key, 0))
			if _valid_codex_id(id) and count > 0:
				out[id] = count
	return out


func _sanitize_plain_dict(raw) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var out := {}
	for key in (raw as Dictionary).keys():
		var value = (raw as Dictionary).get(key)
		match typeof(value):
			TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				out[str(key)] = value
			TYPE_DICTIONARY:
				out[str(key)] = _sanitize_plain_dict(value)
			TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
				out[str(key)] = _string_array(value)
	return out


func _string_array(raw) -> Array:
	var out: Array = []
	if raw is Array or typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		for item in raw:
			var text := str(item)
			if not text.is_empty() and text not in out:
				out.append(text)
	elif not str(raw).is_empty():
		out.append(str(raw))
	return out


func _record_build_snapshot_from_run(record: Dictionary) -> void:
	var build: Dictionary = record.get("build", {})
	if build.is_empty():
		return
	var records: Array = profile.get("build_records", [])
	records.append(build.duplicate(true))
	while records.size() > BUILD_RECORD_LIMIT:
		records.pop_front()
	profile["build_records"] = records


func _update_stats_from_run(record: Dictionary) -> void:
	var stats: Dictionary = profile.get("stats", {})
	var kills := 0
	for count in (record.get("enemy_kills", {}) as Dictionary).values():
		kills += int(count)
	stats["runs_total"] = int(stats.get("runs_total", 0)) + 1
	if VariantUtils.as_bool(record.get("victory", false)):
		stats["victories"] = int(stats.get("victories", 0)) + 1
		profile["ascension_count"] = int(profile.get("ascension_count", 0)) + 1
	stats["lifetime_kills"] = int(stats.get("lifetime_kills", profile.get("lifetime_kills", 0))) + kills
	stats["best_rooms_cleared"] = maxi(int(stats.get("best_rooms_cleared", 0)), int(record.get("rooms_cleared", 0)))
	stats["best_combo"] = maxi(int(stats.get("best_combo", 0)), int(record.get("best_combo", 0)))
	stats["best_dao_peak"] = maxi(int(stats.get("best_dao_peak", 0)), int(record.get("dao_peak", 0)))
	profile["stats"] = stats
	profile["lifetime_kills"] = int(stats.get("lifetime_kills", 0))


func _record_codex_from_run(record: Dictionary) -> void:
	var payload := {
		"run_id": str(record.get("run_id", "")),
		"seed": int(record.get("seed", 0)),
		"timestamp_unix": int(record.get("timestamp_unix", Time.get_unix_time_from_system())),
	}
	_record_codex_seen("paths", str(record.get("cultivation_path_id", "")), payload, false)
	_record_codex_seen("weapons", str(record.get("weapon_id", "")), payload, false)
	for mod_id in record.get("weapon_mods", []):
		_record_codex_seen("weapon_mods", str(mod_id), payload, false)
	for affix in record.get("affixes", []):
		if affix is Dictionary:
			_record_codex_seen("affixes", str((affix as Dictionary).get("id", "")), payload, false)
	for weather_id in record.get("weather_seen", []):
		_record_codex_seen("weather", str(weather_id), payload, false)
	for terrain_id in record.get("terrain_seen", []):
		_record_codex_seen("terrain", str(terrain_id), payload, false)
	for stage_id in record.get("stages_seen", []):
		_record_codex_seen("stages", str(stage_id), payload, false)
	for enemy_id in (record.get("enemy_kills", {}) as Dictionary).keys():
		var enemy_payload := payload.duplicate(true)
		enemy_payload["kill_count"] = int((record.get("enemy_kills", {}) as Dictionary).get(enemy_id, 0))
		_record_codex_seen("enemies", str(enemy_id), enemy_payload, false)
	for chain_id in record.get("hidden_chains", []):
		_record_codex_seen("hidden_chains", str(chain_id), payload, false)
	if not str(record.get("dao_tradition_id", "")).is_empty():
		_record_codex_seen("dao_traditions", str(record.get("dao_tradition_id", "")), payload, false)


func _record_codex_seen(kind: String, id: String, payload: Dictionary = {}, _save_after: bool = true) -> bool:
	if kind.is_empty() or not _valid_codex_id(id):
		return false
	_ensure_profile_schema_shallow()
	var codex: Dictionary = profile.get("codex", {})
	var bucket: Dictionary = codex.get(kind, {})
	var entry: Dictionary = bucket.get(id, {})
	var changed := false
	var now := int(payload.get("timestamp_unix", Time.get_unix_time_from_system()))
	if entry.is_empty():
		entry = {
			"seen": true,
			"first_seen_run": str(payload.get("run_id", "")),
			"first_seen_seed": int(payload.get("seed", profile.get("last_run_seed", 0))),
			"first_seen_at": now,
			"seen_count": 0,
			"kill_count": 0,
		}
		changed = true
	entry["seen"] = true
	entry["seen_count"] = int(entry.get("seen_count", 0)) + int(payload.get("seen_count", 1))
	entry["kill_count"] = int(entry.get("kill_count", 0)) + int(payload.get("kill_count", 0))
	entry["last_seen_run"] = str(payload.get("run_id", entry.get("last_seen_run", "")))
	entry["last_seen_seed"] = int(payload.get("seed", entry.get("last_seen_seed", profile.get("last_run_seed", 0))))
	entry["last_seen_at"] = now
	bucket[id] = entry
	codex[kind] = bucket
	profile["codex"] = codex
	return changed or int(payload.get("seen_count", 1)) != 0 or int(payload.get("kill_count", 0)) != 0


func _ensure_profile_schema_shallow() -> void:
	if not (profile.get("codex", {}) is Dictionary):
		profile["codex"] = _default_profile()["codex"].duplicate(true)
	var codex: Dictionary = profile.get("codex", {})
	for key in (_default_profile()["codex"] as Dictionary).keys():
		if not (codex.get(key, {}) is Dictionary):
			codex[key] = {}
	profile["codex"] = codex


func _valid_codex_id(id: String) -> bool:
	var clean := id.strip_edges()
	return not clean.is_empty() and clean.to_lower() not in ["unknown", "none", "null", "nil"]


func _codex_bucket_count(codex: Dictionary, bucket_name: String, fallback: int = 0) -> int:
	var bucket = codex.get(bucket_name, {})
	if bucket is Dictionary:
		return maxi((bucket as Dictionary).size(), fallback)
	return fallback
