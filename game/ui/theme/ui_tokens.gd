class_name UiTokens
extends RefCounted

## Samsara Ascension UI tokens.
## Art direction: dark ink jade, weather-lit neon elements, restrained ritual gold.

# --- Background ---
static var BG_DEEP := color_from_hex("#05070B")
static var BG_VOID := color_from_hex("#080D12")
static var BG_PANEL := color_from_hex("#0E1718")
static var BG_PANEL_ALT := color_from_hex("#13231F")
static var BG_PANEL_WARM := color_from_hex("#201711")

# --- Text ---
static var TEXT_PRIMARY := color_from_hex("#F5EFD8")
static var TEXT_SECONDARY := color_from_hex("#BBAF92")
static var TEXT_MUTED := color_from_hex("#726A62")
static var TEXT_COLD := color_from_hex("#B9E7D8")

# --- Accent ---
static var ACCENT_GOLD := color_from_hex("#F0C95A")
static var ACCENT_GOLD_SOFT := color_from_hex("#9C7A3B")
static var ACCENT_JADE := color_from_hex("#57D7B0")
static var ACCENT_JADE_DARK := color_from_hex("#1F7F69")
static var ACCENT_BLOOD := color_from_hex("#D24848")
static var ACCENT_INK_PURPLE := color_from_hex("#6D5BD6")

# --- Elements (属性色) ---
static var ELEM_FIRE := color_from_hex("#FF654A")
static var ELEM_WATER := color_from_hex("#4FC7E8")
static var ELEM_THUNDER := color_from_hex("#FFE062")
static var ELEM_WOOD := color_from_hex("#68D36E")
static var ELEM_EARTH := color_from_hex("#C49A5A")
static var ELEM_CHAOS := color_from_hex("#B46CFF")

# --- Quality (品质色) ---
static var QUALITY_COMMON := color_from_hex("#8A918E")
static var QUALITY_RARE := color_from_hex("#47A4FF")
static var QUALITY_EPIC := color_from_hex("#B46CFF")
static var QUALITY_LEGENDARY := color_from_hex("#F0B84C")
static var QUALITY_DAO := color_from_hex("#FF4F5F")

static var QUALITY_COLORS: Array[Color] = [
	QUALITY_COMMON,
	QUALITY_RARE,
	QUALITY_EPIC,
	QUALITY_LEGENDARY,
	QUALITY_DAO,
]

# --- Semantic state (语义色) ---
static var STATE_HP := color_from_hex("#E64A43")
static var STATE_HP_GRADIENT_END := color_from_hex("#FF8A62")
static var STATE_MANA := color_from_hex("#40A7E8")
static var STATE_MANA_GRADIENT_END := color_from_hex("#7BE4FF")
static var STATE_BUFF := color_from_hex("#68D36E")
static var STATE_DEBUFF := color_from_hex("#D24848")
static var STATE_LEARN := color_from_hex("#F0C95A")
static var STATE_REBIND := color_from_hex("#5FC8FF")
static var STATE_SKILL := color_from_hex("#77E0B4")

# --- Button ---
static var BTN_DANGER := color_from_hex("#7A2525")

# --- Spacing (不变) ---
static var SPACE_XS := 4
static var SPACE_SM := 8
static var SPACE_MD := 12
static var SPACE_LG := 16
static var SPACE_XL := 24

# --- Radius ---
static var RADIUS_SM := 3
static var RADIUS_MD := 6
static var RADIUS_LG := 8

# --- Panel decoration ---
static var PANEL_INNER_STROKE := Color(0.34, 0.84, 0.69, 0.16)
static var DIVIDER := Color(0.94, 0.79, 0.35, 0.32)

# --- Dimmer overlays ---
static var DIMMER_COMBAT := Color(0.0, 0.0, 0.0, 0.64)
static var DIMMER_SETUP := Color(0.01, 0.015, 0.02, 0.82)


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
		2: return ELEM_WATER
		3: return ELEM_CHAOS
		4: return ELEM_FIRE
		5: return ELEM_THUNDER
		_: return ACCENT_GOLD
