extends Control
class_name HudCompanionArtifactPanel

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

var _pet_texture: Texture2D
var _artifact_texture: Texture2D
var _pet_name := "待结缘"
var _pet_detail := "灵宠未结缘"
var _pet_ready := false
var _artifact_name := "玄玉葫"
var _artifact_charge := 0.0
var _artifact_state := "沉寂"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(220, 170)
	_pet_texture = AssetPaths.load_texture(AssetPaths.HUD_PET_HUO_YING_AVATAR)
	_artifact_texture = AssetPaths.load_texture(AssetPaths.HUD_ARTIFACT_XUANYU_GOURD)
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
	var pos := Vector2(24, 108)
	var rect := Rect2(pos, Vector2(52, 52))
	if _pet_ready:
		draw_circle(rect.get_center(), 35.0, Color(UiTokens.ELEM_FIRE.r, UiTokens.ELEM_FIRE.g, UiTokens.ELEM_FIRE.b, 0.14))
	if _pet_texture:
		draw_texture_rect(_pet_texture, rect, false)
	else:
		draw_circle(rect.get_center(), 24.0, UiTokens.ELEM_FIRE)
	_draw_centered(font, _pet_name, rect.get_center() + Vector2(0, 47), UiTokens.ELEM_FIRE, 12)
	_draw_centered(font, "自动协同", rect.get_center() + Vector2(0, 63), UiTokens.TEXT_SECONDARY, 10)


func _draw_artifact(font: Font) -> void:
	var pos := Vector2(18, 12)
	var rect := Rect2(pos, Vector2(56, 56))
	var center := rect.get_center()
	var awake := _artifact_charge >= 0.72
	var full := _artifact_charge >= 0.995
	var halo_color := UiTokens.ACCENT_GOLD if full else UiTokens.ELEM_CHAOS if awake else UiTokens.TEXT_MUTED
	draw_circle(center, 40.0, Color(halo_color.r, halo_color.g, halo_color.b, 0.08 if not awake else 0.16))
	if _artifact_texture:
		draw_texture_rect(_artifact_texture, rect, false)
	else:
		draw_circle(center, 25.0, UiTokens.ELEM_CHAOS)
	if awake:
		draw_arc(center, 35.0, 0.0, TAU, 48, Color(halo_color.r, halo_color.g, halo_color.b, 0.82), 2.0)
	if full:
		draw_arc(center, 40.0, 0.0, TAU, 48, Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.56), 1.0)
	_draw_text(font, _artifact_name, Vector2(86, 18), UiTokens.ACCENT_GOLD, 14)
	_draw_text(font, _artifact_state, Vector2(86, 42), UiTokens.ACCENT_GOLD if full else UiTokens.ELEM_CHAOS if awake else UiTokens.TEXT_SECONDARY, 13)
	_draw_text(font, "随道势唤醒", Vector2(86, 62), UiTokens.TEXT_SECONDARY, 10)


func _draw_text(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	draw_string(font, pos + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_draw_text(font, value, pos - Vector2(width * 0.5, 0), color, font_size)
