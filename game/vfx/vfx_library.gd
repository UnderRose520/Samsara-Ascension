class_name VfxLibrary
extends RefCounted

const VariantUtils = preload("res://core/utils/variant_utils.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

const PRESETS := {
	"hit": {"amount": 7, "lifetime": 0.30, "speed_min": 22.0, "speed_max": 68.0, "spread": 132.0, "gravity_y": 44.0, "scale_min": 0.06, "scale_max": 0.14},
	"crit": {"amount": 9, "lifetime": 0.40, "speed_min": 34.0, "speed_max": 96.0, "spread": 150.0, "gravity_y": 22.0, "scale_min": 0.08, "scale_max": 0.18},
	"combo": {"amount": 8, "lifetime": 0.38, "speed_min": 28.0, "speed_max": 78.0, "spread": 140.0, "gravity_y": -10.0, "scale_min": 0.06, "scale_max": 0.14},
	"gold": {"amount": 6, "lifetime": 0.50, "speed_min": 14.0, "speed_max": 46.0, "spread": 118.0, "gravity_y": -20.0, "scale_min": 0.09, "scale_max": 0.16},
	"cast": {"amount": 7, "lifetime": 0.34, "speed_min": 24.0, "speed_max": 66.0, "spread": 210.0, "gravity_y": 0.0, "scale_min": 0.06, "scale_max": 0.13},
	"dao": {"amount": 8, "lifetime": 0.48, "speed_min": 16.0, "speed_max": 56.0, "spread": 128.0, "gravity_y": -8.0, "scale_min": 0.07, "scale_max": 0.15},
	"heal": {"amount": 6, "lifetime": 0.46, "speed_min": 10.0, "speed_max": 38.0, "spread": 96.0, "gravity_y": -34.0, "scale_min": 0.06, "scale_max": 0.12},
}

const ELEMENT_VFX_COLORS := {
	"fire": Color(1.0, 0.22, 0.06),
	"thunder": Color(0.66, 0.34, 1.0),
	"lightning": Color(0.66, 0.34, 1.0),
	"water": Color(0.10, 0.62, 1.0),
	"ice": Color(0.26, 0.78, 1.0),
	"wood": Color(0.18, 0.92, 0.42),
	"earth": Color(0.88, 0.58, 0.22),
	"chaos": Color(0.72, 0.28, 1.0),
	"soul": Color(0.72, 0.28, 1.0),
	"void": Color(0.72, 0.28, 1.0),
	"neutral": Color(0.78, 0.74, 0.62),
}

const STATUS_VFX_COLORS := {
	"burn": Color(1.0, 0.22, 0.06),
	"ignite": Color(1.0, 0.22, 0.06),
	"slow": Color(0.26, 0.78, 1.0),
	"freeze": Color(0.26, 0.78, 1.0),
	"chill": Color(0.26, 0.78, 1.0),
	"wet": Color(0.10, 0.62, 1.0),
	"paralyze": Color(0.66, 0.34, 1.0),
	"shock": Color(0.66, 0.34, 1.0),
	"stun": Color(0.66, 0.34, 1.0),
	"poison": Color(0.18, 0.92, 0.42),
	"root": Color(0.18, 0.92, 0.42),
	"shield": Color(0.88, 0.58, 0.22),
	"guard": Color(0.88, 0.58, 0.22),
	"haste": Color(0.28, 0.82, 1.0),
	"dodge": Color(0.28, 0.82, 1.0),
	"boss": Color(1.0, 0.32, 0.12),
	"elite": Color(0.92, 0.58, 0.18),
	"promoted": Color(0.90, 0.66, 0.22),
	"dao": Color(0.92, 0.72, 0.22),
	"counter": Color(0.92, 0.72, 0.22),
	"mutation": Color(1.0, 0.24, 0.12),
	"windup": Color(1.0, 0.24, 0.12),
}


static func create_burst(preset_name: String, color: Color, element: String = "", status: String = "", tier: int = 1) -> CPUParticles2D:
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
	p.color = ink_vfx_color(color, preset_name, element, status, tier)
	p.texture = particle_texture(preset_name)
	return p


static func particle_texture(preset_name: String) -> Texture2D:
	if preset_name == "gold":
		return AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)
	return AssetPaths.load_texture(AssetPaths.combat_action_fx("status_badge_backing"))


static func ink_vfx_color(color: Color, preset_name: String = "", element: String = "", status: String = "", tier: int = 1) -> Color:
	var resolved := color
	var status_key := status.strip_edges().to_lower()
	if STATUS_VFX_COLORS.has(status_key):
		resolved = resolved.lerp(STATUS_VFX_COLORS[status_key], 0.68)
	else:
		var element_key := element.strip_edges().to_lower()
		if ELEMENT_VFX_COLORS.has(element_key):
			resolved = resolved.lerp(ELEMENT_VFX_COLORS[element_key], 0.58)
	return _tone_for_dark_ink(resolved, preset_name, tier)


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


static func _tone_for_dark_ink(color: Color, preset_name: String, tier: int) -> Color:
	var alpha := clampf(color.a, 0.0, 1.0)
	var r := clampf(color.r, 0.0, 1.15)
	var g := clampf(color.g, 0.0, 1.15)
	var b := clampf(color.b, 0.0, 1.15)
	var min_channel := minf(r, minf(g, b))
	var white_bleed := min_channel * 0.16
	r = maxf(0.0, r - white_bleed)
	g = maxf(0.0, g - white_bleed)
	b = maxf(0.0, b - white_bleed)

	var average := (r + g + b) / 3.0
	var saturation_boost := 1.12 + 0.04 * float(clampi(tier - 1, 0, 2))
	r = clampf(average + (r - average) * saturation_boost, 0.0, 1.0)
	g = clampf(average + (g - average) * saturation_boost, 0.0, 1.0)
	b = clampf(average + (b - average) * saturation_boost, 0.0, 1.0)

	var max_channel := maxf(r, maxf(g, b))
	var cap := _value_cap_for_preset(preset_name)
	if max_channel > cap and max_channel > 0.001:
		var scale := cap / max_channel
		r *= scale
		g *= scale
		b *= scale

	var ink_mix := 0.025 if preset_name in ["crit", "gold", "dao"] else 0.045
	r = lerpf(r, 0.035, ink_mix)
	g = lerpf(g, 0.052, ink_mix)
	b = lerpf(b, 0.052, ink_mix)
	return Color(r, g, b, alpha)


static func _value_cap_for_preset(preset_name: String) -> float:
	match preset_name:
		"crit", "gold", "dao":
			return 0.90
		"combo":
			return 0.88
		"hit":
			return 0.88
		"heal":
			return 0.90
		"cast":
			return 0.88
	return 0.86
