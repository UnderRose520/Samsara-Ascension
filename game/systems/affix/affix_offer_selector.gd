class_name AffixOfferSelector

const AffixBuildMatcher = preload("res://systems/affix/affix_build_matcher.gd")
const BuildArchetypeRegistry = preload("res://systems/affix/build_archetype_registry.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")

const NORMAL_WEIGHTS := {"common": 70, "rare": 25, "epic": 5, "legendary": 0, "dao": 0}
const ELITE_WEIGHTS := {"common": 40, "rare": 40, "epic": 15, "legendary": 5, "dao": 0}
const TEMPTATIONS := [
	{"id": "blood_price", "penalty_id": "enemy_damage", "benefit_text": "打法：把当前机缘提前抬一阶，适合短爆发抢先清场。", "cost_text": "代价：下一房敌人伤害 +18%，逼你用走位换爆发窗口。", "bonus_shift": 1, "min_rooms": 1, "risk": 1},
	{"id": "heavy_karma", "penalty_id": "enemy_hp", "benefit_text": "打法：用更高品阶换更长战线，持续输出和叠层流收益更高。", "cost_text": "代价：下一房敌人真元 +28%，没有穿透时会明显拖慢击杀。", "bonus_shift": 1, "min_rooms": 1, "risk": 1},
	{"id": "storm_chase", "penalty_id": "enemy_speed", "benefit_text": "打法：立刻补强控制或位移相关构筑，下一房靠拉扯兑现。", "cost_text": "代价：下一房敌人移速 +14%，站桩输出会被快速贴身。", "bonus_shift": 1, "min_rooms": 2, "risk": 1},
	{"id": "elite_echo", "penalty_id": "elite_pressure", "benefit_text": "打法：提前拿到核心牌，赌下一房用精英压力喂出成型节奏。", "cost_text": "代价：下一房精英威压增强，精英血量与压迫感都会抬高。", "bonus_shift": 1, "min_rooms": 2, "risk": 2},
	{"id": "blood_oath", "penalty_id": "enemy_damage", "benefit_text": "打法：当前机缘破格两阶，爆发流可以直接赌一波清屏。", "cost_text": "高危代价：下一房敌人伤害 +30%，失误会被连段带走。", "bonus_shift": 2, "min_rooms": 5, "risk": 3},
	{"id": "karma_surge", "penalty_id": "enemy_hp", "benefit_text": "打法：把穿透、连锁、毒火这类滚雪球词条直接推入后期形态。", "cost_text": "高危代价：下一房敌人真元 +42%，输出启动慢会被拖进苦战。", "bonus_shift": 2, "min_rooms": 6, "risk": 3},
	{"id": "elite_tribulation", "penalty_id": "elite_pressure", "benefit_text": "打法：用两阶机缘换精英试炼，适合已有闪避、护体或清场手段时赌。", "cost_text": "高危代价：下一房必有精英压迫，精英会更耐打也更难放风筝。", "bonus_shift": 2, "min_rooms": 7, "risk": 3},
	{"id": "yin_jie_ru_jian", "penalty_id": "enemy_speed", "benefit_text": "打法：引劫入器，当前机缘破格两阶，雷火/剑气流下一房追着怪打。", "cost_text": "高危代价：下一房敌人移速 +22%，天雷追身般逼你连续闪避。", "bonus_shift": 2, "min_rooms": 6, "risk": 3},
	{"id": "heart_demon_trade", "penalty_id": "enemy_damage", "benefit_text": "打法：用心魔换极高品阶，低血爆发和吸血流会变得非常锋利。", "cost_text": "高危代价：下一房敌人伤害 +34%，血线越低越不能贪刀。", "bonus_shift": 2, "min_rooms": 8, "risk": 3},
	{"id": "mirror_subweapon", "penalty_id": "enemy_hp", "benefit_text": "打法：镜中异器映照当前机缘，两阶提升适合多段、召唤、符阵流。", "cost_text": "高危代价：下一房敌人真元 +48%，需要靠多段连锁快速破局。", "bonus_shift": 2, "min_rooms": 9, "risk": 3},
]
const GRAY_PREVIEWS := [
	{"element": "fire", "combo": "burn"},
	{"element": "thunder", "combo": "paralyze"},
	{"element": "wood", "combo": "heal"},
	{"element": "earth", "combo": "defense"},
]


static func roll_offers(all_affixes: Array, count: int, owned_ids: Array, rng: RandomNumberGenerator, context: Dictionary = {}) -> Array:
	var table: Dictionary = ELITE_WEIGHTS if context.get("elite", false) else NORMAL_WEIGHTS
	var element_bias: String = str(context.get("element_bias", ""))
	var desired_tags: Array = context.get("desired_combo_tags", [])
	var archetypes: Array = context.get("build_archetypes", [])
	var director_build_boost := float(context.get("director_build_boost", 1.0))
	var survival_help := float(context.get("director_survival_help", 1.0))

	var pool: Array = []
	for tag in all_affixes:
		if tag.id in owned_ids:
			continue
		var q_key := _quality_key(tag.quality)
		var weight: int = int(table.get(q_key, 5))
		if not element_bias.is_empty() and ElementUtils.key(tag.element) == element_bias:
			weight = int(weight * 1.2)
		if _matches_desired_build(tag, element_bias, desired_tags):
			weight = int(weight * maxf(1.35, director_build_boost))
		var archetype_score := BuildArchetypeRegistry.match_score(tag, archetypes)
		if archetype_score > 0.0:
			weight = int(round(float(weight) * clampf(1.0 + archetype_score * 0.22, 1.0, 2.25)))
		if survival_help > 1.0 and _is_survival_offer(tag):
			weight = int(weight * survival_help)
		pool.append({"tag": tag, "weight": weight})

	var offers: Array = []
	var working := pool.duplicate()
	for _i in count:
		if working.is_empty():
			break
		var pick = _weighted_pick(working, rng)
		offers.append(pick)
		var picked_id: String = pick.id
		var next: Array = []
		for entry in working:
			if entry.tag.id != picked_id:
				next.append(entry)
		working = next
	return _decorate_special_offers(offers, all_affixes, owned_ids, rng, context)


static func unwrap_offer(offer):
	if typeof(offer) == TYPE_DICTIONARY:
		return offer.get("tag")
	return offer


static func is_offer_locked(offer) -> bool:
	return typeof(offer) == TYPE_DICTIONARY and bool(offer.get("locked", false))


static func _weighted_pick(pool: Array, rng: RandomNumberGenerator):
	var total := 0
	for entry in pool:
		total += entry.weight
	var roll := rng.randi_range(1, maxi(total, 1))
	var acc := 0
	for entry in pool:
		acc += entry.weight
		if roll <= acc:
			return entry.tag
	return pool[0].tag


static func _matches_desired_build(tag, element_bias: String, desired_tags: Array) -> bool:
	return AffixBuildMatcher.matches(tag, element_bias, desired_tags)


static func _is_survival_offer(tag) -> bool:
	if tag == null:
		return false
	var key := ElementUtils.key(tag.element)
	if key in ["wood", "earth", "water"]:
		return true
	if int(tag.dao_bucket) == 0 and int(tag.quality) <= 2:
		return true
	for combo_tag in tag.combo_tags:
		if str(combo_tag) in ["heal", "defense", "body"]:
			return true
	return false


static func _decorate_special_offers(offers: Array, all_affixes: Array, owned_ids: Array, rng: RandomNumberGenerator, context: Dictionary) -> Array:
	if (
		offers.is_empty()
		or bool(context.get("from_event", false))
		or bool(context.get("from_shop", false))
		or bool(context.get("opening_choice", false))
	):
		return offers
	var out := offers.duplicate()
	var rooms_cleared := int(context.get("rooms_cleared", 0))
	var owned_count := int(context.get("owned_count", owned_ids.size()))
	var allow_temptation := rooms_cleared >= 1 or owned_count >= 1
	var allow_gray_preview := rooms_cleared >= 2 and owned_count >= 1
	if allow_temptation and rng.randf() < 0.24:
		var idx := rng.randi_range(0, out.size() - 1)
		var tag = unwrap_offer(out[idx])
		var temptation: Dictionary = _pick_temptation(rng, rooms_cleared)
		var shift := int(temptation.get("bonus_shift", 0))
		var preview_tag = tag
		if shift > 0:
			var compiled = ConfigRegistry.compile_affix(tag.id, shift)
			if compiled:
				preview_tag = compiled
		out[idx] = {
			"tag": tag,
			"preview_tag": preview_tag,
			"offer_type": "temptation",
			"temptation_id": str(temptation.get("id", "")),
			"penalty_id": str(temptation.get("penalty_id", "")),
			"benefit_text": str(temptation.get("benefit_text", "")),
			"cost_text": str(temptation.get("cost_text", "")),
			"bonus_shift": shift,
			"risk": int(temptation.get("risk", 1)),
			"badge": "破格诱惑",
		}
	if allow_gray_preview and rng.randf() < 0.18 and out.size() > 0:
		var preview := _make_gray_preview(all_affixes, owned_ids, rng, context)
		if not preview.is_empty():
			out[out.size() - 1] = preview
	return out


static func _pick_temptation(rng: RandomNumberGenerator, rooms_cleared: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for rule in TEMPTATIONS:
		if rooms_cleared >= int(rule.get("min_rooms", 1)):
			candidates.append(rule)
	if candidates.is_empty():
		return TEMPTATIONS[0]
	var late_roll := rooms_cleared >= 6 and rng.randf() < 0.42
	if late_roll:
		var high_risk: Array[Dictionary] = []
		for rule in candidates:
			if int(rule.get("bonus_shift", 1)) >= 2:
				high_risk.append(rule)
		if not high_risk.is_empty():
			return high_risk[rng.randi_range(0, high_risk.size() - 1)]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _make_gray_preview(all_affixes: Array, owned_ids: Array, rng: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	var element_bias := str(context.get("element_bias", ""))
	var desired_tags: Array = context.get("desired_combo_tags", [])
	var candidates: Array = []
	var preview_rule: Dictionary = GRAY_PREVIEWS[rng.randi_range(0, GRAY_PREVIEWS.size() - 1)]
	for tag in all_affixes:
		if tag.id in owned_ids:
			continue
		if _matches_desired_build(tag, element_bias, desired_tags):
			continue
		var key := ElementUtils.key(tag.element)
		var combo := str(preview_rule.get("combo", ""))
		if key == str(preview_rule.get("element", "")) or combo in tag.combo_tags:
			candidates.append(tag)
	if candidates.is_empty():
		return {}
	var tag = candidates[rng.randi_range(0, candidates.size() - 1)]
	var lock_reason := _build_lock_reason(tag, element_bias, desired_tags)
	return {
		"tag": tag,
		"offer_type": "gray",
		"locked": true,
		"badge": "未悟之缘",
		"lock_reason": lock_reason,
		"preview_text": "完整效果已显现，但此世根基暂时接不住。",
	}


static func _build_lock_reason(tag, element_bias: String, desired_tags: Array) -> String:
	var element_key := ElementUtils.key(tag.element)
	var missing: Array[String] = []
	if not element_key.is_empty() and element_key != "none" and element_key != element_bias:
		missing.append("%s根基不足" % _element_name(element_key))
	for combo_tag in tag.combo_tags:
		var key := str(combo_tag)
		if key in ["fire", "thunder", "wood", "earth", "water", "burn", "paralyze", "heal", "defense", "body"] and key not in desired_tags:
			missing.append("%s连携未成" % _combo_name(key))
		if missing.size() >= 2:
			break
	if missing.is_empty():
		return "当前构筑尚未形成承载条件"
	return " / ".join(missing)


static func _element_name(key: String) -> String:
	match key:
		"fire": return "火系"
		"thunder": return "雷系"
		"wood": return "木系"
		"earth": return "土系"
		"water": return "水系"
		"chaos": return "混元"
		"soul": return "魂系"
	return key


static func _combo_name(key: String) -> String:
	match key:
		"burn": return "灼烧"
		"paralyze": return "麻痹"
		"heal": return "续航"
		"defense": return "护体"
		"body": return "体魄"
	return _element_name(key)


static func _quality_key(quality) -> String:
	match quality:
		0: return "common"
		1: return "rare"
		2: return "epic"
		3: return "legendary"
		4: return "dao"
	return "common"


