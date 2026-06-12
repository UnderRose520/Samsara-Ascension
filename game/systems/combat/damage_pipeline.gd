class_name DamagePipeline

const GameConstants = preload("res://core/constants/game_constants.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")


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


static func resolve_bucket_mult(ctx: Dictionary, bucket_key: String) -> float:
	var sources: Array = ctx.get("bucket_%s" % bucket_key, [])
	if not sources.is_empty():
		return apply_bucket_multipliers(sources)
	return float(ctx.get("mult_%s" % bucket_key, 1.0))


static func compute_pve(ctx: Dictionary) -> Dictionary:
	var damage: float = float(ctx.get("base_damage", 0.0))
	damage *= 1.0 + float(ctx.get("additive_bonus", 0.0))
	damage *= resolve_bucket_mult(ctx, "a")
	damage *= resolve_bucket_mult(ctx, "b")
	damage *= resolve_bucket_mult(ctx, "c")
	damage *= resolve_bucket_mult(ctx, "d")
	var is_crit := VariantUtils.as_bool(ctx.get("is_crit", false))
	if is_crit:
		damage *= float(ctx.get("crit_mult", 1.5))
	damage *= 1.0 - calc_mitigation(float(ctx.get("target_defense", 0.0)))
	return {
		"final_damage": maxf(damage, 1.0),
		"is_crit": is_crit,
		"element_key": str(ctx.get("element_key", "")),
		"trigger_on_hit": VariantUtils.as_bool(ctx.get("trigger_on_hit", true)),
	}
