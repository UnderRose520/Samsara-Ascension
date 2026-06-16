extends Node

const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")
const CombatAim = preload("res://systems/combat/combat_aim.gd")
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
	for slot in SLOT_ORDER:
		var default_id: String = str(SpellProgress.get_default_bindings().get(slot, "lie_yan_bolt"))
		var preview: Dictionary = ActiveSpellRegistry.get_spell(default_id)
		var unlocked: bool = is_slot_unlocked(slot)
		var spell: Dictionary = _spell_for_slot(slot) if unlocked else preview
		var cd: float = float(_cooldowns.get(slot, 0.0))
		var total: float = _effective_spell_cooldown(spell) if unlocked else 0.0
		out[slot] = {
			"name": str(spell.get("name", slot)),
			"unlocked": unlocked,
			"cd_remaining": cd,
			"cd_total": total,
			"casting": _casting_slot == slot and _windup > 0.0,
		}
	return out


func _fire_spell(slot: String, direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var spell: Dictionary = _spell_for_slot(slot)
	var spell_id: String = str(spell_by_slot.get(slot, ""))
	var color: Color = SPELL_COLORS.get(spell_id, Color(1.0, 0.45, 0.15))
	var element_key := _spell_element_key(spell_id)
	var damage: float = float(spell.get("damage", 40.0))
	var speed: float = float(spell.get("speed", 360.0))
	var radius: float = float(spell.get("radius", 7.0))
	var pierce: int = int(spell.get("pierce", 0))
	var extra: String = str(spell.get("extra", ""))
	if extra.begins_with("heal_pct:"):
		_cast_heal_spell(slot, spell, color, float(extra.get_slice(":", 1)))
		return
	var count: int = 1
	var spread: float = 0.0
	if extra.begins_with("count:"):
		count = maxi(int(extra.get_slice(":", 1)), 1)
		spread = 0.22 if count > 1 else 0.0
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
		})
	VfxManager.spawn_world(_owner.global_position, "cast", color)
	var cooldown: float = _effective_spell_cooldown(spell)
	_cooldowns[slot] = cooldown
	cooldown_changed.emit(slot, cooldown, cooldown)
	spell_cast.emit(slot, spell)
	_casting_slot = ""


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
	if spell_id == "yu_jian_thrust":
		return "earth"
	if spell_id == "qi_fu":
		return "wood"
	if spell_id == "summon_soul":
		return "soul"
	if spell_id.begins_with("lei_"):
		return "thunder"
	if spell_id.begins_with("xuan_bing"):
		return "water"
	if spell_id == "hui_chun_jue":
		return "wood"
	if spell_id.begins_with("lie_yan"):
		return "fire"
	return "fire"
