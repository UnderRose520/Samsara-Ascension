class_name AssetPaths
extends RefCounted

## Central paths for UIUX-generated PNG assets (see game/tools/generate_2d_*.py).

const UI_ROOT := "res://assets/ui/"
const HUD_UI_ROOT := UI_ROOT + "hud/"
const CARD_UI_ROOT := UI_ROOT + "cards/"
const SPRITE_ROOT := "res://assets/sprites/"
const SPRITE_FRAME_ROOT := SPRITE_ROOT + "frames/"
const FX_ROOT := SPRITE_ROOT + "fx/"

# --- 全局面板与背景 (Global panels / backdrops) ---
const MENU_BACKDROP := UI_ROOT + "bg_main_menu_celestial_hall.png"

const RUN_SETUP_BACKDROP := UI_ROOT + "bg_run_setup_inner_court.png"
const RUN_RESULT_BACKDROP := UI_ROOT + "bg_run_result_reincarnation_pool.png"
const EVENT_SECRET_ILLUSTRATION := UI_ROOT + "event_illustration_secret_encounter.png"
const PANEL_NINEPATCH := UI_ROOT + "panel_ninepatch_256.png"
const MODAL_INK_VEIL := UI_ROOT + "modal_ink_veil_1920x1080.png"
const SCROLL_TOAST := UI_ROOT + "scroll_toast_520x72.png"
const MODAL_TITLE_BAR := UI_ROOT + "modal_title_bar_720x52.png"
const DIVIDER_GOLD := UI_ROOT + "divider_gold_256x2.png"
const EVENT_BANNER := UI_ROOT + "event_banner_640x160.png"
const EVENT_ILLUSTRATION := UI_ROOT + "event_illustration_560x96.png"
const BOSS_BANNER := UI_ROOT + "boss_banner_640x80.png"
const BREAKTHROUGH_BG_OVERLAY := UI_ROOT + "breakthrough_bg_overlay.png"
const BREAKTHROUGH_BACKDROP := UI_ROOT + "breakthrough_backdrop_no_emblem_v3_1920x1080.png"
const REALM_GATE_PANEL := UI_ROOT + "realm_gate_panel_760x360.png"
const DEATH_MOMENT_VIGNETTE := UI_ROOT + "death_moment_vignette_1920x1080.png"
const DEATH_SOUL_TOTEM_DISC := UI_ROOT + "death_soul_totem_disc_512.png"
const RUN_RESULT_VICTORY_SEAL := UI_ROOT + "dao_heart_enlighten_128.png"

# --- HUD 专用 (Combat HUD) ---
const HUD_PANEL_BG := UI_ROOT + "hud_panel_bg_320x448.png"
const HUD_WEATHER_PANEL := UI_ROOT + "hud_weather_panel_280x120.png"
const HUD_SKILL_DOCK_FRAME := UI_ROOT + "hud_spell_dock_frame.png"
const HUD_SPELL_SLOT_READY_FRAME := UI_ROOT + "spell_slot_ready_frame_96.png"
const HUD_SPELL_SLOT_COOLDOWN_FRAME := UI_ROOT + "spell_slot_cooldown_frame_96.png"
const HUD_SPELL_SLOT_LOCKED_FRAME := UI_ROOT + "spell_slot_locked_frame_96.png"
const HUD_SPELL_SHORTCUT_BADGE := UI_ROOT + "spell_shortcut_badge_32.png"
const HUD_SPELL_COOLDOWN_SWEEP := UI_ROOT + "spell_cooldown_sweep_96.png"
const PROGRESS_HP := UI_ROOT + "progress_hp_9slice.png"
const PROGRESS_MANA := UI_ROOT + "progress_mana_9slice.png"
const COMBO_TRACK := UI_ROOT + "combo_track_256x8.png"
const ENEMY_HP_BAR := UI_ROOT + "enemy_hp_bar_9slice.png"
const ENEMY_NAMEPLATE := UI_ROOT + "enemy_nameplate_128x24.png"
const HUD_PET_HUO_YING_AVATAR_64 := HUD_UI_ROOT + "pet_huo_ying_avatar_64.png"
const HUD_PET_HUO_YING_AVATAR_96 := HUD_UI_ROOT + "pet_huo_ying_avatar_96.png"
const HUD_ARTIFACT_XUANYU_GOURD_64 := HUD_UI_ROOT + "artifact_xuanyu_gourd_pendant_64.png"
const HUD_ARTIFACT_XUANYU_GOURD_96 := HUD_UI_ROOT + "artifact_xuanyu_gourd_pendant_96.png"
const HUD_PET_HUO_YING_AVATAR := HUD_PET_HUO_YING_AVATAR_64
const HUD_ARTIFACT_XUANYU_GOURD := HUD_ARTIFACT_XUANYU_GOURD_64
const HUD_WEATHER_THUNDER_SIG := UI_ROOT + "hud_weather_thunder_sig_96.png"
const HUD_AUTO_SEAL_BASE := HUD_UI_ROOT + "auto_seal_attack_64.png"
const HUD_AUTO_SEAL_ATTACK := HUD_UI_ROOT + "auto_seal_attack_64.png"
const HUD_AUTO_SEAL_GUARD := HUD_UI_ROOT + "auto_seal_guard_64.png"
const HUD_AUTO_SEAL_PET := HUD_UI_ROOT + "auto_seal_pet_64.png"
const HUD_AUTO_SEAL_ARTIFACT := HUD_UI_ROOT + "auto_seal_artifact_64.png"
const HUD_LEFT_PANEL_FRAME := HUD_UI_ROOT + "hud_left_panel_frame_448x512.png"
const HUD_LEFT_OBJECTIVE_CARD := HUD_UI_ROOT + "hud_left_objective_card_384x112.png"
const HUD_LEFT_RESOURCE_TRACK := HUD_UI_ROOT + "hud_left_resource_track_384x32.png"
const HUD_LEFT_BUILD_BADGE := HUD_UI_ROOT + "hud_left_build_badge_320x40.png"
const HUD_LEFT_SECTION_DIVIDER := HUD_UI_ROOT + "hud_left_section_divider_320x24.png"
const HUD_AFFIX_RUNE_FIRE := HUD_UI_ROOT + "affix_rune_fire_64.png"
const HUD_AFFIX_RUNE_THUNDER := HUD_UI_ROOT + "affix_rune_thunder_64.png"
const HUD_AFFIX_RUNE_WATER := HUD_UI_ROOT + "affix_rune_water_64.png"
const HUD_AFFIX_RUNE_WOOD := HUD_UI_ROOT + "affix_rune_wood_64.png"
const HUD_AFFIX_RUNE_EARTH := HUD_UI_ROOT + "affix_rune_earth_64.png"
const HUD_AFFIX_RUNE_SEAL := HUD_UI_ROOT + "affix_rune_seal_64.png"

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

# --- 奖励卡框 (Reward card frames) ---
## 240x373 runtime frames match the 360x560 reward-card master ratio from the
## dark ink UIUX direction. Legacy QUALITY_FRAMES stay available for older UI.
const REWARD_CARD_FRAMES := [
	CARD_UI_ROOT + "card_reward_common_240x373.png",
	CARD_UI_ROOT + "card_reward_rare_240x373.png",
	CARD_UI_ROOT + "card_reward_epic_240x373.png",
	CARD_UI_ROOT + "card_reward_legendary_240x373.png",
	CARD_UI_ROOT + "card_reward_dao_240x373.png",
]
const REWARD_CARD_FORBIDDEN_OVERLAY := CARD_UI_ROOT + "card_reward_forbidden_overlay_240x373.png"
const REWARD_CARD_LOCKED_OVERLAY := CARD_UI_ROOT + "card_reward_locked_overlay_240x373.png"
const REWARD_QUALITY_AURA := CARD_UI_ROOT + "reward_quality_aura_256.png"
const REWARD_QUALITY_MOTE := CARD_UI_ROOT + "reward_quality_mote_64.png"
const REWARD_FORBIDDEN_REVERSE_MARK := CARD_UI_ROOT + "reward_forbidden_reverse_mark_128x48.png"

# --- 元素图标 (Element icons) ---
const ELEMENT_ICONS := {
	"fire": UI_ROOT + "elem_fire_32.png",
	"water": UI_ROOT + "elem_water_32.png",
	"thunder": UI_ROOT + "elem_thunder_32.png",
	"wood": UI_ROOT + "elem_wood_32.png",
	"earth": UI_ROOT + "elem_earth_32.png",
	"chaos": UI_ROOT + "elem_chaos_32.png",
	"soul": UI_ROOT + "elem_chaos_32.png",
	"none": UI_ROOT + "elem_chaos_32.png",
}

# --- 状态图标 (Combat status icons) ---
## Dedicated status PNGs may be added later; until then each status falls back
## to an element icon so combat readability does not depend on missing assets.
const STATUS_ICONS := {
	"burn": UI_ROOT + "status_burn_32.png",
	"ignite": UI_ROOT + "status_burn_32.png",
	"slow": UI_ROOT + "status_slow_32.png",
	"freeze": UI_ROOT + "status_freeze_32.png",
	"chill": UI_ROOT + "status_freeze_32.png",
	"paralyze": UI_ROOT + "status_paralyze_32.png",
	"shock": UI_ROOT + "status_paralyze_32.png",
	"stun": UI_ROOT + "status_paralyze_32.png",
	"poison": UI_ROOT + "status_poison_32.png",
	"root": UI_ROOT + "status_root_32.png",
	"bleed": UI_ROOT + "status_bleed_32.png",
	"curse": UI_ROOT + "status_curse_32.png",
	"wet": UI_ROOT + "status_wet_32.png",
	"elite": UI_ROOT + "status_elite_32.png",
	"boss": UI_ROOT + "status_boss_32.png",
	"promoted": UI_ROOT + "status_promoted_32.png",
	"shield": UI_ROOT + "status_shield_32.png",
	"guard": UI_ROOT + "status_shield_32.png",
	"haste": UI_ROOT + "status_haste_32.png",
	"dodge": UI_ROOT + "status_haste_32.png",
	"dao": UI_ROOT + "status_dao_32.png",
	"counter": UI_ROOT + "status_counter_32.png",
	"mutation": UI_ROOT + "status_mutation_32.png",
	"windup": UI_ROOT + "status_windup_32.png",
}

const STATUS_ICON_ELEMENT_FALLBACKS := {
	"burn": "fire",
	"ignite": "fire",
	"slow": "water",
	"freeze": "water",
	"chill": "water",
	"wet": "water",
	"paralyze": "thunder",
	"shock": "thunder",
	"stun": "thunder",
	"poison": "wood",
	"root": "wood",
	"elite": "earth",
	"boss": "earth",
	"promoted": "earth",
	"shield": "earth",
	"guard": "earth",
	"bleed": "chaos",
	"curse": "chaos",
	"dao": "chaos",
	"counter": "chaos",
	"mutation": "fire",
	"windup": "fire",
	"haste": "water",
	"dodge": "water",
}

## 机缘选择卡专用大图标（80px，避免 32px 拉伸模糊）
const ELEMENT_ICONS_LARGE := {
	"fire": UI_ROOT + "elem_fire_large_80.png",
	"water": UI_ROOT + "elem_water_large_80.png",
	"ice": UI_ROOT + "elem_ice_large_80.png",
	"thunder": UI_ROOT + "elem_thunder_large_80.png",
	"wood": UI_ROOT + "elem_wood_large_80.png",
	"earth": UI_ROOT + "elem_earth_large_80.png",
	"chaos": UI_ROOT + "elem_chaos_large_80.png",
	"soul": UI_ROOT + "elem_chaos_large_80.png",
	"none": UI_ROOT + "elem_chaos_large_80.png",
}

# --- 天象图标 (Weather icons) ---
const HUD_WEATHER_CLEAR_ICON := HUD_UI_ROOT + "weather_clear_icon_64.png"
const HUD_WEATHER_RAIN_ICON := HUD_UI_ROOT + "weather_rain_icon_64.png"
const HUD_WEATHER_THUNDER_ICON := HUD_UI_ROOT + "weather_thunder_icon_64.png"
const HUD_WEATHER_FIRE_ICON := HUD_UI_ROOT + "weather_fire_icon_64.png"
const HUD_WEATHER_WIND_ICON := HUD_UI_ROOT + "weather_wind_icon_64.png"
const HUD_WEATHER_FOG_ICON := HUD_UI_ROOT + "weather_fog_icon_64.png"
const HUD_WEATHER_SNOW_ICON := HUD_UI_ROOT + "weather_snow_icon_64.png"
const HUD_WEATHER_SAND_ICON := HUD_UI_ROOT + "weather_sand_icon_64.png"
const HUD_WEATHER_THUNDERSTORM_ICON := HUD_UI_ROOT + "weather_thunderstorm_icon_64.png"
const HUD_WEATHER_THUNDERSTORM_CHARM := HUD_UI_ROOT + "weather_thunderstorm_charm_160x96.png"

const HUD_WEATHER_ICONS := {
	"clear": HUD_WEATHER_CLEAR_ICON,
	"rain": HUD_WEATHER_RAIN_ICON,
	"thunder": HUD_WEATHER_THUNDER_ICON,
	"storm": HUD_WEATHER_THUNDERSTORM_ICON,
	"thunderstorm": HUD_WEATHER_THUNDERSTORM_ICON,
	"fire": HUD_WEATHER_FIRE_ICON,
	"wind": HUD_WEATHER_WIND_ICON,
	"fog": HUD_WEATHER_FOG_ICON,
	"snow": HUD_WEATHER_SNOW_ICON,
	"sand": HUD_WEATHER_SAND_ICON,
}

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
const HUD_SPELL_Q_FIRE_TALISMAN := HUD_UI_ROOT + "spell_q_fire_talisman_96.png"
const HUD_SPELL_E_JADE_SWORD_ARRAY := HUD_UI_ROOT + "spell_e_jade_sword_array_96.png"
const HUD_SPELL_R_THUNDER_FAN := HUD_UI_ROOT + "spell_r_thunder_fan_96.png"
const HUD_SPELL_LOCKED_JADE_SEAL := HUD_UI_ROOT + "spell_locked_jade_seal_96.png"
const HUD_SPELL_LIE_YAN_BOLT := HUD_UI_ROOT + "spell_lie_yan_bolt_96.png"
const HUD_SPELL_YU_JIAN_THRUST := HUD_UI_ROOT + "spell_yu_jian_thrust_96.png"
const HUD_SPELL_QI_FU := HUD_UI_ROOT + "spell_qi_fu_96.png"
const HUD_SPELL_SUMMON_SOUL := HUD_UI_ROOT + "spell_summon_soul_96.png"
const HUD_SPELL_LEI_CHI_STRIKE := HUD_UI_ROOT + "spell_lei_chi_strike_96.png"
const HUD_SPELL_LEI_CHI_CHAIN := HUD_UI_ROOT + "spell_lei_chi_chain_96.png"
const HUD_SPELL_XUAN_BING_FAN := HUD_UI_ROOT + "spell_xuan_bing_fan_96.png"
const HUD_SPELL_XUAN_BING_LANCE := HUD_UI_ROOT + "spell_xuan_bing_lance_96.png"
const HUD_SPELL_HUI_CHUN_JUE := HUD_UI_ROOT + "spell_hui_chun_jue_96.png"

const SPELL_ICONS := {
	"q": HUD_SPELL_Q_FIRE_TALISMAN,
	"e": HUD_SPELL_E_JADE_SWORD_ARRAY,
	"r": HUD_SPELL_R_THUNDER_FAN,
	"q_locked": HUD_SPELL_LOCKED_JADE_SEAL,
	"e_locked": HUD_SPELL_LOCKED_JADE_SEAL,
	"r_locked": HUD_SPELL_LOCKED_JADE_SEAL,
}

const SPELL_ICONS_BY_ID := {
	"lie_yan_bolt": HUD_SPELL_LIE_YAN_BOLT,
	"yu_jian_thrust": HUD_SPELL_YU_JIAN_THRUST,
	"qi_fu": HUD_SPELL_QI_FU,
	"summon_soul": HUD_SPELL_SUMMON_SOUL,
	"lei_chi_strike": HUD_SPELL_LEI_CHI_STRIKE,
	"lei_chi_chain": HUD_SPELL_LEI_CHI_CHAIN,
	"xuan_bing_fan": HUD_SPELL_XUAN_BING_FAN,
	"xuan_bing_lance": HUD_SPELL_XUAN_BING_LANCE,
	"hui_chun_jue": HUD_SPELL_HUI_CHUN_JUE,
}

const SPELL_ICONS_BY_ELEMENT := {
	"fire": HUD_SPELL_Q_FIRE_TALISMAN,
	"thunder": HUD_SPELL_R_THUNDER_FAN,
	"lightning": HUD_SPELL_R_THUNDER_FAN,
	"water": HUD_SPELL_XUAN_BING_FAN,
	"ice": HUD_SPELL_XUAN_BING_FAN,
	"wood": HUD_SPELL_HUI_CHUN_JUE,
	"earth": ELEMENT_ICONS_LARGE["earth"],
	"chaos": HUD_SPELL_SUMMON_SOUL,
	"soul": HUD_SPELL_SUMMON_SOUL,
	"void": HUD_SPELL_SUMMON_SOUL,
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
const ENEMY_BOSS_THUNDER_NORMAL := SPRITE_ROOT + "enemy_thunder_elite_ingame_64.png"
const ENEMY_BOSS_THUNDER_CHIBI := SPRITE_ROOT + "enemy_thunder_elite_chibi_64.png"

const PROJECTILE_FIRE := SPRITE_ROOT + "projectile_fire_16.png"
const PROJECTILE_THUNDER := SPRITE_ROOT + "projectile_thunder_16.png"
const PROJECTILE_ICE := SPRITE_ROOT + "projectile_ice_16.png"
const PROJECTILE_WATER := SPRITE_ROOT + "projectile_water_16.png"
const PROJECTILE_WOOD := SPRITE_ROOT + "projectile_wood_16.png"
const PROJECTILE_EARTH := SPRITE_ROOT + "projectile_earth_16.png"
const PROJECTILE_GENERIC := SPRITE_ROOT + "projectile_generic_16.png"
const PROJECTILE_CHAOS := SPRITE_ROOT + "projectile_chaos_16.png"

const WEATHER_DECALS := {
	"clear": FX_ROOT + "weather_decal_clear_128.png",
	"rain": FX_ROOT + "weather_decal_rain_128.png",
	"thunder": FX_ROOT + "weather_decal_thunder_128.png",
	"storm": FX_ROOT + "weather_decal_thunder_128.png",
	"thunderstorm": FX_ROOT + "weather_decal_thunder_128.png",
	"fire": FX_ROOT + "weather_decal_fire_128.png",
	"wind": FX_ROOT + "weather_decal_wind_128.png",
	"fog": FX_ROOT + "weather_decal_fog_128.png",
	"snow": FX_ROOT + "weather_decal_snow_128.png",
	"sand": FX_ROOT + "weather_decal_sand_128.png",
}

const WEATHER_OVERLAY_PARTICLES := {
	"clear": FX_ROOT + "weather_particle_clear_64.png",
	"rain": FX_ROOT + "weather_particle_rain_64x96.png",
	"thunder": FX_ROOT + "weather_particle_thunder_64x96.png",
	"storm": FX_ROOT + "weather_particle_thunder_64x96.png",
	"thunderstorm": FX_ROOT + "weather_particle_thunder_64x96.png",
	"fire": FX_ROOT + "weather_particle_fire_64.png",
	"wind": FX_ROOT + "weather_particle_wind_128x64.png",
	"fog": FX_ROOT + "weather_particle_fog_128.png",
	"snow": FX_ROOT + "weather_particle_snow_64.png",
	"sand": FX_ROOT + "weather_particle_sand_96x64.png",
}

const ENEMY_PROJECTILE_TRAILS := {
	"generic": FX_ROOT + "enemy_projectile_trail_generic_128x48.png",
	"fire": FX_ROOT + "enemy_projectile_trail_fire_128x48.png",
	"thunder": FX_ROOT + "enemy_projectile_trail_thunder_128x48.png",
	"lightning": FX_ROOT + "enemy_projectile_trail_thunder_128x48.png",
	"ice": FX_ROOT + "enemy_projectile_trail_ice_128x48.png",
	"water": FX_ROOT + "enemy_projectile_trail_water_128x48.png",
	"wood": FX_ROOT + "enemy_projectile_trail_wood_128x48.png",
	"earth": FX_ROOT + "enemy_projectile_trail_earth_128x48.png",
	"chaos": FX_ROOT + "enemy_projectile_trail_chaos_128x48.png",
	"soul": FX_ROOT + "enemy_projectile_trail_chaos_128x48.png",
	"void": FX_ROOT + "enemy_projectile_trail_chaos_128x48.png",
}

const THUNDER_STRIKE_WARNING := FX_ROOT + "thunder_strike_warning_192.png"
const THUNDER_STRIKE_IMPACT := FX_ROOT + "thunder_strike_impact_192.png"
const THUNDER_STRIKE_BOLT := FX_ROOT + "thunder_strike_bolt_128x512.png"
const THUNDER_STRIKE_SCORCH := FX_ROOT + "thunder_strike_scorch_192.png"

const ENEMY_SPAWN_TELEGRAPH := FX_ROOT + "enemy_spawn_telegraph_128.png"
const ENEMY_SPAWN_TELEGRAPH_ELITE := FX_ROOT + "enemy_spawn_telegraph_elite_128.png"
const ENEMY_ATTACK_LINE := FX_ROOT + "enemy_attack_line_256x64.png"
const ENEMY_ATTACK_DASH := FX_ROOT + "enemy_attack_dash_256x96.png"
const ENEMY_ATTACK_SNIPER := FX_ROOT + "enemy_attack_sniper_256x48.png"
const ENEMY_ATTACK_MELEE := FX_ROOT + "enemy_attack_melee_128.png"

const FX_PLAYER_SLASH_ARC := FX_ROOT + "player_slash_arc_192x128.png"
const FX_CRIT_SCREEN_SLASH := FX_ROOT + "crit_screen_slash_640x180.png"
const FX_ENEMY_WINDUP_SEAL := FX_ROOT + "enemy_windup_seal_160.png"
const FX_ACTOR_PRESENCE_SHADOW := FX_ROOT + "actor_presence_shadow_128x64.png"
const FX_PLAYER_DAO_AURA := FX_ROOT + "player_dao_aura_160.png"
const FX_PLAYER_COUNTER_AURA := FX_ROOT + "player_counter_aura_160.png"
const FX_ENEMY_IDENTITY_RING_ELITE := FX_ROOT + "enemy_identity_ring_elite_160.png"
const FX_ENEMY_IDENTITY_RING_BOSS := FX_ROOT + "enemy_identity_ring_boss_192.png"
const FX_ENEMY_GUARD_AURA := FX_ROOT + "enemy_guard_aura_192.png"
const FX_STATUS_BADGE_BACKING := FX_ROOT + "status_badge_backing_48.png"
const FX_DAO_PATTERN_FIRE := FX_ROOT + "dao_pattern_fire_256.png"
const FX_DAO_PATTERN_THUNDER := FX_ROOT + "dao_pattern_thunder_256.png"
const FX_DAO_PATTERN_WOOD := FX_ROOT + "dao_pattern_wood_256.png"
const FX_DAO_PATTERN_WATER := FX_ROOT + "dao_pattern_water_256.png"
const FX_DAO_PATTERN_FIVE := FX_ROOT + "dao_pattern_five_256.png"
const FX_CRIT_EDGE_TOP := FX_ROOT + "crit_edge_top_512x96.png"
const FX_CRIT_EDGE_SIDE := FX_ROOT + "crit_edge_side_96x512.png"
const FX_CRIT_EDGE_CORNER := FX_ROOT + "crit_edge_corner_192.png"

const COMBAT_ACTION_FX := {
	"player_slash_arc": FX_PLAYER_SLASH_ARC,
	"crit_screen_slash": FX_CRIT_SCREEN_SLASH,
	"enemy_windup_seal": FX_ENEMY_WINDUP_SEAL,
	"actor_presence_shadow": FX_ACTOR_PRESENCE_SHADOW,
	"player_dao_aura": FX_PLAYER_DAO_AURA,
	"player_counter_aura": FX_PLAYER_COUNTER_AURA,
	"enemy_identity_ring_elite": FX_ENEMY_IDENTITY_RING_ELITE,
	"enemy_identity_ring_boss": FX_ENEMY_IDENTITY_RING_BOSS,
	"enemy_guard_aura": FX_ENEMY_GUARD_AURA,
	"status_badge_backing": FX_STATUS_BADGE_BACKING,
	"dao_pattern_fire": FX_DAO_PATTERN_FIRE,
	"dao_pattern_thunder": FX_DAO_PATTERN_THUNDER,
	"dao_pattern_wood": FX_DAO_PATTERN_WOOD,
	"dao_pattern_water": FX_DAO_PATTERN_WATER,
	"dao_pattern_five": FX_DAO_PATTERN_FIVE,
	"crit_edge_top": FX_CRIT_EDGE_TOP,
	"crit_edge_side": FX_CRIT_EDGE_SIDE,
	"crit_edge_corner": FX_CRIT_EDGE_CORNER,
}

const ENEMY_WINDUP_WEAPONS := {
	"claw": FX_ROOT + "enemy_weapon_claw_96x64.png",
	"wind_blade": FX_ROOT + "enemy_weapon_claw_96x64.png",
	"mud_bow": FX_ROOT + "enemy_weapon_crossbow_112x64.png",
	"cloud_crossbow": FX_ROOT + "enemy_weapon_crossbow_112x64.png",
	"furnace_core": FX_ROOT + "enemy_weapon_furnace_core_96.png",
	"xuanwu_shield": FX_ROOT + "enemy_weapon_xuanwu_shield_96.png",
	"soul_banner": FX_ROOT + "enemy_weapon_soul_banner_96x128.png",
	"poison_spit": FX_ROOT + "enemy_weapon_poison_spit_80x64.png",
}

const PROJECTILES_BY_ELEMENT := {
	"fire": PROJECTILE_FIRE,
	"thunder": PROJECTILE_THUNDER,
	"lightning": PROJECTILE_THUNDER,
	"water": PROJECTILE_WATER,
	"ice": PROJECTILE_ICE,
	"chaos": PROJECTILE_CHAOS,
	"soul": PROJECTILE_CHAOS,
	"void": PROJECTILE_CHAOS,
	"wood": PROJECTILE_WOOD,
	"earth": PROJECTILE_EARTH,
}

const PROJECTILE_ELEMENT_BY_STATUS := {
	"burn": "fire",
	"ignite": "fire",
	"shock": "thunder",
	"stun": "thunder",
	"slow": "ice",
	"freeze": "ice",
	"chill": "ice",
	"poison": "wood",
	"root": "wood",
	"bleed": "chaos",
	"curse": "chaos",
}

const STYLE_NORMAL := "normal"
const STYLE_CHIBI := "chibi"
const DEFAULT_SPRITE_STYLE := STYLE_NORMAL

const PLAYER_STYLE_PATHS := {
	STYLE_NORMAL: SPRITE_ROOT + "player_style_normal_64.png",
	STYLE_CHIBI: SPRITE_ROOT + "player_style_chibi_64.png",
}

const PLAYER_STYLE_PATHS_128 := {
	STYLE_NORMAL: SPRITE_ROOT + "player_style_normal_128.png",
	STYLE_CHIBI: SPRITE_ROOT + "player_style_chibi_128.png",
}

const ENEMY_STYLE_PATHS := {
	"normal": {
		"normal": SPRITE_ROOT + "enemy_style_normal_melee_64.png",
		"ranged": SPRITE_ROOT + "enemy_style_normal_ranged_64.png",
		"sniper": SPRITE_ROOT + "enemy_style_normal_ranged_64.png",
		"berserker": SPRITE_ROOT + "enemy_style_normal_melee_64.png",
		"skirmisher": SPRITE_ROOT + "enemy_style_normal_melee_64.png",
		"shaman": SPRITE_ROOT + "enemy_style_normal_ranged_64.png",
		"elite": SPRITE_ROOT + "enemy_style_normal_elite_64.png",
		"boss": ENEMY_BOSS_THUNDER_NORMAL,
	},
	"chibi": {
		"normal": SPRITE_ROOT + "enemy_style_chibi_melee_64.png",
		"ranged": SPRITE_ROOT + "enemy_style_chibi_ranged_64.png",
		"sniper": SPRITE_ROOT + "enemy_style_chibi_ranged_64.png",
		"berserker": SPRITE_ROOT + "enemy_style_chibi_melee_64.png",
		"skirmisher": SPRITE_ROOT + "enemy_style_chibi_melee_64.png",
		"shaman": SPRITE_ROOT + "enemy_style_chibi_ranged_64.png",
		"elite": SPRITE_ROOT + "enemy_style_chibi_elite_64.png",
		"boss": ENEMY_BOSS_THUNDER_CHIBI,
	},
}


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
		7: return ELEMENT_ICONS["soul"]
		_: return ELEMENT_ICONS["none"]


static func elem_icon_large(element_id: int) -> String:
	## 机缘选择卡用大图标；缺失时回退到 32px，避免资源缺口影响运行时。
	var key := ""
	match element_id:
		1: key = "fire"
		2: key = "water"
		3: key = "thunder"
		4: key = "wood"
		5: key = "earth"
		6: key = "chaos"
		7: key = "soul"
		_: key = "none"
	var dedicated := str(ELEMENT_ICONS_LARGE.get(key, ""))
	if not dedicated.is_empty() and ResourceLoader.exists(dedicated):
		return dedicated
	return elem_icon(element_id)


static func quality_frame(quality: int) -> String:
	var tier := clampi(quality, 0, QUALITY_FRAMES.size() - 1)
	return QUALITY_FRAMES[tier]


static func reward_card_frame(quality: int) -> String:
	var tier := clampi(quality, 0, REWARD_CARD_FRAMES.size() - 1)
	return REWARD_CARD_FRAMES[tier]


static func weather_icon(weather_id: String) -> String:
	var hud_icon := str(HUD_WEATHER_ICONS.get(weather_id, ""))
	if not hud_icon.is_empty() and ResourceLoader.exists(hud_icon):
		return hud_icon
	return WEATHER_ICONS.get(weather_id, WEATHER_ICONS["clear"])


static func status_icon(status_name: String) -> String:
	var key := status_name.strip_edges().to_lower()
	var dedicated := str(STATUS_ICONS.get(key, ""))
	if not dedicated.is_empty() and ResourceLoader.exists(dedicated):
		return dedicated
	var element_key := str(STATUS_ICON_ELEMENT_FALLBACKS.get(key, "none"))
	return ELEMENT_ICONS.get(element_key, ELEMENT_ICONS["none"])


static func spell_icon(spell_id: String, element: String, slot: String, unlocked: bool) -> String:
	var slot_key := slot.strip_edges().to_lower()
	if not unlocked:
		return str(SPELL_ICONS.get("%s_locked" % slot_key, HUD_SPELL_LOCKED_JADE_SEAL))
	var id_key := spell_id.strip_edges().to_lower()
	var dedicated := str(SPELL_ICONS_BY_ID.get(id_key, ""))
	if not dedicated.is_empty() and ResourceLoader.exists(dedicated):
		return dedicated
	var element_key := _normalize_spell_element(element)
	var element_icon := str(SPELL_ICONS_BY_ELEMENT.get(element_key, ""))
	if not element_icon.is_empty() and ResourceLoader.exists(element_icon):
		return element_icon
	return str(SPELL_ICONS.get(slot_key, SPELL_ICONS["q"]))


static func spell_slot_frame(ready: bool, unlocked: bool) -> String:
	if not unlocked:
		return HUD_SPELL_SLOT_LOCKED_FRAME
	return HUD_SPELL_SLOT_READY_FRAME if ready else HUD_SPELL_SLOT_COOLDOWN_FRAME


static func spell_shortcut_badge() -> String:
	return HUD_SPELL_SHORTCUT_BADGE


static func spell_cooldown_sweep() -> String:
	return HUD_SPELL_COOLDOWN_SWEEP


static func weather_panel_frame(weather_id: String) -> String:
	if weather_id == "thunder" or weather_id == "storm" or weather_id == "thunderstorm":
		if ResourceLoader.exists(HUD_WEATHER_THUNDERSTORM_CHARM):
			return HUD_WEATHER_THUNDERSTORM_CHARM
	return HUD_WEATHER_PANEL


static func karma_icon(karma_key: String) -> String:
	return KARMA_ICONS.get(karma_key, ELEMENT_ICONS["wood"])


static func enemy_sprite(archetype: String, is_boss: bool = false) -> String:
	return enemy_sprite_for_style(archetype, is_boss, DEFAULT_SPRITE_STYLE)


static func sprite_style(style: String) -> String:
	var normalized: String = style.strip_edges().to_lower()
	if normalized == STYLE_CHIBI:
		return STYLE_CHIBI
	return STYLE_NORMAL


static func player_sprite(style: String = DEFAULT_SPRITE_STYLE, size: int = 64) -> String:
	var resolved_style: String = sprite_style(style)
	var path: String = str(PLAYER_STYLE_PATHS.get(resolved_style, PLAYER))
	if size >= 128:
		path = str(PLAYER_STYLE_PATHS_128.get(resolved_style, path))
	if ResourceLoader.exists(path):
		return path
	return PLAYER


static func enemy_sprite_for_style(archetype: String, is_boss: bool = false, style: String = DEFAULT_SPRITE_STYLE) -> String:
	var resolved_style: String = sprite_style(style)
	var style_map: Dictionary = ENEMY_STYLE_PATHS.get(resolved_style, {})
	var key: String = "boss" if is_boss else archetype
	var path: String = str(style_map.get(key, ""))
	if path.is_empty():
		path = str(style_map.get("normal", ENEMY_TRAINING))
	if ResourceLoader.exists(path):
		return path
	if is_boss:
		return ENEMY_BERSERKER
	match archetype:
		"berserker": return ENEMY_BERSERKER
		"sniper": return ENEMY_ARCHER
		"ranged": return ENEMY_BOMBER
		"shaman": return ENEMY_ARCHER
		_: return ENEMY_TRAINING


static func enemy_sprite_for_identity(enemy_id: String, archetype: String, is_boss: bool = false, style: String = DEFAULT_SPRITE_STYLE) -> String:
	var id_key := enemy_id.strip_edges().to_lower()
	var resolved_style: String = sprite_style(style)
	if not id_key.is_empty() and id_key != "boss":
		if resolved_style == STYLE_CHIBI:
			var chibi_dedicated := SPRITE_ROOT + "enemy_%s_chibi_64.png" % id_key
			if ResourceLoader.exists(chibi_dedicated):
				return chibi_dedicated
		var dedicated := SPRITE_ROOT + "enemy_%s_64.png" % id_key
		if ResourceLoader.exists(dedicated):
			return dedicated
	return enemy_sprite_for_style(archetype, is_boss, resolved_style)


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


static func projectile_for_semantics(element: String = "", status: String = "", fallback_color: Color = Color.TRANSPARENT) -> String:
	var resolved_element := _normalize_projectile_element(element, status)
	if PROJECTILES_BY_ELEMENT.has(resolved_element):
		return str(PROJECTILES_BY_ELEMENT[resolved_element])
	if fallback_color != Color.TRANSPARENT:
		return projectile_for_color(fallback_color)
	return PROJECTILE_GENERIC


static func weather_decal(weather_id: String) -> String:
	var key := weather_id.strip_edges().to_lower()
	var path := str(WEATHER_DECALS.get(key, WEATHER_DECALS["clear"]))
	if ResourceLoader.exists(path):
		return path
	return ""


static func weather_overlay_particle(weather_id: String) -> String:
	var key := weather_id.strip_edges().to_lower()
	var path := str(WEATHER_OVERLAY_PARTICLES.get(key, WEATHER_OVERLAY_PARTICLES["clear"]))
	if ResourceLoader.exists(path):
		return path
	return ""


static func enemy_projectile_trail(element: String = "", status: String = "") -> String:
	var key := _normalize_projectile_element(element, status)
	if key.is_empty():
		key = "generic"
	var path := str(ENEMY_PROJECTILE_TRAILS.get(key, ENEMY_PROJECTILE_TRAILS["generic"]))
	if ResourceLoader.exists(path):
		return path
	return ""


static func projectile_trail(element: String = "", status: String = "") -> String:
	return enemy_projectile_trail(element, status)


static func enemy_spawn_telegraph(elite: bool = false) -> String:
	var path := ENEMY_SPAWN_TELEGRAPH_ELITE if elite else ENEMY_SPAWN_TELEGRAPH
	if ResourceLoader.exists(path):
		return path
	return ""


static func enemy_attack_telegraph(kind: String = "line") -> String:
	var key := kind.strip_edges().to_lower()
	var path := ENEMY_ATTACK_LINE
	match key:
		"dash":
			path = ENEMY_ATTACK_DASH
		"sniper":
			path = ENEMY_ATTACK_SNIPER
		"melee":
			path = ENEMY_ATTACK_MELEE
	if ResourceLoader.exists(path):
		return path
	return ""


static func combat_action_fx(key: String) -> String:
	var normalized := key.strip_edges().to_lower()
	var path := str(COMBAT_ACTION_FX.get(normalized, ""))
	if ResourceLoader.exists(path):
		return path
	return ""


static func enemy_windup_weapon(weapon_id: String) -> String:
	var key := weapon_id.strip_edges().to_lower()
	var path := str(ENEMY_WINDUP_WEAPONS.get(key, ENEMY_WINDUP_WEAPONS["claw"]))
	if ResourceLoader.exists(path):
		return path
	return combat_action_fx("enemy_windup_seal")


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


static func animation_dir_for_texture(path: String) -> String:
	var slug := _sprite_slug(path)
	if slug.is_empty():
		return ""
	return SPRITE_FRAME_ROOT + slug


static func animation_prefix_for_texture(path: String) -> String:
	var slug := _sprite_slug(path)
	if slug.begins_with("projectile_"):
		return "fly"
	if slug.begins_with("impact_"):
		return "impact"
	return "idle"


static func animation_frame_paths_for_texture(path: String, prefix: String = "") -> Array[String]:
	var dir_path := animation_dir_for_texture(path)
	if dir_path.is_empty():
		return []
	var resolved_prefix := prefix if not prefix.is_empty() else animation_prefix_for_texture(path)
	return animation_frame_paths(dir_path, resolved_prefix)


static func impact_frame_paths_for_color(color: Color) -> Array[String]:
	var projectile_slug := _sprite_slug(projectile_for_color(color))
	if projectile_slug.is_empty():
		return []
	var impact_slug := projectile_slug.replace("projectile_", "impact_")
	return animation_frame_paths(SPRITE_FRAME_ROOT + impact_slug, "impact")


static func impact_frame_paths_for_semantics(element: String = "", status: String = "", fallback_color: Color = Color.TRANSPARENT) -> Array[String]:
	var projectile_slug := _sprite_slug(projectile_for_semantics(element, status, fallback_color))
	if not projectile_slug.is_empty():
		var semantic_frames := animation_frame_paths(SPRITE_FRAME_ROOT + projectile_slug.replace("projectile_", "impact_"), "impact")
		if not semantic_frames.is_empty():
			return semantic_frames
	if fallback_color != Color.TRANSPARENT:
		return impact_frame_paths_for_color(fallback_color)
	return animation_frame_paths(SPRITE_FRAME_ROOT + "impact_generic", "impact")


static func animation_frame_paths(dir_path: String, prefix: String = "") -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".png"):
			continue
		if not prefix.is_empty() and not file_name.begins_with(prefix + "_"):
			continue
		result.append(dir_path.path_join(file_name))
	return result


static func _sprite_slug(path: String) -> String:
	if path.is_empty():
		return ""
	var slug := path.get_file().get_basename()
	var last_underscore := slug.rfind("_")
	if last_underscore <= 0:
		return slug
	var suffix := slug.substr(last_underscore + 1)
	if suffix.is_valid_int():
		return slug.substr(0, last_underscore)
	return slug


static func _normalize_projectile_element(element: String, status: String = "") -> String:
	var normalized := element.strip_edges().to_lower()
	if normalized.is_empty() or normalized == "none" or normalized == "neutral":
		var status_key := status.strip_edges().to_lower()
		normalized = str(PROJECTILE_ELEMENT_BY_STATUS.get(status_key, ""))
	return normalized


static func _normalize_spell_element(element: String) -> String:
	var normalized := element.strip_edges().to_lower()
	if normalized == "none" or normalized == "neutral":
		return ""
	return normalized
