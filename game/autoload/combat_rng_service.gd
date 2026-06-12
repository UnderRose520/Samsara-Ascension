extends Node

## 战斗内确定性 RNG（暴击、状态施加等），与 RunContext 种子解耦。

var combat_roll_seq := 0


func reset() -> void:
	combat_roll_seq = 0


func combat_rng(label: String) -> RandomNumberGenerator:
	combat_roll_seq += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = RunContext.derive_rng_seed("combat_%d_%s" % [combat_roll_seq, label])
	return rng


func roll_chance(label: String, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return combat_rng(label).randf() < chance
