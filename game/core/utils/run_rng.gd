class_name RunRng
extends RefCounted

## Seeded RNG helpers — all in-run randomness goes through RunContext.derive_rng_seed.


static func make(context: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = RunContext.derive_rng_seed(context)
	return rng


static func rollf(context: String) -> float:
	return make(context).randf()


static func roll_chance(context: String, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return rollf(context) < chance


static func stage_room(stage_index: int, room_index: int, template_id: String) -> RandomNumberGenerator:
	return make("stage_room_%d_%d_%s" % [stage_index, room_index, template_id])


static func run_controller(context: String) -> RandomNumberGenerator:
	return make("run_controller_%s" % context)


static func training(context: String) -> RandomNumberGenerator:
	return make("training_%s" % context)


static func enemy_jitter(spawn_index: int) -> RandomNumberGenerator:
	if RunContext.training_mode:
		return make("training_jitter_w%d_%d" % [RunContext.training_wave, spawn_index])
	return make("enemy_jitter_%d_%d_%d" % [RunContext.current_stage, RunContext.current_room, spawn_index])
