extends Control
class_name HudJadeCodexOverlay

const AssetPaths = preload("res://assets/asset_paths.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

signal close_requested

const TABS := ["词条", "道统", "灵宠", "本命器", "战绩", "自动策略"]
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
	"lifetime_items": [],
	"last_life": {},
	"best_life": {},
	"build_record": {},
	"lifetime_summary": "",
	"strategy_items": [],
	"weather": "",
}

var _active_tab := TAB_AFFIX
var _tab_rects: Array = []
var _pet_texture: Texture2D
var _artifact_texture: Texture2D
var _panel_texture: Texture2D
var _divider_texture: Texture2D
var _tab_texture: Texture2D
var _section_texture: Texture2D
var _dao_pattern_texture: Texture2D
var _dao_thunder_texture: Texture2D
var _status_badge_texture: Texture2D
var _seal_base_texture: Texture2D
var _cooldown_sweep_texture: Texture2D
var _resource_track_texture: Texture2D
var _shortcut_badge_texture: Texture2D
var _rune_textures := {}
var _pattern_texture_hits := 0
var _badge_texture_hits := 0
var _progress_texture_hits := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false
	_pet_texture = AssetPaths.load_texture(AssetPaths.HUD_PET_HUO_YING_AVATAR_96)
	_artifact_texture = AssetPaths.load_texture(AssetPaths.HUD_ARTIFACT_XUANYU_GOURD_96)
	_panel_texture = AssetPaths.load_texture(AssetPaths.PANEL_NINEPATCH)
	_divider_texture = AssetPaths.load_texture(AssetPaths.DIVIDER_GOLD)
	_tab_texture = AssetPaths.load_texture(AssetPaths.BTN_SECONDARY)
	_section_texture = AssetPaths.load_texture(AssetPaths.HUD_LEFT_OBJECTIVE_CARD)
	_dao_pattern_texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("dao_pattern_five"))
	_dao_thunder_texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("dao_pattern_thunder"))
	_status_badge_texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("status_badge_backing"))
	_seal_base_texture = AssetPaths.load_texture(AssetPaths.HUD_AUTO_SEAL_BASE)
	_cooldown_sweep_texture = AssetPaths.load_texture(AssetPaths.spell_cooldown_sweep())
	_resource_track_texture = AssetPaths.load_texture(AssetPaths.HUD_LEFT_RESOURCE_TRACK)
	_shortcut_badge_texture = AssetPaths.load_texture(AssetPaths.spell_shortcut_badge())
	_rune_textures = {
		"fire": AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_FIRE),
		"thunder": AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_THUNDER),
		"water": AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_WATER),
		"wood": AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_WOOD),
		"earth": AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_EARTH),
		"seal": AssetPaths.load_texture(AssetPaths.HUD_AFFIX_RUNE_SEAL),
	}


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
	if font == null:
		return
	_pattern_texture_hits = 0
	_badge_texture_hits = 0
	_progress_texture_hits = 0
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
	_draw_ink_panel(panel, Color(0.74, 0.98, 0.90, 0.70))
	if _divider_texture:
		draw_texture_rect(_divider_texture, Rect2(panel.position + Vector2(30, 80), Vector2(panel.size.x - 60.0, 6.0)), false, Color(0.95, 0.82, 0.54, 0.74))


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
		_draw_codex_tab(rect, active, accent)
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
	_draw_wrapped(font, str(_snapshot.get("lifetime_summary", "")), left.position + Vector2(18, 194), left.size.x - 36.0, UiTokens.ACCENT_GOLD, 13)
	_draw_stats_grid(font, center, "lifetime_items")
	_draw_detail_surface(right, UiTokens.ACCENT_GOLD)
	_draw_section_title(font, "最近前世", "前世碑与本局构筑", right, UiTokens.ACCENT_GOLD)
	var last_life := _dict("last_life")
	if last_life.is_empty():
		_draw_wrapped(font, "暂无前世记录。本局结算后会刻入前世碑。", right.position + Vector2(18, 74), right.size.x - 36.0, UiTokens.TEXT_SECONDARY, 13)
	else:
		var result_label := "飞升" if bool(last_life.get("victory", false)) else "道消"
		_draw_text(font, "%s · 种子 %d" % [result_label, int(last_life.get("seed", 0))], right.position + Vector2(18, 74), UiTokens.ACCENT_GOLD, 17)
		_draw_wrapped(font, "房间 %d · 最高连击 %d · 道势 %d/%d" % [
			int(last_life.get("rooms_cleared", 0)),
			int(last_life.get("best_combo", 0)),
			int(last_life.get("dao_peak", 0)),
			int(last_life.get("dao_max", 100)),
		], right.position + Vector2(18, 112), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13)
		var death := _dict_from(last_life.get("death_summary", {}))
		if not death.is_empty():
			_draw_wrapped(font, str(death.get("line", death.get("detail", ""))), right.position + Vector2(18, 168), right.size.x - 36.0, UiTokens.TEXT_SECONDARY, 12)
	var build := _dict("build_record")
	_draw_text(font, "本局构筑", right.position + Vector2(18, 246), UiTokens.ACCENT_JADE, 13)
	_draw_wrapped(font, "%s · %s" % [
		str(build.get("path_name", build.get("path_id", "未知道途"))),
		str(build.get("weapon_name", build.get("weapon_id", "本命器"))),
	], right.position + Vector2(18, 276), right.size.x - 36.0, UiTokens.TEXT_PRIMARY, 13)
	var mods := _array_to_strings(build.get("weapon_mods", []))
	_draw_wrapped(font, "祭炼：" + (" / ".join(mods) if not mods.is_empty() else "未祭炼"), right.position + Vector2(18, 330), right.size.x - 36.0, UiTokens.TEXT_SECONDARY, 12)
	var highlight := _dict("highlight")
	if not highlight.is_empty():
		_draw_wrapped(font, "高光：" + str(highlight.get("title", "")), right.position + Vector2(18, 382), right.size.x - 36.0, UiTokens.ACCENT_GOLD, 12)


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
	_draw_codex_surface(rect, accent, false)


func _draw_detail_surface(rect: Rect2, accent: Color) -> void:
	_draw_codex_surface(rect, accent, true)


func _draw_ink_panel(rect: Rect2, tint: Color) -> void:
	if _panel_texture:
		_draw_ninepatch_texture(_panel_texture, rect, 32.0, tint)


func _draw_codex_surface(rect: Rect2, accent: Color, warm: bool) -> void:
	var base_tint := Color(0.66, 0.96, 0.88, 0.36)
	if warm:
		base_tint = Color(0.96, 0.82, 0.54, 0.30)
	_draw_ink_panel(rect, base_tint)
	if _section_texture:
		var texture_tint := Color(0.42 + accent.r * 0.18, 0.48 + accent.g * 0.16, 0.46 + accent.b * 0.18, 0.24)
		draw_texture_rect(_section_texture, rect.grow(-6.0), false, texture_tint)
	_draw_divider_band(Rect2(rect.position + Vector2(14, 8), Vector2(rect.size.x - 28.0, 3.0)), Color(accent.r, accent.g, accent.b, 0.62))


func _draw_small_codex_card(rect: Rect2, accent: Color) -> void:
	_draw_ink_panel(rect, Color(0.70 + accent.r * 0.10, 0.88 + accent.g * 0.08, 0.82 + accent.b * 0.08, 0.32))
	_draw_divider_band(Rect2(rect.position + Vector2(10, 7), Vector2(rect.size.x - 20.0, 2.0)), Color(accent.r, accent.g, accent.b, 0.42))


func _draw_codex_tab(rect: Rect2, active: bool, accent: Color, alpha: float = -1.0) -> void:
	var tint_alpha := alpha if alpha >= 0.0 else (0.92 if active else 0.52)
	var tint := Color(0.78 + accent.r * 0.10, 0.88 + accent.g * 0.08, 0.84 + accent.b * 0.08, tint_alpha)
	if _tab_texture:
		draw_texture_rect(_tab_texture, rect, false, tint)
	else:
		_draw_texture_missing_fallback(rect, tint_alpha)
	var band_alpha := 0.72 if active else 0.28
	_draw_divider_band(Rect2(rect.position + Vector2(10, rect.size.y - 5.0), Vector2(rect.size.x - 20.0, 3.0)), Color(accent.r, accent.g, accent.b, band_alpha))


func _draw_texture_missing_fallback(rect: Rect2, alpha: float) -> void:
	pass


func _draw_divider_band(rect: Rect2, tint: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if _divider_texture:
		draw_texture_rect(_divider_texture, rect, false, tint)


func _draw_ninepatch_texture(texture: Texture2D, rect: Rect2, margin: float, tint: Color) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source_size := texture.get_size()
	var mx := minf(margin, minf(source_size.x * 0.5, rect.size.x * 0.5))
	var my := minf(margin, minf(source_size.y * 0.5, rect.size.y * 0.5))
	var dst_x := [rect.position.x, rect.position.x + mx, rect.end.x - mx]
	var dst_y := [rect.position.y, rect.position.y + my, rect.end.y - my]
	var dst_w := [mx, maxf(rect.size.x - mx * 2.0, 0.0), mx]
	var dst_h := [my, maxf(rect.size.y - my * 2.0, 0.0), my]
	var src_x := [0.0, mx, source_size.x - mx]
	var src_y := [0.0, my, source_size.y - my]
	var src_w := [mx, maxf(source_size.x - mx * 2.0, 0.0), mx]
	var src_h := [my, maxf(source_size.y - my * 2.0, 0.0), my]
	for row in range(3):
		for col in range(3):
			if dst_w[col] <= 0.0 or dst_h[row] <= 0.0 or src_w[col] <= 0.0 or src_h[row] <= 0.0:
				continue
			var dst := Rect2(Vector2(dst_x[col], dst_y[row]), Vector2(dst_w[col], dst_h[row]))
			var src := Rect2(Vector2(src_x[col], src_y[row]), Vector2(src_w[col], src_h[row]))
			draw_texture_rect_region(texture, dst, src, tint)


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
	_draw_pattern_disc(center, radius * 2.04, UiTokens.ACCENT_GOLD, 0.50, _dao_pattern_texture)
	_draw_charge_sweep(Rect2(center - Vector2(radius * 0.72, radius * 0.72), Vector2(radius * 1.44, radius * 1.44)), UiTokens.ACCENT_JADE, 0.20)
	var labels := ["核心", "临时", "封印", "道统", "本命"]
	var colors := [UiTokens.ACCENT_GOLD, UiTokens.ACCENT_JADE, UiTokens.TEXT_SECONDARY, UiTokens.ELEM_THUNDER, UiTokens.ELEM_CHAOS]
	var rune_keys := ["fire", "wood", "seal", "thunder", "earth"]
	for i in range(labels.size()):
		var ang := -PI * 0.5 + TAU * float(i) / float(labels.size())
		var pos := center + Vector2(cos(ang), sin(ang)) * radius * 0.84
		_draw_orbit_connector(center, pos, colors[i])
		_draw_codex_badge(Rect2(pos - Vector2(24, 24), Vector2(48, 48)), colors[i], rune_keys[i])
		_draw_centered(font, labels[i], pos + Vector2(0, 5), colors[i], 11)
	_draw_centered(font, _short_text(str(_snapshot.get("build", "构筑")), 12), center + Vector2(0, -8), UiTokens.ACCENT_GOLD, 19)
	_draw_centered(font, "%s %s" % [str(progress.get("name", "道统")), _progress_fraction(progress)], center + Vector2(0, 22), UiTokens.ELEM_THUNDER, 12)
	_draw_centered(font, "共鸣 " + str(combo.get("name", "未成")), center + Vector2(0, 48), UiTokens.TEXT_SECONDARY, 11)


func _draw_dao_ring(font: Font, rect: Rect2, progress: Dictionary) -> void:
	var center := rect.get_center() + Vector2(0, -8)
	var radius := minf(rect.size.x, rect.size.y) * 0.31
	var pct := clampf(float(progress.get("progress", 0.0)), 0.0, 1.0)
	_draw_pattern_disc(center, radius * 2.05, UiTokens.ELEM_THUNDER, 0.52, _dao_thunder_texture)
	_draw_progress_bar(Rect2(center + Vector2(-radius * 0.92, radius * 0.82), Vector2(radius * 1.84, 14.0)), pct, UiTokens.ELEM_THUNDER)
	_draw_charge_sweep(Rect2(center - Vector2(radius * 0.84, radius * 0.84), Vector2(radius * 1.68, radius * 1.68)), UiTokens.ELEM_THUNDER, 0.30 + pct * 0.26)
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
	_draw_pattern_disc(center, 210.0, accent, 0.30 if acquired else 0.18, _dao_pattern_texture)
	_draw_codex_badge(Rect2(center - Vector2(58, 58), Vector2(116, 116)), accent, "fire")
	var avatar_rect := Rect2(center - Vector2(48, 48), Vector2(96, 96))
	if _pet_texture:
		draw_texture_rect(_pet_texture, avatar_rect, false, Color(1, 1, 1, 0.95 if acquired else 0.42))
		_badge_texture_hits += 1
	else:
		_draw_codex_badge(Rect2(center - Vector2(42, 42), Vector2(84, 84)), accent, "fire")
	if ready:
		_draw_charge_sweep(Rect2(center - Vector2(66, 66), Vector2(132, 132)), UiTokens.ACCENT_GOLD, 0.56)
	_draw_centered(font, str(pet.get("name", "待结缘")), center + Vector2(0, 94), accent, 20)
	_draw_centered(font, "就绪" if ready else str(pet.get("cooldown_text", "自动协同")), center + Vector2(0, 124), UiTokens.ACCENT_GOLD if ready else UiTokens.TEXT_SECONDARY, 13)


func _draw_artifact_core(font: Font, rect: Rect2, artifact: Dictionary) -> void:
	var center := rect.get_center() + Vector2(0, -8)
	var pct := clampf(float(artifact.get("charge_pct", 0.0)), 0.0, 1.0)
	_draw_pattern_disc(center, 220.0, UiTokens.ELEM_CHAOS, 0.34, _dao_pattern_texture)
	_draw_progress_bar(Rect2(center + Vector2(-110, 82), Vector2(220, 14)), pct, UiTokens.ELEM_CHAOS)
	_draw_charge_sweep(Rect2(center - Vector2(68, 68), Vector2(136, 136)), UiTokens.ELEM_CHAOS, 0.28 + pct * 0.30)
	var icon_rect := Rect2(center - Vector2(48, 48), Vector2(96, 96))
	if _artifact_texture:
		draw_texture_rect(_artifact_texture, icon_rect, false)
		_badge_texture_hits += 1
	else:
		_draw_codex_badge(Rect2(center - Vector2(42, 42), Vector2(84, 84)), UiTokens.ELEM_CHAOS, "earth")
	_draw_centered(font, str(artifact.get("name", "玄玉葫")), center + Vector2(0, 98), UiTokens.ACCENT_GOLD, 20)
	_draw_centered(font, "道势 %d/%d" % [int(artifact.get("current", 0)), int(artifact.get("maximum", 100))], center + Vector2(0, 128), UiTokens.ELEM_CHAOS, 14)
	_draw_centered(font, str(artifact.get("state_text", "沉寂")), center + Vector2(0, 154), UiTokens.ACCENT_GOLD if pct >= 1.0 else UiTokens.TEXT_SECONDARY, 13)


func _draw_stats_grid(font: Font, rect: Rect2, key: String = "stats_items") -> void:
	var raw = _snapshot.get(key, [])
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
		_draw_small_codex_card(cell, UiTokens.ACCENT_JADE)
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
		_draw_small_codex_card(row, accent)
		var dot := row.position + Vector2(24, 30)
		_draw_strategy_status_badge(Rect2(dot - Vector2(14, 14), Vector2(28, 28)), accent, enabled)
		_draw_text(font, str(item.get("name", "")), row.position + Vector2(48, 25), UiTokens.TEXT_PRIMARY if enabled else UiTokens.TEXT_SECONDARY, 14)
		_draw_right_text(font, "开" if enabled else "关", row.position + Vector2(row.size.x - 18, 25), accent if enabled else UiTokens.TEXT_MUTED, 13)
		_draw_text(font, str(item.get("detail", "")), row.position + Vector2(48, 48), UiTokens.TEXT_SECONDARY, 11)
		y += 74.0


func _draw_metric_pill(font: Font, rect: Rect2, value: String, accent: Color) -> void:
	_draw_codex_tab(rect, true, accent, 0.66)
	_draw_centered(font, _short_text(value, 10), rect.get_center() + Vector2(0, 5), accent, 12)


func _draw_progress_bar(rect: Rect2, pct: float, accent: Color) -> void:
	var clamped := clampf(pct, 0.0, 1.0)
	if _resource_track_texture:
		draw_texture_rect(_resource_track_texture, rect, false, Color(0.80 + accent.r * 0.18, 0.86 + accent.g * 0.10, 0.82 + accent.b * 0.12, 0.58))
		_progress_texture_hits += 1
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y))
		if fill_rect.size.x > 1.0:
			draw_texture_rect(_resource_track_texture, fill_rect, false, Color(1.0 + accent.r * 0.12, 0.94 + accent.g * 0.16, 0.74 + accent.b * 0.16, 0.92))
			_progress_texture_hits += 1
		return
	_draw_divider_band(rect, Color(accent.r, accent.g, accent.b, 0.42))


func _draw_pattern_disc(center: Vector2, diameter: float, tint: Color, alpha: float, texture: Texture2D) -> void:
	if texture == null:
		return
	var rect := Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter))
	draw_texture_rect(texture, rect, false, Color(0.72 + tint.r * 0.26, 0.80 + tint.g * 0.20, 0.78 + tint.b * 0.20, alpha))
	_pattern_texture_hits += 1


func _draw_codex_badge(rect: Rect2, tint: Color, rune_key: String = "") -> void:
	if _status_badge_texture:
		draw_texture_rect(_status_badge_texture, rect, false, Color(0.86 + tint.r * 0.18, 0.86 + tint.g * 0.12, 0.78 + tint.b * 0.16, 0.86))
		_badge_texture_hits += 1
	elif _seal_base_texture:
		draw_texture_rect(_seal_base_texture, rect, false, Color(0.86 + tint.r * 0.18, 0.86 + tint.g * 0.12, 0.78 + tint.b * 0.16, 0.74))
		_badge_texture_hits += 1
	var rune: Texture2D = _rune_textures.get(rune_key, null)
	if rune:
		draw_texture_rect(rune, rect.grow(-8.0), false, Color(1, 1, 1, 0.72))
		_badge_texture_hits += 1


func _draw_orbit_connector(from_pos: Vector2, to_pos: Vector2, tint: Color) -> void:
	if _shortcut_badge_texture == null:
		return
	var midpoint := from_pos.lerp(to_pos, 0.5)
	var length := maxf(from_pos.distance_to(to_pos), 1.0)
	var rect := Rect2(Vector2(-length * 0.5, -4.0), Vector2(length, 8.0))
	draw_set_transform(midpoint, (to_pos - from_pos).angle(), Vector2.ONE)
	draw_texture_rect(_shortcut_badge_texture, rect, false, Color(0.82 + tint.r * 0.16, 0.90 + tint.g * 0.10, 0.84 + tint.b * 0.12, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_badge_texture_hits += 1


func _draw_charge_sweep(rect: Rect2, tint: Color, alpha: float) -> void:
	if _cooldown_sweep_texture == null:
		return
	draw_texture_rect(_cooldown_sweep_texture, rect, false, Color(0.90 + tint.r * 0.16, 0.90 + tint.g * 0.12, 0.88 + tint.b * 0.12, alpha))
	_progress_texture_hits += 1


func _draw_strategy_status_badge(rect: Rect2, tint: Color, enabled: bool) -> void:
	if _shortcut_badge_texture:
		draw_texture_rect(_shortcut_badge_texture, rect, false, Color(0.92 + tint.r * 0.10, 0.92 + tint.g * 0.08, 0.86 + tint.b * 0.08, 0.72 if enabled else 0.32))
		_badge_texture_hits += 1
		return
	_draw_codex_badge(rect, tint if enabled else UiTokens.TEXT_MUTED, "")


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


func get_pattern_texture_hit_count() -> int:
	return _pattern_texture_hits


func get_badge_texture_hit_count() -> int:
	return _badge_texture_hits


func get_progress_texture_hit_count() -> int:
	return _progress_texture_hits


func _dict(key: String) -> Dictionary:
	var raw = _snapshot.get(key, {})
	return _dict_from(raw)


func _dict_from(raw) -> Dictionary:
	if raw is Dictionary:
		return raw
	return {}


func _string_array(key: String) -> PackedStringArray:
	return _array_to_strings(_snapshot.get(key, PackedStringArray()))


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
