extends PanelContainer
class_name HudSkillDock

const AssetPaths = preload("res://assets/asset_paths.gd")
const HudStyles = preload("res://ui/hud_styles.gd")

@onready var dock_frame: TextureRect = $DockFrame
@onready var spell_q = %SpellQ
@onready var spell_e = %SpellE
@onready var spell_r = %SpellR

var spell_slots: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_slots = {"q": spell_q, "e": spell_e, "r": spell_r}
	apply_polish()


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


func pulse() -> void:
	var tw := create_tween()
	modulate = Color(1.2, 1.15, 0.9)
	tw.tween_property(self, "modulate", Color.WHITE, 1.0)
