class_name UiTokens
extends RefCounted

## Design tokens from docs/UIUX_轮回仙途_v1.0.md §3.1–3.3

# --- Background ---
static var BG_DEEP := color_from_hex("#0D0D0D")
static var BG_PANEL := color_from_hex("#1A1A2E")
static var BG_PANEL_ALT := color_from_hex("#2D2D44")

# --- Text ---
static var TEXT_PRIMARY := color_from_hex("#F0ECE4")
static var TEXT_SECONDARY := color_from_hex("#C4B69C")
static var TEXT_MUTED := color_from_hex("#8A8278")

# --- Accent ---
static var ACCENT_GOLD := color_from_hex("#FFD700")
static var ACCENT_GOLD_SOFT := color_from_hex("#F0D68A")

# --- Elements ---
static var ELEM_FIRE := color_from_hex("#FF6B35")
static var ELEM_WATER := color_from_hex("#4ECDC4")
static var ELEM_THUNDER := color_from_hex("#FFD700")
static var ELEM_WOOD := color_from_hex("#7BC67E")
static var ELEM_EARTH := color_from_hex("#C4A35A")
static var ELEM_CHAOS := color_from_hex("#B57EDC")

# --- Quality ---
static var QUALITY_COMMON := color_from_hex("#B0B0B0")
static var QUALITY_RARE := color_from_hex("#4E9AF1")
static var QUALITY_EPIC := color_from_hex("#A855F7")
static var QUALITY_LEGENDARY := color_from_hex("#F59E0B")
static var QUALITY_DAO := color_from_hex("#EF4444")

static var QUALITY_COLORS: Array[Color] = [
	QUALITY_COMMON,
	QUALITY_RARE,
	QUALITY_EPIC,
	QUALITY_LEGENDARY,
	QUALITY_DAO,
]

# --- Semantic state ---
static var STATE_HP := color_from_hex("#E85D5D")
static var STATE_HP_GRADIENT_END := color_from_hex("#FF8A7A")
static var STATE_MANA := color_from_hex("#5B9BD5")
static var STATE_MANA_GRADIENT_END := color_from_hex("#7EC8FF")
static var STATE_BUFF := color_from_hex("#7BC67E")
static var STATE_DEBUFF := color_from_hex("#C45C5C")
static var STATE_LEARN := color_from_hex("#FFD700")
static var STATE_REBIND := color_from_hex("#8EC5FF")
static var STATE_SKILL := color_from_hex("#A6F0C6")

# --- Button ---
static var BTN_DANGER := color_from_hex("#8B3A3A")

# --- Spacing ---
static var SPACE_XS := 4
static var SPACE_SM := 8
static var SPACE_MD := 12
static var SPACE_LG := 16
static var SPACE_XL := 24

# --- Radius ---
static var RADIUS_SM := 4
static var RADIUS_MD := 8
static var RADIUS_LG := 12

# --- Panel decoration ---
static var PANEL_INNER_STROKE := Color(1.0, 1.0, 1.0, 0.08)
static var DIVIDER := Color(0.769, 0.714, 0.612, 0.25)

# --- Dimmer overlays (prototype alignment §13) ---
static var DIMMER_COMBAT := Color(0.0, 0.0, 0.0, 0.55)
static var DIMMER_SETUP := Color(0.02, 0.02, 0.031, 0.92)


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
		_: return TEXT_MUTED


static func quality_color(tier: int) -> Color:
	if tier < 0 or tier >= QUALITY_COLORS.size():
		return QUALITY_COMMON
	return QUALITY_COLORS[tier]


## UIUX §9 — 关卡 HUD 强调色
static func stage_accent(stage_index: int) -> Color:
	match stage_index:
		1: return ELEM_WOOD
		2: return ELEM_WATER
		3: return ELEM_FIRE
		4: return ELEM_THUNDER
		5: return QUALITY_DAO
		_: return ACCENT_GOLD
