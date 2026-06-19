extends Control
class_name HudJadeCodexOverlay

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

signal close_requested

const TABS := ["词条", "道统", "灵宠", "本命器", "统计", "自动策略"]
const TAB_AFFIX := 0
const TAB_DAO := 1
const TAB_PET := 2
const TAB_ARTIFACT := 3
const TAB_STATS := 4
const TAB_STRATEGY := 5

var _snapshot := {
	"realm": "炼气",
	"build": "构筑未成",
	"dao": "道统 未成",
	"pet": "待结缘",
	"artifact": "玄玉葫 · 沉寂",
	"stats": "本局统计暂无",
	"strategy": "自动普攻 / 自动护体 / 灵宠自动 / 器灵半自动",
	"affixes": PackedStringArray(),
	"sealed_affixes": PackedStringArray(),
	"slot_summary": {},
	"dao_progress": {},
	"dao_detail": {},
	"combo_display": {},
	"pet_state": {},
	"artifact_state": {},
	"weapon_mods": PackedStringArray(),
	"stats_items": [],
	"strategy_items": [],
	"weather": "",
}

var _active_tab := TAB_AFFIX
var _tab_rects: Array = []
var _pet_texture: Texture2D
var _artifact_texture: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	_pet_texture = AssetPaths.load_texture(AssetPaths.HUD_PET_HUO_YING_AVATAR)
	_artifact_texture = AssetPaths.load_texture(AssetPaths.HUD_ARTIFACT_XUANYU_GOURD)


func set_snapshot(snapshot: Dictionary) -> void:
	for key in snapshot.keys():
		_snapshot[key] = snapshot[key]
	queue_redraw()


func open() -> void:
	visible = true
	grab_focus()
	queue_redraw()


func close() -> void:
	visible = false
	release_focus()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(_tab_rects.size()):
			var rect: Rect2 = _tab_rects[i]
			if rect.has_point(mouse_event.position):
				_set_active_tab(i)
				accept_event()
				return
	var key_event := event as InputEventKey
	if handle_key_event(key_event):
		accept_event()


func handle_key_event(key_event: InputEventKey) -> bool:
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	match key_event.keycode:
		KEY_ESCAPE, KEY_TAB:
			close_requested.emit()
			return true
		KEY_RIGHT, KEY_E, KEY_PAGEUP:
			_set_active_tab(_active_tab + 1)
			return true
		KEY_LEFT, KEY_Q, KEY_PAGEDOWN:
			_set_active_tab(_active_tab - 1)
			return true
	return false


func _set_active_tab(index: int) -> void:
	_active_tab = wrapi(index, 0, TABS.size())
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var panel := _main_panel_rect()
	var header_rect := Rect2(panel.position, Vector2(panel.size.x, 126.0))
	var content := Rect2(
		panel.position + Vector2(28.0, 142.0),
		panel.size - Vector2(56.0, 198.0)
	)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78), true)
	_draw_panel(panel)
	_draw_header(font, header_rect)
	_draw_tabs(font, panel)
	match _active_tab:
		TAB_AFFIX:
			_draw_affix_page(font, content)
		TAB_DAO:
			_draw_dao_page(font, content)
		TAB_PET:
			_draw_pet_page(font, content)
		TAB_ARTIFACT:
			_draw_artifact_page(font, content)
		TAB_STATS:
			_draw_stats_page(font, content)
		TAB_STRATEGY:
			_draw_strategy_page(font, content)
	_draw_footer(font, panel)


func _main_panel_rect() -> Rect2:
	var margin_x := clampf(size.x * 0.045, 40.0, 76.0)
	var margin_y := clampf(size.y * 0.052, 34.0, 58.0)
	return Rect2(Vector2(margin_x, margin_y), size - Vector2(margin_x * 2.0, margin_y * 2.0))


func _draw_panel(panel: Rect2) -> void:
	draw_rect(panel, Color(0.012, 0.026, 0.028, 0.985), true)
	draw_rect(panel.grow(-1.0), Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.58), false, 1.0)
	draw_line(panel.position + Vector2(24, 86), panel.position + Vector2(panel.size.x - 24, 86), Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.16), 1.0)
	var corner := 24.0
	var c := Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.72)
	draw_line(panel.position + Vector2(12, 12), panel.position + Vector2(corner + 12, 12), c, 1.5)
	draw_line(panel.position + Vector2(12, 12), panel.position + Vector2(12, corner + 12), c, 1.5)
	draw_line(panel.position + Vector2(panel.size.x - 12, 12), panel.position + Vector2(panel.size.x - corner - 12, 12), c, 1.5)
	draw_line(panel.position + Vector2(panel.size.x - 12, 12), panel.position + Vector2(panel.size.x - 12, corner + 12), c, 1.5)
	draw_line(panel.position + Vector2(12, panel.size.y - 12), panel.position + Vector2(corner + 12, panel.size.y - 12), c, 1.5)
	draw_line(panel.position + Vector2(12, panel.size.y - 12), panel.position + Vector2(12, panel.size.y - corner - 12), c, 1.5)
	draw_line(panel.position + Vector2(panel.size.x - 12, panel.size.y - 12), panel.position + Vector2(panel.size.x - corner - 12, panel.size.y - 12), c, 1.5)
	draw_line(panel.position + Vector2(panel.size.x - 12, panel.size.y - 12), panel.position + Vector2(panel.size.x - 12, panel.size.y - corner - 12), c, 1.5)


func _draw_header(font: Font, rect: Rect2) -> void:
	_draw_text(font, "玉简 · 构筑命盘", rect.position + Vector2(32, 42), UiTokens.ACCENT_GOLD, 24)
	_draw_text(font, "暂停查看词条、道统缺口、灵宠、本命器与自动策略", rect.position + Vector2(32, 70), UiTokens.TEXT_SECONDARY, 13)
	var status_x := rect.position.x + rect.size.x - 322.0
	var realm := str(_snapshot.get("realm", "炼气"))
	var weather := str(_snapshot.get("weather", ""))
	_draw_metric_pill(font, Rect2(Vector2(status_x, rect.position.y + 28), Vector2(132, 32)), realm, UiTokens.ACCENT_JADE)
	_draw_metric_pill(font, Rect2(Vector2(status_x + 148, rect.position.y + 28), Vector2(160, 32)), weather if not weather.is_empty() else "天象未明", UiTokens.ELEM_THUNDER)


func _draw_tabs(font: Font, panel: Rect2) -> void:
	_tab_rects.clear()
	var tab_y := panel.position.y + 92.0
	var x := panel.position.x + 28.0
	var available := panel.size.x - 56.0
	var gap := 10.0
	var tab_w := minf(102.0, (available - gap * float(TABS.size() - 1)) / float(TABS.size()))
	for i in range(TABS.size()):
		var rect := Rect2(Vector2(x + float(i) * (tab_w + gap), tab_y), Vector2(tab_w, 30.0))
		_tab_rects.append(rect)
		var active := i == _active_tab
		var accent := UiTokens.ACCENT_GOLD if active else UiTokens.ACCENT_JADE
		draw_rect(rect, Color(0.03, 0.07, 0.066, 0.68 if active else 0.32), true)
		if active:
			draw_line(rect.position + Vector2(8, rect.size.y - 2), rect.position + Vector2(rect.size.x - 8, rect.size.y - 2), accent, 2.0)
		else:
			draw_line(rect.position + Vector2(12, rect.size.y - 2), rect.position + Vector2(rect.size.x - 12, rect.size.y - 2), Color(accent.r, accent.g, accent.b, 0.26), 1.0)
		_draw_centered(font, TABS[i], rect.get_center() + Vector2(0, 5), accent if active else UiTokens.TEXT_SECONDARY, 12)


func _draw_footer(font: Font, panel: Rect2) -> void:
	var y := panel.position.y + panel.size.y - 26.0
	_draw_text(font, "Tab / Esc 关闭     ← / → 切页", panel.position + Vector2(32, y), UiTokens.TEXT_SECONDARY, 12)
	_draw_right_text(font, "当前页 · %s" % TABS[_active_tab], panel.position + Vector2(panel.size.x - 32, y), UiTokens.ACCENT_GOLD, 12)


func _draw_affix_page(font: Font, content: Rect2) -> void:
	var columns := _three_columns(content)
	var left: Rect2 = columns[0]
	var center: Rect2 = columns[1]
	var right: Rect2 = columns[2]
	var affixes := _string_array("affixes")
	var sealed := _string_array("sealed_affixes")
	var slots := _dict("slot_summary")
	var core_max := int(slots.get("core_max", 3))
	var active_used := int(slots.get("active_used", affixes.size()))
	var active_max := int(slots.get("active_max", maxi(core_max, affixes.size())))
	_draw_section_surface(left, UiTokens.ACCENT_JADE)
	_draw_section_title(font, "词条槽位", "核心 / 临时 / 封印", left, UiTokens.ACCENT_JADE)
	_draw_text(font, "已装备 %d/%d" % [active_used, active_max], left.position + Vector2(18, 58), UiTokens.ACCENT_GOLD, 13)
	var y := left.position.y + 88.0
	y = _draw_affix_group(font, left, "核心", affixes, 0, core_max, y, UiTokens.ACCENT_GOLD)
	y = _draw_affix_group(font, left, "临时", affixes, core_max, affixes.size(), y + 8.0, UiTokens.ACCENT_JADE)
	_draw_affix_group(font, left, "封印", sealed, 0, sealed.size(), y + 8.0, UiTokens.TEXT_SECONDARY)
	_draw_affix_mandala(font, center)
	_draw_detail_surface(right, UiTokens.ACCENT_GOLD)
	_draw_section_title(font, "构筑总览", "当前成型与下一缺口", right, UiTokens.ACCENT_GOLD)
	_draw_wrapped(font, "流派：" + str(_snapshot.get("build", "")), right.position + Vector2(18, 64), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13)
	_draw_wrapped(font, str(_snapshot.get("dao", "")), right.position + Vector2(18, 126), right.size.x - 36.0, UiTokens.ACCENT_GOLD, 13)
	var combo := _dict("combo_display")
	_draw_wrapped(font, "共鸣：" + str(combo.get("name", "未成")) + "  " + _combo_progress_text(combo), right.position + Vector2(18, 184), right.size.x - 36.0, UiTokens.ELEM_THUNDER, 13)
	_draw_wrapped(font, _next_build_hint(), right.position + Vector2(18, 242), right.size.x - 36.0, UiTokens.ACCENT_JADE, 12)


func _draw_dao_page(font: Font, content: Rect2) -> void:
	var columns := _three_columns(content)
	var left: Rect2 = columns[0]
	var center: Rect2 = columns[1]
	var right: Rect2 = columns[2]
	var progress := _dict("dao_progress")
	var detail := _dict("dao_detail")
	_draw_section_surface(left, UiTokens.ACCENT_JADE)
	_draw_section_title(font, "道统候选", "最接近觉醒的传承", left, UiTokens.ACCENT_JADE)
	_draw_text(font, str(progress.get("name", "道统未明")), left.position + Vector2(18, 68), UiTokens.ACCENT_GOLD, 20)
	_draw_wrapped(font, str(detail.get("title", "以词条填入道统槽位，完成后觉醒被动传承。")), left.position + Vector2(18, 106), left.size.x - 36.0, UiTokens.TEXT_SECONDARY, 12)
	_draw_text(font, "当前境界", left.position + Vector2(18, 176), UiTokens.TEXT_MUTED, 11)
	_draw_text(font, str(_snapshot.get("realm", "")), left.position + Vector2(18, 202), UiTokens.TEXT_PRIMARY, 15)
	_draw_dao_ring(font, center, progress)
	_draw_detail_surface(right, UiTokens.ACCENT_GOLD)
	_draw_section_title(font, "缺口与收益", "补齐后进入觉醒链", right, UiTokens.ACCENT_GOLD)
	var missing := _array_to_strings(progress.get("missing_slots", []))
	if missing.is_empty():
		_draw_text(font, "道统已圆满", right.position + Vector2(18, 68), UiTokens.ACCENT_GOLD, 17)
	else:
		_draw_text(font, "仍缺", right.position + Vector2(18, 68), UiTokens.TEXT_MUTED, 11)
		for i in range(mini(missing.size(), 6)):
			_draw_text(font, "◇ " + missing[i], right.position + Vector2(18, 100 + i * 26), UiTokens.TEXT_PRIMARY, 13)
	var desc_y := right.position.y + 282.0
	_draw_wrapped(font, str(detail.get("description", "奖励页优先选择带有缺口标签的词条。")), Vector2(right.position.x + 18, desc_y), right.size.x - 36.0, UiTokens.ACCENT_JADE, 12)
	var passive := str(detail.get("passive_dsl", ""))
	if not passive.is_empty():
		_draw_wrapped(font, "被动：" + passive, Vector2(right.position.x + 18, desc_y + 64), right.size.x - 36.0, UiTokens.TEXT_SECONDARY, 11)


func _draw_pet_page(font: Font, content: Rect2) -> void:
	var columns := _three_columns(content)
	var left: Rect2 = columns[0]
	var center: Rect2 = columns[1]
	var right: Rect2 = columns[2]
	var pet := _dict("pet_state")
	var acquired := bool(pet.get("acquired", false))
	var ready := bool(pet.get("ready", false))
	_draw_section_surface(left, UiTokens.ELEM_FIRE)
	_draw_section_title(font, "灵宠", "局内协同与护主", left, UiTokens.ELEM_FIRE)
	_draw_text(font, str(pet.get("name", "待结缘")), left.position + Vector2(18, 72), UiTokens.ELEM_FIRE if acquired else UiTokens.TEXT_SECONDARY, 22)
	_draw_wrapped(font, str(pet.get("detail", "灵宠未结缘")), left.position + Vector2(18, 112), left.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13)
	_draw_text(font, "协同状态", left.position + Vector2(18, 184), UiTokens.TEXT_MUTED, 11)
	_draw_text(font, "就绪" if ready else str(pet.get("cooldown_text", "自动协同")), left.position + Vector2(18, 212), UiTokens.ACCENT_GOLD if ready else UiTokens.TEXT_SECONDARY, 16)
	_draw_pet_orbit(font, center, pet)
	_draw_detail_surface(right, UiTokens.ELEM_FIRE)
	_draw_section_title(font, "协同关系", "与词条 / 道统 / 本命器联动", right, UiTokens.ELEM_FIRE)
	var lines := PackedStringArray([
		"自动协同：保持后台触发，不占主动技能槽。",
		"手动协同：就绪时宠符灯浮现 V。",
		"护主：危险时可触发短暂保命反馈。",
		"战果：协同结果进入右侧战果流。"
	])
	_draw_bullet_lines(font, lines, right.position + Vector2(18, 68), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13, 28)
	_draw_wrapped(font, "当前构筑：" + str(_snapshot.get("build", "")), right.position + Vector2(18, 218), right.size.x - 36.0, UiTokens.ACCENT_JADE, 12)


func _draw_artifact_page(font: Font, content: Rect2) -> void:
	var columns := _three_columns(content)
	var left: Rect2 = columns[0]
	var center: Rect2 = columns[1]
	var right: Rect2 = columns[2]
	var artifact := _dict("artifact_state")
	_draw_section_surface(left, UiTokens.ELEM_CHAOS)
	_draw_section_title(font, "祭炼节点", "本命器词缀", left, UiTokens.ELEM_CHAOS)
	var mods := _string_array("weapon_mods")
	_draw_bullet_lines(font, mods, left.position + Vector2(18, 72), left.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13, 30)
	_draw_artifact_core(font, center, artifact)
	_draw_detail_surface(right, UiTokens.ELEM_CHAOS)
	_draw_section_title(font, "器灵状态", "道势与归一", right, UiTokens.ELEM_CHAOS)
	_draw_text(font, str(artifact.get("name", "玄玉葫")), right.position + Vector2(18, 70), UiTokens.ACCENT_GOLD, 20)
	_draw_text(font, str(artifact.get("state_text", "沉寂")), right.position + Vector2(18, 104), UiTokens.ELEM_CHAOS, 15)
	_draw_wrapped(font, str(artifact.get("hint", "积累道势后，本命器进入可觉醒状态。")), right.position + Vector2(18, 150), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13)
	_draw_wrapped(font, "本命器：" + str(_snapshot.get("artifact", "")), right.position + Vector2(18, 238), right.size.x - 36.0, UiTokens.TEXT_SECONDARY, 12)


func _draw_stats_page(font: Font, content: Rect2) -> void:
	var columns := _three_columns(content)
	var left: Rect2 = columns[0]
	var center: Rect2 = columns[1]
	var right: Rect2 = columns[2]
	_draw_section_surface(left, UiTokens.ACCENT_JADE)
	_draw_section_title(font, "本局记录", "当前战斗摘要", left, UiTokens.ACCENT_JADE)
	_draw_wrapped(font, str(_snapshot.get("stats", "")), left.position + Vector2(18, 70), left.size.x - 36.0, UiTokens.TEXT_PRIMARY, 14)
	_draw_wrapped(font, "天气：" + str(_snapshot.get("weather", "天象未明")), left.position + Vector2(18, 132), left.size.x - 36.0, UiTokens.ELEM_THUNDER, 13)
	_draw_stats_grid(font, center)
	_draw_detail_surface(right, UiTokens.ACCENT_GOLD)
	_draw_section_title(font, "高光", "这一世最值得记住的瞬间", right, UiTokens.ACCENT_GOLD)
	var highlight := _dict("highlight")
	if highlight.is_empty():
		_draw_wrapped(font, "暂无高光记录。继续推进房间、连击、道统或隐藏连锁会写入这里。", right.position + Vector2(18, 74), right.size.x - 36.0, UiTokens.TEXT_SECONDARY, 13)
	else:
		_draw_text(font, str(highlight.get("title", "高光")), right.position + Vector2(18, 74), UiTokens.ACCENT_GOLD, 18)
		_draw_wrapped(font, str(highlight.get("detail", "")), right.position + Vector2(18, 116), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13)


func _draw_strategy_page(font: Font, content: Rect2) -> void:
	var columns := _three_columns(content)
	var left: Rect2 = columns[0]
	var center: Rect2 = columns[1]
	var right: Rect2 = columns[2]
	_draw_section_surface(left, UiTokens.ACCENT_JADE)
	_draw_section_title(font, "策略总览", "减少不必要按键负担", left, UiTokens.ACCENT_JADE)
	_draw_wrapped(font, str(_snapshot.get("strategy", "")), left.position + Vector2(18, 72), left.size.x - 36.0, UiTokens.TEXT_PRIMARY, 14)
	_draw_strategy_list(font, center)
	_draw_detail_surface(right, UiTokens.ACCENT_GOLD)
	_draw_section_title(font, "战斗表现", "常驻技能收束原则", right, UiTokens.ACCENT_GOLD)
	var lines := PackedStringArray([
		"主动决策只保留 Q / E / R。",
		"攻、护、宠、器用符灯表达后台状态。",
		"V / F 只在可触发时短暂浮现。",
		"详细阈值进入暂停菜单配置。"
	])
	_draw_bullet_lines(font, lines, right.position + Vector2(18, 74), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13, 32)


func _three_columns(content: Rect2) -> Array:
	var gap := 26.0
	var left_w := clampf(content.size.x * 0.285, 260.0, 340.0)
	var right_w := clampf(content.size.x * 0.285, 260.0, 340.0)
	var center_w := maxf(content.size.x - left_w - right_w - gap * 2.0, 280.0)
	var left := Rect2(content.position, Vector2(left_w, content.size.y))
	var center := Rect2(Vector2(left.end.x + gap, content.position.y), Vector2(center_w, content.size.y))
	var right := Rect2(Vector2(center.end.x + gap, content.position.y), Vector2(right_w, content.size.y))
	return [left, center, right]


func _draw_section_surface(rect: Rect2, accent: Color) -> void:
	draw_rect(rect, Color(0.018, 0.047, 0.047, 0.42), true)
	draw_line(rect.position + Vector2(0, 0), rect.position + Vector2(rect.size.x, 0), Color(accent.r, accent.g, accent.b, 0.42), 1.0)
	draw_line(rect.position + Vector2(0, 0), rect.position + Vector2(0, rect.size.y), Color(accent.r, accent.g, accent.b, 0.16), 1.0)


func _draw_detail_surface(rect: Rect2, accent: Color) -> void:
	draw_rect(rect, Color(0.035, 0.04, 0.032, 0.42), true)
	draw_line(rect.position + Vector2(0, 0), rect.position + Vector2(rect.size.x, 0), Color(accent.r, accent.g, accent.b, 0.44), 1.0)
	draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x, rect.size.y), Color(accent.r, accent.g, accent.b, 0.16), 1.0)


func _draw_section_title(font: Font, title: String, subtitle: String, rect: Rect2, accent: Color) -> void:
	_draw_text(font, title, rect.position + Vector2(18, 28), accent, 17)
	_draw_text(font, subtitle, rect.position + Vector2(18, 48), UiTokens.TEXT_SECONDARY, 11)


func _draw_affix_group(font: Font, rect: Rect2, title: String, lines: PackedStringArray, start: int, stop: int, y: float, accent: Color) -> float:
	_draw_text(font, title, Vector2(rect.position.x + 18, y), accent, 12)
	y += 24.0
	if start >= stop:
		_draw_text(font, "· 暂无", Vector2(rect.position.x + 28, y), UiTokens.TEXT_MUTED, 12)
		return y + 26.0
	for i in range(start, min(stop, lines.size())):
		if y > rect.end.y - 22.0:
			_draw_text(font, "· …", Vector2(rect.position.x + 28, y), UiTokens.TEXT_MUTED, 12)
			return y + 26.0
		_draw_text(font, "◇ " + lines[i], Vector2(rect.position.x + 28, y), UiTokens.TEXT_PRIMARY, 13)
		y += 26.0
	return y


func _draw_affix_mandala(font: Font, rect: Rect2) -> void:
	var center := rect.get_center() + Vector2(0, -10)
	var radius := minf(rect.size.x, rect.size.y) * 0.30
	var progress := _dict("dao_progress")
	var combo := _dict("combo_display")
	draw_circle(center, radius * 0.92, Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.035))
	draw_arc(center, radius, 0.0, TAU, 96, Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.82), 2.0)
	draw_arc(center, radius * 0.68, 0.0, TAU, 96, Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.58), 1.2)
	var labels := ["核心", "临时", "封印", "道统", "本命"]
	var colors := [UiTokens.ACCENT_GOLD, UiTokens.ACCENT_JADE, UiTokens.TEXT_SECONDARY, UiTokens.ELEM_THUNDER, UiTokens.ELEM_CHAOS]
	for i in range(labels.size()):
		var ang := -PI * 0.5 + TAU * float(i) / float(labels.size())
		var pos := center + Vector2(cos(ang), sin(ang)) * radius * 0.84
		draw_line(center, pos, Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.22), 1.0)
		draw_circle(pos, 24.0, Color(0.018, 0.04, 0.045, 0.88))
		draw_arc(pos, 24.0, 0.0, TAU, 42, colors[i], 1.4)
		_draw_centered(font, labels[i], pos + Vector2(0, 5), colors[i], 11)
	_draw_centered(font, _short_text(str(_snapshot.get("build", "构筑")), 12), center + Vector2(0, -8), UiTokens.ACCENT_GOLD, 19)
	_draw_centered(font, "%s %s" % [str(progress.get("name", "道统")), _progress_fraction(progress)], center + Vector2(0, 22), UiTokens.ELEM_THUNDER, 12)
	_draw_centered(font, "共鸣 " + str(combo.get("name", "未成")), center + Vector2(0, 48), UiTokens.TEXT_SECONDARY, 11)


func _draw_dao_ring(font: Font, rect: Rect2, progress: Dictionary) -> void:
	var center := rect.get_center() + Vector2(0, -8)
	var radius := minf(rect.size.x, rect.size.y) * 0.31
	var pct := clampf(float(progress.get("progress", 0.0)), 0.0, 1.0)
	draw_circle(center, radius * 0.96, Color(UiTokens.ELEM_THUNDER.r, UiTokens.ELEM_THUNDER.g, UiTokens.ELEM_THUNDER.b, 0.035))
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU, 96, Color(UiTokens.TEXT_MUTED.r, UiTokens.TEXT_MUTED.g, UiTokens.TEXT_MUTED.b, 0.32), 8.0)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * pct, 96, UiTokens.ELEM_THUNDER, 8.0)
	_draw_centered(font, str(progress.get("name", "道统")), center + Vector2(0, -20), UiTokens.ACCENT_GOLD, 24)
	_draw_centered(font, _progress_fraction(progress), center + Vector2(0, 16), UiTokens.ELEM_THUNDER, 36)
	var missing := _array_to_strings(progress.get("missing_slots", []))
	var label := "缺口已补齐" if missing.is_empty() else "缺 " + " / ".join(missing.slice(0, mini(missing.size(), 3)))
	_draw_centered(font, label, center + Vector2(0, 58), UiTokens.TEXT_SECONDARY, 12)


func _draw_pet_orbit(font: Font, rect: Rect2, pet: Dictionary) -> void:
	var center := rect.get_center() + Vector2(0, -10)
	var acquired := bool(pet.get("acquired", false))
	var ready := bool(pet.get("ready", false))
	var accent := UiTokens.ELEM_FIRE if acquired else UiTokens.TEXT_MUTED
	draw_circle(center, 92.0, Color(accent.r, accent.g, accent.b, 0.06))
	draw_arc(center, 110.0, 0.0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.42), 1.5)
	draw_arc(center, 78.0, 0.0, TAU, 96, Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.24), 1.0)
	var avatar_rect := Rect2(center - Vector2(56, 56), Vector2(112, 112))
	if _pet_texture:
		draw_texture_rect(_pet_texture, avatar_rect, false, Color(1, 1, 1, 0.95 if acquired else 0.42))
	else:
		draw_circle(center, 48.0, accent)
	if ready:
		draw_arc(center, 124.0, -PI * 0.5, PI * 1.5, 96, UiTokens.ACCENT_GOLD, 3.0)
	_draw_centered(font, str(pet.get("name", "待结缘")), center + Vector2(0, 94), accent, 20)
	_draw_centered(font, "就绪" if ready else str(pet.get("cooldown_text", "自动协同")), center + Vector2(0, 124), UiTokens.ACCENT_GOLD if ready else UiTokens.TEXT_SECONDARY, 13)


func _draw_artifact_core(font: Font, rect: Rect2, artifact: Dictionary) -> void:
	var center := rect.get_center() + Vector2(0, -8)
	var pct := clampf(float(artifact.get("charge_pct", 0.0)), 0.0, 1.0)
	draw_circle(center, 106.0, Color(UiTokens.ELEM_CHAOS.r, UiTokens.ELEM_CHAOS.g, UiTokens.ELEM_CHAOS.b, 0.06))
	draw_arc(center, 124.0, -PI * 0.5, -PI * 0.5 + TAU, 96, Color(UiTokens.TEXT_MUTED.r, UiTokens.TEXT_MUTED.g, UiTokens.TEXT_MUTED.b, 0.28), 7.0)
	draw_arc(center, 124.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 96, UiTokens.ELEM_CHAOS, 7.0)
	var icon_rect := Rect2(center - Vector2(58, 58), Vector2(116, 116))
	if _artifact_texture:
		draw_texture_rect(_artifact_texture, icon_rect, false)
	else:
		draw_circle(center, 46.0, UiTokens.ELEM_CHAOS)
	_draw_centered(font, str(artifact.get("name", "玄玉葫")), center + Vector2(0, 98), UiTokens.ACCENT_GOLD, 20)
	_draw_centered(font, "道势 %d/%d" % [int(artifact.get("current", 0)), int(artifact.get("maximum", 100))], center + Vector2(0, 128), UiTokens.ELEM_CHAOS, 14)
	_draw_centered(font, str(artifact.get("state_text", "沉寂")), center + Vector2(0, 154), UiTokens.ACCENT_GOLD if pct >= 1.0 else UiTokens.TEXT_SECONDARY, 13)


func _draw_stats_grid(font: Font, rect: Rect2) -> void:
	var raw = _snapshot.get("stats_items", [])
	var items: Array = raw if raw is Array else []
	var cell_w := (rect.size.x - 18.0) * 0.5
	var cell_h := 92.0
	var start := rect.position + Vector2(0, 14)
	for i in range(mini(items.size(), 8)):
		var raw_item = items[i]
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var col := i % 2
		var row := i / 2
		var cell := Rect2(start + Vector2(float(col) * (cell_w + 18.0), float(row) * (cell_h + 16.0)), Vector2(cell_w, cell_h))
		draw_rect(cell, Color(0.025, 0.06, 0.058, 0.42), true)
		draw_line(cell.position, cell.position + Vector2(cell.size.x, 0), Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.30), 1.0)
		_draw_text(font, str(item.get("label", "")), cell.position + Vector2(14, 26), UiTokens.TEXT_SECONDARY, 12)
		_draw_text(font, str(item.get("value", "")), cell.position + Vector2(14, 62), UiTokens.ACCENT_GOLD, 24)


func _draw_strategy_list(font: Font, rect: Rect2) -> void:
	var raw = _snapshot.get("strategy_items", [])
	var items: Array = raw if raw is Array else []
	var y := rect.position.y + 12.0
	for i in range(mini(items.size(), 6)):
		var raw_item = items[i]
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var enabled := bool(item.get("enabled", false))
		var accent := UiTokens.ACCENT_JADE
		var raw_accent = item.get("accent", UiTokens.ACCENT_JADE)
		if raw_accent is Color:
			accent = raw_accent
		var row := Rect2(Vector2(rect.position.x + 12.0, y), Vector2(rect.size.x - 24.0, 60.0))
		draw_rect(row, Color(0.022, 0.054, 0.052, 0.42), true)
		draw_line(row.position, row.position + Vector2(row.size.x, 0), Color(accent.r, accent.g, accent.b, 0.36), 1.0)
		var dot := row.position + Vector2(24, 30)
		draw_circle(dot, 10.0, Color(accent.r, accent.g, accent.b, 0.18 if enabled else 0.06))
		draw_arc(dot, 10.0, 0.0, TAU, 28, accent if enabled else UiTokens.TEXT_MUTED, 1.5)
		_draw_text(font, str(item.get("name", "")), row.position + Vector2(48, 25), UiTokens.TEXT_PRIMARY if enabled else UiTokens.TEXT_SECONDARY, 14)
		_draw_right_text(font, "开" if enabled else "关", row.position + Vector2(row.size.x - 18, 25), accent if enabled else UiTokens.TEXT_MUTED, 13)
		_draw_text(font, str(item.get("detail", "")), row.position + Vector2(48, 48), UiTokens.TEXT_SECONDARY, 11)
		y += 74.0


func _draw_metric_pill(font: Font, rect: Rect2, value: String, accent: Color) -> void:
	draw_rect(rect, Color(0.018, 0.044, 0.042, 0.56), true)
	draw_line(rect.position + Vector2(8, rect.size.y - 2), rect.position + Vector2(rect.size.x - 8, rect.size.y - 2), Color(accent.r, accent.g, accent.b, 0.62), 1.0)
	_draw_centered(font, _short_text(value, 10), rect.get_center() + Vector2(0, 5), accent, 12)


func _draw_progress_bar(rect: Rect2, pct: float, accent: Color) -> void:
	var clamped := clampf(pct, 0.0, 1.0)
	draw_rect(rect, Color(0, 0, 0, 0.38), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y)), Color(accent.r, accent.g, accent.b, 0.82), true)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.30), false, 1.0)


func _draw_bullet_lines(font: Font, lines: PackedStringArray, pos: Vector2, max_width: float, color: Color, font_size: int, line_gap: int) -> void:
	var y := pos.y
	if lines.is_empty():
		_draw_text(font, "· 暂无", pos, UiTokens.TEXT_MUTED, font_size)
		return
	for line in lines:
		_draw_wrapped(font, "◇ " + line, Vector2(pos.x, y), max_width, color, font_size)
		y += line_gap


func _draw_text(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	draw_string(font, pos + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0, 0, 0, color.a * 0.76))
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_draw_text(font, value, pos - Vector2(width * 0.5, 0), color, font_size)


func _draw_right_text(font: Font, value: String, pos: Vector2, color: Color, font_size: int) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_draw_text(font, value, pos - Vector2(width, 0), color, font_size)


func _draw_wrapped(font: Font, value: String, pos: Vector2, max_width: float, color: Color, font_size: int) -> void:
	var line := ""
	var y := pos.y
	for ch in value:
		var test := line + ch
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > max_width and not line.is_empty():
			_draw_text(font, line, Vector2(pos.x, y), color, font_size)
			y += font_size + 7
			line = ch
		else:
			line = test
	if not line.is_empty():
		_draw_text(font, line, Vector2(pos.x, y), color, font_size)


func _dict(key: String) -> Dictionary:
	var raw = _snapshot.get(key, {})
	if raw is Dictionary:
		return raw
	return {}


func _string_array(key: String) -> PackedStringArray:
	var raw = _snapshot.get(key, PackedStringArray())
	var out := PackedStringArray()
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		return raw
	if raw is Array:
		for item in raw:
			out.append(str(item))
	elif not str(raw).is_empty():
		out.append(str(raw))
	return out


func _array_to_strings(raw) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		return raw
	if raw is Array:
		for item in raw:
			out.append(str(item))
	elif not str(raw).is_empty():
		out.append(str(raw))
	return out


func _progress_fraction(info: Dictionary) -> String:
	return "%d/%d" % [int(info.get("matched", 0)), maxi(int(info.get("total", 1)), 1)]


func _combo_progress_text(info: Dictionary) -> String:
	var matched = info.get("matched", [])
	var matched_count := 0
	if matched is Array or typeof(matched) == TYPE_PACKED_STRING_ARRAY:
		matched_count = matched.size()
	return "%d/%d" % [matched_count, maxi(int(info.get("total", 1)), 1)]


func _next_build_hint() -> String:
	var progress := _dict("dao_progress")
	var missing := _array_to_strings(progress.get("missing_slots", []))
	if not missing.is_empty():
		return "优先补足：" + " / ".join(missing.slice(0, mini(missing.size(), 3)))
	var combo := _dict("combo_display")
	var combo_missing := _array_to_strings(combo.get("missing", []))
	if not combo_missing.is_empty():
		return "共鸣缺口：" + " / ".join(combo_missing.slice(0, mini(combo_missing.size(), 3)))
	return "构筑已成型，后续优先强化本命器与关键品质。"


func _short_text(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return value.substr(0, max_chars - 1) + "…"
