extends Node

const DamagePipeline = preload("res://systems/combat/damage_pipeline.gd")
const CombatContextBuilder = preload("res://systems/combat/combat_context_builder.gd")
const ComboGraph = preload("res://systems/affix/combo_graph.gd")
const AffixCompiler = preload("res://systems/affix/affix_compiler.gd")
const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")
const ElementUtils = preload("res://core/utils/element_utils.gd")

signal changed

const MAX_AFFIXES := 5  # fallback; use get_max_affixes()

var player_body: CharacterBody2D
var equipped: Array = []
var sealed_affixes: Array = []
var skill_passives: Array = []
var talent_passives: Array = []
var recent_elements: Array = []

var flat_attack := 0.0
var flat_defense := 0.0
var flat_max_hp := 0.0
var bonus_crit_rate := 0.0
var bonus_crit_mult := 0.0
var attack_speed_mult := 1.0
var projectile_pierce := 0
var bucket_a: Array = []
var bucket_b: Array = []
var bucket_c: Array = []
var bucket_d: Array = []
var dao_tradition_passives: Array = []

var _discovered_combos: Dictionary = {}

func _ready() -> void:
	if player_body == null:
		player_body = get_parent() as CharacterBody2D
	EventBus.realm_changed.connect(func(_lvl, _slots):
		refresh_stats()
		changed.emit()
	)
	EventBus.pet_acquired.connect(func(_id): EntityCache.invalidate_pet())


func get_max_affixes() -> int:
	return RunContext.affix_slot_max()


func get_core_slot_max() -> int:
	return RunContext.affix_core_slot_max()


func get_temporary_slot_max() -> int:
	return RunContext.affix_temporary_slot_max()


func get_sealed_slot_max() -> int:
	return RunContext.affix_sealed_slot_max()


func can_equip() -> bool:
	return equipped.size() < get_max_affixes()


func can_seal() -> bool:
	return sealed_affixes.size() < get_sealed_slot_max()


func get_slot_summary() -> Dictionary:
	var core_used := mini(equipped.size(), get_core_slot_max())
	var temp_used := maxi(equipped.size() - get_core_slot_max(), 0)
	return {
		"core_used": core_used,
		"core_max": get_core_slot_max(),
		"temporary_used": temp_used,
		"temporary_max": get_temporary_slot_max(),
		"active_used": equipped.size(),
		"active_max": get_max_affixes(),
		"sealed_used": sealed_affixes.size(),
		"sealed_max": get_sealed_slot_max(),
	}


func add_affix(tag) -> bool:
	if not can_equip():
		return false
	if _has_affix(tag.id):
		return false
	equipped.append(tag)
	recent_elements.append(tag.element)
	if recent_elements.size() > 3:
		recent_elements.pop_front()
	_recompute()
	_check_combo_discovery()
	EventBus.affix_acquired.emit(tag.id)
	_notify_affix_spell_unlock(tag)
	changed.emit()
	_try_dao_tradition_awaken()
	return true


func replace_affix(index: int, tag) -> bool:
	if tag == null or index < 0 or index >= equipped.size():
		return false
	if _has_affix_except(tag.id, index):
		return false
	equipped[index] = tag
	recent_elements.append(tag.element)
	if recent_elements.size() > 3:
		recent_elements.pop_front()
	_recompute_after_affix_change(tag)
	return true


func seal_affix(tag) -> bool:
	if tag == null or not can_seal():
		return false
	if _has_affix(tag.id) or _has_sealed_affix(tag.id):
		return false
	sealed_affixes.append(tag)
	changed.emit()
	return true


func dissolve_value(tag) -> int:
	if tag == null:
		return 6
	var quality := int(tag.quality)
	return 8 + quality * 5


func get_affix_label(index: int) -> String:
	if index < 0 or index >= equipped.size():
		return ""
	var tag = equipped[index]
	return "%s %s" % [str(tag.name), _quality_label(tag.quality)]


func _recompute_after_affix_change(tag) -> void:
	_recompute()
	_check_combo_discovery()
	EventBus.affix_acquired.emit(tag.id)
	_notify_affix_spell_unlock(tag)
	changed.emit()
	_try_dao_tradition_awaken()


func apply_dao_tradition(tradition: Dictionary) -> void:
	var dsl := str(tradition.get("passive_dsl", "")).strip_edges()
	if dsl.is_empty():
		return
	var dummy = AffixCompiler.compile_row({"id": str(tradition.get("id", "dao")), "effect1": dsl})
	for effect in dummy.passives:
		dao_tradition_passives.append(effect)
	_recompute()


func _try_dao_tradition_awaken() -> void:
	const DaoTraditionRegistry = preload("res://systems/dao/dao_tradition_registry.gd")
	var tradition = DaoTraditionRegistry.try_awaken(self)
	if tradition == null:
		EventBus.dao_tradition_progress.emit(DaoTraditionRegistry.get_best_progress(self))
		return
	apply_dao_tradition(tradition)
	RunContext.dao_tradition_awakened_this_run = str(tradition.get("id", ""))
	SaveManager.record_dao_tradition(RunContext.dao_tradition_awakened_this_run)
	EventBus.dao_tradition_awakened.emit(tradition)
	changed.emit()


func apply_talent(talent: Dictionary) -> void:
	var dsl := str(talent.get("effect1", "")).strip_edges()
	if dsl.is_empty():
		return
	var dummy = AffixCompiler.compile_row({"id": str(talent.get("id", "talent")), "effect1": dsl})
	for effect in dummy.passives:
		talent_passives.append(effect)
	_recompute()


func apply_skill_effect(dsl: String) -> void:
	if dsl.is_empty():
		return
	var dummy = AffixCompiler.compile_row({"id": "skill_temp", "effect1": dsl})
	for effect in dummy.passives:
		skill_passives.append(effect)
	for effect in dummy.on_hit:
		skill_passives.append(effect)
	_recompute()


func refresh_stats() -> void:
	_recompute()


func get_spell_effects() -> Array:
	var effects: Array = []
	for tag in equipped:
		for effect in tag.passives:
			if _is_spell_effect(effect):
				effects.append(effect)
	for effect in talent_passives:
		if _is_spell_effect(effect):
			effects.append(effect)
	for effect in skill_passives:
		if _is_spell_effect(effect):
			effects.append(effect)
	for effect in dao_tradition_passives:
		if _is_spell_effect(effect):
			effects.append(effect)
	return effects


func has_combo_tag(tag_name: String) -> bool:
	for tag in equipped:
		if tag_name in tag.combo_tags:
			return true
	return false


func get_element_bias() -> String:
	if recent_elements.size() < 3:
		return ""
	var first = recent_elements[0]
	for e in recent_elements:
		if e != first:
			return ""
	return ElementUtils.key(first)


func get_owned_ids() -> Array:
	var ids: Array = []
	for tag in equipped:
		ids.append(tag.id)
	return ids


func get_summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for tag in equipped:
		lines.append("%s·%s" % [tag.name, _quality_label(tag.quality)])
	if lines.is_empty():
		lines.append("暂无")
	return lines


func get_combo_display() -> Dictionary:
	var tags := ComboGraph.collect_tags_from_affixes(equipped)
	var results := ComboGraph.evaluate(tags)
	var best = null
	for entry in results:
		if best == null or entry.progress > best.progress:
			best = entry
	return best if best else {"name": "—", "progress": 0.0, "matched": [], "total": 1, "missing": [], "hint": ""}


func build_damage_context(
	base_damage: float,
	target_defense: float,
	crit_rate: float,
	crit_mult: float,
	hit_label: String = "hit",
) -> Dictionary:
	return CombatContextBuilder.build(
		self,
		base_damage,
		target_defense,
		crit_rate,
		crit_mult,
		hit_label,
	)

func proc_on_hit(target: Node) -> float:
	if target == null:
		return 0.0
	var bonus_explosion := 0.0
	for tag in equipped:
		for effect in tag.on_hit:
			_try_status_effect(target, effect)
			_try_heal_on_hit(effect)
			_try_lifesteal_attack(effect)
	for effect in skill_passives:
		if effect.get("kind") == "on_hit_status":
			_try_status_effect(target, effect)
		elif effect.get("kind") == "heal_on_hit":
			_try_heal_on_hit(effect)
		elif effect.get("kind") == "lifesteal_attack":
			_try_lifesteal_attack(effect)
	if target.has_method("get_burn_stacks") and target.get_burn_stacks() >= 5 and has_combo_tag("combust"):
		if target.has_method("detonate_burn"):
			bonus_explosion = target.detonate_burn(flat_attack + (player_body.attack_power if player_body else 10.0))
	return bonus_explosion


func _try_status_effect(target: Node, effect: Dictionary) -> void:
	if effect.get("kind") != "on_hit_status":
		return
	var chance := float(effect.get("chance", 0.0))
	var status_name := str(effect.get("status", ""))
	if not CombatRngService.roll_chance("status_%s" % status_name, chance):
		return
	if target.has_method("apply_status"):
		target.apply_status(status_name, float(effect.get("duration", 1.0)))


func _try_heal_on_hit(effect: Dictionary) -> void:
	if effect.get("kind") != "heal_on_hit":
		return
	if player_body == null or not player_body.has_node("HealthComponent"):
		return
	var chance := float(effect.get("chance", 0.0))
	if not CombatRngService.roll_chance("heal_on_hit", chance):
		return
	var health: Node = player_body.get_node("HealthComponent")
	var healed := 0.0
	if health.has_method("heal"):
		healed = health.heal(float(effect.get("value", 0.0)))
	if healed <= 0.0:
		return
	VfxManager.spawn_world(player_body.global_position, "heal", Color(0.45, 1.0, 0.55))


func _try_lifesteal_attack(effect: Dictionary) -> void:
	if effect.get("kind") != "lifesteal_attack":
		return
	if player_body == null or not player_body.has_node("HealthComponent"):
		return
	var chance := float(effect.get("chance", 0.0))
	if not CombatRngService.roll_chance("lifesteal_attack", chance):
		return
	var attack_value := float(player_body.attack_power) + flat_attack
	var heal_amount := attack_value * float(effect.get("ratio", 0.0))
	if heal_amount <= 0.0:
		return
	var health: Node = player_body.get_node("HealthComponent")
	var healed := 0.0
	if health.has_method("heal"):
		healed = health.heal(heal_amount)
	if healed <= 0.0:
		return
	VfxManager.spawn_world(player_body.global_position, "heal", Color(0.45, 1.0, 0.55))


func _recompute() -> void:
	flat_attack = 0.0
	flat_defense = 0.0
	flat_max_hp = 0.0
	bonus_crit_rate = 0.0
	bonus_crit_mult = 0.0
	attack_speed_mult = 1.0
	projectile_pierce = 0
	bucket_a.clear()
	bucket_b.clear()
	bucket_c.clear()
	bucket_d.clear()

	for tag in equipped:
		for effect in tag.passives:
			_apply_passive_effect(effect, tag)

	for effect in skill_passives:
		_apply_passive_effect(effect, null, 1)

	for effect in talent_passives:
		_apply_passive_effect(effect, null, 4)

	for effect in dao_tradition_passives:
		_apply_passive_effect(effect, null, 4)

	_apply_to_player()
	_notify_spell_caster()


func _apply_passive_effect(effect: Dictionary, tag = null, default_dao_bucket: int = 0) -> void:
	match str(effect.get("kind", "")):
		"flat_attack":
			flat_attack += float(effect.get("value", 0.0))
		"flat_defense":
			flat_defense += float(effect.get("value", 0.0))
		"flat_max_hp":
			flat_max_hp += float(effect.get("value", 0.0))
		"mult_crit_rate":
			bonus_crit_rate += float(effect.get("value", 0.0))
		"mult_crit_mult":
			bonus_crit_mult += float(effect.get("value", 0.0))
		"mult_attack_speed":
			attack_speed_mult *= float(effect.get("value", 1.0))
		"projectile_pierce":
			projectile_pierce += int(effect.get("value", 0))
		"mult_attack", "dao_mult":
			var dao_bucket := int(tag.dao_bucket) if tag != null else default_dao_bucket
			_append_mult_by_dao_bucket_value(float(effect.get("value", 1.0)), dao_bucket)


func _append_mult_by_dao_bucket_value(value: float, dao_bucket: int) -> void:
	match dao_bucket:
		1:
			bucket_a.append(value)
		2:
			bucket_b.append(value)
		3:
			bucket_c.append(value)
		4:
			bucket_d.append(value)
		_:
			bucket_a.append(value)


func _is_spell_effect(effect: Dictionary) -> bool:
	var kind := str(effect.get("kind", ""))
	return kind == "unlock_spell" or kind == "bind_spell"


func _notify_spell_caster() -> void:
	if player_body == null or not player_body.has_node("PlayerSpellCaster"):
		return
	player_body.get_node("PlayerSpellCaster").sync_spell_state()


func _notify_affix_spell_unlock(tag) -> void:
	for effect in tag.passives:
		var kind := str(effect.get("kind", ""))
		if kind == "unlock_spell":
			var slot := str(effect.get("slot", "")).to_lower()
			var spell_id := str(SpellProgress.get_default_bindings().get(slot, ""))
			var spell := ActiveSpellRegistry.get_spell(spell_id)
			var spell_name := str(spell.get("name", slot.to_upper()))
			EventBus.learn_feedback.emit("词条解锁 · %s %s" % [slot.to_upper(), spell_name], "spell")
		elif kind == "bind_spell":
			var spell_id := str(effect.get("spell_id", ""))
			var spell := ActiveSpellRegistry.get_spell(spell_id)
			var spell_name := str(spell.get("name", spell_id))
			EventBus.learn_feedback.emit("法术换绑 · %s" % spell_name, "rebind")


func _check_combo_discovery() -> void:
	var tags := ComboGraph.collect_tags_from_affixes(equipped)
	for entry in ComboGraph.evaluate(tags):
		if not entry.get("complete", false):
			continue
		var combo_id: String = str(entry.get("id", ""))
		if combo_id.is_empty() or _discovered_combos.get(combo_id, false):
			continue
		_discovered_combos[combo_id] = true
		EventBus.combo_discovered.emit(combo_id)


func _has_affix(id: String) -> bool:
	for tag in equipped:
		if tag.id == id:
			return true
	return false


func _has_affix_except(id: String, except_index: int) -> bool:
	for i in equipped.size():
		if i == except_index:
			continue
		var tag = equipped[i]
		if tag.id == id:
			return true
	return false


func _has_sealed_affix(id: String) -> bool:
	for tag in sealed_affixes:
		if tag.id == id:
			return true
	return false


func _apply_to_player() -> void:
	if player_body == null:
		return
	var stats := RunContext.apply_realm_growth_to_stats(ConfigRegistry.get_default_player_stats())
	# flat_attack 仅在伤害流水线中加算，避免与 build_damage_context 重复叠加
	player_body.attack_power = stats.attack
	player_body.defense = stats.defense
	player_body.move_speed = stats.move_speed
	player_body.dodge_cooldown = stats.dodge_cooldown
	player_body.crit_rate = clampf(stats.crit_rate + bonus_crit_rate, 0.0, 0.95)
	player_body.crit_mult = stats.crit_mult + bonus_crit_mult
	if player_body.has_node("HealthComponent"):
		var health: Node = player_body.get_node("HealthComponent")
		var new_max: float = stats.hp + flat_max_hp
		var ratio: float = health.current_hp / maxf(health.max_hp, 1.0)
		health.max_hp = new_max
		health.current_hp = minf(new_max, new_max * ratio)
		health.changed.emit(health.current_hp, health.max_hp)


func _quality_label(quality) -> String:
	match quality:
		0: return "凡"
		1: return "灵"
		2: return "仙"
		3: return "天"
		4: return "道"
	return "凡"
