extends Control
class_name HudCombatRail

const UiTokens = preload("res://ui/theme/ui_tokens.gd")

const ACTION_LIFETIME := 2.0
const MAX_ACTIONS := 3

var combo_count := 0
var combo_stage := "静息"
var _actions: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 360)
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
	var font := get_theme_default_font()
	var rail_x := size.x - 24.0
	var rail_top := 18.0
	var rail_bottom := size.y - 20.0
	draw_line(Vector2(rail_x, rail_top), Vector2(rail_x, rail_bottom), Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.46), 2.0)
	for i in range(6):
		var y := rail_top + float(i) * ((rail_bottom - rail_top) / 5.0)
		var active := combo_count > i * 20
		var col := UiTokens.ACCENT_GOLD if active else UiTokens.TEXT_MUTED
		draw_circle(Vector2(rail_x, y), 6.0, Color(0.02, 0.04, 0.04, 0.86))
		draw_arc(Vector2(rail_x, y), 6.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.85 if active else 0.42), 1.5)
	if combo_count > 0:
		_draw_right_text(font, "连击", Vector2(rail_x - 22.0, 28.0), UiTokens.ACCENT_GOLD, 22)
		_draw_right_text(font, str(combo_count), Vector2(rail_x - 22.0, 78.0), Color(1.0, 0.86, 0.34), 64)
		_draw_right_text(font, combo_stage, Vector2(rail_x - 22.0, 146.0), UiTokens.ELEM_THUNDER, 27)
	else:
		_draw_right_text(font, "连击", Vector2(rail_x - 22.0, 66.0), Color(UiTokens.TEXT_MUTED.r, UiTokens.TEXT_MUTED.g, UiTokens.TEXT_MUTED.b, 0.65), 18)
	var action_y := 202.0
	for action in _actions:
		var t := clampf(float(action.get("time", 0.0)) / ACTION_LIFETIME, 0.0, 1.0)
		var alpha := minf(1.0, t * 1.6)
		var col: Color = action.get("accent", UiTokens.ACCENT_JADE)
		var label := str(action.get("text", ""))
		var y := action_y
		draw_circle(Vector2(rail_x - 18.0, y + 10.0), 4.0, Color(col.r, col.g, col.b, 0.85 * alpha))
		_draw_right_text(font, label, Vector2(rail_x - 36.0, y), Color(col.r, col.g, col.b, alpha), 15)
		action_y += 36.0


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
