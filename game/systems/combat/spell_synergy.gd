class_name SpellSynergy

const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")


static func element_for_spell(spell_id: String) -> String:
	if spell_id == "yu_jian_thrust":
		return "earth"
	if spell_id == "qi_fu":
		return "wood"
	if spell_id == "summon_soul":
		return "soul"
	if spell_id.begins_with("lei_"):
		return "thunder"
	if spell_id.begins_with("xuan_bing"):
		return "water"
	if spell_id == "hui_chun_jue":
		return "wood"
	if spell_id.begins_with("lie_yan"):
		return "fire"
	if spell_id.begins_with("lian_dan"):
		return "fire"
	if spell_id.begins_with("beng_shan"):
		return "earth"
	return "fire"


static func color_for_element(element_key: String) -> Color:
	match element_key:
		"fire":
			return Color(1.0, 0.42, 0.14)
		"thunder":
			return Color(0.58, 0.78, 1.0)
		"water":
			return Color(0.42, 0.92, 1.0)
		"wood":
			return Color(0.44, 0.85, 0.48)
		"earth":
			return Color(0.82, 0.68, 0.38)
		"soul":
			return Color(0.72, 0.42, 1.0)
	return Color(1.0, 0.84, 0.22)


static func branch_for_spell(spell_id: String, layer: int) -> String:
	if layer <= 1:
		return "base"
	if spell_id.begins_with("lie_yan"):
		return "fire_burst" if layer == 2 else "fire_chain"
	if spell_id == "yu_jian_thrust":
		return "sword_pierce" if layer == 2 else "sword_array"
	if spell_id.begins_with("lei_"):
		return "thunder_chain" if layer == 2 else "thunder_net"
	if spell_id.begins_with("xuan_bing"):
		return "ice_spread" if layer == 2 else "ice_domain"
	if spell_id == "qi_fu":
		return "talisman_pair" if layer == 2 else "talisman_array"
	if spell_id == "summon_soul":
		return "soul_echo" if layer == 2 else "soul_swarm"
	return "base"


static func branch_label(branch_id: String) -> String:
	match branch_id:
		"fire_burst":
			return "爆裂"
		"fire_chain":
			return "连锁"
		"sword_pierce":
			return "贯虹"
		"sword_array":
			return "剑阵"
		"thunder_chain":
			return "连雷"
		"thunder_net":
			return "雷网"
		"ice_spread":
			return "寒扩"
		"ice_domain":
			return "冰域"
		"talisman_pair":
			return "双符"
		"talisman_array":
			return "符阵"
		"soul_echo":
			return "魂回"
		"soul_swarm":
			return "魂潮"
	return ""


static func element_counts(spell_ids: Array) -> Dictionary:
	var counts := {}
	for spell_id in spell_ids:
		var id := str(spell_id)
		if id.is_empty() or ActiveSpellRegistry.get_spell(id).is_empty():
			continue
		var element_key := element_for_spell(id)
		counts[element_key] = int(counts.get(element_key, 0)) + 1
	return counts


static func strongest_element(counts: Dictionary) -> Dictionary:
	var best_element := ""
	var best_count := 0
	for key in counts.keys():
		var count := int(counts.get(key, 0))
		if count > best_count:
			best_count = count
			best_element = str(key)
	return {"element": best_element, "count": best_count}


static func synergy_label(element_key: String, count: int) -> String:
	if element_key.is_empty() or count < 2:
		return ""
	var element_name := element_display_name(element_key)
	if count >= 3:
		return "%s元素爆发" % element_name
	return "%s合体技" % element_name


static func element_display_name(element_key: String) -> String:
	match element_key:
		"fire":
			return "火"
		"thunder":
			return "雷"
		"water":
			return "冰"
		"wood":
			return "木"
		"earth":
			return "土"
		"soul":
			return "魂"
	return element_key
