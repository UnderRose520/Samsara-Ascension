class_name CombatContextBuilder
extends RefCounted

## Builds damage pipeline context — coordinates affix stats, weather, terrain, and pet mult.


static func build(
	holder: Node,
	base_damage: float,
	target_defense: float,
	crit_rate: float,
	crit_mult: float,
	hit_label: String = "hit",
) -> Dictionary:
	var is_crit := CombatRngService.roll_chance("crit_%s" % hit_label, crit_rate)
	var element_key := str(holder.get_element_bias()) if holder.has_method("get_element_bias") else "fire"
	if element_key.is_empty():
		element_key = "fire"

	var ctx := {
		"base_damage": base_damage + holder.flat_attack,
		"additive_bonus": 0.0,
		"bucket_a": holder.bucket_a.duplicate(),
		"bucket_b": holder.bucket_b.duplicate(),
		"bucket_c": holder.bucket_c.duplicate(),
		"bucket_d": holder.bucket_d.duplicate(),
		"is_crit": is_crit,
		"crit_mult": crit_mult,
		"target_defense": maxf(target_defense, 0.0),
		"element_key": element_key,
		"trigger_on_hit": true,
	}
	WeatherSystem.apply_to_context(ctx, element_key)

	var player_body: Node2D = holder.player_body
	if player_body:
		TerrainSystem.apply_to_context(ctx, element_key, player_body.global_position)

	var pet := EntityCache.get_pet()
	if pet and pet.has_method("get_mult_c"):
		var pet_mult: float = float(pet.get_mult_c())
		if pet_mult != 1.0:
			ctx["bucket_c"].append(pet_mult)
	return ctx


static func build_fallback(
	base_damage: float,
	target_defense: float,
	crit_rate: float,
	crit_mult: float,
	element_key: String,
	player: Node2D,
	hit_label: String,
	trigger_on_hit: bool,
) -> Dictionary:
	var is_crit := CombatRngService.roll_chance("crit_%s" % hit_label, crit_rate)
	var ctx := {
		"base_damage": base_damage,
		"additive_bonus": 0.0,
		"bucket_a": [],
		"bucket_b": [],
		"bucket_c": [],
		"bucket_d": [],
		"mult_a": 1.0,
		"mult_b": 1.0,
		"mult_c": 1.0,
		"mult_d": 1.0,
		"is_crit": is_crit,
		"crit_mult": crit_mult,
		"target_defense": maxf(target_defense, 0.0),
		"element_key": element_key,
		"trigger_on_hit": trigger_on_hit,
	}
	WeatherSystem.apply_to_context(ctx, element_key)
	if player:
		TerrainSystem.apply_to_context(ctx, element_key, player.global_position)
	return ctx
