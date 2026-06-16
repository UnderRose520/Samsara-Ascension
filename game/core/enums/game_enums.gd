class_name GameEnums
extends RefCounted

enum GameMode { MAIN_RUN, ENDLESS, ANCIENT_REALM }
enum DaoHeart { ASK_DAO, ENLIGHTEN, PROVE_DAO }
enum AffixCategory { SKILL, SPELL, CONSTITUTION, DIVINE, SYNERGY, COMPANION }
enum Quality { COMMON, RARE, EPIC, LEGENDARY, DAO }
enum Element { NONE, FIRE, WATER, THUNDER, WOOD, EARTH, CHAOS, SOUL }
enum StatusType { BURN, SLOW, PARALYZE, POISON, FREEZE }
enum TriggerType { PASSIVE, ON_HIT, ON_KILL, ON_DODGE, ON_ATTACK }
enum RoomType { COMBAT, COMBAT_HARD, ELITE, EVENT, REST, SHOP, BOSS, HIDDEN, UNKNOWN }
enum EffectType {
	FLAT_ATTACK,
	FLAT_DEFENSE,
	FLAT_MAX_HP,
	MULT_ATTACK,
	MULT_CRIT_RATE,
	MULT_CRIT_MULT,
	MULT_ATTACK_SPEED,
	MULT_DAO,
	ON_HIT_STATUS,
	PROJECTILE_PIERCE,
}


static func parse_room_type(type_id: String) -> RoomType:
	match type_id:
		"combat":
			return RoomType.COMBAT
		"combat_hard":
			return RoomType.COMBAT_HARD
		"elite":
			return RoomType.ELITE
		"event":
			return RoomType.EVENT
		"rest":
			return RoomType.REST
		"shop":
			return RoomType.SHOP
		"boss":
			return RoomType.BOSS
		"hidden":
			return RoomType.HIDDEN
		_:
			return RoomType.UNKNOWN


static func room_type_id(room_type: RoomType) -> String:
	match room_type:
		RoomType.COMBAT:
			return "combat"
		RoomType.COMBAT_HARD:
			return "combat_hard"
		RoomType.ELITE:
			return "elite"
		RoomType.EVENT:
			return "event"
		RoomType.REST:
			return "rest"
		RoomType.SHOP:
			return "shop"
		RoomType.BOSS:
			return "boss"
		RoomType.HIDDEN:
			return "hidden"
		_:
			return ""


static func is_combat_room_type(room_type: RoomType) -> bool:
	return room_type in [RoomType.COMBAT, RoomType.COMBAT_HARD, RoomType.ELITE]


static func is_boss_room_type(room_type: RoomType) -> bool:
	return room_type == RoomType.BOSS
