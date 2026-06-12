class_name AssetPaths
extends RefCounted

## Central paths for UIUX-generated PNG assets (see game/tools/generate_2d_*.py).

const UI_ROOT := "res://assets/ui/"
const SPRITE_ROOT := "res://assets/sprites/"

const MENU_BACKDROP := UI_ROOT + "bg_jade_palace_hall.png"
const PANEL_NINEPATCH := UI_ROOT + "panel_ninepatch_256.png"
const SCROLL_TOAST := UI_ROOT + "scroll_toast_520x72.png"
const HUD_PANEL_BG := UI_ROOT + "hud_panel_bg_320x448.png"
const MODAL_TITLE_BAR := UI_ROOT + "modal_title_bar_720x52.png"
const DIVIDER_GOLD := UI_ROOT + "divider_gold_256x2.png"
const EVENT_BANNER := UI_ROOT + "event_banner_640x160.png"
const TALENT_SCROLL := UI_ROOT + "talent_scroll_210x200.png"
const PET_AVATAR_RING := UI_ROOT + "pet_avatar_ring_40.png"
const COMBO_TRACK := UI_ROOT + "combo_track_256x8.png"
const PROGRESS_HP := UI_ROOT + "progress_hp_9slice.png"
const PROGRESS_MANA := UI_ROOT + "progress_mana_9slice.png"

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

const QUALITY_FRAMES := [
	UI_ROOT + "quality_common_220x280.png",
	UI_ROOT + "quality_rare_220x280.png",
	UI_ROOT + "quality_epic_220x280.png",
	UI_ROOT + "quality_legendary_220x280.png",
	UI_ROOT + "quality_dao_220x280.png",
]

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

const ELEMENT_ICONS := {
	"fire": UI_ROOT + "elem_fire_32.png",
	"water": UI_ROOT + "elem_water_32.png",
	"thunder": UI_ROOT + "elem_thunder_32.png",
	"wood": UI_ROOT + "elem_wood_32.png",
	"earth": UI_ROOT + "elem_earth_32.png",
	"chaos": UI_ROOT + "elem_chaos_32.png",
	"none": UI_ROOT + "elem_chaos_32.png",
}

const SPELL_ICONS := {
	"q": UI_ROOT + "spell_q_fire_40.png",
	"e": UI_ROOT + "spell_e_thunder_40.png",
	"r": UI_ROOT + "spell_r_water_40.png",
	"q_locked": UI_ROOT + "spell_q_locked_40.png",
	"e_locked": UI_ROOT + "spell_e_locked_40.png",
	"r_locked": UI_ROOT + "spell_r_locked_40.png",
}

const DAO_HEART_ICONS := {
	"ask": UI_ROOT + "dao_heart_ask_128.png",
	"enlighten": UI_ROOT + "dao_heart_enlighten_128.png",
	"prove": UI_ROOT + "dao_heart_prove_128.png",
}

const PATH_ICONS := {
	"continue": UI_ROOT + "path_combat_48.png",
	"combat": UI_ROOT + "path_combat_48.png",
	"rest": UI_ROOT + "path_rest_48.png",
	"shop": UI_ROOT + "path_shop_48.png",
	"event": UI_ROOT + "path_event_48.png",
	"elite": UI_ROOT + "path_elite_48.png",
}


static func elem_icon(element_id: int) -> String:
	match element_id:
		1: return ELEMENT_ICONS["fire"]
		2: return ELEMENT_ICONS["water"]
		3: return ELEMENT_ICONS["thunder"]
		4: return ELEMENT_ICONS["wood"]
		5: return ELEMENT_ICONS["earth"]
		6: return ELEMENT_ICONS["chaos"]
		_: return ELEMENT_ICONS["none"]


static func quality_frame(quality: int) -> String:
	var tier := clampi(quality, 0, QUALITY_FRAMES.size() - 1)
	return QUALITY_FRAMES[tier]


static func weather_icon(weather_id: String) -> String:
	return WEATHER_ICONS.get(weather_id, WEATHER_ICONS["clear"])


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


static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D
