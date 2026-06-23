extends Control
class_name HudStatusOrbs

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

class SealState:
	var glyph := ""
	var label := ""
	var accent := Color.WHITE
	var mode := "on"
	var keycap := ""


@export_enum("all", "left", "right") var seal_set := "all"

var _seal_textures: Dictionary = {}
var _base_texture: Texture2D
var _key_badge_texture: Texture2D
var _states: Array[SealState] = []
var _seal_texture_hits := 0
var _base_texture_hits := 0
var _key_badge_texture_hits := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(178, 52) if seal_set == "all" else Vector2(86, 52)
	_base_texture = AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_BASE)
	_key_badge_texture = AssetPaths.load_texture(AssetPaths.spell_shortcut_badge())
	_seal_textures = {
		"攻": AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_ATTACK),
		"护": AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_GUARD),
		"宠": AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_PET),
		"器": AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_ARTIFACT),
	}
	_set_defaults()


func _set_defaults() -> void:
	_states.clear()
	if seal_set == "left" or seal_set == "all":
		_states.append(_make_state("攻", "普攻", UiTokens.TEXT_SECONDARY, "on", ""))
		_states.append(_make_state("护", "护体", UiTokens.ACCENT_JADE, "pulse", ""))
	if seal_set == "right" or seal_set == "all":
		_states.append(_make_state("宠", "协同", UiTokens.ELEM_FIRE, "on", ""))
		_states.append(_make_state("器", "器灵", UiTokens.ELEM_CHAOS, "on", ""))
	queue_redraw()


func set_auto_attack(active: bool) -> void:
	if seal_set == "right":
		return
	if _states.is_empty():
		return
	_states[0].mode = "on" if active else "off"
	queue_redraw()


func set_pet_state(acquired: bool, ready: bool, manual_key: bool = true) -> void:
	if seal_set == "left":
		return
	if _states.is_empty():
		return
	var idx := 0 if seal_set == "right" else 2
	if idx >= _states.size():
		return
	_states[idx].mode = "ready" if acquired and ready else "on" if acquired else "off"
	_states[idx].keycap = "V" if acquired and ready and manual_key else ""
	queue_redraw()


func set_artifact_state(ready: bool, key_ready: bool) -> void:
	if seal_set == "left":
		return
	if _states.is_empty():
		return
	var idx := 1 if seal_set == "right" else 3
	if idx >= _states.size():
		return
	_states[idx].mode = "ready" if ready else "on"
	_states[idx].keycap = "F" if key_ready else ""
	queue_redraw()


func _make_state(glyph: String, label: String, accent: Color, mode: String, keycap: String) -> SealState:
	var state := SealState.new()
	state.glyph = glyph
	state.label = label
	state.accent = accent
	state.mode = mode
	state.keycap = keycap
	return state


func _draw() -> void:
	var font := get_theme_default_font()
	for i in range(_states.size()):
		var state := _states[i]
		var center := Vector2(22.0 + i * 44.0, 21.0)
		var alpha := 0.4 if state.mode == "off" else 1.0
		var accent := Color(state.accent.r, state.accent.g, state.accent.b, alpha)
		var base_color := Color(1, 1, 1, 0.64 * alpha)
		if state.mode == "ready":
			base_color = Color(1.16, 1.12, 0.92, 0.9 * alpha)
		elif state.mode == "pulse":
			base_color = Color(0.82, 1.08, 1.0, 0.78 * alpha)
		if _base_texture:
			draw_texture_rect(_base_texture, Rect2(center - Vector2(24, 24), Vector2(48, 48)), false, base_color)
			_base_texture_hits += 1
		var tex: Texture2D = _seal_textures.get(state.glyph, null)
		if tex:
			draw_texture_rect(tex, Rect2(center - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, 0.76 * alpha))
			_seal_texture_hits += 1
		_draw_centered(font, state.glyph, center + Vector2(0, 5), accent, 14)
		_draw_centered(font, state.label, center + Vector2(0, 35), Color(UiTokens.TEXT_SECONDARY.r, UiTokens.TEXT_SECONDARY.g, UiTokens.TEXT_SECONDARY.b, 0.9 * alpha), 10)
		if not state.keycap.is_empty():
			var key_rect := Rect2(center + Vector2(11, -26), Vector2(24, 20))
			if _key_badge_texture:
				draw_texture_rect(_key_badge_texture, Rect2(key_rect.position - Vector2(4, 6), Vector2(32, 32)), false, Color(1, 1, 1, alpha))
				_key_badge_texture_hits += 1
			_draw_centered(font, state.keycap, key_rect.get_center() + Vector2(0, 4), accent, 11)


func _draw_centered(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, pos - Vector2(width * 0.5, 0) + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func get_seal_texture_hit_count() -> int:
	return _seal_texture_hits


func get_base_texture_hit_count() -> int:
	return _base_texture_hits


func get_key_badge_texture_hit_count() -> int:
	return _key_badge_texture_hits
