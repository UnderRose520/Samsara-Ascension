class_name HudStyles
extends RefCounted
## 战斗 HUD 专用样式 — 玄玉战斗界面

const UiTokens = preload("res://ui/theme/ui_tokens.gd")


static func top_bar() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.03, 0.04, 0.74)
	sb.border_width_bottom = 1
	sb.border_color = Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.28)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.shadow_color = Color(0, 0, 0, 0.52)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	return sb


static func left_scroll_panel(_accent: Color = UiTokens.ACCENT_GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.018, 0.032, 0.035, 0.86)
	sb.border_width_left = 1
	sb.border_width_top = 2
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(_accent.r, _accent.g, _accent.b, 0.52)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 18
	sb.shadow_color = Color(0, 0, 0, 0.68)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(5, 8)
	sb.content_margin_left = 14
	sb.content_margin_top = 10
	sb.content_margin_right = 12
	sb.content_margin_bottom = 10
	return sb


static func left_status_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	return sb


static func transparent_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	return sb


static func vital_avatar_frame(accent: Color = UiTokens.ACCENT_GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.028, 0.032, 0.62)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.shadow_color = Color(0, 0, 0, 0.48)
	sb.shadow_size = 8
	sb.content_margin_left = 5
	sb.content_margin_top = 5
	sb.content_margin_right = 5
	sb.content_margin_bottom = 5
	return sb


static func affix_rune_slot(accent: Color = UiTokens.ACCENT_JADE, filled: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.026, 0.03, 0.82) if filled else Color(0.01, 0.018, 0.024, 0.62)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.78 if filled else 0.34)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.18 if filled else 0.04)
	sb.shadow_size = 5 if filled else 2
	sb.content_margin_left = 3
	sb.content_margin_top = 3
	sb.content_margin_right = 3
	sb.content_margin_bottom = 3
	return sb


static func stat_pill(accent: Color = UiTokens.TEXT_SECONDARY) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.065, 0.062, 0.82)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.32)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 8
	sb.content_margin_top = 3
	sb.content_margin_right = 10
	sb.content_margin_bottom = 3
	return sb


static func combo_badge(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(0.72, 0.19, 0.08, 0.22)
		sb.border_color = Color(UiTokens.ELEM_FIRE.r, UiTokens.ELEM_FIRE.g, UiTokens.ELEM_FIRE.b, 0.58)
	else:
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.24)
		sb.border_color = Color(UiTokens.TEXT_MUTED.r, UiTokens.TEXT_MUTED.g, UiTokens.TEXT_MUTED.b, 0.28)
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
	sb.bg_color = Color(0.012, 0.024, 0.032, 0.72)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.36)
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	sb.corner_radius_bottom_left = 26
	sb.corner_radius_bottom_right = 26
	sb.shadow_color = Color(0, 0, 0, 0.58)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 18
	sb.content_margin_top = 10
	sb.content_margin_right = 18
	sb.content_margin_bottom = 10
	return sb


static func spell_dock_slot(ready: bool, unlocked: bool) -> StyleBoxFlat:
	# Circular jade slot (corner_radius == half size) with a soft inner shadow.
	var sb := StyleBoxFlat.new()
	if not unlocked:
		sb.bg_color = Color(0.018, 0.036, 0.04, 0.86)
		sb.border_color = Color(0.35, 0.42, 0.42, 0.32)
	elif ready:
		sb.bg_color = Color(0.05, 0.18, 0.15, 0.95)
		sb.border_color = Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.64)
	else:
		sb.bg_color = Color(0.035, 0.09, 0.085, 0.92)
		sb.border_color = Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.32)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.content_margin_left = 6
	sb.content_margin_top = 6
	sb.content_margin_right = 6
	sb.content_margin_bottom = 6
	return sb


static func realm_badge() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.075, 0.07, 0.86)
	sb.border_color = Color(UiTokens.ACCENT_GOLD.r, UiTokens.ACCENT_GOLD.g, UiTokens.ACCENT_GOLD.b, 0.42)
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


static func objective_panel(accent: Color = UiTokens.ACCENT_GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	return sb


static func objective_bar_fill(accent: Color = UiTokens.ACCENT_GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.9)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


static func weather_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.014, 0.03, 0.042, 0.74)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.34)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0, 0, 0.52)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(-3, 5)
	sb.content_margin_left = 12
	sb.content_margin_top = 9
	sb.content_margin_right = 12
	sb.content_margin_bottom = 9
	return sb


static func modal_panel(accent: Color = UiTokens.ACCENT_GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.024, 0.03, 0.94)
	sb.border_width_left = 1
	sb.border_width_top = 2
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.48)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.shadow_color = Color(0, 0, 0, 0.72)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 18
	sb.content_margin_top = 16
	sb.content_margin_right = 18
	sb.content_margin_bottom = 16
	return sb


static func decision_card(accent: Color, selected: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.034, 0.04, 0.94) if not selected else Color(0.05, 0.085, 0.075, 0.98)
	var bw := 2 if selected else 1
	sb.border_width_left = bw
	sb.border_width_top = bw
	sb.border_width_right = bw
	sb.border_width_bottom = bw
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.66 if selected else 0.38)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.20 if selected else 0.08)
	sb.shadow_size = 18 if selected else 9
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 12
	sb.content_margin_top = 12
	sb.content_margin_right = 12
	sb.content_margin_bottom = 12
	return sb
