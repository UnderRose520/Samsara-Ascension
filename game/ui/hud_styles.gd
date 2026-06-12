class_name HudStyles
extends RefCounted
## 战斗 HUD 专用样式 — 玉简仪表盘

const UiTokens = preload("res://ui/theme/ui_tokens.gd")


static func top_bar() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.08, 0.72)
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 0.843, 0, 0.22)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	return sb


static func left_scroll_panel(_accent: Color = UiTokens.ACCENT_GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.065, 0.11, 0.88)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 0.843, 0, 0.16)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(2, 4)
	sb.content_margin_left = 12
	sb.content_margin_top = 10
	sb.content_margin_right = 10
	sb.content_margin_bottom = 10
	return sb


static func stat_pill(accent: Color = UiTokens.TEXT_SECONDARY) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.13, 0.72)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 8
	sb.content_margin_top = 3
	sb.content_margin_right = 10
	sb.content_margin_bottom = 3
	return sb


static func combo_badge(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(1, 0.45, 0.15, 0.18)
		sb.border_color = Color(1, 0.55, 0.2, 0.55)
	else:
		sb.bg_color = Color(1, 1, 1, 0.04)
		sb.border_color = Color(1, 1, 1, 0.1)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 4
	return sb


static func spell_dock() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.09, 0.82)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 0.843, 0, 0.28)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 14
	sb.content_margin_top = 8
	sb.content_margin_right = 14
	sb.content_margin_bottom = 8
	return sb


static func spell_dock_slot(ready: bool, unlocked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if not unlocked:
		sb.bg_color = Color(0.06, 0.06, 0.08, 0.65)
		sb.border_color = Color(0.4, 0.4, 0.45, 0.35)
	elif ready:
		sb.bg_color = Color(1, 0.843, 0, 0.08)
		sb.border_color = Color(1, 0.843, 0, 0.45)
	else:
		sb.bg_color = Color(0.1, 0.1, 0.14, 0.75)
		sb.border_color = Color(1, 1, 1, 0.12)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	return sb


static func realm_badge() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.45, 0.95, 0.12)
	sb.border_color = Color(0.75, 0.65, 1, 0.35)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8
	sb.content_margin_top = 3
	sb.content_margin_right = 8
	sb.content_margin_bottom = 3
	return sb
