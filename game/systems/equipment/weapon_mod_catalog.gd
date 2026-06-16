class_name WeaponModCatalog

const MAX_MODS := 3

const MODS := {
	"tempered_edge": {
		"id": "tempered_edge",
		"name": "\u6dec\u5203",
		"kind": "temper",
		"rarity": "common",
		"tags": ["temper", "weapon"],
		"conflicts": [],
		"weight": 10,
		"damage_mult": 1.08,
		"range_mult": 1.06,
		"description": "\u672c\u547d\u5668\u4f24\u5bb3\u4e0e\u89e6\u53ca\u7565\u589e",
	},
	"flowing_edge": {
		"id": "flowing_edge",
		"name": "\u6d41\u5149\u6dec\u5203",
		"kind": "temper",
		"rarity": "rare",
		"tags": ["temper", "sword", "crit"],
		"conflicts": [],
		"weight": 7,
		"damage_mult": 1.12,
		"attack_interval_mult": 0.94,
		"description": "\u5251\u5668\u6d41\u5149\uff0c\u666e\u653b\u66f4\u5feb\u4e14\u4f24\u5bb3\u63d0\u5347",
	},
	"fire_inscription": {
		"id": "fire_inscription",
		"name": "\u8d64\u7130\u94ed\u7eb9",
		"kind": "inscription",
		"rarity": "rare",
		"tags": ["fire", "status", "inscription"],
		"conflicts": ["cold_jade_inscription"],
		"weight": 8,
		"element_override": "fire",
		"status_on_hit": "burn",
		"status_duration": 2.5,
		"description": "\u672c\u547d\u5668\u9644\u706b\uff0c\u547d\u4e2d\u707c\u70e7",
	},
	"thunder_wood_inscription": {
		"id": "thunder_wood_inscription",
		"name": "\u96f7\u51fb\u6728\u94ed\u7eb9",
		"kind": "inscription",
		"rarity": "rare",
		"tags": ["thunder", "status", "range", "inscription"],
		"conflicts": [],
		"weight": 8,
		"element_override": "thunder",
		"status_on_hit": "paralyze",
		"status_duration": 0.45,
		"range_mult": 1.08,
		"description": "\u672c\u547d\u5668\u5f15\u96f7\uff0c\u89e6\u53ca\u66f4\u8fdc\u5e76\u77ed\u6682\u9ebb\u75f9",
	},
	"cold_jade_inscription": {
		"id": "cold_jade_inscription",
		"name": "\u5bd2\u7389\u94ed\u7eb9",
		"kind": "inscription",
		"rarity": "rare",
		"tags": ["water", "status", "inscription"],
		"conflicts": ["fire_inscription"],
		"weight": 8,
		"element_override": "water",
		"status_on_hit": "slow",
		"status_duration": 1.8,
		"description": "\u672c\u547d\u5668\u542b\u5bd2\uff0c\u547d\u4e2d\u51cf\u901f",
	},
	"soul_bone_inscription": {
		"id": "soul_bone_inscription",
		"name": "\u9b42\u9aa8\u94ed\u7eb9",
		"kind": "inscription",
		"rarity": "epic",
		"tags": ["soul", "damage", "inscription"],
		"conflicts": [],
		"weight": 5,
		"element_override": "soul",
		"damage_mult": 1.04,
		"description": "\u672c\u547d\u5668\u67d3\u9b42\uff0c\u5f52\u4e00\u66f4\u6613\u8d70\u9b42\u7cfb",
	},
	"jade_orb_matrix": {
		"id": "jade_orb_matrix",
		"name": "\u7389\u73e0\u9635\u7eb9",
		"kind": "matrix",
		"rarity": "rare",
		"tags": ["orb", "spell", "range"],
		"conflicts": [],
		"weight": 7,
		"range_mult": 1.12,
		"damage_mult": 1.05,
		"description": "\u6cd5\u73e0\u6210\u9635\uff0c\u8fdc\u51fb\u66f4\u7a33\u4e14\u7565\u589e\u4f24\u5bb3",
	},
	"talisman_root_array": {
		"id": "talisman_root_array",
		"name": "\u9752\u6728\u7b26\u9635",
		"kind": "matrix",
		"rarity": "rare",
		"tags": ["talisman", "wood", "status", "range"],
		"conflicts": [],
		"weight": 7,
		"element_override": "wood",
		"status_on_hit": "poison",
		"status_duration": 2.2,
		"range_mult": 1.05,
		"description": "\u7b26\u5668\u690d\u6839\uff0c\u547d\u4e2d\u6bd2\u4f24\u5e76\u62d3\u5c55\u5c04\u7a0b",
	},
	"soul_lantern_core": {
		"id": "soul_lantern_core",
		"name": "\u9b42\u706f\u5668\u82af",
		"kind": "core",
		"rarity": "epic",
		"tags": ["banner", "soul", "core", "damage"],
		"conflicts": [],
		"weight": 4,
		"element_override": "soul",
		"damage_mult": 1.10,
		"attack_interval_mult": 1.04,
		"description": "\u9b42\u5e61\u70b9\u706f\uff0c\u4f24\u5bb3\u63d0\u5347\u4f46\u51fa\u624b\u7565\u6162",
	},
}

const RARITY_LABELS := {
	"common": "\u51e1\u54c1",
	"rare": "\u7075\u54c1",
	"epic": "\u7384\u54c1",
}

const TAG_LABELS := {
	"temper": "\u6dec\u70bc",
	"weapon": "\u672c\u547d",
	"fire": "\u706b",
	"water": "\u6c34",
	"thunder": "\u96f7",
	"wood": "\u6728",
	"soul": "\u9b42",
	"status": "\u72b6\u6001",
	"range": "\u89e6\u53ca",
	"damage": "\u4f24\u5bb3",
	"inscription": "\u94ed\u7eb9",
	"matrix": "\u9635\u7eb9",
	"core": "\u5668\u82af",
	"spell": "\u6cd5\u672f",
	"crit": "\u7834\u52bf",
	"sword": "\u5251",
	"orb": "\u73e0",
	"talisman": "\u7b26",
	"banner": "\u5e61",
}

const FAMILY_TAGS := {
	"orb": ["orb", "spell", "fire", "range"],
	"sword": ["sword", "temper", "crit", "thunder"],
	"talisman": ["talisman", "wood", "matrix", "range"],
	"banner": ["banner", "soul", "core", "damage"],
}


static func get_mod(id: String) -> Dictionary:
	return (MODS.get(id, {}) as Dictionary).duplicate(true)


static func get_all_mods() -> Array:
	var out: Array = []
	for id in MODS.keys():
		out.append(get_mod(str(id)))
	return out


static func build_offer_pool(owned_ids: Array, element_hint: String = "", path_hint: String = "", focus_tags: Array = []) -> Array:
	var pool: Array = []
	for mod in get_all_mods():
		if not _can_offer(mod, owned_ids):
			continue
		var copies := maxi(int(mod.get("weight", 1)), 1)
		var element := str(mod.get("element_override", ""))
		var tags: Array = mod.get("tags", [])
		if not element_hint.is_empty() and element == element_hint:
			copies += 4
		copies += _path_bonus(tags, path_hint)
		copies += _focus_bonus(tags, focus_tags)
		for _i in copies:
			pool.append(mod)
	return pool


static func roll_offers(rng: RandomNumberGenerator, count: int, owned_ids: Array, element_hint: String = "", path_hint: String = "", focus_tags: Array = []) -> Array:
	var pool := build_offer_pool(owned_ids, element_hint, path_hint, focus_tags)
	var offers: Array = []
	var picked: Dictionary = {}
	while offers.size() < count and not pool.is_empty():
		var mod: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var id := str(mod.get("id", ""))
		if id.is_empty() or picked.has(id):
			pool = pool.filter(func(candidate: Dictionary) -> bool:
				return str(candidate.get("id", "")) != id
			)
			continue
		picked[id] = true
		offers.append(mod.duplicate(true))
		pool = pool.filter(func(candidate: Dictionary) -> bool:
			return str(candidate.get("id", "")) != id
		)
	_ensure_rare_offer(offers, owned_ids, element_hint, path_hint, focus_tags, rng)
	return offers


static func roll_mod(rng: RandomNumberGenerator, owned_ids: Array, element_hint: String = "", path_hint: String = "", focus_tags: Array = []) -> Dictionary:
	var offers := roll_offers(rng, 1, owned_ids, element_hint, path_hint, focus_tags)
	return offers[0] if not offers.is_empty() else {}


static func format_mod(mod: Dictionary) -> String:
	var rarity := str(mod.get("rarity", "common"))
	return "%s / %s" % [mod.get("name", mod.get("id", "")), RARITY_LABELS.get(rarity, rarity)]


static func format_tags(mod: Dictionary) -> String:
	var labels: PackedStringArray = []
	for tag in mod.get("tags", []):
		labels.append(str(TAG_LABELS.get(str(tag), str(tag))))
	return " / ".join(labels)


static func format_conflicts(mod: Dictionary) -> String:
	var names: PackedStringArray = []
	for id in mod.get("conflicts", []):
		var conflict := get_mod(str(id))
		if not conflict.is_empty():
			names.append(str(conflict.get("name", id)))
	return "\u3001".join(names)


static func _can_offer(mod: Dictionary, owned_ids: Array) -> bool:
	var id := str(mod.get("id", ""))
	if id.is_empty() or id in owned_ids:
		return false
	for conflict_id in mod.get("conflicts", []):
		if str(conflict_id) in owned_ids:
			return false
	return true


static func _path_bonus(tags: Array, path_hint: String) -> int:
	if path_hint.is_empty():
		return 0
	var wanted: Array = FAMILY_TAGS.get(path_hint, [])
	if wanted.is_empty():
		wanted = [path_hint]
	var bonus := 0
	for tag in tags:
		if str(tag) in wanted:
			bonus += 2
	return mini(bonus, 8)


static func _focus_bonus(tags: Array, focus_tags: Array) -> int:
	if focus_tags.is_empty():
		return 0
	var bonus := 0
	for tag in tags:
		if str(tag) in focus_tags:
			bonus += 2
	return mini(bonus, 8)


static func _ensure_rare_offer(offers: Array, owned_ids: Array, element_hint: String, path_hint: String, focus_tags: Array, rng: RandomNumberGenerator) -> void:
	if offers.is_empty():
		return
	for mod in offers:
		if str(mod.get("rarity", "common")) in ["rare", "epic"]:
			return
	var candidates: Array = []
	var offered_ids: Dictionary = {}
	for offer in offers:
		offered_ids[str(offer.get("id", ""))] = true
	for mod in get_all_mods():
		if not _can_offer(mod, owned_ids):
			continue
		if offered_ids.has(str(mod.get("id", ""))):
			continue
		if str(mod.get("rarity", "common")) not in ["rare", "epic"]:
			continue
		if _path_bonus(mod.get("tags", []), path_hint) > 0 or _focus_bonus(mod.get("tags", []), focus_tags) > 0 or str(mod.get("element_override", "")) == element_hint:
			candidates.append(mod)
	if candidates.is_empty():
		return
	var replacement: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	offers[offers.size() - 1] = replacement.duplicate(true)
