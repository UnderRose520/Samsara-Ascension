extends Control
class_name HudCombatRail

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

const ACTION_LIFETIME := 2.0
const MAX_ACTIONS := 3
const COMBO_NUMBER_FONT_SIZE := 36
const ACTION_FEED_FONT_SIZE := 12

var combo_count := 0
var combo_stage := "静息"
var _actions: Array[Dictionary] = []
var _rail_texture: Texture2D
var _tick_texture: Texture2D
var _action_texture: Texture2D
var _rail_texture_hits := 0
var _tick_texture_hits := 0
var _action_texture_hits := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(144, 310)
	_rail_texture = AssetPaths.load_texture(AssetPaths.COMBO_TRACK)
	_tick_texture = AssetPaths.load_texture(AssetPaths.spell_shortcut_badge())
	_action_texture = AssetPaths.load_texture(AssetPaths.spell_cooldown_sweep())
	set_process(true)


func set_combo(count: int) -> void:
	combo_count = maxi(count, 0)
	combo_stage = _stage_for_combo(combo_count)
	queue_redraw()


func push_action(text: String, accent: Color = UiTokens.ACCENT_JADE) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	_actions.push_front({
		"text": text,
		"accent": accent,
		"time": ACTION_LIFETIME,
	})
	while _actions.size() > MAX_ACTIONS:
		_actions.pop_back()
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	for action in _actions:
		action["time"] = float(action.get("time", 0.0)) - delta
		changed = true
	_actions = _actions.filter(func(action): return float(action.get("time", 0.0)) > 0.0)
	if changed:
		queue_redraw()


func _draw() -> void:
	_rail_texture_hits = 0
	_tick_texture_hits = 0
	_action_texture_hits = 0
	var font := get_theme_default_font()
	var rail_x := size.x - 30.0
	var rail_top := 30.0
	var rail_bottom := size.y - 26.0
	_draw_vertical_rail(rail_x, rail_top, rail_bottom)
	for i in range(6):
		var y := rail_top + float(i) * ((rail_bottom - rail_top) / 5.0)
		var active := combo_count > i * 20
		var col := UiTokens.ACCENT_GOLD if active else UiTokens.TEXT_MUTED
		_draw_rail_tick(Vector2(rail_x, y), col, active)
	if combo_count > 0:
		_draw_right_text(font, "连击", Vector2(rail_x - 24.0, 42.0), Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.82), 18)
		_draw_right_text(font, str(combo_count), Vector2(rail_x - 24.0, 82.0), Color(1.0, 0.84, 0.34, 0.84), COMBO_NUMBER_FONT_SIZE)
		_draw_right_text(font, combo_stage, Vector2(rail_x - 24.0, 136.0), Color(UiTokens.ELEM_THUNDER.r, UiTokens.ELEM_THUNDER.g, UiTokens.ELEM_THUNDER.b, 0.78), 21)
	else:
		_draw_right_text(font, "连击", Vector2(rail_x - 24.0, 78.0), Color(UiTokens.TEXT_MUTED.r, UiTokens.TEXT_MUTED.g, UiTokens.TEXT_MUTED.b, 0.52), 16)
	var action_y := 194.0
	var action_index := 0
	for action in _actions:
		var t := clampf(float(action.get("time", 0.0)) / ACTION_LIFETIME, 0.0, 1.0)
		var alpha := minf(1.0, t * 1.6) * (1.0 if action_index < 2 else 0.45)
		var col: Color = action.get("accent", UiTokens.ACCENT_JADE)
		var label := str(action.get("text", ""))
		var y := action_y
		_draw_action_mark(Vector2(rail_x - 18.0, y + 8.0), col, alpha)
		_draw_right_text(font, label, Vector2(rail_x - 38.0, y), Color(col.r, col.g, col.b, alpha * 0.72), ACTION_FEED_FONT_SIZE)
		action_y += 28.0
		action_index += 1


func _draw_vertical_rail(rail_x: float, rail_top: float, rail_bottom: float) -> void:
	if _rail_texture == null:
		return
	var length := rail_bottom - rail_top
	draw_set_transform(Vector2(rail_x, rail_top), PI * 0.5, Vector2.ONE)
	draw_texture_rect(_rail_texture, Rect2(Vector2.ZERO, Vector2(length, 6.0)), false, Color(0.92, 0.96, 0.82, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_rail_texture_hits += 1


func _draw_rail_tick(center: Vector2, color: Color, active: bool) -> void:
	if _tick_texture == null:
		return
	var alpha := 0.62 if active else 0.26
	var tint := Color(0.92 + color.r * 0.08, 0.94 + color.g * 0.06, 0.88 + color.b * 0.06, alpha)
	draw_texture_rect(_tick_texture, Rect2(center - Vector2(7, 7), Vector2(14, 14)), false, tint)
	_tick_texture_hits += 1


func _draw_action_mark(center: Vector2, color: Color, alpha: float) -> void:
	if _action_texture == null:
		return
	var tint := Color(0.94 + color.r * 0.10, 0.94 + color.g * 0.07, 0.88 + color.b * 0.06, 0.40 * alpha)
	draw_texture_rect(_action_texture, Rect2(center - Vector2(7, 7), Vector2(14, 14)), false, tint)
	_action_texture_hits += 1


func _draw_right_text(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, pos - Vector2(width, 0.0) + Vector2(1.0, 1.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, color.a * 0.78))
	draw_string(font, pos - Vector2(width, 0.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _stage_for_combo(count: int) -> String:
	if count >= 200:
		return "无双"
	if count >= 100:
		return "天人"
	if count >= 60:
		return "游龙"
	if count >= 30:
		return "破竹"
	if count >= 10:
		return "入势"
	return "起手"


func get_rail_texture_hit_count() -> int:
	return _rail_texture_hits


func get_tick_texture_hit_count() -> int:
	return _tick_texture_hits


func get_action_texture_hit_count() -> int:
	return _action_texture_hits


func get_combo_number_font_size() -> int:
	return COMBO_NUMBER_FONT_SIZE


func get_action_font_size() -> int:
	return ACTION_FEED_FONT_SIZE
