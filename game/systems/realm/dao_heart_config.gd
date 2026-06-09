class_name DaoHeartConfig

enum DaoHeart { ASK_DAO, ENLIGHTEN, PROVE_DAO }

const LABELS := {
	DaoHeart.ASK_DAO: "问道",
	DaoHeart.ENLIGHTEN: "悟道",
	DaoHeart.PROVE_DAO: "证道",
}

const ENEMY_HP_MULT := {
	DaoHeart.ASK_DAO: 0.8,
	DaoHeart.ENLIGHTEN: 1.0,
	DaoHeart.PROVE_DAO: 1.2,
}

const BOSS_HP_MULT := {
	DaoHeart.ASK_DAO: 0.85,
	DaoHeart.ENLIGHTEN: 1.0,
	DaoHeart.PROVE_DAO: 1.15,
}

const ENEMY_COUNT_DELTA := {
	DaoHeart.ASK_DAO: -1,
	DaoHeart.ENLIGHTEN: 0,
	DaoHeart.PROVE_DAO: 1,
}


static func label(heart: int) -> String:
	return LABELS.get(heart, "悟道")


static func enemy_hp_mult(heart: int, is_boss: bool = false) -> float:
	if is_boss:
		return BOSS_HP_MULT.get(heart, 1.0)
	return ENEMY_HP_MULT.get(heart, 1.0)


static func enemy_count_delta(heart: int) -> int:
	return ENEMY_COUNT_DELTA.get(heart, 0)
