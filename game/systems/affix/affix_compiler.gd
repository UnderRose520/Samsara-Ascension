class_name AffixCompiler

const QUALITY_MAP := {
	"common": 0,
	"rare": 1,
	"epic": 2,
	"legendary": 3,
	"dao": 4,
}

const CATEGORY_MAP := {
	"skill": 0,
	"spell": 1,
	"constitution": 2,
	"divine": 3,
	"synergy": 4,
	"companion": 5,
}

const ELEMENT_MAP := {
	"none": 0,
	"fire": 1,
	"water": 2,
	"thunder": 3,
	"wood": 4,
	"earth": 5,
	"chaos": 6,
}


static func compile_row(row: Dictionary):
	var CompiledTagClass = preload("res://core/structs/compiled_tag.gd")
	var tag = CompiledTagClass.new()
	tag.id = str(row.get("id", ""))
	tag.name = str(row.get("name", tag.id))
	tag.category = CATEGORY_MAP.get(str(row.get("category", "spell")).to_lower(), 1)
	tag.element = ELEMENT_MAP.get(str(row.get("element", "none")).to_lower(), 0)
	tag.quality = QUALITY_MAP.get(str(row.get("quality", "common")).to_lower(), 0)
	tag.dao_bucket = int(row.get("dao_bucket", 0))
	tag.description = str(row.get("description", ""))
	var combo_raw := str(row.get("combo_tags", ""))
	if not combo_raw.is_empty():
		tag.combo_tags = PackedStringArray(combo_raw.split("|", false))

	for effect_key in ["effect1", "effect2", "effect3"]:
		var dsl := str(row.get(effect_key, "")).strip_edges()
		if dsl.is_empty():
			continue
		_apply_effect_dsl(tag, dsl)
	return tag


static func _apply_effect_dsl(tag, dsl: String) -> void:
	var parts := dsl.split(":")
	var kind := parts[0]
	match kind:
		"flat_attack", "flat_defense", "flat_max_hp", "mult_attack", "mult_crit_rate", "mult_crit_mult", "mult_attack_speed", "projectile_pierce", "dao_mult":
			tag.passives.append({"kind": kind, "value": float(parts[1]) if parts.size() > 1 else 0.0})
		"on_hit_status":
			if parts.size() >= 4:
				tag.on_hit.append({
					"kind": "on_hit_status",
					"status": parts[1],
					"duration": float(parts[2]),
					"chance": float(parts[3]),
				})
		"unlock_spell":
			if parts.size() >= 2:
				tag.passives.append({"kind": "unlock_spell", "slot": str(parts[1]).to_lower()})
		"bind_spell":
			if parts.size() >= 3:
				tag.passives.append({
					"kind": "bind_spell",
					"slot": str(parts[1]).to_lower(),
					"spell_id": str(parts[2]),
				})
