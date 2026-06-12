class_name VfxLibrary
extends RefCounted

const VariantUtils = preload("res://core/utils/variant_utils.gd")

const PRESETS := {
	"hit": {"amount": 8, "lifetime": 0.35, "speed_min": 30.0, "speed_max": 90.0, "spread": 160.0, "gravity_y": 80.0, "scale_min": 1.5, "scale_max": 3.0},
	"crit": {"amount": 18, "lifetime": 0.55, "speed_min": 60.0, "speed_max": 160.0, "spread": 180.0, "gravity_y": 40.0, "scale_min": 2.0, "scale_max": 5.0},
	"combo": {"amount": 22, "lifetime": 0.6, "speed_min": 50.0, "speed_max": 140.0, "spread": 180.0, "gravity_y": -20.0, "scale_min": 2.0, "scale_max": 4.5},
	"gold": {"amount": 24, "lifetime": 0.9, "speed_min": 20.0, "speed_max": 100.0, "spread": 180.0, "gravity_y": -30.0, "scale_min": 1.0, "scale_max": 3.5},
	"cast": {"amount": 14, "lifetime": 0.45, "speed_min": 40.0, "speed_max": 110.0, "spread": 360.0, "gravity_y": 0.0, "scale_min": 1.5, "scale_max": 3.5},
	"dao": {"amount": 36, "lifetime": 1.2, "speed_min": 30.0, "speed_max": 130.0, "spread": 180.0, "gravity_y": -15.0, "scale_min": 2.0, "scale_max": 6.0},
	"heal": {"amount": 12, "lifetime": 0.7, "speed_min": 15.0, "speed_max": 70.0, "spread": 120.0, "gravity_y": -50.0, "scale_min": 1.5, "scale_max": 3.0},
}


static func create_burst(preset_name: String, color: Color) -> CPUParticles2D:
	var cfg: Dictionary = PRESETS.get(preset_name, PRESETS["hit"])
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = int(cfg.get("amount", 10))
	p.lifetime = float(cfg.get("lifetime", 0.4))
	p.emitting = false
	p.direction = Vector2(0, -1)
	p.spread = float(cfg.get("spread", 180.0))
	p.gravity = Vector2(0, float(cfg.get("gravity_y", 60.0)))
	p.initial_velocity_min = float(cfg.get("speed_min", 30.0))
	p.initial_velocity_max = float(cfg.get("speed_max", 100.0))
	p.scale_amount_min = float(cfg.get("scale_min", 1.5))
	p.scale_amount_max = float(cfg.get("scale_max", 3.5))
	p.color = color
	return p


static func color_for_damage(result: Dictionary) -> Color:
	if VariantUtils.as_bool(result.get("is_combo", false)):
		return Color(1.0, 0.42, 0.12)
	if VariantUtils.as_bool(result.get("is_crit", false)):
		return Color(1.0, 0.88, 0.25)
	if VariantUtils.as_bool(result.get("target_is_player", false)):
		return Color(0.95, 0.3, 0.3)
	return Color(0.94, 0.92, 0.88)


static func preset_for_damage(result: Dictionary) -> String:
	if VariantUtils.as_bool(result.get("is_combo", false)):
		return "combo"
	if VariantUtils.as_bool(result.get("is_crit", false)):
		return "crit"
	return "hit"
