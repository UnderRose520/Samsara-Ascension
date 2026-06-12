class_name AssetPaths
extends RefCounted

## Central paths for UIUX-generated PNG assets (see game/tools/generate_2d_*.py).

const UI_ROOT := "res://assets/ui/"
const SPRITE_ROOT := "res://assets/sprites/"

# --- 全局面板与背景 (Global panels / backdrops) ---
const MENU_BACKDROP := UI_ROOT + "bg_jade_palace_hall.png"
const PANEL_NINEPATCH := UI_ROOT + "panel_ninepatch_256.png"
const SCROLL_TOAST := UI_ROOT + "scroll_toast_520x72.png"
const MODAL_TITLE_BAR := UI_ROOT + "modal_title_bar_720x52.png"
const DIVIDER_GOLD := UI_ROOT + "divider_gold_256x2.png"
const EVENT_BANNER := UI_ROOT + "event_banner_640x160.png"
const EVENT_ILLUSTRATION := UI_ROOT + "event_illustration_560x96.png"
const BOSS_BANNER := UI_ROOT + "boss_banner_640x80.png"
const BREAKTHROUGH_BG_OVERLAY := UI_ROOT + "breakthrough_bg_overlay.png"

# --- HUD 专用 (Combat HUD) ---
const HUD_PANEL_BG := UI_ROOT + "hud_panel_bg_320x448.png"
const HUD_WEATHER_PANEL := UI_ROOT + "hud_weather_panel_280x120.png"
const HUD_SKILL_DOCK_FRAME := UI_ROOT + "hud_spell_dock_frame.png"
const PROGRESS_HP := UI_ROOT + "progress_hp_9slice.png"
const PROGRESS_MANA := UI_ROOT + "progress_mana_9slice.png"
const COMBO_TRACK := UI_ROOT + "combo_track_256x8.png"
const ENEMY_HP_BAR := UI_ROOT + "enemy_hp_bar_9slice.png"

# --- 图标：灵石 / 宠物 (Icons: currency, pet) ---
const ICON_SPIRIT_STONE := UI_ROOT + "icon_spirit_stone_32.png"
const ICON_HEAL := UI_ROOT + "icon_heal_32.png"
const ICON_DODGE := UI_ROOT + "icon_dodge_32.png"
const ICON_REROLL := UI_ROOT + "icon_reroll_24.png"
const ICON_SKIP := UI_ROOT + "icon_skip_24.png"
const PET_AVATAR_RING := UI_ROOT + "pet_avatar_ring_40.png"

# --- 境界天赋分类图标 (Realm talent icons) ---
## 优先加载 talent_icon_realm_1~5.png，缺失时回退到 elem_*_32.png
const TALENT_REALM_ICON_FALLBACK := {
	1: UI_ROOT + "elem_wood_32.png",
	2: UI_ROOT + "elem_earth_32.png",
	3: UI_ROOT + "elem_fire_32.png",
	4: UI_ROOT + "elem_thunder_32.png",
	5: UI_ROOT + "elem_chaos_32.png",
}

# --- 品质框 (Quality frames) ---
const QUALITY_FRAMES := [
	UI_ROOT + "quality_common_220x280.png",
	UI_ROOT + "quality_rare_220x280.png",
	UI_ROOT + "quality_epic_220x280.png",
	UI_ROOT + "quality_legendary_220x280.png",
	UI_ROOT + "quality_dao_220x280.png",
]

# --- 元素图标 (Element icons) ---
const ELEMENT_ICONS := {
	"fire": UI_ROOT + "elem_fire_32.png",
	"water": UI_ROOT + "elem_water_32.png",
	"thunder": UI_ROOT + "elem_thunder_32.png",
	"wood": UI_ROOT + "elem_wood_32.png",
	"earth": UI_ROOT + "elem_earth_32.png",
	"chaos": UI_ROOT + "elem_chaos_32.png",
	"none": UI_ROOT + "elem_chaos_32.png",
}

## 机缘选择卡专用大图标（80px，避免 32px 拉伸模糊）
const ELEMENT_ICONS_LARGE := {
	"fire": UI_ROOT + "elem_fire_large_80.png",
	"ice": UI_ROOT + "elem_ice_large_80.png",
	"thunder": UI_ROOT + "elem_thunder_large_80.png",
}

# --- 天象图标 (Weather icons) ---
const WEATHER_ICONS := {
	"clear": UI_ROOT + "weather_clear_32.png",
	"rain": UI_ROOT + "weather_rain_32.png",
	"thunder": UI_ROOT + "weather_thunder_32.png",
	"fire": UI_ROOT + "weather_fire_32.png",
	"wind": UI_ROOT + "weather_wind_32.png",
	"fog": UI_ROOT + "weather_fog_32.png",
	"snow": UI_ROOT + "weather_snow_32.png",
	"sand": UI_ROOT + "weather_sand_32.png",
}

# --- 法术图标 (Spell icons) ---
const SPELL_ICONS := {
	"q": UI_ROOT + "spell_q_fire_40.png",
	"e": UI_ROOT + "spell_e_thunder_40.png",
	"r": UI_ROOT + "spell_r_water_40.png",
	"q_locked": UI_ROOT + "spell_q_locked_40.png",
	"e_locked": UI_ROOT + "spell_e_locked_40.png",
	"r_locked": UI_ROOT + "spell_r_locked_40.png",
}

## 法术槽位底圈（圆形玉简空槽 / 锁定槽）
const SPELL_SLOT_EMPTY := UI_ROOT + "spell_slot_empty_40.png"
const SPELL_SLOT_LOCKED := UI_ROOT + "spell_slot_locked_40.png"

# --- 道心图标 (Dao Heart icons) ---
const DAO_HEART_ICONS := {
	"ask": UI_ROOT + "dao_heart_ask_128.png",
	"enlighten": UI_ROOT + "dao_heart_enlighten_128.png",
	"prove": UI_ROOT + "dao_heart_prove_128.png",
}

# --- 道心卡片框 (Dao Heart card frame) ---
const DAO_HEART_CARD_FRAME := UI_ROOT + "dao_heart_card_frame.png"

# --- 路径图标 (Path icons) ---
const PATH_ICONS := {
	"continue": UI_ROOT + "path_combat_48.png",
	"combat": UI_ROOT + "path_combat_48.png",
	"rest": UI_ROOT + "path_rest_48.png",
	"shop": UI_ROOT + "path_shop_48.png",
	"event": UI_ROOT + "path_event_48.png",
	"elite": UI_ROOT + "path_elite_48.png",
}

# --- 因果倾向色点 (Karma tendency dots, 用于事件选项) ---
const KARMA_ICONS := {
	"good": UI_ROOT + "karma_good_16.png",
	"evil": UI_ROOT + "karma_evil_16.png",
	"greed": UI_ROOT + "karma_greed_16.png",
	"rebellion": UI_ROOT + "karma_rebellion_16.png",
	"dao_heart": UI_ROOT + "karma_dao_heart_16.png",
}

# --- 天赋卷轴卡 (Talent scroll card) ---
const TALENT_SCROLL := UI_ROOT + "talent_scroll_210x200.png"
const TALENT_SCROLL_HIGHLIGHT := UI_ROOT + "talent_scroll_210x200_highlight.png"

# --- 装饰元素 (Decorative ornaments) ---
const SETUP_TITLE_ORNAMENT := UI_ROOT + "setup_title_ornament.png"
const BT_SLOT_ARROW := UI_ROOT + "bt_slot_arrow_32.png"
const COUPLET_PANEL_LEFT := UI_ROOT + "couplet_panel_left.png"
const COUPLET_PANEL_RIGHT := UI_ROOT + "couplet_panel_right.png"

# --- 徽章/角标 (Badges) ---
const BADGE_OWNED := UI_ROOT + "badge_owned_32.png"
const BADGE_TRAINING := UI_ROOT + "badge_training_48x16.png"
const ICON_HEART_DEMON_TRIAL := UI_ROOT + "icon_heart_demon_trial_24.png"

## 天赋效果类型角标
const TALENT_BADGES := {
	"attack": UI_ROOT + "talent_badge_attack.png",
	"defense": UI_ROOT + "talent_badge_defense.png",
	"spirit": UI_ROOT + "talent_badge_spirit.png",
	"utility": UI_ROOT + "talent_badge_utility.png",
}

## 品质标签底图
const QUALITY_TAGS := {
	"common": UI_ROOT + "tag_common.png",
	"rare": UI_ROOT + "tag_rare.png",
	"epic": UI_ROOT + "tag_epic.png",
}

## 元素系标签底图
const ELEMENT_TAGS := {
	"ice": UI_ROOT + "tag_ice.png",
	"thunder": UI_ROOT + "tag_thunder.png",
	"fire": UI_ROOT + "tag_fire.png",
}

# --- 按钮纹理 (Button textures) ---
const BTN_PRIMARY_GOLD := UI_ROOT + "btn_primary_gold_360x48.png"
const BTN_SECONDARY := UI_ROOT + "btn_secondary_360x40.png"

# --- 战斗精灵 (Combat sprites) ---
const PLAYER := SPRITE_ROOT + "player_cultivator_64.png"
const PET_HUO_YING := SPRITE_ROOT + "pet_huo_ying_32.png"

const ENEMY_TRAINING := SPRITE_ROOT + "enemy_training_dummy_64.png"
const ENEMY_BERSERKER := SPRITE_ROOT + "enemy_berserker_64.png"
const ENEMY_ARCHER := SPRITE_ROOT + "enemy_archer_64.png"
const ENEMY_BOMBER := SPRITE_ROOT + "enemy_bomber_64.png"

const PROJECTILE_FIRE := SPRITE_ROOT + "projectile_fire_16.png"
const PROJECTILE_THUNDER := SPRITE_ROOT + "projectile_thunder_16.png"
const PROJECTILE_ICE := SPRITE_ROOT + "projectile_ice_16.png"
const PROJECTILE_WATER := SPRITE_ROOT + "projectile_water_16.png"
const PROJECTILE_GENERIC := SPRITE_ROOT + "projectile_generic_16.png"
const PROJECTILE_CHAOS := SPRITE_ROOT + "projectile_chaos_16.png"


# ============================================================================
# 工具方法 (Utility functions)
# ============================================================================

static func elem_icon(element_id: int) -> String:
	match element_id:
		1: return ELEMENT_ICONS["fire"]
		2: return ELEMENT_ICONS["water"]
		3: return ELEMENT_ICONS["thunder"]
		4: return ELEMENT_ICONS["wood"]
		5: return ELEMENT_ICONS["earth"]
		6: return ELEMENT_ICONS["chaos"]
		_: return ELEMENT_ICONS["none"]


static func elem_icon_large(element_id: int) -> String:
	## 机缘选择卡用大图标；仅火/雷有大图，其余回退到 32px
	## 注意：冰系大图标 elem_ice_large_80.png 需通过 ELEMENT_ICONS_LARGE["ice"] 直接引用
	var key := ""
	match element_id:
		1: key = "fire"
		3: key = "thunder"
		_: return elem_icon(element_id)
	return ELEMENT_ICONS_LARGE.get(key, elem_icon(element_id))


static func quality_frame(quality: int) -> String:
	var tier := clampi(quality, 0, QUALITY_FRAMES.size() - 1)
	return QUALITY_FRAMES[tier]


static func weather_icon(weather_id: String) -> String:
	return WEATHER_ICONS.get(weather_id, WEATHER_ICONS["clear"])


static func karma_icon(karma_key: String) -> String:
	return KARMA_ICONS.get(karma_key, ELEMENT_ICONS["wood"])


static func enemy_sprite(archetype: String, is_boss: bool = false) -> String:
	if is_boss:
		return ENEMY_BERSERKER
	match archetype:
		"berserker": return ENEMY_BERSERKER
		"sniper": return ENEMY_ARCHER
		"ranged": return ENEMY_BOMBER
		"shaman": return ENEMY_ARCHER
		_: return ENEMY_TRAINING


static func projectile_for_color(color: Color) -> String:
	if color.is_equal_approx(Color(1.0, 0.45, 0.15)):
		return PROJECTILE_FIRE
	if color.is_equal_approx(Color(1.0, 0.85, 0.3)) or color.g > 0.8 and color.r > 0.8:
		return PROJECTILE_THUNDER
	if color.is_equal_approx(Color(0.55, 0.85, 1.0)) or color.b > 0.7 and color.g > 0.7:
		return PROJECTILE_ICE
	if color.is_equal_approx(Color(0.4, 0.75, 1.0)):
		return PROJECTILE_WATER
	if color.is_equal_approx(Color(0.85, 0.35, 0.95)):
		return PROJECTILE_CHAOS
	return PROJECTILE_GENERIC


static func path_icon(path_id: String) -> String:
	return PATH_ICONS.get(path_id, PATH_ICONS["continue"])


static func talent_realm_icon(realm_level: int) -> String:
	var dedicated := UI_ROOT + "talent_icon_realm_%d.png" % realm_level
	if ResourceLoader.exists(dedicated):
		return dedicated
	return TALENT_REALM_ICON_FALLBACK.get(realm_level, ELEMENT_ICONS["wood"])


static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D
