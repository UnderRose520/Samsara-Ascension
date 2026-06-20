extends Node

const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")
const CombatAim = preload("res://systems/combat/combat_aim.gd")
const SpellSynergy = preload("res://systems/combat/spell_synergy.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

const SLOT_ORDER: PackedStringArray = ["q", "e", "r"]
const SLOT_ACTIONS := {
	"q": "spell_q",
	"e": "spell_e",
	"r": "spell_r",
}
const SLOT_LABELS := {
	"q": "Q",
	"e": "E",
	"r": "R",
}
const SPELL_COLORS := {
	"lie_yan_bolt": Color(1.0, 0.45, 0.15),
	"yu_jian_thrust": Color(0.72, 0.9, 1.0),
	"qi_fu": Color(0.44, 0.85, 0.48),
	"summon_soul": Color(0.66, 0.42, 1.0),
	"lei_chi_strike": Color(0.75, 0.88, 1.0),
	"lei_chi_chain": Color(0.55, 0.75, 1.0),
	"xuan_bing_fan": Color(0.45, 0.9, 1.0),
	"xuan_bing_lance": Color(0.35, 0.95, 1.0),
	"hui_chun_jue": Color(0.45, 1.0, 0.55),
}

signal spell_cast(slot: String, spell: Dictionary)
signal cooldown_changed(slot: String, remaining: float, total: float)
signal spell_state_changed

var spell_by_slot: Dictionary = {}
var _unlocked_slots: Dictionary = {}
var _cooldowns: Dictionary = {}
var _windup := 0.0
var _casting_slot := ""
var _pending_dir := Vector2.RIGHT
var _owner: CharacterBody2D
var _last_synergy_ms: Dictionary = {}


func _ready() -> void:
	_owner = get_parent() as CharacterBody2D
	for slot in SLOT_ORDER:
		_cooldowns[slot] = 0.0
	sync_spell_state()
	EventBus.spell_unlock_changed.connect(func(_slots): sync_spell_state())
	if _owner and _owner.has_node("AffixHolder"):
		_owner.get_node("AffixHolder").changed.connect(sync_spell_state)


func sync_spell_state() -> void:
	_unlocked_slots = SpellProgress.get_unlocks()
	spell_by_slot = SpellProgress.get_default_bindings()
	if _owner and _owner.has_node("AffixHolder"):
		for effect in _owner.get_node("AffixHolder").get_spell_effects():
			var kind: String = str(effect.get("kind", ""))
			if kind == "unlock_spell":
				_unlocked_slots[str(effect.get("slot", ""))] = true
			elif kind == "bind_spell":
				var slot: String = str(effect.get("slot", ""))
				var spell_id: String = str(effect.get("spell_id", ""))
				if not spell_id.is_empty() and not ActiveSpellRegistry.get_spell(spell_id).is_empty():
					spell_by_slot[slot] = spell_id
	spell_state_changed.emit()


func _physics_process(delta: float) -> void:
	if get_tree().paused or RunContext.ui_blocking:
		return
	for slot in SLOT_ORDER:
		if not is_slot_unlocked(slot):
			continue
		var remaining: float = float(_cooldowns.get(slot, 0.0))
		if remaining > 0.0:
			remaining = maxf(remaining - delta, 0.0)
			_cooldowns[slot] = remaining
			var spell := _spell_for_slot(slot)
			cooldown_changed.emit(slot, remaining, _effective_spell_cooldown(spell))
	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		if _windup <= 0.0:
			_fire_spell(_casting_slot, _pending_dir)
		return
	for slot in SLOT_ORDER:
		if not is_slot_unlocked(slot):
			continue
		var action: String = str(SLOT_ACTIONS.get(slot, ""))
		if action.is_empty():
			continue
		if Input.is_action_just_pressed(action):
			try_cast_slot(slot)


func is_slot_unlocked(slot: String) -> bool:
	return VariantUtils.as_bool(_unlocked_slots.get(slot, false))


func try_cast_slot(slot: String) -> bool:
	if _owner == null or _windup > 0.0:
		return false
	if not is_slot_unlocked(slot):
		return false
	if float(_cooldowns.get(slot, 0.0)) > 0.0:
		return false
	if not spell_by_slot.has(slot) or str(spell_by_slot.get(slot, "")).is_empty():
		return false
	var move_hint := Vector2.RIGHT
	if _owner.has_method("get_aim_move_hint"):
		move_hint = _owner.get_aim_move_hint()
	elif _owner:
		move_hint = _owner.velocity
	var dir := CombatAim.resolve_direction(_owner, move_hint)
	_pending_dir = dir
	_casting_slot = slot
	var spell: Dictionary = _spell_for_slot(slot)
	_windup = float(spell.get("windup", 0.2))
	spell_cast.emit(slot, spell)
	return true


func get_cooldown_remaining(slot: String = "q") -> float:
	return float(_cooldowns.get(slot, 0.0))


func is_casting() -> bool:
	return _windup > 0.0


func get_casting_slot() -> String:
	return _casting_slot


func get_casting_color() -> Color:
	if _casting_slot.is_empty():
		return Color(1.0, 0.45, 0.15)
	var spell_id: String = str(spell_by_slot.get(_casting_slot, ""))
	return SPELL_COLORS.get(spell_id, Color(1.0, 0.45, 0.15))


func get_spell_display_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for slot in SLOT_ORDER:
		var label: String = str(SLOT_LABELS.get(slot, slot.to_upper()))
		var preview_id: String = str(SpellProgress.get_default_bindings().get(slot, ""))
		var preview: Dictionary = ActiveSpellRegistry.get_spell(preview_id)
		var name_text: String = str(preview.get("name", slot))
		if not is_slot_unlocked(slot):
			lines.append("%s %s · 未解锁" % [label, name_text])
			continue
		var spell: Dictionary = _spell_for_slot(slot)
		name_text = str(spell.get("name", name_text))
		if _casting_slot == slot and _windup > 0.0:
			lines.append("%s %s · 蓄力" % [label, name_text])
			continue
		var cd: float = float(_cooldowns.get(slot, 0.0))
		if cd > 0.05:
			lines.append("%s %s · %.1fs" % [label, name_text, cd])
		else:
			lines.append("%s %s · 就绪" % [label, name_text])
	return lines


func get_spell_slots_state() -> Dictionary:
	var out := {}
	var counts := SpellSynergy.element_counts(_unlocked_spell_ids())
	for slot in SLOT_ORDER:
		var default_id: String = str(SpellProgress.get_default_bindings().get(slot, "lie_yan_bolt"))
		var preview: Dictionary = ActiveSpellRegistry.get_spell(default_id)
		var unlocked: bool = is_slot_unlocked(slot)
		var spell: Dictionary = _spell_for_slot(slot) if unlocked else preview
		var spell_id := str(spell_by_slot.get(slot, default_id))
		var cd: float = float(_cooldowns.get(slot, 0.0))
		var total: float = _effective_spell_cooldown(spell) if unlocked else 0.0
		var layer := _skill_evolution_layer() if unlocked else 1
		var branch_id := SpellSynergy.branch_for_spell(spell_id, layer)
		var element_key := SpellSynergy.element_for_spell(spell_id)
		var synergy_count := int(counts.get(element_key, 0)) if unlocked else 0
		out[slot] = {
			"name": _format_spell_state_name(str(spell.get("name", slot)), branch_id, element_key, synergy_count),
			"unlocked": unlocked,
			"cd_remaining": cd,
			"cd_total": total,
			"casting": _casting_slot == slot and _windup > 0.0,
			"element": element_key,
			"branch": branch_id,
			"synergy_count": synergy_count,
		}
	return out


func get_spell_synergy_state() -> Dictionary:
	var counts := SpellSynergy.element_counts(_unlocked_spell_ids())
	var best := SpellSynergy.strongest_element(counts)
	return {
		"counts": counts,
		"best_element": str(best.get("element", "")),
		"best_count": int(best.get("count", 0)),
		"label": SpellSynergy.synergy_label(str(best.get("element", "")), int(best.get("count", 0))),
	}


func _format_spell_state_name(base_name: String, branch_id: String, element_key: String, synergy_count: int) -> String:
	var suffixes: Array = []
	var branch_label := SpellSynergy.branch_label(branch_id)
	if not branch_label.is_empty():
		suffixes.append(branch_label)
	if synergy_count >= 3:
		suffixes.append("%s爆发" % SpellSynergy.element_display_name(element_key))
	elif synergy_count >= 2:
		suffixes.append("%s合" % SpellSynergy.element_display_name(element_key))
	if suffixes.is_empty():
		return base_name
	return "%s·%s" % [base_name, "/".join(suffixes)]


func _fire_spell(slot: String, direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var spell: Dictionary = _spell_for_slot(slot)
	var spell_id: String = str(spell_by_slot.get(slot, ""))
	var color: Color = SPELL_COLORS.get(spell_id, Color(1.0, 0.45, 0.15))
	var element_key := SpellSynergy.element_for_spell(spell_id)
	var damage: float = float(spell.get("damage", 40.0))
	var speed: float = float(spell.get("speed", 360.0))
	var radius: float = float(spell.get("radius", 7.0))
	var pierce: int = int(spell.get("pierce", 0))
	var extra: String = str(spell.get("extra", ""))
	var evolution_layer := _skill_evolution_layer()
	var evolution_branch := SpellSynergy.branch_for_spell(spell_id, evolution_layer)
	var evolution := _spell_evolution(spell_id, evolution_layer, evolution_branch)
	var synergy := _spell_synergy_for_cast(element_key)
	damage *= float(evolution.get("damage_mult", 1.0))
	speed *= float(evolution.get("speed_mult", 1.0))
	radius *= float(evolution.get("radius_mult", 1.0))
	pierce += int(evolution.get("pierce_bonus", 0))
	damage *= float(synergy.get("damage_mult", 1.0))
	radius *= float(synergy.get("radius_mult", 1.0))
	if extra.begins_with("heal_pct:"):
		_cast_heal_spell(slot, spell, color, float(extra.get_slice(":", 1)))
		return
	_emit_spell_anchor(spell_id, color, direction, evolution_branch)
	var count: int = 1
	var spread: float = 0.0
	if extra.begins_with("count:"):
		count = maxi(int(extra.get_slice(":", 1)), 1)
		spread = 0.22 if count > 1 else 0.0
	count += int(evolution.get("count_bonus", 0))
	count += int(synergy.get("count_bonus", 0))
	if count > 1:
		spread = maxf(spread, float(evolution.get("spread", 0.18)))
	_emit_synergy_anchor(synergy, color, direction)
	for i in count:
		var dir: Vector2 = direction
		if count > 1:
			dir = direction.rotated(spread * (float(i) - float(count - 1) * 0.5))
		EventBus.spawn_player_projectile_requested.emit({
			"scene_root": _owner.get_tree().current_scene,
			"position": _owner.global_position + dir * 18.0,
			"direction": dir,
			"damage": damage,
			"owner": _owner,
			"speed": speed,
			"radius": radius,
			"color": color,
			"pierce": pierce,
			"element": element_key,
			"source_tag": "spell_%s" % spell_id,
			"evolution_layer": evolution_layer,
			"evolution_branch": evolution_branch,
			"synergy_rank": int(synergy.get("rank", 0)),
		})
	VfxManager.spawn_world(_owner.global_position, "cast", color)
	var cooldown: float = _effective_spell_cooldown(spell)
	_cooldowns[slot] = cooldown
	cooldown_changed.emit(slot, cooldown, cooldown)
	spell_cast.emit(slot, spell)
	_casting_slot = ""


func _skill_evolution_layer() -> int:
	if _owner and _owner.has_node("SkillProgression"):
		var progression: Node = _owner.get_node("SkillProgression")
		if progression.has_method("get_highest_unlocked_layer"):
			return int(progression.get_highest_unlocked_layer())
	return 1


func _spell_evolution(spell_id: String, layer: int, branch_id: String = "base") -> Dictionary:
	var out := {
		"damage_mult": 1.0,
		"speed_mult": 1.0,
		"radius_mult": 1.0,
		"pierce_bonus": 0,
		"count_bonus": 0,
		"spread": 0.18,
	}
	if layer <= 1:
		return out
	match branch_id:
		"fire_burst":
			out["radius_mult"] = 1.28
			out["damage_mult"] = 1.08
		"fire_chain":
			out["radius_mult"] = 1.45
			out["damage_mult"] = 1.16
			out["count_bonus"] = 1
		"sword_pierce":
			out["pierce_bonus"] = 1
			out["speed_mult"] = 1.10
			out["damage_mult"] = 1.06
		"sword_array":
			out["pierce_bonus"] = 2
			out["speed_mult"] = 1.14
			out["damage_mult"] = 1.12
			out["count_bonus"] = 1
			out["spread"] = 0.10
		"thunder_chain":
			out["count_bonus"] = 1
			out["spread"] = 0.14
		"thunder_net":
			out["count_bonus"] = 2
			out["pierce_bonus"] = 1
			out["spread"] = 0.16
		"ice_spread":
			out["radius_mult"] = 1.24
			out["damage_mult"] = 1.04
		"ice_domain":
			out["radius_mult"] = 1.45
			out["damage_mult"] = 1.10
			out["count_bonus"] = 1
			out["spread"] = 0.24
		"talisman_pair":
			out["count_bonus"] = 1
		"talisman_array":
			out["count_bonus"] = 2
			out["radius_mult"] = 1.14
	return out


func _emit_spell_anchor(spell_id: String, color: Color, direction: Vector2, branch_id: String = "base") -> void:
	var anchor_id := "spell_fire"
	if spell_id == "yu_jian_thrust":
		anchor_id = "spell_sword"
	elif spell_id == "qi_fu":
		anchor_id = "spell_talisman"
	elif spell_id.begins_with("lei_"):
		anchor_id = "spell_thunder"
	elif spell_id.begins_with("xuan_bing"):
		anchor_id = "spell_ice"
	elif spell_id == "summon_soul":
		anchor_id = "spell_talisman"
	var cast_pos := _owner.global_position + direction.normalized() * 22.0
	var branch_label := SpellSynergy.branch_label(branch_id)
	EventBus.feedback_anchor_requested.emit(anchor_id, {
		"world_position": cast_pos,
		"color": color,
		"label": branch_label,
		"duration": 0.22 if not branch_label.is_empty() else 0.0,
	})


func _spell_synergy_for_cast(element_key: String) -> Dictionary:
	var counts := SpellSynergy.element_counts(_unlocked_spell_ids())
	var rank := int(counts.get(element_key, 0))
	var out := {
		"rank": rank,
		"element": element_key,
		"damage_mult": 1.0,
		"radius_mult": 1.0,
		"count_bonus": 0,
	}
	if rank >= 3:
		out["damage_mult"] = 1.24
		out["radius_mult"] = 1.32
		out["count_bonus"] = 1
	elif rank >= 2:
		out["damage_mult"] = 1.12
		out["radius_mult"] = 1.16
	return out


func _unlocked_spell_ids() -> Array:
	var ids: Array = []
	for slot in SLOT_ORDER:
		if not is_slot_unlocked(slot):
			continue
		var spell_id := str(spell_by_slot.get(slot, ""))
		if not spell_id.is_empty():
			ids.append(spell_id)
	return ids


func _emit_synergy_anchor(synergy: Dictionary, fallback_color: Color, direction: Vector2) -> void:
	var rank := int(synergy.get("rank", 0))
	if rank < 2:
		return
	var element_key := str(synergy.get("element", ""))
	var now := Time.get_ticks_msec()
	var cooldown := 2400 if rank >= 3 else 1600
	if now - int(_last_synergy_ms.get(element_key, 0)) < cooldown:
		return
	_last_synergy_ms[element_key] = now
	var color := SpellSynergy.color_for_element(element_key)
	if element_key.is_empty():
		color = fallback_color
	var label := SpellSynergy.synergy_label(element_key, rank)
	var cast_pos := _owner.global_position + direction.normalized() * 30.0
	EventBus.feedback_anchor_requested.emit("spell_element_burst" if rank >= 3 else "spell_fusion", {
		"world_position": cast_pos,
		"color": color,
		"label": label,
	})


func _cast_heal_spell(slot: String, spell: Dictionary, color: Color, heal_pct: float) -> void:
	if _owner and _owner.has_node("HealthComponent"):
		var health: Node = _owner.get_node("HealthComponent")
		if health.has_method("heal"):
			var amount: float = float(health.max_hp) * heal_pct
			var healed: float = health.heal(amount)
			if healed > 0.0:
				VfxManager.spawn_world(_owner.global_position, "heal", color)
				EventBus.learn_feedback.emit("回春续命 · +%d" % int(round(healed)), "skill")
	var cooldown: float = _effective_spell_cooldown(spell)
	_cooldowns[slot] = cooldown
	cooldown_changed.emit(slot, cooldown, cooldown)
	spell_cast.emit(slot, spell)
	_casting_slot = ""


func _spell_for_slot(slot: String) -> Dictionary:
	var spell_id: String = str(spell_by_slot.get(slot, SpellProgress.get_default_bindings().get(slot, "lie_yan_bolt")))
	return ActiveSpellRegistry.get_spell(spell_id)


func _effective_spell_cooldown(spell: Dictionary) -> float:
	return float(spell.get("cooldown", 3.5)) * RunContext.get_spell_cooldown_mult()


func _spell_element_key(spell_id: String) -> String:
	return SpellSynergy.element_for_spell(spell_id)
