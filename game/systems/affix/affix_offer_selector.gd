class_name AffixOfferSelector

const NORMAL_WEIGHTS := {"common": 70, "rare": 25, "epic": 5, "legendary": 0, "dao": 0}
const ELITE_WEIGHTS := {"common": 40, "rare": 40, "epic": 15, "legendary": 5, "dao": 0}


static func roll_offers(all_affixes: Array, count: int, owned_ids: Array, rng: RandomNumberGenerator, context: Dictionary = {}) -> Array:
	var table: Dictionary = ELITE_WEIGHTS if context.get("elite", false) else NORMAL_WEIGHTS
	var element_bias: String = str(context.get("element_bias", ""))

	var pool: Array = []
	for tag in all_affixes:
		if tag.id in owned_ids:
			continue
		var q_key := _quality_key(tag.quality)
		var weight: int = int(table.get(q_key, 5))
		if not element_bias.is_empty() and _element_key(tag.element) == element_bias:
			weight = int(weight * 1.2)
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
	return offers


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


static func _quality_key(quality) -> String:
	match quality:
		0: return "common"
		1: return "rare"
		2: return "epic"
		3: return "legendary"
		4: return "dao"
	return "common"


static func _element_key(element_id: int) -> String:
	match element_id:
		1: return "fire"
		2: return "water"
		3: return "thunder"
		4: return "wood"
		5: return "earth"
	return ""
