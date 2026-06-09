class_name DamagePipeline

const GameConstants = preload("res://core/constants/game_constants.gd")


static func calc_mitigation(defense: float) -> float:
	if defense <= 0.0:
		return 0.0
	return defense / (defense + 100.0)


static func apply_bucket_multipliers(sources: Array) -> float:
	if sources.is_empty():
		return 1.0
	var sorted: Array = sources.duplicate()
	sorted.sort()
	sorted.reverse()
	var product := 1.0
	for i in sorted.size():
		var mult: float = float(sorted[i])
		var decay_index: int = mini(i, GameConstants.BUCKET_DECAY.size() - 1)
		var decay: float = GameConstants.BUCKET_DECAY[decay_index]
		product *= 1.0 + (mult - 1.0) * decay
	return product


static func compute_pve(ctx: Dictionary) -> Dictionary:
	var damage: float = float(ctx.get("base_damage", 0.0))
	damage *= 1.0 + float(ctx.get("additive_bonus", 0.0))
	damage *= float(ctx.get("mult_a", 1.0))
	damage *= float(ctx.get("mult_b", 1.0))
	damage *= float(ctx.get("mult_c", 1.0))
	damage *= float(ctx.get("mult_d", 1.0))
	if bool(ctx.get("is_crit", false)):
		damage *= float(ctx.get("crit_mult", 1.5))
	damage *= 1.0 - calc_mitigation(float(ctx.get("target_defense", 0.0)))
	return {"final_damage": maxf(damage, 1.0), "is_crit": ctx.get("is_crit", false)}
