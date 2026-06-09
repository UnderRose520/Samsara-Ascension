extends Node

const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/projectile.tscn")

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
	"lei_chi_strike": Color(0.75, 0.88, 1.0),
	"lei_chi_chain": Color(0.55, 0.75, 1.0),
	"xuan_bing_fan": Color(0.45, 0.9, 1.0),
	"xuan_bing_lance": Color(0.35, 0.95, 1.0),
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
	_unlocked_slots = RunContext.get_spell_unlocks()
	spell_by_slot = RunContext.get_default_spell_bindings()
	if _owner and _owner.has_node("AffixHolder"):
		for effect in _owner.get_node("AffixHolder").get_spell_effects():
			var kind := str(effect.get("kind", ""))
			if kind == "unlock_spell":
				_unlocked_slots[str(effect.get("slot", ""))] = true
			elif kind == "bind_spell":
				var slot := str(effect.get("slot", ""))
				var spell_id := str(effect.get("spell_id", ""))
				if not spell_id.is_empty() and not ActiveSpellRegistry.get_spell(spell_id).is_empty():
					spell_by_slot[slot] = spell_id
	spell_state_changed.emit()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	for slot in SLOT_ORDER:
		if not is_slot_unlocked(slot):
			continue
		var remaining: float = float(_cooldowns.get(slot, 0.0))
		if remaining > 0.0:
			remaining = maxf(remaining - delta, 0.0)
			_cooldowns[slot] = remaining
			var spell := _spell_for_slot(slot)
			cooldown_changed.emit(slot, remaining, float(spell.get("cooldown", 3.5)))
	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		if _windup <= 0.0:
			_fire_spell(_casting_slot, _pending_dir)
		return
	for slot in SLOT_ORDER:
		if not is_slot_unlocked(slot):
			continue
		var action := str(SLOT_ACTIONS.get(slot, ""))
		if action.is_empty():
			continue
		if Input.is_action_just_pressed(action):
			try_cast_slot(slot)


func is_slot_unlocked(slot: String) -> bool:
	return bool(_unlocked_slots.get(slot, false))


func try_cast_slot(slot: String) -> bool:
	if _owner == null or _windup > 0.0:
		return false
	if not is_slot_unlocked(slot):
		return false
	if float(_cooldowns.get(slot, 0.0)) > 0.0:
		return false
	if not spell_by_slot.has(slot) or str(spell_by_slot.get(slot, "")).is_empty():
		return false
	var dir := (_owner.get_global_mouse_position() - _owner.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_pending_dir = dir
	_casting_slot = slot
	var spell := _spell_for_slot(slot)
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
	var spell_id := str(spell_by_slot.get(_casting_slot, ""))
	return SPELL_COLORS.get(spell_id, Color(1.0, 0.45, 0.15))


func get_spell_display_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for slot in SLOT_ORDER:
		var label := str(SLOT_LABELS.get(slot, slot.to_upper()))
		var preview_id := str(RunContext.get_default_spell_bindings().get(slot, ""))
		var preview := ActiveSpellRegistry.get_spell(preview_id)
		var name_text := str(preview.get("name", slot))
		if not is_slot_unlocked(slot):
			lines.append("%s %s · 未解锁" % [label, name_text])
			continue
		var spell := _spell_for_slot(slot)
		name_text = str(spell.get("name", name_text))
		if _casting_slot == slot and _windup > 0.0:
			lines.append("%s %s · 蓄力" % [label, name_text])
			continue
		var cd := float(_cooldowns.get(slot, 0.0))
		if cd > 0.05:
			lines.append("%s %s · %.1fs" % [label, name_text, cd])
		else:
			lines.append("%s %s · 就绪" % [label, name_text])
	return lines


func _fire_spell(slot: String, direction: Vector2) -> void:
	var spell := _spell_for_slot(slot)
	var spell_id := str(spell_by_slot.get(slot, ""))
	var color: Color = SPELL_COLORS.get(spell_id, Color(1.0, 0.45, 0.15))
	var damage := float(spell.get("damage", 40.0))
	var speed := float(spell.get("speed", 360.0))
	var radius := float(spell.get("radius", 7.0))
	var pierce := int(spell.get("pierce", 0))
	var extra := str(spell.get("extra", ""))
	var count := 1
	var spread := 0.0
	if extra.begins_with("count:"):
		count = maxi(int(extra.get_slice(":", 1)), 1)
		spread = 0.22 if count > 1 else 0.0
	for i in count:
		var dir := direction
		if count > 1:
			dir = direction.rotated(spread * (float(i) - float(count - 1) * 0.5))
		var projectile: Area2D = PROJECTILE_SCENE.instantiate()
		projectile.global_position = _owner.global_position + dir * 18.0
		projectile.setup(dir, damage, _owner, speed, radius, color, pierce)
		_owner.get_tree().current_scene.add_child(projectile)
	_cooldowns[slot] = float(spell.get("cooldown", 3.5))
	cooldown_changed.emit(slot, float(_cooldowns[slot]), float(_cooldowns[slot]))
	spell_cast.emit(slot, spell)
	_casting_slot = ""


func _spell_for_slot(slot: String) -> Dictionary:
	var spell_id := str(spell_by_slot.get(slot, RunContext.get_default_spell_bindings().get(slot, "lie_yan_bolt")))
	return ActiveSpellRegistry.get_spell(spell_id)
