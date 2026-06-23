extends PanelContainer
class_name HudSkillDock

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")
const VariantUtils = preload("res://core/utils/variant_utils.gd")

@onready var dock_frame: TextureRect = $DockFrame
@onready var spell_q = %SpellQ
@onready var spell_e = %SpellE
@onready var spell_r = %SpellR
@onready var left_orbs: HudStatusOrbs = %LeftOrbs
@onready var right_orbs: HudStatusOrbs = %RightOrbs

var spell_slots: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_slots = {"q": spell_q, "e": spell_e, "r": spell_r}
	apply_polish()
	apply_spell_states(SpellProgress.get_slot_preview_states())


func apply_polish() -> void:
	add_theme_stylebox_override("panel", HudStyles.spell_dock())
	var tex := AssetPaths.load_texture(AssetPaths.HUD_SKILL_DOCK_FRAME)
	if tex and dock_frame:
		dock_frame.texture = tex
		dock_frame.modulate = Color(1, 1, 1, 0.28)
	for slot in spell_slots.values():
		if slot.has_method("set_dock"):
			slot.set_dock(true)
	call_deferred("_layout_frame")


func _layout_frame() -> void:
	if dock_frame:
		dock_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		move_child(dock_frame, 0)


func apply_spell_states(states: Dictionary) -> void:
	for slot in spell_slots.keys():
		var node = spell_slots[slot]
		if not states.has(slot) or not node.has_method("apply_state"):
			continue
		var raw_info = states[slot]
		if not (raw_info is Dictionary):
			continue
		var info: Dictionary = raw_info
		node.apply_state(
			slot,
			str(info.get("name", slot)),
			VariantUtils.as_bool(info.get("unlocked", false)),
			float(info.get("cd_remaining", 0.0)),
			float(info.get("cd_total", 0.0)),
			VariantUtils.as_bool(info.get("casting", false)),
			str(info.get("spell_id", "")),
			str(info.get("element", ""))
		)


func get_spell_slot_node(slot: String) -> Node:
	return spell_slots.get(slot.strip_edges().to_lower(), null) as Node


func pulse() -> void:
	var tw := create_tween()
	modulate = Color(1.2, 1.15, 0.9)
	tw.tween_property(self, "modulate", Color.WHITE, 1.0)


func set_auto_attack(active: bool) -> void:
	if left_orbs:
		left_orbs.set_auto_attack(active)


func set_pet_state(acquired: bool, ready: bool) -> void:
	if right_orbs:
		right_orbs.set_pet_state(acquired, ready, true)


func set_artifact_state(ready: bool, key_ready: bool) -> void:
	if right_orbs:
		right_orbs.set_artifact_state(ready, key_ready)
