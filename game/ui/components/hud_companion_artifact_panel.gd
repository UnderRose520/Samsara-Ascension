extends Control
class_name HudCompanionArtifactPanel

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

var _pet_texture: Texture2D
var _artifact_texture: Texture2D
var _seal_base_texture: Texture2D
var _charge_sweep_texture: Texture2D
var _pet_name := "待结缘"
var _pet_detail := "灵宠未结缘"
var _pet_ready := false
var _artifact_name := "玄玉葫"
var _artifact_charge := 0.0
var _artifact_state := "沉寂"
var _pet_texture_hits := 0
var _artifact_texture_hits := 0
var _base_texture_hits := 0
var _charge_texture_hits := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(228, 224)
	_pet_texture = AssetPaths.load_texture(AssetPaths.HUD_PET_HUO_YING_AVATAR_96)
	_artifact_texture = AssetPaths.load_texture(AssetPaths.HUD_ARTIFACT_XUANYU_GOURD_96)
	_seal_base_texture = AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_BASE)
	_charge_sweep_texture = AssetPaths.load_texture(AssetPaths.spell_cooldown_sweep())
	queue_redraw()


func set_pet(name: String, detail: String, ready: bool) -> void:
	_pet_name = name
	_pet_detail = detail
	_pet_ready = ready
	tooltip_text = "%s\n%s\n点击或 Tab 查看灵宠详情" % [_pet_name, _pet_detail]
	queue_redraw()


func set_artifact(name: String, charge_pct: float, state: String) -> void:
	_artifact_name = name
	_artifact_charge = clampf(charge_pct, 0.0, 1.0)
	_artifact_state = state
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	_draw_pet(font)
	_draw_artifact(font)


func _draw_pet(font: Font) -> void:
	var pos := Vector2(24, 122)
	var rect := Rect2(pos, Vector2(64, 64))
	_draw_icon_base(rect, UiTokens.ELEM_FIRE, 0.95 if _pet_ready else 0.72)
	if _pet_texture:
		draw_texture_rect(_pet_texture, rect, false, Color(1, 1, 1, 0.98 if _pet_ready else 0.82))
		_pet_texture_hits += 1
	if _pet_ready:
		_draw_charge_sweep(rect.grow(6.0), UiTokens.ELEM_FIRE, 0.52)
	_draw_centered(font, _pet_name, rect.get_center() + Vector2(0, 50), UiTokens.ELEM_FIRE, 11)
	_draw_centered(font, "自动协同", rect.get_center() + Vector2(0, 64), UiTokens.TEXT_SECONDARY, 9)


func _draw_artifact(font: Font) -> void:
	var pos := Vector2(18, 12)
	var rect := Rect2(pos, Vector2(64, 64))
	var center := rect.get_center()
	var awake := _artifact_charge >= 0.72
	var full := _artifact_charge >= 0.995
	var halo_color := UiTokens.ACCENT_GOLD if full else UiTokens.ELEM_CHAOS if awake else UiTokens.TEXT_MUTED
	_draw_icon_base(rect, halo_color, 0.98 if awake else 0.68)
	if _artifact_texture:
		draw_texture_rect(_artifact_texture, rect, false, Color(1, 1, 1, 0.98))
		_artifact_texture_hits += 1
	if awake or full:
		_draw_charge_sweep(rect.grow(8.0), halo_color, 0.56 if full else 0.38)
	_draw_text(font, _artifact_name, Vector2(86, 18), UiTokens.ACCENT_GOLD, 14)
	_draw_text(font, _artifact_state, Vector2(86, 42), UiTokens.ACCENT_GOLD if full else UiTokens.ELEM_CHAOS if awake else UiTokens.TEXT_SECONDARY, 13)
	_draw_text(font, "随道势唤醒", Vector2(86, 62), UiTokens.TEXT_SECONDARY, 10)


func _draw_icon_base(rect: Rect2, tint: Color, alpha: float) -> void:
	if _seal_base_texture == null:
		return
	var base_rect := rect.grow(8.0)
	draw_texture_rect(_seal_base_texture, base_rect, false, Color(1.0 + tint.r * 0.12, 1.0 + tint.g * 0.08, 1.0 + tint.b * 0.08, alpha))
	_base_texture_hits += 1


func _draw_charge_sweep(rect: Rect2, tint: Color, alpha: float) -> void:
	if _charge_sweep_texture == null:
		return
	draw_set_transform(rect.get_center(), -TAU * clampf(_artifact_charge, 0.0, 1.0) * 0.18, Vector2.ONE)
	draw_texture_rect(_charge_sweep_texture, Rect2(-rect.size * 0.5, rect.size), false, Color(1.0 + tint.r * 0.08, 1.0 + tint.g * 0.08, 1.0 + tint.b * 0.08, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_charge_texture_hits += 1


func _draw_text(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	draw_string(font, pos + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_draw_text(font, value, pos - Vector2(width * 0.5, 0), color, font_size)


func get_pet_texture_hit_count() -> int:
	return _pet_texture_hits


func get_artifact_texture_hit_count() -> int:
	return _artifact_texture_hits


func get_base_texture_hit_count() -> int:
	return _base_texture_hits


func get_charge_texture_hit_count() -> int:
	return _charge_texture_hits
