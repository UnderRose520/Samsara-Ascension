class_name UiTokens
extends RefCounted

## Design tokens from docs/UIUX_轮回仙途_像素风_v2.0.md §2.1
## Pixel art dark xianxia palette (现代像素风 × 暗黑仙侠)

# --- Background (暗黑仙侠像素面板色系) ---
static var BG_DEEP := color_from_hex("#0A0A0F")
static var BG_PANEL := color_from_hex("#14141F")
static var BG_PANEL_ALT := color_from_hex("#1A2A24")

# --- Text ---
static var TEXT_PRIMARY := color_from_hex("#F0EDE0")
static var TEXT_SECONDARY := color_from_hex("#A09888")
static var TEXT_MUTED := color_from_hex("#6A6268")

# --- Accent ---
static var ACCENT_GOLD := color_from_hex("#E8C850")
static var ACCENT_GOLD_SOFT := color_from_hex("#8A7040")

# --- Elements (属性色) ---
static var ELEM_FIRE := color_from_hex("#E84030")
static var ELEM_WATER := color_from_hex("#38B0B8")
static var ELEM_THUNDER := color_from_hex("#E0C030")
static var ELEM_WOOD := color_from_hex("#58A848")
static var ELEM_EARTH := color_from_hex("#B09050")
static var ELEM_CHAOS := color_from_hex("#A040C8")

# --- Quality (品质色) ---
static var QUALITY_COMMON := color_from_hex("#888888")
static var QUALITY_RARE := color_from_hex("#4088E0")
static var QUALITY_EPIC := color_from_hex("#9040D0")
static var QUALITY_LEGENDARY := color_from_hex("#D08820")
static var QUALITY_DAO := color_from_hex("#D02030")

static var QUALITY_COLORS: Array[Color] = [
	QUALITY_COMMON,
	QUALITY_RARE,
	QUALITY_EPIC,
	QUALITY_LEGENDARY,
	QUALITY_DAO,
]

# --- Semantic state (语义色) ---
static var STATE_HP := color_from_hex("#E84030")
static var STATE_HP_GRADIENT_END := color_from_hex("#FF6A5A")
static var STATE_MANA := color_from_hex("#3890D0")
static var STATE_MANA_GRADIENT_END := color_from_hex("#60B8F0")
static var STATE_BUFF := color_from_hex("#58A848")
static var STATE_DEBUFF := color_from_hex("#C84848")
static var STATE_LEARN := color_from_hex("#E8C850")
static var STATE_REBIND := color_from_hex("#58A8D8")
static var STATE_SKILL := color_from_hex("#70C888")

# --- Button ---
static var BTN_DANGER := color_from_hex("#882020")

# --- Spacing (不变) ---
static var SPACE_XS := 4
static var SPACE_SM := 8
static var SPACE_MD := 12
static var SPACE_LG := 16
static var SPACE_XL := 24

# --- Radius (像素风减小) ---
static var RADIUS_SM := 2
static var RADIUS_MD := 4
static var RADIUS_LG := 6

# --- Panel decoration (像素风面板) ---
static var PANEL_INNER_STROKE := Color(0.91, 0.784, 0.314, 0.18)
static var DIVIDER := Color(0.91, 0.784, 0.314, 0.35)

# --- Dimmer overlays ---
static var DIMMER_COMBAT := Color(0.0, 0.0, 0.0, 0.6)
static var DIMMER_SETUP := Color(0.02, 0.02, 0.03, 0.94)


static func color_from_hex(hex: String) -> Color:
	var cleaned := hex.strip_edges().replace("#", "")
	if cleaned.length() != 6:
		push_warning("UiTokens: invalid hex '%s'" % hex)
		return Color.WHITE
	return Color.from_string("#" + cleaned, Color.WHITE)


static func elem_color(element: String) -> Color:
	match element.to_lower():
		"fire": return ELEM_FIRE
		"water": return ELEM_WATER
		"thunder": return ELEM_THUNDER
		"wood": return ELEM_WOOD
		"earth": return ELEM_EARTH
		"chaos": return ELEM_CHAOS
		"soul": return ELEM_CHAOS
		_: return TEXT_MUTED


static func quality_color(tier: int) -> Color:
	if tier < 0 or tier >= QUALITY_COLORS.size():
		return QUALITY_COMMON
	return QUALITY_COLORS[tier]


## UIUX §7 — 关卡 HUD 强调色
static func stage_accent(stage_index: int) -> Color:
	match stage_index:
		1: return ELEM_WOOD
		2: return ACCENT_GOLD_SOFT
		3: return ELEM_CHAOS
		4: return ACCENT_GOLD
		5: return ELEM_THUNDER
		_: return ACCENT_GOLD
