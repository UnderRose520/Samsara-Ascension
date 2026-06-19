extends Node

const ActiveSpellRegistry = preload("res://systems/combat/active_spell_registry.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

const DEFAULT_SPELL_BINDINGS := {
	"q": "lie_yan_bolt",
	"e": "lei_chi_strike",
	"r": "xuan_bing_fan",
}

var slots_unlocked := {"q": true, "e": false, "r": false}


func reset() -> void:
	slots_unlocked = {"q": true, "e": false, "r": false}


func get_default_bindings() -> Dictionary:
	var bindings := DEFAULT_SPELL_BINDINGS.duplicate()
	if is_instance_valid(RunContext):
		var weapon := RunContext.get_weapon()
		var start_q := str(weapon.get("start_q", ""))
		if not start_q.is_empty() and not ActiveSpellRegistry.get_spell(start_q).is_empty():
			bindings["q"] = start_q
	return bindings


func get_unlocks() -> Dictionary:
	return slots_unlocked.duplicate()


func get_slot_preview_states() -> Dictionary:
	var out := {}
	var bindings := get_default_bindings()
	for slot in ["q", "e", "r"]:
		var spell_id := str(bindings.get(slot, ""))
		var spell := ActiveSpellRegistry.get_spell(spell_id)
		var unlocked := VariantUtils.as_bool(slots_unlocked.get(slot, false))
		out[slot] = {
			"name": str(spell.get("name", slot.to_upper())),
			"unlocked": unlocked,
			"cd_remaining": 0.0,
			"cd_total": 0.0,
			"casting": false,
		}
	return out


func unlock_slot(slot: String) -> bool:
	if slot.is_empty() or VariantUtils.as_bool(slots_unlocked.get(slot, false)):
		return false
	slots_unlocked[slot] = true
	return true


func grant_for_realm(realm_level: int, affix_slot_cap: int) -> void:
	var newly: Array = []
	match realm_level:
		1:
			if unlock_slot("e"):
				newly.append("e")
				_emit_learn_feedback("e", "breakthrough", affix_slot_cap)
		2:
			if unlock_slot("r"):
				newly.append("r")
				_emit_learn_feedback("r", "breakthrough", affix_slot_cap)
	if not newly.is_empty():
		EventBus.spell_unlock_changed.emit(newly)


func _emit_learn_feedback(slot: String, source: String, affix_slot_cap: int) -> void:
	var spell_id := str(get_default_bindings().get(slot, ""))
	var spell := ActiveSpellRegistry.get_spell(spell_id)
	var spell_name := str(spell.get("name", slot.to_upper()))
	var slot_label := slot.to_upper()
	var text := "习得法术 · %s %s" % [slot_label, spell_name]
	if source == "breakthrough":
		text = "突破习得 · %s %s · 词条槽 %d" % [slot_label, spell_name, affix_slot_cap]
	EventBus.learn_feedback.emit(text, "spell")
