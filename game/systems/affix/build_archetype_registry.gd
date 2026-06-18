class_name BuildArchetypeRegistry

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")

const MAX_ACTIVE_ARCHETYPES := 3

static var _archetypes: Array[Dictionary] = []
static var _loaded := false


static func get_active_archetypes(path_id: String, owned_tags: Array, element_bias: String, rng: RandomNumberGenerator, count: int = MAX_ACTIVE_ARCHETYPES) -> Array:
	_ensure_loaded()
	var candidates: Array[Dictionary] = []
	for row in _archetypes:
		var row_path := str(row.get("path_id", ""))
		if row_path != "any" and row_path != path_id:
			continue
		var candidate := row.duplicate(true)
		candidate["score"] = _score_archetype(candidate, owned_tags, element_bias)
		candidates.append(candidate)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.get("score", 0.0))
		var b_score := float(b.get("score", 0.0))
		if is_equal_approx(a_score, b_score):
			return str(a.get("build_id", "")) < str(b.get("build_id", ""))
		return a_score > b_score
	)
	var top_count := mini(maxi(count + 1, count), candidates.size())
	var pool: Array[Dictionary] = []
	for i in top_count:
		pool.append(candidates[i])
	var result: Array = []
	while result.size() < count and not pool.is_empty():
		var idx := _weighted_index(pool, rng)
		result.append(pool[idx])
		pool.remove_at(idx)
	return result


static func match_score(tag, archetypes: Array) -> float:
	if tag == null or archetypes.is_empty():
		return 0.0
	var best := 0.0
	var element_key := ElementUtils.key(tag.element)
	for raw in archetypes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var score := 0.0
		if str(tag.id) in _split_tokens(row.get("core_rewards", "")):
			score += 2.8
		var route_tags := _route_tags(row)
		for combo_tag in tag.combo_tags:
			if str(combo_tag) in route_tags:
				score += 0.75
		if not element_key.is_empty() and element_key in route_tags:
			score += 0.9
		if score > best:
			best = score
	return best


static func describe_active(archetypes: Array) -> String:
	var names: Array[String] = []
	for raw in archetypes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var name := str((raw as Dictionary).get("name", ""))
		if not name.is_empty():
			names.append(name)
	return " / ".join(names)


static func _score_archetype(row: Dictionary, owned_tags: Array, element_bias: String) -> float:
	var score := 1.0
	var route_tags := _route_tags(row)
	if not element_bias.is_empty() and element_bias in route_tags:
		score += 1.2
	for owned in owned_tags:
		if str(owned) in route_tags:
			score += 0.65
	var batch := int(row.get("batch", 0))
	if batch <= 0:
		score += 0.35
	return score


static func _route_tags(row: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	for field in ["build_id", "core_rewards", "weather_hooks", "enemy_hooks", "first_power_spike", "late_power_spike", "risk"]:
		for token in _split_tokens(row.get(field, "")):
			_add_tag(tags, token)
			for inferred in _infer_tags(token):
				_add_tag(tags, inferred)
	return tags


static func _split_tokens(value) -> Array[String]:
	var out: Array[String] = []
	for raw in str(value).split("|", false):
		var token := str(raw).strip_edges()
		if not token.is_empty():
			out.append(token)
	return out


static func _infer_tags(text: String) -> Array[String]:
	var tags: Array[String] = []
	var s := text.to_lower()
	if "火" in text or "燃" in text or "烈阳" in text or "fire" in s:
		tags.append("fire")
		tags.append("burn")
	if "雷" in text or "天劫" in text or "thunder" in s:
		tags.append("thunder")
		tags.append("paralyze")
	if "冰" in text or "寒" in text or "霜" in text or "water" in s:
		tags.append("water")
		tags.append("ice")
		tags.append("slow")
	if "毒" in text or "poison" in s:
		tags.append("wood")
		tags.append("poison")
	if "血" in text or "魂" in text or "心魔" in text:
		tags.append("soul")
		tags.append("heal")
	if "盾" in text or "甲" in text or "金身" in text or "反震" in text:
		tags.append("earth")
		tags.append("defense")
		tags.append("body")
	if "符" in text or "阵" in text:
		tags.append("talisman")
		tags.append("chain")
	if "连" in text or "导电" in text or "共鸣" in text:
		tags.append("chain")
	if "回血" in text or "回春" in text or "吸血" in text:
		tags.append("heal")
	return tags


static func _add_tag(tags: Array[String], tag: String) -> void:
	if tag.is_empty() or tag in tags:
		return
	tags.append(tag)


static func _weighted_index(pool: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for row in pool:
		total += maxf(float(row.get("score", 1.0)), 0.1)
	var roll := rng.randf_range(0.0, maxf(total, 0.1))
	var acc := 0.0
	for i in pool.size():
		acc += maxf(float(pool[i].get("score", 1.0)), 0.1)
		if roll <= acc:
			return i
	return 0


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_archetypes.clear()
	for row in CsvLoader.load_rows("res://data/design/build_archetypes.csv"):
		var id := str(row.get("build_id", ""))
		if id.is_empty():
			continue
		_archetypes.append(row)
	_loaded = true
