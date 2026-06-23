#!/usr/bin/env python3
"""QA visual asset coverage for Samsara Ascension.

The report is intentionally scoped to runtime-critical visual assets. Optional
large art that has a code fallback is reported as a warning instead of a hard
failure.
"""

from __future__ import annotations

import json
import re
import struct
import sys
import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
GAME_ROOT = REPO_ROOT / "game"
ASSET_PATHS = GAME_ROOT / "assets" / "asset_paths.gd"
MAP_MANIFEST = GAME_ROOT / "assets" / "maps" / "runtime_scene_manifest.json"
UNIFIED_IMAGE2_STATUS = REPO_ROOT / "output" / "imagegen" / "unified_ink_image2" / "image2_unified_assets_status.json"
UNIFIED_IMAGE2_SUMMARY = REPO_ROOT / "output" / "imagegen" / "unified_ink_image2" / "image2_unified_assets_summary.json"
PET_CONTROLLER = GAME_ROOT / "systems" / "pet" / "pet_controller.gd"
PLAYER_SCENE = GAME_ROOT / "scenes" / "player" / "player.tscn"
TRAINING_DUMMY_SCENE = GAME_ROOT / "scenes" / "enemies" / "training_dummy.tscn"
WORLD_ENEMY_HEALTH_BAR_SCRIPT = GAME_ROOT / "ui" / "components" / "world_enemy_health_bar.gd"
WORLD_ENEMY_HEALTH_BAR_SCENE = GAME_ROOT / "ui" / "components" / "world_enemy_health_bar.tscn"
PET_SCENE = GAME_ROOT / "scenes" / "pet" / "pet.tscn"
STATUS_COMPONENT = GAME_ROOT / "systems" / "combat" / "status_component.gd"
VFX_LIBRARY = GAME_ROOT / "vfx" / "vfx_library.gd"
VFX_MANAGER = GAME_ROOT / "autoload" / "vfx_manager.gd"
COMBAT_FLOOR = GAME_ROOT / "scenes" / "rooms" / "combat_floor.gd"
WEATHER_OVERLAY = GAME_ROOT / "scenes" / "visual" / "weather_overlay.gd"
SPRITE_VISUAL_SCRIPT = GAME_ROOT / "scenes" / "visual" / "sprite_visual.gd"
PROJECTILE_SCRIPT = GAME_ROOT / "scenes" / "combat" / "projectile.gd"
ENEMY_PROJECTILE_SCRIPT = GAME_ROOT / "scenes" / "combat" / "enemy_projectile.gd"
COMBAT_SPAWNER = GAME_ROOT / "autoload" / "combat_spawner.gd"
ENEMY_SKILL_CONTROLLER = GAME_ROOT / "systems" / "combat" / "enemy_skill_controller.gd"
ENEMY_SPAWN_REGISTRY = GAME_ROOT / "systems" / "combat" / "enemy_spawn_registry.gd"
TRAINING_DUMMY_SCRIPT = GAME_ROOT / "scenes" / "enemies" / "training_dummy.gd"
WEAPONS_CSV = GAME_ROOT / "data" / "weapons" / "weapons.csv"
PATHS_CSV = GAME_ROOT / "data" / "paths" / "cultivation_paths.csv"
ENEMIES_CSV = GAME_ROOT / "data" / "enemies" / "enemies.csv"
HUD_SCRIPT = GAME_ROOT / "scenes" / "ui" / "hud.gd"
SAVE_MANAGER = GAME_ROOT / "autoload" / "save_manager.gd"
RUN_CONTEXT = GAME_ROOT / "autoload" / "run_context.gd"
TOP_ANNOUNCEMENT_SCRIPT = GAME_ROOT / "scenes" / "ui" / "top_announcement_overlay.gd"
TOP_ANNOUNCEMENT_SCENE = GAME_ROOT / "scenes" / "ui" / "top_announcement_overlay.tscn"
DAO_TRADITION_SCRIPT = GAME_ROOT / "scenes" / "ui" / "dao_tradition_overlay.gd"
DAO_TRADITION_SCENE = GAME_ROOT / "scenes" / "ui" / "dao_tradition_overlay.tscn"
CRIT_MOMENT_SCRIPT = GAME_ROOT / "scenes" / "ui" / "crit_moment_overlay.gd"
CRIT_MOMENT_SCENE = GAME_ROOT / "scenes" / "ui" / "crit_moment_overlay.tscn"
COMBAT_FEEDBACK_SCRIPT = GAME_ROOT / "scenes" / "ui" / "combat_feedback_layer.gd"
RUN_RESULT_PANEL = GAME_ROOT / "scenes" / "ui" / "run_result_panel.gd"
RUN_RESULT_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "run_result_panel.tscn"
EVENT_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "event_panel.gd"
EVENT_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "event_panel.tscn"
PAUSE_OVERLAY_SCRIPT = GAME_ROOT / "scenes" / "ui" / "pause_overlay.gd"
PAUSE_OVERLAY_SCENE = GAME_ROOT / "scenes" / "ui" / "pause_overlay.tscn"
RUN_SETUP_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "run_setup_panel.gd"
RUN_SETUP_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "run_setup_panel.tscn"
PATH_CHOICE_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "path_choice_panel.gd"
PATH_CHOICE_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "path_choice_panel.tscn"
SHOP_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "shop_panel.gd"
SHOP_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "shop_panel.tscn"
DEATH_MOMENT_SCRIPT = GAME_ROOT / "scenes" / "ui" / "death_moment_overlay.gd"
DEATH_MOMENT_SCENE = GAME_ROOT / "scenes" / "ui" / "death_moment_overlay.tscn"
LEGACY_SELECT_SCRIPT = GAME_ROOT / "scenes" / "ui" / "legacy_select_panel.gd"
LEGACY_SELECT_SCENE = GAME_ROOT / "scenes" / "ui" / "legacy_select_panel.tscn"
META_UPGRADE_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "meta_upgrade_panel.gd"
META_UPGRADE_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "meta_upgrade_panel.tscn"
BREAKTHROUGH_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "breakthrough_panel.gd"
BREAKTHROUGH_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "breakthrough_panel.tscn"
WEAPON_MOD_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "weapon_mod_choice_panel.gd"
WEAPON_MOD_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "weapon_mod_choice_panel.tscn"
JADE_CODEX_OVERLAY = GAME_ROOT / "ui" / "components" / "hud_jade_codex_overlay.gd"
QA_GAMEPLAY_WRAPPER = GAME_ROOT / "tools" / "qa_gameplay_systems.py"
QA_RUN_FLOW_WRAPPER = GAME_ROOT / "tools" / "qa_run_flow_contract.py"
QA_FLOW_UI_SCRIPT = GAME_ROOT / "tools" / "qa_flow_ui_1920.gd"
QA_FLOW_UI_WRAPPER = GAME_ROOT / "tools" / "qa_flow_ui_1920.py"
QA_COMBAT_OVERLAYS_SCRIPT = GAME_ROOT / "tools" / "qa_combat_overlays_1920.gd"
QA_COMBAT_OVERLAYS_WRAPPER = GAME_ROOT / "tools" / "qa_combat_overlays_1920.py"
QA_VISUAL_INTEGRATION_SCRIPT = GAME_ROOT / "tools" / "qa_visual_integration_1920.gd"
QA_VISUAL_INTEGRATION_WRAPPER = GAME_ROOT / "tools" / "qa_visual_integration_1920.py"
QA_ENEMY_IDENTITY_SCRIPT = GAME_ROOT / "tools" / "qa_enemy_identity_showcase_1920.gd"
QA_ENEMY_IDENTITY_WRAPPER = GAME_ROOT / "tools" / "qa_enemy_identity_showcase_1920.py"
QA_VISUAL_REGRESSION = GAME_ROOT / "tools" / "qa_visual_regression_1920.py"
AFFIX_CARD_SCRIPT = GAME_ROOT / "ui" / "components" / "affix_card.gd"
AFFIX_CARD_SCENE = GAME_ROOT / "ui" / "components" / "affix_card.tscn"
AFFIX_CHOICE_PANEL_SCRIPT = GAME_ROOT / "scenes" / "ui" / "affix_choice_panel.gd"
AFFIX_CHOICE_PANEL_SCENE = GAME_ROOT / "scenes" / "ui" / "affix_choice_panel.tscn"
QUALITY_GLOW_SCRIPT = GAME_ROOT / "ui" / "components" / "quality_glow.gd"
HUD_WEATHER_PANEL_SCRIPT = GAME_ROOT / "ui" / "components" / "hud_weather_panel.gd"
HUD_SKILL_DOCK_SCRIPT = GAME_ROOT / "ui" / "components" / "hud_skill_dock.gd"
HUD_SKILL_DOCK_SCENE = GAME_ROOT / "ui" / "components" / "hud_skill_dock.tscn"
HUD_STATUS_ORBS_SCRIPT = GAME_ROOT / "ui" / "components" / "hud_status_orbs.gd"
HUD_COMPANION_ARTIFACT_PANEL_SCRIPT = GAME_ROOT / "ui" / "components" / "hud_companion_artifact_panel.gd"
HUD_COMBAT_RAIL_SCRIPT = GAME_ROOT / "ui" / "components" / "hud_combat_rail.gd"
SPELL_SLOT_SCRIPT = GAME_ROOT / "ui" / "components" / "spell_slot.gd"
SPELL_SLOT_SCENE = GAME_ROOT / "ui" / "components" / "spell_slot.tscn"
SPELL_ICON_FRAME_SCRIPT = GAME_ROOT / "ui" / "components" / "spell_icon_frame.gd"
TALENT_CARD_SCRIPT = GAME_ROOT / "ui" / "components" / "talent_card.gd"
TALENT_CARD_SCENE = GAME_ROOT / "ui" / "components" / "talent_card.tscn"

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
RES_PATH_RE = re.compile(r'"(res://[^"]+)"')
DICT_BLOCK_RE_TEMPLATE = r"const\s+{name}\s*:=\s*\{{(?P<body>.*?)\n\}}"
DICT_ENTRY_RE = re.compile(r'"(?P<key>[^"]+)"\s*:\s*(?P<value>[^,\n]+)')
UI_ROOT_CONCAT_RE = re.compile(r'UI_ROOT\s*\+\s*"(?P<suffix>[^"]+)"')
STRING_RE = re.compile(r'"(?P<value>[^"]+)"')
VECTOR2_RE = re.compile(r"Vector2\((?P<x>-?\d+(?:\.\d+)?),\s*(?P<y>-?\d+(?:\.\d+)?)\)")
TSCN_NODE_RE = re.compile(r'\[node name="(?P<name>[^"]+)"[^]]*\](?P<body>.*?)(?=\n\[node |\Z)', re.S)
TSCN_PROP_RE = re.compile(r"^(?P<key>[^=\n]+?)\s*=\s*(?P<value>.+)$", re.M)


@dataclass(frozen=True)
class ImageRule:
    label: str
    path: str
    min_width: int = 1
    min_height: int = 1
    exact_width: int | None = None
    exact_height: int | None = None
    severity: str = "error"
    note: str = ""


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.info: list[str] = []

    def add(self, severity: str, message: str) -> None:
        if severity == "error":
            self.errors.append(message)
        elif severity == "warning":
            self.warnings.append(message)
        else:
            self.info.append(message)


def res_to_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"not a Godot res:// path: {res_path}")
    return GAME_ROOT / res_path.removeprefix("res://")


def rel(path: Path) -> str:
    try:
        return path.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def png_size(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as fh:
        header = fh.read(24)
    if len(header) < 24 or not header.startswith(PNG_SIGNATURE):
        return None
    return struct.unpack(">II", header[16:24])


def file_sha256(path: Path) -> str:
    import hashlib

    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_csv_rows(path: Path, report: Report, label: str) -> list[dict[str, str]]:
    if not path.exists():
        report.add("error", f"{label}: missing {rel(path)}")
        return []
    with path.open("r", encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


def check_image(rule: ImageRule, report: Report) -> None:
    path = res_to_path(rule.path) if rule.path.startswith("res://") else REPO_ROOT / rule.path
    if not path.exists():
        suffix = f" ({rule.note})" if rule.note else ""
        report.add(rule.severity, f"{rule.label}: missing {rel(path)}{suffix}")
        return

    size = png_size(path)
    if size is None:
        report.add("error", f"{rule.label}: not a valid PNG {rel(path)}")
        return

    width, height = size
    if rule.exact_width is not None and rule.exact_height is not None:
        if (width, height) != (rule.exact_width, rule.exact_height):
            report.add(
                rule.severity,
                f"{rule.label}: expected {rule.exact_width}x{rule.exact_height}, got {width}x{height} at {rel(path)}",
            )
        return

    if width < rule.min_width or height < rule.min_height:
        report.add(
            rule.severity,
            f"{rule.label}: expected at least {rule.min_width}x{rule.min_height}, got {width}x{height} at {rel(path)}",
        )


def collect_asset_paths() -> set[str]:
    text = ASSET_PATHS.read_text(encoding="utf-8")
    return set(RES_PATH_RE.findall(text))


def check_asset_paths_refs(report: Report) -> None:
    missing: list[str] = []
    for res_path in sorted(collect_asset_paths()):
        if not res_to_path(res_path).exists():
            missing.append(res_path)
    if missing:
        for res_path in missing:
            report.add("error", f"AssetPaths reference missing: {res_path}")
    else:
        report.info.append("AssetPaths res:// references all exist.")


def check_unified_image2_asset_traceability(report: Report) -> None:
    if not UNIFIED_IMAGE2_STATUS.exists():
        report.add("error", f"unified image2 status missing: {rel(UNIFIED_IMAGE2_STATUS)}")
        return
    if not UNIFIED_IMAGE2_SUMMARY.exists():
        report.add("error", f"unified image2 summary missing: {rel(UNIFIED_IMAGE2_SUMMARY)}")
        return
    try:
        rows = json.loads(UNIFIED_IMAGE2_STATUS.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.add("error", f"unified image2 status is not valid JSON: {exc}")
        return
    try:
        summary = json.loads(UNIFIED_IMAGE2_SUMMARY.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.add("error", f"unified image2 summary is not valid JSON: {exc}")
        return
    if not isinstance(rows, list):
        report.add("error", "unified image2 status should be a list")
        return

    required_keys = {
        "dao_heart_icon_atlas_3x1:dao_heart_ask_128.png",
        "dao_heart_icon_atlas_3x1:dao_heart_enlighten_128.png",
        "dao_heart_icon_atlas_3x1:dao_heart_prove_128.png",
        "path_choice_icon_atlas_3x2:path_combat_48.png",
        "path_choice_icon_atlas_3x2:path_rest_48.png",
        "path_choice_icon_atlas_3x2:path_shop_48.png",
        "path_choice_icon_atlas_3x2:path_event_48.png",
        "path_choice_icon_atlas_3x2:path_elite_48.png",
        "card_reward_epic_240x373",
        "card_reward_legendary_240x373",
        "card_reward_dao_240x373",
        "card_reward_forbidden_overlay_240x373",
        "card_reward_locked_overlay_240x373",
        "reward_quality_aura_256",
        "reward_quality_mote_64",
        "reward_forbidden_reverse_mark_128x48",
        "modal_ink_veil_1920x1080",
        "panel_ninepatch_256",
        "dao_heart_card_frame",
        "setup_title_ornament",
        "couplet_panel_left",
        "couplet_panel_right",
        "modal_title_bar_720x52",
        "btn_primary_gold_360x48",
        "btn_secondary_360x40",
        "scroll_toast_520x72",
        "divider_gold_256x2",
        "event_banner_640x160",
        "event_illustration_560x96",
        "boss_banner_640x80",
        "breakthrough_bg_overlay",
        "spell_icon_atlas_4x4:spell_hui_chun_jue_96.png",
        "companion_artifact_icon_atlas_2x2:artifact_xuanyu_gourd_pendant_96.png",
        "status_icon_atlas_5x4:status_burn_32.png",
        "status_icon_atlas_5x4:status_boss_32.png",
        "element_icon_atlas_4x2:elem_fire_large_80.png",
        "element_icon_atlas_4x2:elem_chaos_large_80.png",
        "utility_karma_icon_atlas_5x4:karma_good_16.png",
        "utility_karma_icon_atlas_5x4:icon_spirit_stone_32.png",
        "hud_rune_surface_atlas_5x4:affix_rune_fire_64.png",
        "hud_rune_surface_atlas_5x4:hud_spell_dock_frame.png",
        "talent_tag_icon_atlas_5x3:talent_badge_attack.png",
        "talent_tag_icon_atlas_5x3:talent_icon_realm_5.png",
        "projectile_impact_core_atlas_4x6:fire:fly_00.png",
        "projectile_impact_core_atlas_4x6:chaos:impact_03.png",
        "projectile_impact_core_atlas_4x6:projectile_fire_16.png",
        "quality_talent_surface_atlas_5x4:quality_legendary_220x280.png",
        "quality_talent_surface_atlas_5x4:talent_scroll_210x200.png",
        "enemy_wild_wolf:alias:enemy_style_normal_melee_64.png",
        "enemy_wild_wolf_chibi:enemy_wild_wolf_chibi_64.png",
        "enemy_crossbow_cultivator_chibi:enemy_crossbow_cultivator_chibi_64.png",
        "enemy_shield_guard_chibi:enemy_shield_guard_chibi_64.png",
        "enemy_sky_bat_chibi:enemy_sky_bat_chibi_64.png",
        "enemy_mud_serpent_chibi:enemy_mud_serpent_chibi_64.png",
        "enemy_wind_mantis_chibi:enemy_wind_mantis_chibi_64.png",
        "enemy_furnace_golem_chibi:enemy_furnace_golem_chibi_64.png",
        "weather_ground_decal_atlas_4x2:weather_decal_rain_128.png",
        "weather_ground_decal_atlas_4x2:weather_decal_thunder_128.png",
        "weather_ground_decal_atlas_4x2:weather_decal_fire_128.png",
        "thunder_strike_decal_atlas_2x2:thunder_strike_warning_192.png",
        "thunder_strike_decal_atlas_2x2:thunder_strike_bolt_128x512.png",
        "enemy_telegraph_atlas_3x2:enemy_spawn_telegraph_elite_128.png",
        "enemy_telegraph_atlas_3x2:enemy_attack_sniper_256x48.png",
        "combat_action_fx_atlas_4x4:player_slash_arc_192x128.png",
        "combat_action_fx_atlas_4x4:crit_screen_slash_640x180.png",
        "combat_action_fx_atlas_4x4:enemy_windup_seal_160.png",
        "combat_action_fx_atlas_4x4:enemy_weapon_soul_banner_96x128.png",
        "overlay_ornament_fx_atlas_4x2:dao_pattern_fire_256.png",
        "overlay_ornament_fx_atlas_4x2:dao_pattern_thunder_256.png",
        "overlay_ornament_fx_atlas_4x2:dao_pattern_wood_256.png",
        "overlay_ornament_fx_atlas_4x2:dao_pattern_water_256.png",
        "overlay_ornament_fx_atlas_4x2:dao_pattern_five_256.png",
        "overlay_ornament_fx_atlas_4x2:crit_edge_top_512x96.png",
        "overlay_ornament_fx_atlas_4x2:crit_edge_side_96x512.png",
        "overlay_ornament_fx_atlas_4x2:crit_edge_corner_192.png",
    }
    seen_keys: set[str] = set()
    recomputed = {"tracked": len(rows), "image2_ready": 0, "missing_raw": 0, "missing_runtime": 0, "missing_prompt": 0}
    category_summary: dict[str, dict[str, int]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            report.add("error", f"unified image2 status row {index} should be an object")
            continue
        key = str(row.get("key", ""))
        category = str(row.get("category", ""))
        seen_keys.add(key)
        raw = Path(str(row.get("raw", "")))
        runtime = Path(str(row.get("runtime", "")))
        prompt = Path(str(row.get("prompt", "")))
        raw_ok = raw.exists() and png_size(raw) is not None
        runtime_ok = runtime.exists() and png_size(runtime) is not None
        prompt_ok = prompt.exists() and bool(prompt.read_text(encoding="utf-8").strip())
        ready = raw_ok and runtime_ok and prompt_ok
        recomputed["image2_ready"] += int(ready)
        recomputed["missing_raw"] += int(not raw_ok)
        recomputed["missing_runtime"] += int(not runtime_ok)
        recomputed["missing_prompt"] += int(not prompt_ok)
        bucket = category_summary.setdefault(
            category,
            {"tracked": 0, "image2_ready": 0, "missing_raw": 0, "missing_runtime": 0, "missing_prompt": 0},
        )
        bucket["tracked"] += 1
        bucket["image2_ready"] += int(ready)
        bucket["missing_raw"] += int(not raw_ok)
        bucket["missing_runtime"] += int(not runtime_ok)
        bucket["missing_prompt"] += int(not prompt_ok)
        if not ready:
            report.add(
                "error",
                f"unified image2 asset not ready for `{key}`: raw_ok={raw_ok}, runtime_ok={runtime_ok}, prompt_ok={prompt_ok}",
            )
        if bool(row.get("image2_ready")) != ready:
            report.add("error", f"unified image2 row `{key}` image2_ready flag does not match files")

    for key in sorted(required_keys - seen_keys):
        report.add("error", f"unified image2 status missing required visible asset key `{key}`")

    for metric, value in recomputed.items():
        if int(summary.get(metric, -1)) != value:
            report.add("error", f"unified image2 summary `{metric}` expected {value}, got {summary.get(metric)}")
    summary_categories = summary.get("categories", {})
    if not isinstance(summary_categories, dict):
        report.add("error", "unified image2 summary categories should be an object")
    else:
        for category, bucket in category_summary.items():
            reported = summary_categories.get(category, {})
            if not isinstance(reported, dict):
                report.add("error", f"unified image2 summary missing category `{category}`")
                continue
            for metric, value in bucket.items():
                if int(reported.get(metric, -1)) != value:
                    report.add("error", f"unified image2 summary `{category}.{metric}` expected {value}, got {reported.get(metric)}")

    if recomputed["tracked"] < 344:
        report.add("error", f"unified image2 status should track at least 344 assets, got {recomputed['tracked']}")
    report.info.append(
        "Unified image2 traceability: %d/%d ready."
        % (recomputed["image2_ready"], recomputed["tracked"])
    )


def mandatory_rules() -> list[ImageRule]:
    ui = "res://assets/ui/"
    cards = ui + "cards/"
    hud = "res://assets/ui/hud/"
    sprites = "res://assets/sprites/"
    fx = sprites + "fx/"
    return [
        ImageRule("main menu backdrop", ui + "bg_main_menu_celestial_hall.png", 1280, 720),
        ImageRule("run setup backdrop", ui + "bg_run_setup_inner_court.png", 1280, 720),
        ImageRule("run result backdrop", ui + "bg_run_result_reincarnation_pool.png", 1280, 720),
        ImageRule("secret event illustration", ui + "event_illustration_secret_encounter.png", 560, 96),
        ImageRule("regular event banner", ui + "event_banner_640x160.png", 640, 160),
        ImageRule("weather karma event illustration", ui + "event_illustration_560x96.png", 560, 96),
        ImageRule("shared modal ink veil", ui + "modal_ink_veil_1920x1080.png", exact_width=1920, exact_height=1080),
        ImageRule("panel ninepatch", ui + "panel_ninepatch_256.png", 128, 128),
        ImageRule("Dao-heart card frame", ui + "dao_heart_card_frame.png", 128, 180),
        ImageRule("setup title ornament", ui + "setup_title_ornament.png", 320, 32),
        ImageRule("left couplet panel", ui + "couplet_panel_left.png", 40, 160),
        ImageRule("right couplet panel", ui + "couplet_panel_right.png", 40, 160),
        ImageRule("toast scroll", ui + "scroll_toast_520x72.png", 260, 36),
        ImageRule("modal title bar", ui + "modal_title_bar_720x52.png", 360, 26),
        ImageRule("primary button texture", ui + "btn_primary_gold_360x48.png", 360, 48),
        ImageRule("secondary button texture", ui + "btn_secondary_360x40.png", 360, 40),
        ImageRule("gold divider texture", ui + "divider_gold_256x2.png", 256, 2),
        ImageRule("boss banner", ui + "boss_banner_640x80.png", 640, 80),
        ImageRule("breakthrough overlay", ui + "breakthrough_bg_overlay.png", 1280, 720),
        ImageRule("HUD left panel frame", hud + "hud_left_panel_frame_448x512.png", 448, 512),
        ImageRule("HUD objective card", hud + "hud_left_objective_card_384x112.png", 384, 112),
        ImageRule("HUD resource track", hud + "hud_left_resource_track_384x32.png", 384, 32),
        ImageRule("HUD build badge", hud + "hud_left_build_badge_320x40.png", 320, 40),
        ImageRule("HUD section divider", hud + "hud_left_section_divider_320x24.png", 320, 24),
        ImageRule("HUD skill dock frame", ui + "hud_spell_dock_frame.png", 320, 64),
        ImageRule("HP progress 9slice", ui + "progress_hp_9slice.png", 16, 8),
        ImageRule("mana progress 9slice", ui + "progress_mana_9slice.png", 16, 8),
        ImageRule("enemy HP bar 9slice", ui + "enemy_hp_bar_9slice.png", 16, 6),
        ImageRule("enemy world nameplate", ui + "enemy_nameplate_128x24.png", exact_width=128, exact_height=24),
        ImageRule("reward card frame common", cards + "card_reward_common_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward card frame rare", cards + "card_reward_rare_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward card frame epic", cards + "card_reward_epic_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward card frame legendary", cards + "card_reward_legendary_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward card frame dao", cards + "card_reward_dao_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward card forbidden overlay", cards + "card_reward_forbidden_overlay_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward card locked overlay", cards + "card_reward_locked_overlay_240x373.png", exact_width=240, exact_height=373),
        ImageRule("reward quality aura", cards + "reward_quality_aura_256.png", exact_width=256, exact_height=256),
        ImageRule("reward quality mote", cards + "reward_quality_mote_64.png", exact_width=64, exact_height=64),
        ImageRule("reward forbidden reverse mark", cards + "reward_forbidden_reverse_mark_128x48.png", exact_width=128, exact_height=48),
        ImageRule("Dao-heart ask icon", ui + "dao_heart_ask_128.png", 128, 128),
        ImageRule("Dao-heart enlighten icon", ui + "dao_heart_enlighten_128.png", 128, 128),
        ImageRule("Dao-heart prove icon", ui + "dao_heart_prove_128.png", 128, 128),
        ImageRule("path combat icon", ui + "path_combat_48.png", 48, 48),
        ImageRule("path rest icon", ui + "path_rest_48.png", 48, 48),
        ImageRule("path shop icon", ui + "path_shop_48.png", 48, 48),
        ImageRule("path event icon", ui + "path_event_48.png", 48, 48),
        ImageRule("path elite icon", ui + "path_elite_48.png", 48, 48),
        ImageRule("spirit stone icon", ui + "icon_spirit_stone_32.png", 32, 32),
        ImageRule("heal icon", ui + "icon_heal_32.png", 32, 32),
        ImageRule("dodge icon", ui + "icon_dodge_32.png", 32, 32),
        ImageRule("reroll icon", ui + "icon_reroll_24.png", 24, 24),
        ImageRule("skip icon", ui + "icon_skip_24.png", 24, 24),
        ImageRule("pet avatar ring", ui + "pet_avatar_ring_40.png", 40, 40),
        ImageRule("spell Q fire talisman", hud + "spell_q_fire_talisman_96.png", 96, 96),
        ImageRule("spell E jade sword array", hud + "spell_e_jade_sword_array_96.png", 96, 96),
        ImageRule("spell R thunder fan", hud + "spell_r_thunder_fan_96.png", 96, 96),
        ImageRule("spell locked jade seal", hud + "spell_locked_jade_seal_96.png", 96, 96),
        ImageRule("spell icon lie_yan_bolt", hud + "spell_lie_yan_bolt_96.png", 96, 96),
        ImageRule("spell icon yu_jian_thrust", hud + "spell_yu_jian_thrust_96.png", 96, 96),
        ImageRule("spell icon qi_fu", hud + "spell_qi_fu_96.png", 96, 96),
        ImageRule("spell icon summon_soul", hud + "spell_summon_soul_96.png", 96, 96),
        ImageRule("spell icon lei_chi_strike", hud + "spell_lei_chi_strike_96.png", 96, 96),
        ImageRule("spell icon lei_chi_chain", hud + "spell_lei_chi_chain_96.png", 96, 96),
        ImageRule("spell icon xuan_bing_fan", hud + "spell_xuan_bing_fan_96.png", 96, 96),
        ImageRule("spell icon xuan_bing_lance", hud + "spell_xuan_bing_lance_96.png", 96, 96),
        ImageRule("spell icon hui_chun_jue", hud + "spell_hui_chun_jue_96.png", 96, 96),
        ImageRule("element large icon fire", ui + "elem_fire_large_80.png", 80, 80),
        ImageRule("element large icon water", ui + "elem_water_large_80.png", 80, 80),
        ImageRule("element large icon ice", ui + "elem_ice_large_80.png", 80, 80),
        ImageRule("element large icon thunder", ui + "elem_thunder_large_80.png", 80, 80),
        ImageRule("element large icon wood", ui + "elem_wood_large_80.png", 80, 80),
        ImageRule("element large icon earth", ui + "elem_earth_large_80.png", 80, 80),
        ImageRule("element large icon chaos", ui + "elem_chaos_large_80.png", 80, 80),
        ImageRule("affix rune fire", hud + "affix_rune_fire_64.png", 64, 64),
        ImageRule("affix rune thunder", hud + "affix_rune_thunder_64.png", 64, 64),
        ImageRule("affix rune water", hud + "affix_rune_water_64.png", 64, 64),
        ImageRule("affix rune wood", hud + "affix_rune_wood_64.png", 64, 64),
        ImageRule("affix rune earth", hud + "affix_rune_earth_64.png", 64, 64),
        ImageRule("affix rune seal", hud + "affix_rune_seal_64.png", 64, 64),
        ImageRule("HUD weather icon clear", hud + "weather_clear_icon_64.png", 64, 64),
        ImageRule("HUD weather icon rain", hud + "weather_rain_icon_64.png", 64, 64),
        ImageRule("HUD weather icon thunder", hud + "weather_thunder_icon_64.png", 64, 64),
        ImageRule("HUD weather icon fire", hud + "weather_fire_icon_64.png", 64, 64),
        ImageRule("HUD weather icon wind", hud + "weather_wind_icon_64.png", 64, 64),
        ImageRule("HUD weather icon fog", hud + "weather_fog_icon_64.png", 64, 64),
        ImageRule("HUD weather icon snow", hud + "weather_snow_icon_64.png", 64, 64),
        ImageRule("HUD weather icon sand", hud + "weather_sand_icon_64.png", 64, 64),
        ImageRule("HUD weather thunderstorm icon", hud + "weather_thunderstorm_icon_64.png", 64, 64),
        ImageRule("HUD thunderstorm charm", hud + "weather_thunderstorm_charm_160x96.png", 160, 96),
        ImageRule("talent realm icon 1", ui + "talent_icon_realm_1.png", 32, 32),
        ImageRule("talent realm icon 2", ui + "talent_icon_realm_2.png", 32, 32),
        ImageRule("talent realm icon 3", ui + "talent_icon_realm_3.png", 32, 32),
        ImageRule("talent realm icon 4", ui + "talent_icon_realm_4.png", 32, 32),
        ImageRule("talent realm icon 5", ui + "talent_icon_realm_5.png", 32, 32),
        ImageRule("player sprite", sprites + "player_cultivator_64.png", 64, 64),
        ImageRule("player normal sprite", sprites + "player_style_normal_64.png", 64, 64),
        ImageRule("enemy training sprite", sprites + "enemy_training_dummy_64.png", 64, 64),
        ImageRule("enemy berserker sprite", sprites + "enemy_berserker_64.png", 64, 64),
        ImageRule("enemy archer sprite", sprites + "enemy_archer_64.png", 64, 64),
        ImageRule("enemy bomber sprite", sprites + "enemy_bomber_64.png", 64, 64),
        ImageRule("boss thunder normal sprite", sprites + "enemy_thunder_elite_ingame_64.png", 64, 64),
        ImageRule("boss thunder chibi sprite", sprites + "enemy_thunder_elite_chibi_64.png", 64, 64),
        ImageRule("enemy identity wild wolf", sprites + "enemy_wild_wolf_64.png", 64, 64),
        ImageRule("enemy identity crossbow cultivator", sprites + "enemy_crossbow_cultivator_64.png", 64, 64),
        ImageRule("enemy identity shield guard", sprites + "enemy_shield_guard_64.png", 64, 64),
        ImageRule("enemy identity sky bat", sprites + "enemy_sky_bat_64.png", 64, 64),
        ImageRule("enemy identity mud serpent", sprites + "enemy_mud_serpent_64.png", 64, 64),
        ImageRule("enemy identity wind mantis", sprites + "enemy_wind_mantis_64.png", 64, 64),
        ImageRule("enemy identity furnace golem", sprites + "enemy_furnace_golem_64.png", 64, 64),
        ImageRule("enemy identity wild wolf chibi", sprites + "enemy_wild_wolf_chibi_64.png", 64, 64),
        ImageRule("enemy identity crossbow cultivator chibi", sprites + "enemy_crossbow_cultivator_chibi_64.png", 64, 64),
        ImageRule("enemy identity shield guard chibi", sprites + "enemy_shield_guard_chibi_64.png", 64, 64),
        ImageRule("enemy identity sky bat chibi", sprites + "enemy_sky_bat_chibi_64.png", 64, 64),
        ImageRule("enemy identity mud serpent chibi", sprites + "enemy_mud_serpent_chibi_64.png", 64, 64),
        ImageRule("enemy identity wind mantis chibi", sprites + "enemy_wind_mantis_chibi_64.png", 64, 64),
        ImageRule("enemy identity furnace golem chibi", sprites + "enemy_furnace_golem_chibi_64.png", 64, 64),
        ImageRule("projectile fire", sprites + "projectile_fire_16.png", 16, 16),
        ImageRule("projectile thunder", sprites + "projectile_thunder_16.png", 16, 16),
        ImageRule("projectile ice", sprites + "projectile_ice_16.png", 16, 16),
        ImageRule("projectile water", sprites + "projectile_water_16.png", 16, 16),
        ImageRule("projectile wood", sprites + "projectile_wood_16.png", 16, 16),
        ImageRule("projectile earth", sprites + "projectile_earth_16.png", 16, 16),
        ImageRule("projectile generic", sprites + "projectile_generic_16.png", 16, 16),
        ImageRule("projectile chaos", sprites + "projectile_chaos_16.png", 16, 16),
        ImageRule("weather decal clear", fx + "weather_decal_clear_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal rain", fx + "weather_decal_rain_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal thunder", fx + "weather_decal_thunder_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal fire", fx + "weather_decal_fire_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal wind", fx + "weather_decal_wind_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal fog", fx + "weather_decal_fog_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal snow", fx + "weather_decal_snow_128.png", exact_width=128, exact_height=128),
        ImageRule("weather decal sand", fx + "weather_decal_sand_128.png", exact_width=128, exact_height=128),
        ImageRule("weather overlay particle clear", fx + "weather_particle_clear_64.png", exact_width=64, exact_height=64),
        ImageRule("weather overlay particle rain", fx + "weather_particle_rain_64x96.png", exact_width=64, exact_height=96),
        ImageRule("weather overlay particle thunder", fx + "weather_particle_thunder_64x96.png", exact_width=64, exact_height=96),
        ImageRule("weather overlay particle fire", fx + "weather_particle_fire_64.png", exact_width=64, exact_height=64),
        ImageRule("weather overlay particle wind", fx + "weather_particle_wind_128x64.png", exact_width=128, exact_height=64),
        ImageRule("weather overlay particle fog", fx + "weather_particle_fog_128.png", exact_width=128, exact_height=128),
        ImageRule("weather overlay particle snow", fx + "weather_particle_snow_64.png", exact_width=64, exact_height=64),
        ImageRule("weather overlay particle sand", fx + "weather_particle_sand_96x64.png", exact_width=96, exact_height=64),
        ImageRule("enemy projectile trail generic", fx + "enemy_projectile_trail_generic_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail fire", fx + "enemy_projectile_trail_fire_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail thunder", fx + "enemy_projectile_trail_thunder_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail ice", fx + "enemy_projectile_trail_ice_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail water", fx + "enemy_projectile_trail_water_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail wood", fx + "enemy_projectile_trail_wood_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail earth", fx + "enemy_projectile_trail_earth_128x48.png", exact_width=128, exact_height=48),
        ImageRule("enemy projectile trail chaos", fx + "enemy_projectile_trail_chaos_128x48.png", exact_width=128, exact_height=48),
        ImageRule("thunder strike warning decal", fx + "thunder_strike_warning_192.png", exact_width=192, exact_height=192),
        ImageRule("thunder strike impact decal", fx + "thunder_strike_impact_192.png", exact_width=192, exact_height=192),
        ImageRule("thunder strike bolt decal", fx + "thunder_strike_bolt_128x512.png", exact_width=128, exact_height=512),
        ImageRule("thunder strike scorch decal", fx + "thunder_strike_scorch_192.png", exact_width=192, exact_height=192),
        ImageRule("enemy spawn telegraph", fx + "enemy_spawn_telegraph_128.png", exact_width=128, exact_height=128),
        ImageRule("enemy elite spawn telegraph", fx + "enemy_spawn_telegraph_elite_128.png", exact_width=128, exact_height=128),
        ImageRule("enemy attack line telegraph", fx + "enemy_attack_line_256x64.png", exact_width=256, exact_height=64),
        ImageRule("enemy attack dash telegraph", fx + "enemy_attack_dash_256x96.png", exact_width=256, exact_height=96),
        ImageRule("enemy attack sniper telegraph", fx + "enemy_attack_sniper_256x48.png", exact_width=256, exact_height=48),
        ImageRule("enemy attack melee telegraph", fx + "enemy_attack_melee_128.png", exact_width=128, exact_height=128),
        ImageRule("combat FX player slash arc", fx + "player_slash_arc_192x128.png", exact_width=192, exact_height=128),
        ImageRule("combat FX crit screen slash", fx + "crit_screen_slash_640x180.png", exact_width=640, exact_height=180),
        ImageRule("combat FX enemy windup seal", fx + "enemy_windup_seal_160.png", exact_width=160, exact_height=160),
        ImageRule("combat FX actor presence shadow", fx + "actor_presence_shadow_128x64.png", exact_width=128, exact_height=64),
        ImageRule("combat FX player dao aura", fx + "player_dao_aura_160.png", exact_width=160, exact_height=160),
        ImageRule("combat FX player counter aura", fx + "player_counter_aura_160.png", exact_width=160, exact_height=160),
        ImageRule("combat FX enemy elite ring", fx + "enemy_identity_ring_elite_160.png", exact_width=160, exact_height=160),
        ImageRule("combat FX enemy boss ring", fx + "enemy_identity_ring_boss_192.png", exact_width=192, exact_height=192),
        ImageRule("combat FX enemy guard aura", fx + "enemy_guard_aura_192.png", exact_width=192, exact_height=192),
        ImageRule("combat FX status badge backing", fx + "status_badge_backing_48.png", exact_width=48, exact_height=48),
        ImageRule("combat FX enemy claw glyph", fx + "enemy_weapon_claw_96x64.png", exact_width=96, exact_height=64),
        ImageRule("combat FX enemy crossbow glyph", fx + "enemy_weapon_crossbow_112x64.png", exact_width=112, exact_height=64),
        ImageRule("combat FX enemy furnace glyph", fx + "enemy_weapon_furnace_core_96.png", exact_width=96, exact_height=96),
        ImageRule("combat FX enemy shield glyph", fx + "enemy_weapon_xuanwu_shield_96.png", exact_width=96, exact_height=96),
        ImageRule("combat FX enemy soul banner glyph", fx + "enemy_weapon_soul_banner_96x128.png", exact_width=96, exact_height=128),
        ImageRule("combat FX enemy poison glyph", fx + "enemy_weapon_poison_spit_80x64.png", exact_width=80, exact_height=64),
        ImageRule("overlay FX Dao fire pattern", fx + "dao_pattern_fire_256.png", exact_width=256, exact_height=256),
        ImageRule("overlay FX Dao thunder pattern", fx + "dao_pattern_thunder_256.png", exact_width=256, exact_height=256),
        ImageRule("overlay FX Dao wood pattern", fx + "dao_pattern_wood_256.png", exact_width=256, exact_height=256),
        ImageRule("overlay FX Dao water pattern", fx + "dao_pattern_water_256.png", exact_width=256, exact_height=256),
        ImageRule("overlay FX Dao five pattern", fx + "dao_pattern_five_256.png", exact_width=256, exact_height=256),
        ImageRule("overlay FX crit top edge", fx + "crit_edge_top_512x96.png", exact_width=512, exact_height=96),
        ImageRule("overlay FX crit side edge", fx + "crit_edge_side_96x512.png", exact_width=96, exact_height=512),
        ImageRule("overlay FX crit corner flare", fx + "crit_edge_corner_192.png", exact_width=192, exact_height=192),
    ]


def warning_rules() -> list[ImageRule]:
    ui = "res://assets/ui/"
    hud = "res://assets/ui/hud/"
    elements = ["fire", "water", "thunder", "wood", "earth", "chaos"]
    weathers = ["clear", "rain", "thunder", "fire", "wind", "fog", "snow", "sand"]
    rules: list[ImageRule] = []
    for element in elements:
        rules.append(ImageRule(f"element icon {element}", ui + f"elem_{element}_32.png", 32, 32, severity="warning"))
    for weather in weathers:
        rules.append(ImageRule(f"legacy weather icon {weather}", ui + f"weather_{weather}_32.png", 32, 32, severity="warning"))
    return rules


def check_frame_bundle(slug: str, prefix: str, min_frames: int, min_size: int, report: Report, severity: str = "error") -> None:
    directory = GAME_ROOT / "assets" / "sprites" / "frames" / slug
    if not directory.exists():
        report.add(severity, f"frame bundle {slug}: missing directory {rel(directory)}")
        return
    frames = sorted(directory.glob(f"{prefix}_*.png"))
    if len(frames) < min_frames:
        report.add(severity, f"frame bundle {slug}: expected at least {min_frames} {prefix}_*.png frames, got {len(frames)}")
    for frame in frames:
        size = png_size(frame)
        if size is None:
            report.add("error", f"frame bundle {slug}: invalid PNG {rel(frame)}")
        elif size[0] < min_size or size[1] < min_size:
            report.add(severity, f"frame bundle {slug}: frame too small {size[0]}x{size[1]} at {rel(frame)}")


def _asset_paths_text() -> str:
    return ASSET_PATHS.read_text(encoding="utf-8")


def _require_text_contains(label: str, text: str, needle: str, report: Report, severity: str = "error") -> None:
    if needle not in text:
        report.add(severity, f"{label}: expected to find `{needle}`")


def _require_text_absent(label: str, text: str, needle: str, report: Report, severity: str = "error") -> None:
    if needle in text:
        report.add(severity, f"{label}: must not contain `{needle}`")


def _dimmer_node_body(scene_text: str) -> str:
    match = re.search(r'\[node name="Dimmer"[^]]*\](?P<body>.*?)(?=\n\[node |\Z)', scene_text, re.S)
    return match.group("body") if match else ""


def _check_shared_modal_veil_contract(report: Report) -> None:
    asset_text = _asset_paths_text()
    _require_text_contains("shared modal veil AssetPaths contract", asset_text, 'const MODAL_INK_VEIL := UI_ROOT + "modal_ink_veil_1920x1080.png"', report)
    helper_text = (GAME_ROOT / "ui" / "ui_helpers.gd").read_text(encoding="utf-8")
    for label, needle in (
        ("helper exposes shared modal veil", "static func apply_modal_veil(veil: TextureRect, alpha: float = 0.86) -> void:"),
        ("helper loads shared veil texture", "AssetPaths.MODAL_INK_VEIL"),
        ("helper keeps aspect covered", "TextureRect.STRETCH_KEEP_ASPECT_COVERED"),
        ("helper records target alpha", 'veil.set_meta("modal_veil_alpha", alpha)'),
        ("helper uses compact modal title divider", 'divider.name = "ModalTitleDivider"'),
        ("helper title divider uses gold line", "AssetPaths.DIVIDER_GOLD"),
    ):
        _require_text_contains(f"shared modal veil helper contract: {label}", helper_text, needle, report)
    helper_header_start = helper_text.find("static func decorate_modal_header")
    helper_header_end = helper_text.find("\n\nstatic func", helper_header_start + 1) if helper_header_start >= 0 else -1
    helper_header = helper_text[helper_header_start:helper_header_end if helper_header_end >= 0 else len(helper_text)] if helper_header_start >= 0 else ""
    for forbidden in ("ModalTitleBar", "AssetPaths.MODAL_TITLE_BAR", "modal_title_bar_720x52"):
        if forbidden in helper_header:
            report.add("error", f"decorate_modal_header must not create the old empty 720px modal title bar: found `{forbidden}`")
    animation_text = (GAME_ROOT / "ui" / "ui_animations.gd").read_text(encoding="utf-8")
    _require_text_contains("modal animation should respect per-veil alpha", animation_text, "dimmer_target_alpha = dimmer.modulate.a", report)

    scene_contracts = [
        ("EventPanel", EVENT_PANEL_SCRIPT, EVENT_PANEL_SCENE),
        ("AffixChoicePanel", AFFIX_CHOICE_PANEL_SCRIPT, AFFIX_CHOICE_PANEL_SCENE),
        ("PathChoicePanel", PATH_CHOICE_PANEL_SCRIPT, PATH_CHOICE_PANEL_SCENE),
        ("ShopPanel", SHOP_PANEL_SCRIPT, SHOP_PANEL_SCENE),
        ("LegacySelectPanel", LEGACY_SELECT_SCRIPT, LEGACY_SELECT_SCENE),
        ("PauseOverlay", PAUSE_OVERLAY_SCRIPT, PAUSE_OVERLAY_SCENE),
        ("WeaponModChoicePanel", WEAPON_MOD_PANEL_SCRIPT, WEAPON_MOD_PANEL_SCENE),
    ]
    for label, script_path, scene_path in scene_contracts:
        if not script_path.exists() or not scene_path.exists():
            report.add("error", f"{label} shared modal veil files missing")
            continue
        script_text = script_path.read_text(encoding="utf-8")
        scene_text = scene_path.read_text(encoding="utf-8")
        _require_text_contains(f"{label} Dimmer should be TextureRect", scene_text, '[node name="Dimmer" type="TextureRect" parent="."]', report)
        _require_text_absent(f"{label} Dimmer should not be ColorRect", scene_text, '[node name="Dimmer" type="ColorRect" parent="."]', report)
        _require_text_absent(f"{label} Dimmer should not keep scattered flat color", _dimmer_node_body(scene_text), "color = Color(", report)
        _require_text_contains(f"{label} script should type Dimmer as TextureRect", script_text, "@onready var dimmer: TextureRect = $Dimmer", report)
        _require_text_contains(f"{label} script should apply shared modal veil", script_text, "UiHelpers.apply_modal_veil(dimmer", report)


def _parse_vector2(value: str) -> tuple[float, float] | None:
    match = VECTOR2_RE.search(value)
    if not match:
        return None
    return (float(match.group("x")), float(match.group("y")))


def _parse_tscn_nodes(path: Path) -> dict[str, dict[str, str]]:
    text = path.read_text(encoding="utf-8")
    result: dict[str, dict[str, str]] = {}
    for node in TSCN_NODE_RE.finditer(text):
        props: dict[str, str] = {}
        for prop in TSCN_PROP_RE.finditer(node.group("body")):
            props[prop.group("key").strip()] = prop.group("value").strip()
        result[node.group("name")] = props
    return result


def _float_prop(props: dict[str, str], key: str, default: float = 0.0) -> float:
    value = props.get(key)
    if value is None:
        return default
    try:
        return float(value)
    except ValueError:
        return default


def _int_prop(props: dict[str, str], key: str, default: int = 0) -> int:
    value = props.get(key)
    if value is None:
        return default
    try:
        return int(float(value))
    except ValueError:
        return default


def _extract_const_dict(text: str, const_name: str) -> dict[str, str]:
    pattern = re.compile(DICT_BLOCK_RE_TEMPLATE.format(name=re.escape(const_name)), re.S)
    match = pattern.search(text)
    if not match:
        return {}
    result: dict[str, str] = {}
    for entry in DICT_ENTRY_RE.finditer(match.group("body")):
        result[entry.group("key")] = entry.group("value").strip()
    return result


def _resolve_ui_root_value(value: str) -> str:
    ui_match = UI_ROOT_CONCAT_RE.search(value)
    if ui_match:
        return "res://assets/ui/" + ui_match.group("suffix")
    string_match = STRING_RE.search(value)
    if string_match:
        return string_match.group("value")
    return ""


def _unquote_tscn_string(value: str) -> str:
    string_match = STRING_RE.search(value)
    if string_match:
        return string_match.group("value")
    return value.strip()


def _require_scene_body_texture(label: str, scene_path: Path, expected_texture: str, report: Report) -> None:
    if not scene_path.exists():
        report.add("error", f"{label}: missing scene {rel(scene_path)}")
        return
    nodes = _parse_tscn_nodes(scene_path)
    body = nodes.get("BodyVisual")
    if body is None:
        report.add("error", f"{label}: BodyVisual node missing in {rel(scene_path)}")
        return
    actual = _unquote_tscn_string(body.get("texture_path", ""))
    if actual != expected_texture:
        report.add(
            "error",
            f"{label}: BodyVisual.texture_path should default to `{expected_texture}`, got `{actual}`",
        )
    check_image(ImageRule(f"{label} scene default texture", expected_texture, 32, 32), report)


def _check_no_hardcoded_asset_literals(label: str, path: Path, patterns: Iterable[str], report: Report) -> None:
    if not path.exists():
        report.add("error", f"{label}: missing {rel(path)}")
        return
    text = path.read_text(encoding="utf-8")
    for pattern in patterns:
        regex = re.compile(pattern)
        for match in regex.finditer(text):
            line_no = text.count("\n", 0, match.start()) + 1
            report.add("error", f"{label}: hardcoded asset `{match.group(0)}` at {rel(path)}:{line_no}; route through AssetPaths")


def check_status_icon_contract(report: Report) -> None:
    text = _asset_paths_text()
    status_icons = _extract_const_dict(text, "STATUS_ICONS")
    status_fallbacks = _extract_const_dict(text, "STATUS_ICON_ELEMENT_FALLBACKS")
    element_icons = _extract_const_dict(text, "ELEMENT_ICONS")
    if not status_icons:
        report.add("error", "AssetPaths STATUS_ICONS dictionary missing or unparsable")
        return
    if not status_fallbacks:
        report.add("error", "AssetPaths STATUS_ICON_ELEMENT_FALLBACKS dictionary missing or unparsable")
        return
    if not element_icons:
        report.add("error", "AssetPaths ELEMENT_ICONS dictionary missing or unparsable")
        return

    element_keys = set(element_icons.keys())
    for status_key in sorted(status_icons.keys()):
        if status_key not in status_fallbacks:
            report.add("error", f"STATUS_ICONS key `{status_key}` missing fallback element")
            continue
        fallback_value = STRING_RE.search(status_fallbacks[status_key])
        fallback_key = fallback_value.group("value") if fallback_value else ""
        if fallback_key not in element_keys:
            report.add("error", f"STATUS_ICONS key `{status_key}` fallback element `{fallback_key}` missing from ELEMENT_ICONS")

    dedicated_paths = sorted({_resolve_ui_root_value(value) for value in status_icons.values()})
    for res_path in dedicated_paths:
        if not res_path:
            report.add("error", "STATUS_ICONS contains an unresolvable dedicated icon path")
            continue
        check_image(ImageRule(f"status dedicated icon {Path(res_path).stem}", res_path, 32, 32), report)


def check_semantic_icon_route_contract(report: Report) -> None:
    text = _asset_paths_text()

    large_icons = _extract_const_dict(text, "ELEMENT_ICONS_LARGE")
    expected_large_icons = {
        "fire": "elem_fire_large_80.png",
        "water": "elem_water_large_80.png",
        "ice": "elem_ice_large_80.png",
        "thunder": "elem_thunder_large_80.png",
        "wood": "elem_wood_large_80.png",
        "earth": "elem_earth_large_80.png",
        "chaos": "elem_chaos_large_80.png",
        "soul": "elem_chaos_large_80.png",
        "none": "elem_chaos_large_80.png",
    }
    if not large_icons:
        report.add("error", "AssetPaths ELEMENT_ICONS_LARGE dictionary missing or unparsable")
    else:
        for key, filename in expected_large_icons.items():
            value = large_icons.get(key, "")
            if not value:
                report.add("error", f"ELEMENT_ICONS_LARGE missing `{key}`")
            elif filename not in value:
                report.add("error", f"ELEMENT_ICONS_LARGE `{key}` should route to {filename}, got `{value}`")
    _require_text_contains(
        "large reward element icon helper exists",
        text,
        "static func elem_icon_large(element_id: int) -> String:",
        report,
    )
    _require_text_contains(
        "large reward element icon stores dedicated candidate",
        text,
        'var dedicated := str(ELEMENT_ICONS_LARGE.get(key, ""))',
        report,
    )
    _require_text_contains(
        "large reward element icon validates dedicated file before use",
        text,
        "if not dedicated.is_empty() and ResourceLoader.exists(dedicated):",
        report,
    )
    _require_text_contains(
        "large reward element icon returns dedicated file first",
        text,
        "return dedicated",
        report,
    )
    _require_text_contains(
        "large reward element icon keeps 32px fallback",
        text,
        "return elem_icon(element_id)",
        report,
    )

    weather_icons = _extract_const_dict(text, "HUD_WEATHER_ICONS")
    expected_weather_icons = {
        "clear": "HUD_WEATHER_CLEAR_ICON",
        "rain": "HUD_WEATHER_RAIN_ICON",
        "thunder": "HUD_WEATHER_THUNDER_ICON",
        "storm": "HUD_WEATHER_THUNDERSTORM_ICON",
        "thunderstorm": "HUD_WEATHER_THUNDERSTORM_ICON",
        "fire": "HUD_WEATHER_FIRE_ICON",
        "wind": "HUD_WEATHER_WIND_ICON",
        "fog": "HUD_WEATHER_FOG_ICON",
        "snow": "HUD_WEATHER_SNOW_ICON",
        "sand": "HUD_WEATHER_SAND_ICON",
    }
    if not weather_icons:
        report.add("error", "AssetPaths HUD_WEATHER_ICONS dictionary missing or unparsable")
    else:
        for key, expected in expected_weather_icons.items():
            value = weather_icons.get(key, "")
            if not value:
                report.add("error", f"HUD_WEATHER_ICONS missing `{key}`")
            elif expected not in value:
                report.add("error", f"HUD_WEATHER_ICONS `{key}` should route to {expected}, got `{value}`")
    _require_text_contains(
        "weather icon helper prefers dedicated HUD icon table",
        text,
        'var hud_icon := str(HUD_WEATHER_ICONS.get(weather_id, ""))',
        report,
    )
    _require_text_contains(
        "weather icon helper validates dedicated HUD icon",
        text,
        "ResourceLoader.exists(hud_icon)",
        report,
    )
    _require_text_contains(
        "weather icon helper keeps legacy fallback",
        text,
        'return WEATHER_ICONS.get(weather_id, WEATHER_ICONS["clear"])',
        report,
    )
    legacy_weather_icons = _extract_const_dict(text, "WEATHER_ICONS")
    for key in ["clear", "rain", "thunder", "fire", "wind", "fog", "snow", "sand"]:
        value = legacy_weather_icons.get(key, "")
        if not value:
            report.add("error", f"WEATHER_ICONS missing legacy fallback `{key}`")
        elif f"weather_{key}_32.png" not in value:
            report.add("error", f"WEATHER_ICONS `{key}` should route to weather_{key}_32.png, got `{value}`")

    _require_text_contains(
        "talent realm icon helper builds dedicated realm icon path",
        text,
        'var dedicated := UI_ROOT + "talent_icon_realm_%d.png" % realm_level',
        report,
    )
    _require_text_contains(
        "talent realm icon helper validates dedicated realm icon",
        text,
        "if ResourceLoader.exists(dedicated):",
        report,
    )
    _require_text_contains(
        "talent realm icon helper returns dedicated realm icon first",
        text,
        "return dedicated",
        report,
    )
    _require_text_contains(
        "talent realm icon helper keeps element fallback",
        text,
        'return TALENT_REALM_ICON_FALLBACK.get(realm_level, ELEMENT_ICONS["wood"])',
        report,
    )
    for realm_level, fallback in {
        1: "elem_wood_32.png",
        2: "elem_earth_32.png",
        3: "elem_fire_32.png",
        4: "elem_thunder_32.png",
        5: "elem_chaos_32.png",
    }.items():
        _require_text_contains(
            f"talent realm {realm_level} fallback stays semantic",
            text,
            f'{realm_level}: UI_ROOT + "{fallback}"',
            report,
        )
        dedicated_res = f"res://assets/ui/talent_icon_realm_{realm_level}.png"
        fallback_res = f"res://assets/ui/{fallback}"
        check_image(ImageRule(f"talent realm {realm_level} dedicated route", dedicated_res, 32, 32), report)
        check_image(ImageRule(f"talent realm {realm_level} fallback route", fallback_res, 32, 32), report)
        _require_distinct_png(
            f"talent realm {realm_level} dedicated icon",
            dedicated_res,
            fallback_res,
            report,
        )

    if AFFIX_CARD_SCRIPT.exists():
        affix_text = AFFIX_CARD_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "reward card runtime uses 80px element icon route",
            affix_text,
            "AssetPaths.elem_icon_large(display_tag.element)",
            report,
        )
    else:
        report.add("error", f"affix card script missing: {rel(AFFIX_CARD_SCRIPT)}")

    if HUD_WEATHER_PANEL_SCRIPT.exists():
        weather_panel_text = HUD_WEATHER_PANEL_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "weather panel initializes via dedicated weather icon route",
            weather_panel_text,
            'AssetPaths.weather_icon("clear")',
            report,
        )
        _require_text_contains(
            "weather panel uses semantic frame route",
            weather_panel_text,
            "AssetPaths.weather_panel_frame(_weather_id)",
            report,
        )
        _require_text_contains(
            "weather panel consumes thunderstorm sigil asset",
            weather_panel_text,
            "AssetPaths.HUD_WEATHER_THUNDER_SIG",
            report,
        )
    else:
        report.add("error", f"HUD weather panel script missing: {rel(HUD_WEATHER_PANEL_SCRIPT)}")

    if HUD_SCRIPT.exists():
        hud_text = HUD_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "HUD weather updates use dedicated weather icon route",
            hud_text,
            "AssetPaths.weather_icon(weather_id)",
            report,
        )
    else:
        report.add("error", f"HUD script missing: {rel(HUD_SCRIPT)}")

    if TOP_ANNOUNCEMENT_SCRIPT.exists() and TOP_ANNOUNCEMENT_SCENE.exists():
        top_text = TOP_ANNOUNCEMENT_SCRIPT.read_text(encoding="utf-8")
        top_scene_text = TOP_ANNOUNCEMENT_SCENE.read_text(encoding="utf-8")
        for label, needle in (
            ("top announcement loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
            ("top announcement uses compact HUD badge texture", "AssetPaths.HUD_LEFT_BUILD_BADGE"),
            ("top announcement exposes texture hit count", "func get_texture_hit_count() -> int:"),
            ("top announcement compact textured bar", "custom_minimum_size = Vector2(360, 40)"),
            ("top announcement trims overflow text", "TextServer.OVERRUN_TRIM_ELLIPSIS"),
        ):
            _require_text_contains(f"TopAnnouncement asset contract: {label}", top_text + "\n" + top_scene_text, needle, report)
        if "StyleBoxFlat.new()" in top_text:
            report.add("error", "TopAnnouncementOverlay should not regress to StyleBoxFlat backing")
        if "AssetPaths.SCROLL_TOAST" in top_text or "custom_minimum_size = Vector2(520, 54)" in top_scene_text:
            report.add("error", "TopAnnouncementOverlay must not use the long scroll toast in combat HUD")
    else:
        report.add("error", "top announcement overlay files missing")

    if COMBAT_FEEDBACK_SCRIPT.exists():
        feedback_text = COMBAT_FEEDBACK_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("combat feedback loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
            ("combat feedback floater backing", 'backing.name = "FloaterBacking"'),
            ("combat feedback backing texture", 'AssetPaths.combat_action_fx("status_badge_backing")'),
            ("combat feedback floater icon", 'icon.name = "FloaterIcon"'),
            ("combat feedback texture hit getter", "func get_floater_backing_texture_hit_count() -> int:"),
            ("combat feedback icon hit getter", "func get_floater_icon_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"CombatFeedback asset contract: {label}", feedback_text, needle, report)
    else:
        report.add("error", "combat feedback layer script missing")

    if TALENT_CARD_SCRIPT.exists():
        talent_text = TALENT_CARD_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "talent card runtime uses dedicated realm icon route",
            talent_text,
            "AssetPaths.talent_realm_icon(realm_level)",
            report,
        )
    else:
        report.add("error", f"talent card script missing: {rel(TALENT_CARD_SCRIPT)}")

    forbidden_patterns = [
        r"elem_[a-z]+_large_80\.png",
        r"weather_[a-z]+_icon_64\.png",
        r"talent_icon_realm_\d+\.png",
    ]
    for label, path in [
        ("affix card semantic icon consumer", AFFIX_CARD_SCRIPT),
        ("HUD weather semantic icon consumer", HUD_SCRIPT),
        ("HUD weather panel semantic icon consumer", HUD_WEATHER_PANEL_SCRIPT),
        ("talent card semantic icon consumer", TALENT_CARD_SCRIPT),
    ]:
        _check_no_hardcoded_asset_literals(label, path, forbidden_patterns, report)



def check_affix_card_contract(report: Report) -> None:
    if not AFFIX_CARD_SCRIPT.exists():
        report.add("error", f"affix card script missing: {rel(AFFIX_CARD_SCRIPT)}")
        return
    text = AFFIX_CARD_SCRIPT.read_text(encoding="utf-8")
    _require_text_contains(
        "affix reward card uses new reward frame route",
        text,
        "UiHelpers.apply_reward_card_frame(frame_bg, display_tag.quality)",
        report,
    )
    _require_text_contains(
        "affix reward card forbidden overlay route",
        text,
        "AssetPaths.REWARD_CARD_FORBIDDEN_OVERLAY",
        report,
    )
    _require_text_contains(
        "affix reward card locked overlay route",
        text,
        "AssetPaths.REWARD_CARD_LOCKED_OVERLAY",
        report,
    )
    _require_text_contains(
        "temptation affix card second confirm flag",
        text,
        '_requires_second_confirm = offer_type == "temptation" and not select_button.disabled',
        report,
    )
    _require_text_contains(
        "temptation affix card first click arms confirm",
        text,
        'select_button.text = "确认立誓"',
        report,
    )
    _require_text_contains(
        "temptation affix card clear confirm on mouse exit",
        text,
        "_second_confirm_armed = false",
        report,
    )
    _require_text_contains(
        "affix reward card passes temptation state to quality particles",
        text,
        '_quality_glow.configure(quality, offer_type == "temptation", locked)',
        report,
    )
    _require_text_contains(
        "affix reward card hover drives quality particles",
        text,
        "_quality_glow.set_hovered(true)",
        report,
    )
    _require_text_contains(
        "affix reward card second confirm drives forbidden particles",
        text,
        "_quality_glow.set_confirm_armed(true)",
        report,
    )
    _require_text_contains(
        "affix reward tag chips use image2 backing",
        text,
        "UiHelpers.make_button_texture_style(\n\t\tAssetPaths.BTN_SECONDARY",
        report,
    )
    if "StyleBoxFlat.new()" in text:
        report.add("error", "AffixCard should not use StyleBoxFlat for reward tag chips; use image2 texture-backed chips")

    if not QUALITY_GLOW_SCRIPT.exists():
        report.add("error", f"quality glow script missing: {rel(QUALITY_GLOW_SCRIPT)}")
    else:
        glow_text = QUALITY_GLOW_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "quality glow has runtime state contract",
            glow_text,
            "func configure(tier: int, is_forbidden: bool = false, is_locked: bool = false) -> void:",
            report,
        )
        for label, needle in (
            ("loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
            ("builds texture layers", "func _rebuild_texture_layers() -> void:"),
            ("uses dedicated reward aura texture", "AssetPaths.REWARD_QUALITY_AURA"),
            ("uses dedicated reward mote texture", "AssetPaths.REWARD_QUALITY_MOTE"),
            ("uses dedicated forbidden reverse texture", "AssetPaths.REWARD_FORBIDDEN_REVERSE_MARK"),
            ("exposes texture hit count", "func get_texture_hit_count() -> int:"),
            ("exposes particle texture count", "func get_particle_texture_count() -> int:"),
            ("exposes forbidden texture count", "func get_forbidden_texture_count() -> int:"),
        ):
            _require_text_contains(f"quality glow texture contract: {label}", glow_text, needle, report)
        _require_text_contains(
            "quality glow disables locked card particles",
            glow_text,
            "visible = not locked and (quality_tier >= 1 or forbidden)",
            report,
        )
        for forbidden_call in ("draw_rect(", "draw_line(", "draw_circle(", "draw_arc(", "draw_colored_polygon("):
            _require_text_absent("QualityGlow should use image2 texture layers, not procedural geometry", glow_text, forbidden_call, report)
        for forbidden_ref in ("AssetPaths.ICON_SPIRIT_STONE", 'AssetPaths.combat_action_fx("enemy_windup_seal")', "AssetPaths.reward_card_frame(4)"):
            _require_text_absent("QualityGlow should use dedicated reward quality FX assets, not reused semantic assets", glow_text, forbidden_ref, report)

    if not AFFIX_CARD_SCENE.exists():
        report.add("error", f"affix card scene missing: {rel(AFFIX_CARD_SCENE)}")
        return
    nodes = _parse_tscn_nodes(AFFIX_CARD_SCENE)
    root = nodes.get("AffixCard", {})
    card_size = _parse_vector2(root.get("custom_minimum_size", ""))
    if card_size is None or card_size[0] < 278.0 or card_size[1] < 432.0:
        report.add("error", f"AffixCard scene: expected custom_minimum_size at least 278x432, got {card_size}")
    icon = nodes.get("Icon", {})
    icon_size = _parse_vector2(icon.get("custom_minimum_size", ""))
    if icon_size is None or icon_size[0] < 92.0 or icon_size[1] < 92.0:
        report.add("error", f"AffixCard scene: expected at least 92x92 reward icon, got {icon_size}")
    button = nodes.get("SelectButton", {})
    button_size = _parse_vector2(button.get("custom_minimum_size", ""))
    if button_size is None or button_size[1] < 44:
        report.add("error", f"AffixCard scene: select button height must be >=44, got {button_size}")


def check_affix_choice_layout_contract(report: Report) -> None:
    if AFFIX_CHOICE_PANEL_SCRIPT.exists():
        text = AFFIX_CHOICE_PANEL_SCRIPT.read_text(encoding="utf-8")
        checks = [
            ("reward reroll button uses image2 asset style", "UiHelpers.apply_button_asset(reroll_button, false)"),
            ("reward skip button uses image2 asset style", "UiHelpers.apply_button_asset(skip_button, false)"),
            ("reward reroll button uses icon", "reroll_button.icon = AssetPaths.load_texture(AssetPaths.ICON_REROLL)"),
            ("reward skip button uses icon", "skip_button.icon = AssetPaths.load_texture(AssetPaths.ICON_SKIP)"),
            ("reward full-slot action factory", "func _make_full_slot_action_button(text: String, icon_path: String, primary: bool) -> Button:"),
            ("reward full-slot actions use image2 button asset", "UiHelpers.apply_button_asset(button, primary)"),
            ("reward full-slot action buttons load icons", "button.icon = AssetPaths.load_texture(icon_path)"),
            ("reward full-slot panel uses image2 ninepatch", "actions_panel.add_theme_stylebox_override(\"panel\", UiHelpers.make_ninepatch_panel_style())"),
            ("reward full-slot actions panel node", 'actions_panel.name = "FullSlotActionsPanel"'),
            ("reward full-slot actions container node", 'actions.name = "FullSlotActions"'),
            ("reward replace button stable name", 'replace.name = "ReplaceAffixButton_%d" % i'),
            ("reward seal button stable name", 'seal.name = "SealAffixButton"'),
            ("reward dissolve button stable name", 'dissolve.name = "DissolveAffixButton"'),
            ("reward back button stable name", 'back.name = "RewardBackButton"'),
            ("reward full-slot replace icon helper", "func _tag_icon_path(tag) -> String:"),
        ]
        for label, needle in checks:
            _require_text_contains(label, text, needle, report)
    else:
        report.add("error", f"affix choice panel script missing: {rel(AFFIX_CHOICE_PANEL_SCRIPT)}")

    if not AFFIX_CHOICE_PANEL_SCENE.exists():
        report.add("error", f"affix choice panel scene missing: {rel(AFFIX_CHOICE_PANEL_SCENE)}")
        return
    nodes = _parse_tscn_nodes(AFFIX_CHOICE_PANEL_SCENE)
    panel = nodes.get("Panel", {})
    margin = nodes.get("Margin", {})
    vbox = nodes.get("VBox", {})
    cards = nodes.get("Cards", {})
    actions = nodes.get("Actions", {})
    reroll = nodes.get("RerollButton", {})
    skip = nodes.get("SkipButton", {})

    left = _float_prop(panel, "offset_left")
    top = _float_prop(panel, "offset_top")
    right = _float_prop(panel, "offset_right")
    bottom = _float_prop(panel, "offset_bottom")
    panel_w = right - left
    panel_h = bottom - top
    if panel_w <= 0 or panel_h <= 0:
        report.add("error", f"AffixChoicePanel layout: invalid panel offsets {left},{top},{right},{bottom}")
        return
    if panel_w < 1200 or panel_h < 720:
        report.add("error", f"AffixChoicePanel layout: panel {panel_w:.0f}x{panel_h:.0f} should be at least 1200x720 for 1920 visual focus")
    if panel_w > 1320 or panel_h > 820:
        report.add("error", f"AffixChoicePanel layout: panel {panel_w:.0f}x{panel_h:.0f} exceeds 1320x820 1920 safe size")

    margin_l = _int_prop(margin, "theme_override_constants/margin_left")
    margin_t = _int_prop(margin, "theme_override_constants/margin_top")
    margin_r = _int_prop(margin, "theme_override_constants/margin_right")
    margin_b = _int_prop(margin, "theme_override_constants/margin_bottom")
    vbox_sep = _int_prop(vbox, "theme_override_constants/separation")
    card_gap = _int_prop(cards, "theme_override_constants/separation")
    actions_gap = _int_prop(actions, "theme_override_constants/separation")
    inner_w = panel_w - margin_l - margin_r
    inner_h = panel_h - margin_t - margin_b
    card_w = 278
    card_h = 432
    actions_h = 50
    title_two_lines_h = 82
    gold_h = 24
    hover_pad = 16
    vertical_budget = title_two_lines_h + gold_h + card_h + actions_h + hover_pad + vbox_sep * 3
    if inner_h < vertical_budget + 24:
        report.add(
            "error",
            f"AffixChoicePanel layout: vertical budget too tight, inner_h={inner_h:.0f}, required>={vertical_budget + 24:.0f}",
        )
    if 3 * card_w + 2 * card_gap > inner_w:
        report.add(
            "error",
            f"AffixChoicePanel layout: three cards need {3 * card_w + 2 * card_gap:.0f}px, inner width {inner_w:.0f}px",
        )
    if card_gap < 36:
        report.add("error", f"AffixChoicePanel layout: card gap {card_gap}px < 36px")
    for name, props in (("RerollButton", reroll), ("SkipButton", skip)):
        size = _parse_vector2(props.get("custom_minimum_size", ""))
        if size is None or size[1] < 44:
            report.add("error", f"AffixChoicePanel layout: {name} height must be >=44, got {size}")
    if actions_gap < 12:
        report.add("warning", f"AffixChoicePanel layout: actions gap {actions_gap}px is visually tight")


def _check_runtime_actor_mapping(label: str, texture_res_path: str, slug: str, min_size: int, report: Report) -> None:
    check_image(ImageRule(f"{label} runtime texture", texture_res_path, min_size, min_size), report)
    for prefix in ("idle", "walk", "combat"):
        check_frame_bundle(slug, prefix, 4, min_size // 2, report)


def _require_distinct_png(label: str, first: str, second: str, report: Report) -> None:
    first_path = res_to_path(first)
    second_path = res_to_path(second)
    if not first_path.exists() or not second_path.exists():
        return
    if file_sha256(first_path) == file_sha256(second_path):
        report.add("error", f"{label}: {rel(first_path)} must be visually dedicated and not byte-identical to {rel(second_path)}")


def check_boss_dedicated_art_contract(report: Report) -> None:
    sprites = "res://assets/sprites/"
    _require_distinct_png(
        "normal thunder boss dedicated art",
        sprites + "enemy_thunder_elite_ingame_64.png",
        sprites + "enemy_style_normal_elite_64.png",
        report,
    )
    _require_distinct_png(
        "normal thunder boss 128 dedicated art",
        sprites + "enemy_thunder_elite_ingame_128.png",
        sprites + "enemy_style_normal_elite_128.png",
        report,
    )
    _require_distinct_png(
        "chibi thunder boss dedicated art",
        sprites + "enemy_thunder_elite_chibi_64.png",
        sprites + "enemy_style_chibi_elite_64.png",
        report,
    )
    _require_distinct_png(
        "chibi thunder boss 128 dedicated art",
        sprites + "enemy_thunder_elite_chibi_128.png",
        sprites + "enemy_style_chibi_elite_128.png",
        report,
    )


def check_runtime_actor_mappings(report: Report) -> None:
    if not ASSET_PATHS.exists():
        return
    text = _asset_paths_text()
    sprites = "res://assets/sprites/"

    _require_text_contains(
        "normal style default enemy mapping",
        text,
        '"normal": SPRITE_ROOT + "enemy_style_normal_melee_64.png"',
        report,
    )
    _require_text_contains(
        "chibi style default enemy mapping",
        text,
        '"normal": SPRITE_ROOT + "enemy_style_chibi_melee_64.png"',
        report,
    )
    _require_text_contains(
        "boss normal style uses dedicated thunder boss sprite",
        text,
        '"boss": ENEMY_BOSS_THUNDER_NORMAL',
        report,
    )
    _require_text_contains(
        "boss chibi style uses dedicated thunder boss sprite",
        text,
        '"boss": ENEMY_BOSS_THUNDER_CHIBI',
        report,
    )
    _require_text_contains(
        "enemy identity sprite route exists",
        text,
        "static func enemy_sprite_for_identity(enemy_id: String, archetype: String, is_boss: bool = false, style: String = DEFAULT_SPRITE_STYLE) -> String:",
        report,
    )
    _require_text_contains(
        "enemy identity sprite route checks dedicated enemy_id asset",
        text,
        'var dedicated := SPRITE_ROOT + "enemy_%s_64.png" % id_key',
        report,
    )
    _require_text_contains(
        "enemy identity sprite route checks dedicated chibi enemy_id asset first",
        text,
        'var chibi_dedicated := SPRITE_ROOT + "enemy_%s_chibi_64.png" % id_key',
        report,
    )
    _require_text_contains(
        "enemy identity sprite route resolves style before dedicated route",
        text,
        "var resolved_style: String = sprite_style(style)",
        report,
    )
    _require_text_contains(
        "enemy identity sprite route falls back to archetype style",
        text,
        "return enemy_sprite_for_style(archetype, is_boss, resolved_style)",
        report,
    )
    if '"boss": SPRITE_ROOT + "enemy_style_normal_elite_64.png"' in text:
        report.add("error", "boss normal style still falls back to normal elite sprite")
    if '"boss": SPRITE_ROOT + "enemy_style_chibi_elite_64.png"' in text:
        report.add("error", "boss chibi style still falls back to chibi elite sprite")

    runtime_actors = [
        ("player normal", sprites + "player_style_normal_64.png", "player_style_normal", 64),
        ("player chibi", sprites + "player_style_chibi_64.png", "player_style_chibi", 64),
        ("enemy normal melee", sprites + "enemy_style_normal_melee_64.png", "enemy_style_normal_melee", 64),
        ("enemy normal ranged", sprites + "enemy_style_normal_ranged_64.png", "enemy_style_normal_ranged", 64),
        ("enemy normal elite", sprites + "enemy_style_normal_elite_64.png", "enemy_style_normal_elite", 64),
        ("boss normal thunder", sprites + "enemy_thunder_elite_ingame_64.png", "", 64),
        ("enemy chibi melee", sprites + "enemy_style_chibi_melee_64.png", "enemy_style_chibi_melee", 64),
        ("enemy chibi ranged", sprites + "enemy_style_chibi_ranged_64.png", "enemy_style_chibi_ranged", 64),
        ("enemy chibi elite", sprites + "enemy_style_chibi_elite_64.png", "enemy_style_chibi_elite", 64),
        ("boss chibi thunder", sprites + "enemy_thunder_elite_chibi_64.png", "", 64),
        ("enemy wild wolf chibi", sprites + "enemy_wild_wolf_chibi_64.png", "enemy_wild_wolf_chibi", 64),
        ("enemy crossbow cultivator chibi", sprites + "enemy_crossbow_cultivator_chibi_64.png", "enemy_crossbow_cultivator_chibi", 64),
        ("enemy shield guard chibi", sprites + "enemy_shield_guard_chibi_64.png", "enemy_shield_guard_chibi", 64),
        ("enemy sky bat chibi", sprites + "enemy_sky_bat_chibi_64.png", "enemy_sky_bat_chibi", 64),
        ("enemy mud serpent chibi", sprites + "enemy_mud_serpent_chibi_64.png", "enemy_mud_serpent_chibi", 64),
        ("enemy wind mantis chibi", sprites + "enemy_wind_mantis_chibi_64.png", "enemy_wind_mantis_chibi", 64),
        ("enemy furnace golem chibi", sprites + "enemy_furnace_golem_chibi_64.png", "enemy_furnace_golem_chibi", 64),
        ("pet huo_ying", sprites + "pet_huo_ying_32.png", "pet_huo_ying", 32),
    ]
    for label, texture_res_path, slug, min_size in runtime_actors:
        if slug:
            _check_runtime_actor_mapping(label, texture_res_path, slug, min_size, report)
        else:
            check_image(ImageRule(f"{label} runtime texture", texture_res_path, min_size, min_size), report)

    _require_scene_body_texture("player scene default actor", PLAYER_SCENE, sprites + "player_style_normal_64.png", report)
    _require_scene_body_texture("enemy scene default actor", TRAINING_DUMMY_SCENE, sprites + "enemy_style_normal_melee_64.png", report)
    _require_scene_body_texture("pet scene default actor", PET_SCENE, sprites + "pet_huo_ying_32.png", report)

    if not PET_CONTROLLER.exists():
        report.add("error", f"pet controller missing: {rel(PET_CONTROLLER)}")
        return
    pet_text = PET_CONTROLLER.read_text(encoding="utf-8")
    _require_text_contains(
        "pet runtime texture route",
        pet_text,
        "body_visual.set_texture_path(AssetPaths.PET_HUO_YING)",
        report,
    )
    _require_text_contains(
        "pet runtime body is visibly scaled for 1920 combat readability",
        pet_text,
        "body_visual.scale = Vector2(1.25, 1.25)",
        report,
    )
    for label, needle in (
        ("pet world aura uses image2 dao aura", 'AssetPaths.combat_action_fx("player_dao_aura")'),
        ("pet world shadow uses image2 actor presence", 'AssetPaths.combat_action_fx("actor_presence_shadow")'),
        ("pet fallback uses image2 HUD avatar", "AssetPaths.HUD_PET_HUO_YING_AVATAR_64"),
        ("pet exposes aura texture hit count", "func get_pet_aura_texture_hit_count() -> int:"),
        ("pet exposes shadow texture hit count", "func get_pet_shadow_texture_hit_count() -> int:"),
    ):
        _require_text_contains(f"pet world texture contract: {label}", pet_text, needle, report)
    for forbidden in ("draw_arc(", "draw_circle(", "draw_colored_polygon(", "draw_line(", "draw_rect("):
        _require_text_absent("PetController world visuals should use image2 textures, not procedural drawing", pet_text, forbidden, report)

    enemy_script = GAME_ROOT / "scenes" / "enemies" / "training_dummy.gd"
    if not enemy_script.exists():
        report.add("error", f"training dummy script missing: {rel(enemy_script)}")
    else:
        enemy_text = enemy_script.read_text(encoding="utf-8")
        _require_text_contains(
            "enemy runtime texture route prefers identity before archetype fallback",
            enemy_text,
            "AssetPaths.enemy_sprite_for_identity(_enemy_id, _archetype, _is_boss, SaveManager.get_sprite_style())",
            report,
        )
        _require_text_contains(
            "enemy runtime has direct enemy_id configuration route",
            enemy_text,
            "func configure_enemy_by_id(enemy_id: String, is_boss: bool = false, room_type: String = \"combat\", display_name_override: String = \"\") -> void:",
            report,
        )
        _require_text_contains(
            "enemy runtime direct route stores normalized enemy_id",
            enemy_text,
            "_enemy_id = \"boss\" if is_boss else enemy_id.strip_edges().to_lower()",
            report,
        )
        _require_text_contains(
            "enemy runtime body is visibly scaled for 1920 combat readability",
            enemy_text,
            "var visual_scale := 1.36 if _is_boss else (1.18 if _has_persistent_nameplate or _is_promoted_realm else 1.10)",
            report,
        )
        _require_text_contains(
            "enemy runtime has presence shadow",
            enemy_text,
            "func _draw_presence_shadow(radius: float, color: Color) -> void:",
            report,
        )
        _require_text_contains(
            "enemy world status icons expose image2 texture hit count",
            enemy_text,
            "func get_status_icon_texture_hit_count() -> int:",
            report,
        )
        _require_text_contains(
            "enemy world status icon texture route uses AssetPaths",
            enemy_text,
            "AssetPaths.status_icon(status_key)",
            report,
        )
        if "draw_texture_rect(texture, Rect2(Vector2(0.0, -draw_size.y * 0.5), draw_size), false, c)" in enemy_text:
            report.add("error", "enemy windup weapon glyph should not draw a tinted texture rectangle over actors")
        if "_draw_status_fallback_glyph" in enemy_text:
            report.add("error", "enemy world status icons should not keep procedural fallback glyphs after image2 status icon coverage")

        for label, needle in (
            ("enemy loads image2 nameplate", "AssetPaths.ENEMY_NAMEPLATE"),
            ("enemy applies nameplate assets", "func _apply_nameplate_assets() -> void:"),
            ("enemy tints nameplate instead of naked warning text", "func _tint_nameplate(tint: Color) -> void:"),
            ("enemy exposes nameplate texture hit count", "func get_nameplate_texture_hit_count() -> int:"),
            ("enemy exposes world HP texture hit count", "func get_world_hp_texture_hit_count() -> int:"),
            ("enemy ordinary nameplate LOD helper", "func _apply_nameplate_lod() -> void:"),
            ("enemy ordinary reveal timer", "var _plate_reveal_timer := 0.0"),
            ("enemy ordinary reveal duration", "const ORDINARY_PLATE_REVEAL_SEC := 0.65"),
            ("enemy persistent nameplate separates visual elite from hard room", "var _has_persistent_nameplate := false"),
            ("enemy combat hard does not force persistent nameplate", "_has_persistent_nameplate = is_boss or identity_elite"),
            ("enemy visual scale uses persistent nameplate, not hard-room elite", "1.18 if _has_persistent_nameplate or _is_promoted_realm else 1.10"),
            ("enemy ordinary plate visibility helper", "func _should_show_world_plate() -> bool:"),
            ("enemy boss hides redundant world plate", "if _is_boss:\n\t\treturn false"),
            ("enemy ordinary reveal helper", "func _reveal_world_plate(duration: float = ORDINARY_PLATE_REVEAL_SEC) -> void:"),
            ("enemy overlay visibility uses reveal state", "var show_plate := show_hp and _should_show_world_plate()"),
            ("enemy boss nameplate hidden when top boss bar owns text", "nameplate_bg.visible = show_plate and not _is_boss and nameplate_bg.texture != null"),
            ("enemy damage reveals ordinary plate", "_reveal_world_plate()"),
            ("enemy ordinary compact nameplate width", "nameplate_bg.offset_left = -54.0"),
            ("enemy ordinary low-alpha nameplate", "_tint_nameplate(Color(0.55, 0.92, 0.80, 0.26))"),
            ("enemy ordinary secondary name text", "Color(0.78, 0.90, 0.84, 0.66)"),
            ("enemy action label low-alpha text", "Color(ink_color.r, ink_color.g, ink_color.b, 0.68)"),
            ("enemy action label low-alpha backing", "action_label_bg.modulate = Color(ink_color.r, ink_color.g, ink_color.b, 0.24)"),
            ("enemy status badge low-alpha backing", "Color(color.r, color.g, color.b, 0.54)"),
            ("enemy status icon low-alpha draw", "Color(1.0, 1.0, 1.0, 0.66)"),
        ):
            _require_text_contains(f"enemy world nameplate contract: {label}", enemy_text, needle, report)
        for forbidden_color in (
            "Color(1.0, 0.5, 0.28)",
            "Color(1, 0.72, 0.45, 0.72)",
            'next_text = "僵直"',
            'next_text = "缓行"',
            "Color(0.55, 0.92, 0.80, 0.36)",
            "Color(color.r, color.g, color.b, 0.74)",
            "Color(1.0, 1.0, 1.0, 0.78)",
            "name_label.visible = show_hp",
            "world_hp.visible = show_hp and not _is_boss",
        ):
            if forbidden_color in enemy_text:
                report.add("error", f"Enemy world labels should not regress to naked orange/red MMO text: found `{forbidden_color}`")

    if not WORLD_ENEMY_HEALTH_BAR_SCRIPT.exists() or not WORLD_ENEMY_HEALTH_BAR_SCENE.exists():
        report.add("error", "world enemy health bar files missing")
    else:
        enemy_hp_text = WORLD_ENEMY_HEALTH_BAR_SCRIPT.read_text(encoding="utf-8")
        enemy_hp_scene_text = WORLD_ENEMY_HEALTH_BAR_SCENE.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy HP loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
            ("enemy HP uses image2 bar asset", "AssetPaths.ENEMY_HP_BAR"),
            ("enemy HP uses texture style", "StyleBoxTexture.new()"),
            ("enemy HP exposes texture hit count", "func get_texture_style_hit_count() -> int:"),
        ):
            _require_text_contains(f"enemy HP nameplate contract: {label}", enemy_hp_text, needle, report)
        if "StyleBoxFlat.new()" in enemy_hp_text:
            report.add("error", "WorldEnemyHealthBar should use image2 StyleBoxTexture, not StyleBoxFlat")
        if 'name="Bar" type="ProgressBar"' not in enemy_hp_scene_text:
            report.add("error", "WorldEnemyHealthBar should keep a single ProgressBar driven by texture style")
    training_scene_text = TRAINING_DUMMY_SCENE.read_text(encoding="utf-8") if TRAINING_DUMMY_SCENE.exists() else ""
    for label, needle in (
        ("enemy scene has nameplate texture", 'name="NameplateBg" type="TextureRect"'),
        ("enemy scene has action plate texture", 'name="ActionLabelBg" type="TextureRect"'),
    ):
        _require_text_contains(f"enemy world plate scene contract: {label}", training_scene_text, needle, report)
    if 'offset_top = -69.0' not in training_scene_text or 'offset_bottom = -45.0' not in training_scene_text:
        report.add("error", "Enemy NameplateBg should stay raised above HP bar to preserve text/asset spacing")
    if 'offset_top = -35.0' not in training_scene_text or 'offset_bottom = -29.0' not in training_scene_text:
        report.add("error", "Enemy WorldEnemyHealthBar should stay below the nameplate with visible spacing")
    if 'const STATUS_ICON_SIZE := 7.0' not in enemy_text or 'var orbit_radius := radius + 18.0' not in enemy_text:
        report.add("error", "Enemy status icons should stay compact and close to the body so they do not overlap nameplates")

    arena_text = (GAME_ROOT / "scenes" / "rooms" / "arena_base.gd").read_text(encoding="utf-8")
    _require_text_contains(
        "arena runtime spawn passes enemy_id directly",
        arena_text,
        "dummy.configure_enemy_by_id(enemy_id, is_boss, room_type_id, display_name)",
        report,
    )

    if QA_ENEMY_IDENTITY_SCRIPT.exists():
        enemy_qa_text = QA_ENEMY_IDENTITY_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("showcase runs normal style", 'STYLE_CASES := ["normal", "chibi"]'),
            ("showcase sets sprite style per case", "SaveManager.set_sprite_style(style)"),
            ("showcase outputs normal screenshot", "enemy_identity_showcase_%s_1920.png"),
            ("showcase uses direct enemy_id route", "enemy.configure_enemy_by_id(str(spec.get(\"id\", \"\")), false, \"combat\", str(spec.get(\"name\", \"\")))"),
            ("showcase proves identity elite flag matches data", "enemy.is_elite_unit() == expected_elite"),
            ("showcase resolves ordinary archetype", "EnemySpawnRegistry.resolve_archetype_for_id(str(spec.get(\"id\", \"\")), false, \"combat\")"),
            ("showcase checks exact texture path", "texture_path == expected"),
            ("showcase checks chibi identity suffix", '"_chibi_64.png" if SaveManager.get_sprite_style() == "chibi" else "_64.png"'),
            ("showcase reports resolved texture path", 'SaveManager.get_sprite_style(), enemy_id, archetype, texture_path, AssetPaths.animation_dir_for_texture(expected)'),
            ("showcase checks idle/walk/combat frames", "for prefix in [\"idle\", \"walk\", \"combat\"]:"),
            ("showcase checks animation frame route", "AssetPaths.animation_frame_paths_for_texture(expected, prefix)"),
        ):
            _require_text_contains(f"enemy identity showcase runtime contract: {label}", enemy_qa_text, needle, report)

    player_script = GAME_ROOT / "scenes" / "player" / "player.gd"
    if player_script.exists():
        player_text = player_script.read_text(encoding="utf-8")
        _require_text_contains(
            "player runtime body is visibly scaled for 1920 combat readability",
            player_text,
            "body_visual.scale = Vector2(1.16, 1.16)",
            report,
        )
        _require_text_contains(
            "player runtime has presence shadow",
            player_text,
            "func _draw_player_presence_shadow() -> void:",
            report,
        )
        _require_text_contains(
            "player world status icons expose image2 texture hit count",
            player_text,
            "func get_status_icon_texture_hit_count() -> int:",
            report,
        )
        _require_text_contains(
            "player world status icon texture route uses AssetPaths",
            player_text,
            "AssetPaths.status_icon(status_key)",
            report,
        )
        if "_draw_status_fallback_glyph" in player_text:
            report.add("error", "player world status icons should not keep procedural fallback glyphs after image2 status icon coverage")
    else:
        report.add("error", f"player script missing: {rel(player_script)}")


def check_identity_weapon_contract(report: Report) -> None:
    weapon_rows = read_csv_rows(WEAPONS_CSV, report, "weapons.csv")
    path_rows = read_csv_rows(PATHS_CSV, report, "cultivation_paths.csv")
    enemy_rows = read_csv_rows(ENEMIES_CSV, report, "enemies.csv")
    weapons = {row.get("weapon_id", "").strip(): row for row in weapon_rows if row.get("weapon_id", "").strip()}
    required_paths = {"caster", "sword", "talisman", "body", "alchemy", "soul"}
    seen_paths: set[str] = set()
    for row in path_rows:
        path_id = row.get("path_id", "").strip()
        if not path_id:
            report.add("error", "cultivation_paths.csv has a row without path_id")
            continue
        seen_paths.add(path_id)
        weapon_id = row.get("weapon_id", "").strip()
        if not weapon_id:
            report.add("error", f"path {path_id}: missing weapon_id")
            continue
        if weapon_id not in weapons:
            report.add("error", f"path {path_id}: weapon_id `{weapon_id}` missing from weapons.csv")
            continue
        weapon = weapons[weapon_id]
        for field in ("attack_shape", "element_hint", "summary", "start_q"):
            if not weapon.get(field, "").strip():
                report.add("error", f"weapon {weapon_id}: missing identity field `{field}`")
        if weapon.get("attack_shape", "").strip() not in {"projectile", "short_arc"}:
            report.add("error", f"weapon {weapon_id}: unsupported attack_shape `{weapon.get('attack_shape', '')}`")
    missing_paths = sorted(required_paths - seen_paths)
    if missing_paths:
        report.add("error", f"cultivation_paths.csv missing required paths: {', '.join(missing_paths)}")

    weapon_ids = set(weapons.keys())
    required_enemy_ids = {
        "wild_wolf",
        "crossbow_cultivator",
        "shield_guard",
        "sky_bat",
        "mud_serpent",
        "wind_mantis",
        "furnace_golem",
        "boss",
    }
    seen_enemy_ids: set[str] = set()
    enemy_weapon_ids: set[str] = set()
    for row in enemy_rows:
        enemy_id = row.get("enemy_id", "").strip()
        if not enemy_id:
            report.add("error", "enemies.csv has a row without enemy_id")
            continue
        seen_enemy_ids.add(enemy_id)
        weapon_id = row.get("weapon_id", "").strip()
        if not weapon_id:
            report.add("error", f"enemy {enemy_id}: missing weapon_id")
            continue
        enemy_weapon_ids.add(weapon_id)
    missing_enemy_ids = sorted(required_enemy_ids - seen_enemy_ids)
    if missing_enemy_ids:
        report.add("error", f"enemies.csv missing content-pack enemies: {', '.join(missing_enemy_ids)}")
    for weapon_id in sorted(enemy_weapon_ids):
        if weapon_id in weapon_ids:
            continue
        if weapon_id not in {"claw", "poison_spit", "mud_bow", "cloud_crossbow", "wind_blade", "furnace_core", "xuanwu_shield"}:
            report.add("error", f"enemy weapon_id `{weapon_id}` has no weapon table row or dedicated runtime label")

    if not ENEMY_SPAWN_REGISTRY.exists():
        report.add("error", f"enemy spawn registry missing: {rel(ENEMY_SPAWN_REGISTRY)}")
    else:
        registry_text = ENEMY_SPAWN_REGISTRY.read_text(encoding="utf-8")
        _require_text_contains(
            "enemy CSV weapon route",
            registry_text,
            "static func get_weapon_id(enemy_id: String, display_name: String = \"\") -> String:",
            report,
        )
        _require_text_contains(
            "enemy name fallback weapon route",
            registry_text,
            "row = (_enemies_by_name.get(display_name, {}) as Dictionary).duplicate()",
            report,
        )

    if not TRAINING_DUMMY_SCRIPT.exists():
        report.add("error", f"training dummy script missing: {rel(TRAINING_DUMMY_SCRIPT)}")
    else:
        enemy_text = TRAINING_DUMMY_SCRIPT.read_text(encoding="utf-8")
        for marker in (
            "func set_enemy_weapon_id(weapon_id: String) -> void:",
            "func _weapon_label() -> String:",
            "func _draw_weapon_outline(radius: float, color: Color, charge: float) -> void:",
            "const GUARD_AURA_RADIUS :=",
            "const GUARD_DAMAGE_REDUCTION :=",
            "func _apply_guard_protection(amount: float) -> float:",
            "func _is_guarded_by_ally() -> bool:",
            "match _weapon_id:",
            "\"soul_banner\":",
            "\"xuanwu_shield\":",
        ):
            _require_text_contains("enemy weapon readability contract", enemy_text, marker, report)


def check_dark_ink_vfx_toning(report: Report) -> None:
    if not VFX_LIBRARY.exists():
        report.add("error", f"VFX library missing: {rel(VFX_LIBRARY)}")
        return
    library_text = VFX_LIBRARY.read_text(encoding="utf-8")
    _require_text_contains(
        "dark ink VFX color helper",
        library_text,
        "static func ink_vfx_color(color: Color, preset_name: String = \"\", element: String = \"\", status: String = \"\", tier: int = 1) -> Color:",
        report,
    )
    _require_text_contains(
        "burst particles use dark ink toning",
        library_text,
        "p.color = ink_vfx_color(color, preset_name, element, status, tier)",
        report,
    )
    _require_text_contains(
        "burst particles use image2 texture instead of default square particles",
        library_text,
        "p.texture = particle_texture(preset_name)",
        report,
    )
    _require_text_contains(
        "VFX particle texture helper",
        library_text,
        "static func particle_texture(preset_name: String) -> Texture2D:",
        report,
    )
    _require_text_contains(
        "VFX gold particles use spirit stone image2 texture",
        library_text,
        "AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)",
        report,
    )
    if '"gold": {"amount": 24' in library_text or '"scale_max": 3.5' in library_text:
        report.add("error", "VfxLibrary should keep burst particles small/textured; old large default-square particle values found")
    for forbidden in (
        '"hit": {"amount": 10',
        '"crit": {"amount": 12',
        '"combo": {"amount": 14',
        '"dao": {"amount": 16',
        '"scale_max": 0.24',
        '"speed_max": 122.0',
    ):
        if forbidden in library_text:
            report.add("error", f"VfxLibrary burst presets should stay restrained for combat readability: found `{forbidden}`")
    _require_text_contains(
        "VFX element color table",
        library_text,
        "const ELEMENT_VFX_COLORS := {",
        report,
    )
    _require_text_contains(
        "VFX status color table",
        library_text,
        "const STATUS_VFX_COLORS := {",
        report,
    )

    if VFX_MANAGER.exists():
        manager_text = VFX_MANAGER.read_text(encoding="utf-8")
        _require_text_contains(
            "semantic VFX passes element/status to toning",
            manager_text,
            "VfxLibrary.ink_vfx_color(color, preset, element, status, resolved_tier)",
            report,
        )
        _require_text_contains(
            "burst pool keeps semantic color context",
            manager_text,
            "_spawn_burst(parent, global_pos, preset, color, false, element, status, resolved_tier)",
            report,
        )
        _require_text_contains(
            "burst pool reuses particle texture context",
            manager_text,
            "particles.texture = fresh.texture",
            report,
        )
        _require_text_contains(
            "enemy attack telegraph restrained alpha",
            manager_text,
            "lerpf(0.22, 0.03, t)",
            report,
        )
        for label, needle in (
            ("enemy spawn telegraph low alpha", "var alpha := 0.10 + pulse * 0.22"),
            ("enemy spawn telegraph compact radius", "radius * (2.15 if elite else 1.85)"),
            ("enemy attack telegraph restrained lane width", 'width * (2.6 if kind == "dash" else 2.0)'),
            ("enemy reduced motion impact restrained alpha", "modulate.a = 0.42 * (1.0 - t)"),
            ("enemy attack telegraph reduced impact alpha", "mark.modulate = Color(color.r, color.g, color.b, 0.44)"),
        ):
            _require_text_contains(f"VFX readability contract: {label}", manager_text, needle, report)
        for forbidden in (
            "0.22 + pulse * 0.55",
            "0.16 + pulse * 0.34",
            "lerpf(0.42, 0.04, t)",
            "lerpf(0.30, 0.035, t)",
            "width * (4.4 if kind == \"dash\" else 3.4)",
            "width * (3.2 if kind == \"dash\" else 2.45)",
            "modulate.a = 0.58 * (1.0 - t)",
            "mark.modulate = Color(color.r, color.g, color.b, 0.58)",
        ):
            if forbidden in manager_text:
                report.add("error", f"VfxManager should not regress to oversized/overbright combat telegraphs: found `{forbidden}`")
    else:
        report.add("error", f"VFX manager missing: {rel(VFX_MANAGER)}")

    if STATUS_COMPONENT.exists():
        status_text = STATUS_COMPONENT.read_text(encoding="utf-8")
        for old_color in [
            "Color(1.0, 0.95, 0.28)",
            "Color(0.42, 1.0, 0.35)",
            "Color(0.45, 0.9, 1.0)",
        ]:
            if old_color in status_text:
                report.add("error", f"status colors still contain pre-redesign white-hot value {old_color}")
    else:
        report.add("error", f"status component missing: {rel(STATUS_COMPONENT)}")

    if PROJECTILE_SCRIPT.exists():
        projectile_text = PROJECTILE_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "projectile trails use dark ink toning",
            projectile_text,
            "VfxLibrary.ink_vfx_color(_draw_color, \"cast\", element_key, status_on_hit, vfx_tier)",
            report,
        )
        for label, needle in (
            ("player projectile loads image2 trail texture", "AssetPaths.load_texture(AssetPaths.projectile_trail(element_key, status_on_hit))"),
            ("player projectile draws image2 trail texture", "draw_texture_rect(_trail_texture"),
            ("player projectile exposes trail texture hit count", "func get_trail_texture_hit_count() -> int:"),
            ("player projectile exposes trail texture path", "func get_trail_texture_path() -> String:"),
            ("player projectile exposes core texture hit count", "func get_core_texture_hit_count() -> int:"),
            ("player projectile exposes core texture path", "func get_core_texture_path() -> String:"),
            ("player projectile core uses semantic sprite route", "AssetPaths.projectile_for_semantics(element_key, status_on_hit, _draw_color)"),
        ):
            _require_text_contains(label, projectile_text, needle, report)
        if "draw_line(" in projectile_text:
            report.add("error", "player projectile should not use procedural draw_line trails after image2 trail integration")
        for forbidden in (
            "branch_scale = 1.16",
            "_draw_radius * (5.4",
            "74.0",
            "0.42)",
        ):
            if forbidden in projectile_text:
                report.add("error", f"player projectile trail should stay restrained after image2 integration: found `{forbidden}`")
        projectile_draw_start = projectile_text.find("func _draw() -> void:")
        projectile_draw_end = projectile_text.find("\nfunc _draw_trail_texture", projectile_draw_start)
        projectile_draw_block = projectile_text[projectile_draw_start:projectile_draw_end if projectile_draw_end != -1 else len(projectile_text)]
        for forbidden in ("draw_circle(", "draw_rect(", "draw_colored_polygon("):
            if forbidden in projectile_draw_block:
                report.add("error", f"player projectile core should use image2 sprite texture, found `{forbidden}` in _draw")
    else:
        report.add("error", f"projectile script missing: {rel(PROJECTILE_SCRIPT)}")

    if ENEMY_PROJECTILE_SCRIPT.exists():
        enemy_projectile_text = ENEMY_PROJECTILE_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy projectile stores element semantics", "var element_key := \"\""),
            ("enemy projectile stores status semantics", "var status_on_hit := \"\""),
            ("enemy projectile uses semantic sprite route", "AssetPaths.projectile_for_semantics(element_key, status_on_hit, _color)"),
            ("enemy projectile trails use dark ink toning", "VfxLibrary.ink_vfx_color(_color, \"cast\", element_key, status_on_hit, 1)"),
            ("enemy projectile loads image2 trail texture", "AssetPaths.load_texture(AssetPaths.enemy_projectile_trail(element_key, status_on_hit))"),
            ("enemy projectile draws image2 trail texture", "draw_texture_rect(_trail_texture"),
            ("enemy projectile exposes trail texture hit count", "func get_trail_texture_hit_count() -> int:"),
            ("enemy projectile exposes core texture hit count", "func get_core_texture_hit_count() -> int:"),
            ("enemy projectile exposes core texture path", "func get_core_texture_path() -> String:"),
            ("enemy projectile hit uses semantic VFX", "VfxManager.spawn_hit_feedback(global_position, element_key, status_on_hit, _draw_color, 1)"),
            ("enemy projectile expands player hit payload", "body.receive_enemy_projectile(damage, element_key, status_on_hit, status_duration, source_tag)"),
        ):
            _require_text_contains(label, enemy_projectile_text, needle, report)
        if "draw_line(" in enemy_projectile_text:
            report.add("error", "enemy projectile should not use procedural draw_line trails after image2 trail integration")
        for forbidden in (
            "_radius * 5.6",
            "58.0)",
            "0.38)",
        ):
            if forbidden in enemy_projectile_text:
                report.add("error", f"enemy projectile trail should stay restrained after image2 integration: found `{forbidden}`")
        enemy_projectile_draw_start = enemy_projectile_text.find("func _draw() -> void:")
        enemy_projectile_draw_end = enemy_projectile_text.find("\nfunc _enemy_tip_color", enemy_projectile_draw_start)
        enemy_projectile_draw_block = enemy_projectile_text[enemy_projectile_draw_start:enemy_projectile_draw_end if enemy_projectile_draw_end != -1 else len(enemy_projectile_text)]
        for forbidden in ("draw_circle(", "draw_rect(", "draw_colored_polygon("):
            if forbidden in enemy_projectile_draw_block:
                report.add("error", f"enemy projectile core should use image2 sprite texture, found `{forbidden}` in _draw")
    else:
        report.add("error", f"enemy projectile script missing: {rel(ENEMY_PROJECTILE_SCRIPT)}")

    if COMBAT_SPAWNER.exists():
        spawner_text = COMBAT_SPAWNER.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy projectile spawner passes element", 'str(payload.get("element", ""))'),
            ("enemy projectile spawner passes status", 'str(payload.get("status_on_hit", ""))'),
            ("enemy projectile spawner passes status duration", 'float(payload.get("status_duration", 0.0))'),
            ("enemy projectile spawner passes source tag", 'str(payload.get("source_tag", "enemy_projectile"))'),
        ):
            _require_text_contains(label, spawner_text, needle, report)
    else:
        report.add("error", f"combat spawner missing: {rel(COMBAT_SPAWNER)}")

    if ENEMY_SKILL_CONTROLLER.exists():
        skill_controller_text = ENEMY_SKILL_CONTROLLER.read_text(encoding="utf-8")
        _require_text_contains(
            "enemy skill controller asks owner for projectile semantics",
            skill_controller_text,
            "owner_body.has_method(\"get_enemy_projectile_semantics\")",
            report,
        )
        _require_text_contains(
            "enemy projectile source tag preserves weapon id",
            skill_controller_text,
            '"source_tag": "enemy_%s_%s"',
            report,
        )
    else:
        report.add("error", f"enemy skill controller missing: {rel(ENEMY_SKILL_CONTROLLER)}")

    if TRAINING_DUMMY_SCRIPT.exists():
        enemy_text = TRAINING_DUMMY_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy identity exposes projectile semantics", "func get_enemy_projectile_semantics(skill: Dictionary = {}) -> Dictionary:"),
            ("enemy projectile semantics map poison spit", '"poison_spit":'),
            ("enemy projectile semantics map cloud crossbow", '"cloud_crossbow":'),
            ("enemy projectile semantics map furnace core", '"furnace_core":'),
            ("enemy projectile semantics map skill burst to real status", 'result["status"] = "burn"'),
        ):
            _require_text_contains(label, enemy_text, needle, report)

    player_script = GAME_ROOT / "scenes" / "player" / "player.gd"
    if player_script.exists():
        player_text = player_script.read_text(encoding="utf-8")
        for label, needle in (
            ("player enemy projectile interface carries element", "element_key: String = \"\""),
            ("player enemy projectile interface carries status", "status_name: String = \"\""),
            ("player enemy projectile applies semantic status", "apply_status(clean_status, maxf(status_duration, 0.8))"),
            ("player damage event carries enemy projectile source", '"source_tag": source_tag'),
            ("player enemy projectile emits semantic feedback anchor", 'EventBus.feedback_anchor_requested.emit("enemy_projectile_hit"'),
        ):
            _require_text_contains(label, player_text, needle, report)
    else:
        report.add("error", f"player script missing: {rel(player_script)}")

    asset_paths_text = _asset_paths_text()
    for needle in [
        '"water": HUD_SPELL_XUAN_BING_FAN',
        '"ice": HUD_SPELL_XUAN_BING_FAN',
        '"wood": HUD_SPELL_HUI_CHUN_JUE',
        '"chaos": HUD_SPELL_SUMMON_SOUL',
    ]:
        _require_text_contains("spell element fallback uses dedicated 96px icons", asset_paths_text, needle, report)


def check_combat_action_fx_contract(report: Report) -> None:
    asset_paths_text = _asset_paths_text()
    for label, needle in (
        ("combat action FX dictionary", "const COMBAT_ACTION_FX := {"),
        ("enemy windup weapon dictionary", "const ENEMY_WINDUP_WEAPONS := {"),
        ("combat action FX helper", "static func combat_action_fx(key: String) -> String:"),
        ("enemy windup weapon helper", "static func enemy_windup_weapon(weapon_id: String) -> String:"),
        ("player slash route", '"player_slash_arc": FX_PLAYER_SLASH_ARC'),
        ("crit slash route", '"crit_screen_slash": FX_CRIT_SCREEN_SLASH'),
        ("enemy soul banner route", '"soul_banner": FX_ROOT + "enemy_weapon_soul_banner_96x128.png"'),
    ):
        _require_text_contains(f"combat action FX AssetPaths contract: {label}", asset_paths_text, needle, report)

    player_script = GAME_ROOT / "scenes" / "player" / "player.gd"
    if player_script.exists():
        player_text = player_script.read_text(encoding="utf-8")
        for label, needle in (
            ("slash arc loads image2 texture", 'AssetPaths.combat_action_fx("player_slash_arc")'),
            ("slash arc draws image2 texture", "draw_texture_rect(_texture"),
            ("player combat FX texture cache", "func _combat_fx_texture(key: String) -> Texture2D:"),
            ("player combat FX hit counter", "func get_combat_fx_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"player combat FX contract: {label}", player_text, needle, report)
        slash_start = player_text.find("class SlashArcVisual:")
        slash_end = player_text.find("\nfunc _resolve_basic_attack_direction", slash_start)
        slash_block = player_text[slash_start:slash_end if slash_end != -1 else len(player_text)]
        for forbidden in ("draw_arc(", "draw_line("):
            if forbidden in slash_block:
                report.add("error", f"SlashArcVisual should use image2 slash texture, found `{forbidden}` in slash block")
        for forbidden in ("draw_circle(", "draw_arc(", "draw_colored_polygon("):
            if forbidden in player_text:
                report.add("error", f"Player actor/status visuals should fail closed or use image2 textures, found `{forbidden}`")
    else:
        report.add("error", f"player script missing: {rel(player_script)}")

    if SPRITE_VISUAL_SCRIPT.exists():
        sprite_visual_text = SPRITE_VISUAL_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains(
            "SpriteVisual missing actor texture fails closed",
            sprite_visual_text,
            'push_error("SpriteVisual missing image2 texture',
            report,
        )
        for forbidden in ("fallback_radius", "fallback_color", "fallback circle"):
            if forbidden in sprite_visual_text:
                report.add("error", f"SpriteVisual should not expose actor fallback placeholders, found `{forbidden}`")
        for forbidden in ("draw_circle(", "draw_arc(", "draw_line(", "draw_rect(", "draw_colored_polygon("):
            if forbidden in sprite_visual_text:
                report.add("error", f"SpriteVisual should not render procedural actor fallback geometry, found `{forbidden}`")
    else:
        report.add("error", f"sprite visual script missing: {rel(SPRITE_VISUAL_SCRIPT)}")

    for scene_path in (PLAYER_SCENE, PET_SCENE, TRAINING_DUMMY_SCENE):
        if not scene_path.exists():
            report.add("error", f"actor scene missing: {rel(scene_path)}")
            continue
        scene_text = scene_path.read_text(encoding="utf-8")
        for forbidden in ("fallback_radius", "fallback_color", "fallback circle"):
            if forbidden in scene_text:
                report.add("error", f"Actor scene `{rel(scene_path)}` should not keep procedural fallback placeholder fields: found `{forbidden}`")

    for qa_path in (QA_VISUAL_INTEGRATION_SCRIPT, QA_ENEMY_IDENTITY_SCRIPT):
        if not qa_path.exists():
            report.add("error", f"actor visual QA script missing: {rel(qa_path)}")
            continue
        qa_text = qa_path.read_text(encoding="utf-8")
        for forbidden in ("fallback_radius", "fallback_color", "fallback circle"):
            if forbidden in qa_text:
                report.add("error", f"Actor visual QA `{rel(qa_path)}` should not set removed procedural fallback fields: found `{forbidden}`")

    if TRAINING_DUMMY_SCRIPT.exists():
        enemy_text = TRAINING_DUMMY_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy windup seal route", '_combat_fx_texture("enemy_windup_seal")'),
            ("enemy windup weapon route", "AssetPaths.enemy_windup_weapon(_weapon_id)"),
            ("enemy weapon glyph sizing", "func _weapon_glyph_size(charge: float) -> Vector2:"),
            ("enemy combat FX hit counter", "func get_combat_fx_texture_hit_count() -> int:"),
            ("enemy windup hit counter", "func get_windup_weapon_texture_hit_count() -> int:"),
            ("enemy movement trail texture route", "AssetPaths.enemy_projectile_trail(element, \"\")"),
            ("enemy movement trail hit counter", "func get_movement_trail_texture_hit_count() -> int:"),
            ("enemy movement trail draw helper", "func _draw_movement_trail(dir: Vector2, radius: float, streak: float, color: Color) -> void:"),
            ("enemy debug windup hook", "func debug_force_windup(skill_type: String = \"melee\", progress: float = 0.58) -> void:"),
        ):
            _require_text_contains(f"enemy combat FX contract: {label}", enemy_text, needle, report)
        movement_start = enemy_text.find("var move_speed :=")
        movement_end = enemy_text.find("\n\tif _skills and _skills.get_windup_progress()", movement_start)
        movement_block = enemy_text[movement_start:movement_end if movement_end != -1 else len(enemy_text)]
        if "_draw_movement_trail(" not in movement_block:
            report.add("error", "Enemy movement streak should route through image2 movement trail helper")
        for forbidden in ("draw_line(", "draw_circle(", "draw_arc(", "draw_rect(", "draw_colored_polygon("):
            if forbidden in movement_block:
                report.add("error", f"Enemy movement streak should use image2 trail texture, found `{forbidden}`")
        weapon_start = enemy_text.find("func _draw_weapon_outline")
        weapon_end = enemy_text.find("\nfunc _weapon_glyph_size", weapon_start)
        weapon_block = enemy_text[weapon_start:weapon_end if weapon_end != -1 else len(enemy_text)]
        for forbidden in ("draw_line(", "draw_circle(", "draw_arc(", "draw_rect(", "draw_colored_polygon("):
            if forbidden in weapon_block:
                report.add("error", f"Enemy windup weapon outline should use image2 glyph texture, found `{forbidden}`")
        for forbidden in ("draw_line(", "draw_circle(", "draw_arc(", "draw_rect(", "draw_colored_polygon("):
            if forbidden in enemy_text:
                report.add("error", f"Enemy actor/status visuals should fail closed or use image2 textures, found `{forbidden}`")
        if "fallback circle" in enemy_text:
            report.add("error", "Enemy body sprite path should not reference a fallback circle")
        if 'push_error("TrainingDummy missing image2 enemy texture' not in enemy_text:
            report.add("error", "Enemy missing body texture path should fail closed with a push_error")
    else:
        report.add("error", f"training dummy script missing: {rel(TRAINING_DUMMY_SCRIPT)}")

    crit_script = GAME_ROOT / "vfx" / "crit_slash_draw.gd"
    if crit_script.exists():
        crit_text = crit_script.read_text(encoding="utf-8")
        for label, needle in (
            ("crit slash loads image2 texture", 'AssetPaths.combat_action_fx("crit_screen_slash")'),
            ("crit slash draws image2 texture", "draw_texture_rect(_slash_texture"),
            ("crit slash exposes hit count", "func get_slash_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"crit slash FX contract: {label}", crit_text, needle, report)
        for forbidden in ("draw_line(", "draw_arc("):
            if forbidden in crit_text:
                report.add("error", f"CritSlashDraw should not regress to procedural line slash: found `{forbidden}`")
    else:
        report.add("error", f"crit slash script missing: {rel(crit_script)}")

    if ENEMY_SKILL_CONTROLLER.exists():
        controller_text = ENEMY_SKILL_CONTROLLER.read_text(encoding="utf-8")
        _require_text_contains(
            "enemy skill debug windup helper",
            controller_text,
            "func debug_force_windup(skill_type: String = \"melee\", progress: float = 0.58) -> void:",
            report,
        )

    if QA_ENEMY_IDENTITY_SCRIPT.exists():
        enemy_identity_text = QA_ENEMY_IDENTITY_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy showcase detects pure magenta debug blocks", "suspicious_magenta_pixels"),
            ("enemy showcase detects saturated red debug blocks", "suspicious_red_pixels"),
            ("enemy showcase detects clustered pure-color blocks", "suspicious_max_bucket"),
            ("enemy showcase reports suspicious block pixels", "suspicious pure-color block pixels"),
            ("enemy showcase rejects large pure-color blocks", "likely an unkeyed windup/weapon texture"),
        ):
            _require_text_contains(f"enemy identity pure-color QA contract: {label}", enemy_identity_text, needle, report)
    else:
        report.add("error", f"enemy identity showcase script missing: {rel(QA_ENEMY_IDENTITY_SCRIPT)}")

    if QA_VISUAL_REGRESSION.exists():
        regression_text = QA_VISUAL_REGRESSION.read_text(encoding="utf-8")
        visual_integration_text = QA_VISUAL_INTEGRATION_SCRIPT.read_text(encoding="utf-8") if QA_VISUAL_INTEGRATION_SCRIPT.exists() else ""
        visual_integration_wrapper_text = QA_VISUAL_INTEGRATION_WRAPPER.read_text(encoding="utf-8") if QA_VISUAL_INTEGRATION_WRAPPER.exists() else ""
        for label, needle in (
            ("visual integration matrix capture list", "const MAP_MATRIX_CAPTURES := ["),
            ("visual integration matrix runner", "func _capture_map_weather_matrix() -> void:"),
            ("visual integration matrix case contract", "func _check_map_weather_case_contracts(spec: Dictionary, room: Dictionary, image: Image) -> void:"),
            ("visual integration matrix terrain sprite assertion", "_count_textured_sprites_recursive(terrain_root) >= 2"),
            ("visual integration matrix weather particle assertion", "get_weather_particle_texture_hit_count"),
            ("visual integration matrix thunder marker assertion", "ThunderStrikeMarker*"),
            ("visual integration matrix stage1 clear", "map_matrix_stage1_qi_refining_verdant_clear_1920.png"),
            ("visual integration matrix stage2 thunder", "map_matrix_stage2_foundation_cavern_thunder_1920.png"),
            ("visual integration matrix stage3 sand", "map_matrix_stage3_golden_core_demon_sand_1920.png"),
            ("visual integration matrix stage4 snow", "map_matrix_stage4_nascent_soul_ruins_snow_1920.png"),
            ("visual integration matrix stage5 wind", "map_matrix_stage5_tribulation_thunder_wind_1920.png"),
        ):
            _require_text_contains(
                f"map/weather visual matrix contract: {label}",
                visual_integration_text + "\n" + visual_integration_wrapper_text + "\n" + regression_text,
                needle,
                report,
            )
        _require_text_contains(
            "visual regression should include normal enemy identity showcase",
            regression_text,
            "enemy_identity_showcase_normal_1920.png",
            report,
        )
        _require_text_contains(
            "visual regression should include chibi enemy identity showcase",
            regression_text,
            "enemy_identity_showcase_chibi_1920.png",
            report,
        )
    else:
        report.add("error", f"visual regression script missing: {rel(QA_VISUAL_REGRESSION)}")


def check_overlay_ornament_fx_contract(report: Report) -> None:
    asset_paths_text = _asset_paths_text()
    for label, needle in (
        ("Dao fire pattern route", '"dao_pattern_fire": FX_DAO_PATTERN_FIRE'),
        ("Dao thunder pattern route", '"dao_pattern_thunder": FX_DAO_PATTERN_THUNDER'),
        ("Dao wood pattern route", '"dao_pattern_wood": FX_DAO_PATTERN_WOOD'),
        ("Dao water pattern route", '"dao_pattern_water": FX_DAO_PATTERN_WATER'),
        ("Dao five pattern route", '"dao_pattern_five": FX_DAO_PATTERN_FIVE'),
        ("crit edge top route", '"crit_edge_top": FX_CRIT_EDGE_TOP'),
        ("crit edge side route", '"crit_edge_side": FX_CRIT_EDGE_SIDE'),
        ("crit edge corner route", '"crit_edge_corner": FX_CRIT_EDGE_CORNER'),
    ):
        _require_text_contains(f"overlay ornament FX AssetPaths contract: {label}", asset_paths_text, needle, report)

    if DAO_TRADITION_SCRIPT.exists() and DAO_TRADITION_SCENE.exists():
        dao_text = DAO_TRADITION_SCRIPT.read_text(encoding="utf-8")
        dao_scene_text = DAO_TRADITION_SCENE.read_text(encoding="utf-8")
        for label, needle in (
            ("Dao overlay has pattern TextureRect nodes", 'name="TopLeftPattern" type="TextureRect"'),
            ("Dao overlay routes style to image2 pattern", 'AssetPaths.combat_action_fx("dao_pattern_%s" % style)'),
            ("Dao overlay exposes pattern texture hit count", "func get_pattern_texture_hit_count() -> int:"),
            ("Dao overlay keeps fire fallback", 'AssetPaths.combat_action_fx("dao_pattern_fire")'),
            ("Dao overlay uses compact gold divider instead of a combat banner", "AssetPaths.DIVIDER_GOLD"),
            ("Dao overlay applies explicit top band layout", "func _apply_top_band_layout() -> void:"),
            ("Dao overlay hides title frame at startup", "frame.visible = false"),
            ("Dao overlay shows title frame only on awaken", "frame.visible = true"),
            ("Dao overlay has shared visual cleanup", "func _hide_all_visuals() -> void:"),
            ("Dao overlay cleanup always hides title frame", "_hide_all_visuals()\n\t_restore_time_scale()"),
        ):
            _require_text_contains(f"DaoTraditionOverlay assetized pattern contract: {label}", dao_text + "\n" + dao_scene_text, needle, report)
        frame_match = re.search(r'\[node name="Frame"[^]]*\](?P<body>.*?)(?=\n\[node |\Z)', dao_scene_text, re.S)
        if frame_match is None or "visible = false" not in frame_match.group("body"):
            report.add("error", "DaoTraditionOverlay Frame must default to visible=false so announcement backing cannot leak into combat center")
        else:
            body = frame_match.group("body")
            if "anchors_preset = 5" not in body or "anchor_top = 0.5" in body:
                report.add("error", "DaoTraditionOverlay Frame must use a top-band anchor, not centered anchors")
            if "offset_left = -210.0" not in body or "offset_right = 210.0" not in body:
                report.add("error", "DaoTraditionOverlay Frame must stay as a compact 420px divider instead of a modal title bar")
            if "offset_top = 194.0" not in body or "offset_bottom = 198.0" not in body:
                report.add("error", "DaoTraditionOverlay Frame must stay as a thin divider under the title rather than the combat center")
            if "modulate = Color(1, 0.843, 0, 0.42)" not in body:
                report.add("error", "DaoTraditionOverlay Frame should default to a subtle gold divider")
        if "anchor_top = 0.5" in dao_scene_text:
            report.add("error", "DaoTraditionOverlay banner/subtitle/frame must not use centered vertical anchors")
        if "AssetPaths.MODAL_TITLE_BAR" in dao_text or "AssetPaths.SCROLL_TOAST" in dao_text:
            report.add("error", "DaoTraditionOverlay must not load long title/scroll textures for combat overlay moments")
        if 'tween_property(glow, "modulate:a", 0.30' in dao_text or 'tween_property(glow, "modulate:a", 0.20' in dao_text:
            report.add("error", "DaoTraditionOverlay full-screen glow must stay low alpha so combat does not wash out")
        for forbidden in ("draw_polyline(", "draw_line(", "draw_circle(", "draw_arc("):
            if forbidden in dao_text:
                report.add("error", f"DaoTraditionOverlay should use image2 corner patterns, found `{forbidden}`")
    else:
        report.add("error", "DaoTraditionOverlay files missing")

    if CRIT_MOMENT_SCRIPT.exists() and CRIT_MOMENT_SCENE.exists():
        crit_text = CRIT_MOMENT_SCRIPT.read_text(encoding="utf-8")
        crit_scene_text = CRIT_MOMENT_SCENE.read_text(encoding="utf-8")
        for label, needle in (
            ("Crit overlay has edge TextureRect nodes", 'name="Top" type="TextureRect" parent="EdgeGlow"'),
            ("Crit overlay loads top edge image2 texture", 'AssetPaths.combat_action_fx("crit_edge_top")'),
            ("Crit overlay loads side edge image2 texture", 'AssetPaths.combat_action_fx("crit_edge_side")'),
            ("Crit overlay loads corner image2 texture", 'AssetPaths.combat_action_fx("crit_edge_corner")'),
            ("Crit overlay exposes edge texture hit count", "func get_edge_texture_hit_count() -> int:"),
            ("Crit overlay connects viewport resize", "viewport.size_changed.connect(_apply_fullscreen_layout)"),
        ):
            _require_text_contains(f"CritMomentOverlay assetized edge contract: {label}", crit_text + "\n" + crit_scene_text, needle, report)
        if "NOTIFICATION_RESIZED" in crit_text:
            report.add("error", "CritMomentOverlay extends CanvasLayer and must not use Control-only NOTIFICATION_RESIZED")
        edge_start = crit_text.find("func _apply_edge_textures")
        edge_block = crit_text[edge_start if edge_start != -1 else 0:]
        if "draw_rect(" in edge_block or "func _draw_edge_glow" in crit_text:
            report.add("error", "CritMomentOverlay edge glow should use image2 edge textures, not procedural draw_rect edge bars")
        for forbidden in (
            'tween_property(vignette, "modulate:a", 0.84',
            'tween_property(vignette, "modulate:a", 0.78',
            'tween_property(vignette, "modulate:a", 0.72',
            'tween_property(vignette, "modulate:a", 0.55',
            "_set_desaturate_strength(0.82)",
        ):
            if forbidden in crit_text:
                report.add("error", f"CritMomentOverlay must not show full-screen rectangular wash over combat: found `{forbidden}`")
    else:
        report.add("error", "CritMomentOverlay files missing")

    if COMBAT_FEEDBACK_SCRIPT.exists():
        feedback_text = COMBAT_FEEDBACK_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("feedback backing stays icon-sized", "backing.size = Vector2(28, 28)"),
            ("feedback backing preserves aspect", "TextureRect.STRETCH_KEEP_ASPECT_CENTERED"),
            ("damage floater compact root", "root.custom_minimum_size = Vector2(118, 32)"),
            ("text floater compact root", "root.custom_minimum_size = Vector2(138, 32)"),
        ):
            _require_text_contains(f"CombatFeedbackLayer compact floater contract: {label}", feedback_text, needle, report)
        for forbidden in ("backing.size = Vector2(116, 44)", "TextureRect.STRETCH_SCALE"):
            if forbidden in feedback_text:
                report.add("error", f"CombatFeedbackLayer floater backing must not stretch into a horizontal banner: found `{forbidden}`")
    else:
        report.add("error", "CombatFeedbackLayer script missing")


def check_hud_skill_dock_asset_contract(report: Report) -> None:
    asset_paths_text = _asset_paths_text()
    for label, needle in (
        ("ready slot frame constant", "const HUD_SPELL_SLOT_READY_FRAME :="),
        ("cooldown slot frame constant", "const HUD_SPELL_SLOT_COOLDOWN_FRAME :="),
        ("locked slot frame constant", "const HUD_SPELL_SLOT_LOCKED_FRAME :="),
        ("shortcut badge constant", "const HUD_SPELL_SHORTCUT_BADGE :="),
        ("cooldown sweep constant", "const HUD_SPELL_COOLDOWN_SWEEP :="),
        ("spell slot frame helper", "static func spell_slot_frame(ready: bool, unlocked: bool) -> String:"),
        ("spell shortcut badge helper", "static func spell_shortcut_badge() -> String:"),
        ("spell cooldown sweep helper", "static func spell_cooldown_sweep() -> String:"),
    ):
        _require_text_contains(f"HUD SkillDock AssetPaths contract: {label}", asset_paths_text, needle, report)

    for label, res_path, width, height in (
        ("HUD auto seal base", "res://assets/ui/hud_auto_seal_base_64.png", 64, 64),
        ("HUD auto seal attack", "res://assets/ui/hud/auto_seal_attack_64.png", 64, 64),
        ("HUD auto seal guard", "res://assets/ui/hud/auto_seal_guard_64.png", 64, 64),
        ("HUD auto seal pet", "res://assets/ui/hud/auto_seal_pet_64.png", 64, 64),
        ("HUD auto seal artifact", "res://assets/ui/hud/auto_seal_artifact_64.png", 64, 64),
        ("HUD spell slot ready frame", "res://assets/ui/spell_slot_ready_frame_96.png", 96, 96),
        ("HUD spell slot cooldown frame", "res://assets/ui/spell_slot_cooldown_frame_96.png", 96, 96),
        ("HUD spell slot locked frame", "res://assets/ui/spell_slot_locked_frame_96.png", 96, 96),
        ("HUD spell shortcut badge", "res://assets/ui/spell_shortcut_badge_32.png", 32, 32),
        ("HUD spell cooldown sweep", "res://assets/ui/spell_cooldown_sweep_96.png", 96, 96),
    ):
        check_image(ImageRule(label, res_path, exact_width=width, exact_height=height), report)

    if not HUD_SKILL_DOCK_SCRIPT.exists() or not HUD_SKILL_DOCK_SCENE.exists():
        report.add("error", "HudSkillDock files missing")
        return
    if not SPELL_SLOT_SCRIPT.exists() or not SPELL_SLOT_SCENE.exists() or not SPELL_ICON_FRAME_SCRIPT.exists():
        report.add("error", "SpellSlot/SpellIconFrame files missing")
        return
    dock_text = HUD_SKILL_DOCK_SCRIPT.read_text(encoding="utf-8")
    dock_scene_text = HUD_SKILL_DOCK_SCENE.read_text(encoding="utf-8")
    slot_text = SPELL_SLOT_SCRIPT.read_text(encoding="utf-8")
    slot_scene_text = SPELL_SLOT_SCENE.read_text(encoding="utf-8")
    frame_text = SPELL_ICON_FRAME_SCRIPT.read_text(encoding="utf-8")
    combined = "\n".join([dock_text, dock_scene_text, slot_text, slot_scene_text, frame_text])

    for label, needle in (
        ("SpellQ scene node", 'name="SpellQ"'),
        ("SpellE scene node", 'name="SpellE"'),
        ("SpellR scene node", 'name="SpellR"'),
        ("slot frame texture node", 'name="SlotFrame" type="TextureRect"'),
        ("shortcut badge texture node", 'name="ShortcutBadge" type="TextureRect"'),
        ("cooldown texture node", 'name="CooldownSweep" type="TextureRect"'),
        ("spell slot loads frame helper", "AssetPaths.spell_slot_frame(ready, unlocked)"),
        ("spell slot loads shortcut badge helper", "AssetPaths.spell_shortcut_badge()"),
        ("spell frame loads cooldown sweep helper", "AssetPaths.spell_cooldown_sweep()"),
        ("slot frame hit getter", "func get_slot_frame_texture_hit_count() -> int:"),
        ("shortcut badge hit getter", "func get_shortcut_badge_texture_hit_count() -> int:"),
        ("cooldown texture hit getter", "func get_cooldown_texture_hit_count() -> int:"),
        ("dock slot debug accessor", "func get_spell_slot_node(slot: String) -> Node:"),
    ):
        _require_text_contains(f"HUD SkillDock runtime contract: {label}", combined, needle, report)

    for forbidden in (
        "HudStyles.spell_dock_slot",
        "key_bg := StyleBoxFlat.new()",
        "add_theme_stylebox_override(\"panel\", HudStyles.spell_dock_slot",
    ):
        _require_text_absent("SpellSlot should use image2 slot/key textures", slot_text, forbidden, report)
    for forbidden in ("draw_arc(", "draw_circle(", "draw_line(", "draw_rect("):
        _require_text_absent("SpellIconFrame should not use procedural cooldown/ring main visuals", frame_text, forbidden, report)

    if QA_VISUAL_INTEGRATION_SCRIPT.exists():
        integration_text = QA_VISUAL_INTEGRATION_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("runtime skill dock checker", "func _check_hud_skill_dock_texture_contracts() -> void:"),
            ("runtime checks SpellQ", '"q": "SpellQ"'),
            ("runtime checks SpellE", '"e": "SpellE"'),
            ("runtime checks SpellR", '"r": "SpellR"'),
            ("runtime slot frame hit count", "get_slot_frame_texture_hit_count"),
            ("runtime shortcut badge hit count", "get_shortcut_badge_texture_hit_count"),
            ("runtime cooldown hit count", "get_cooldown_texture_hit_count"),
            ("runtime status orbs checker", "func _check_hud_status_orb_texture_contracts() -> void:"),
            ("runtime checks LeftOrbs", '"LeftOrbs"'),
            ("runtime checks RightOrbs", '"RightOrbs"'),
            ("runtime combat rail checker", "func _check_hud_combat_rail_texture_contracts() -> void:"),
            ("runtime combat rail hit count", "get_rail_texture_hit_count"),
            ("runtime combat rail tick hit count", "get_tick_texture_hit_count"),
            ("runtime combat rail action hit count", "get_action_texture_hit_count"),
        ):
            _require_text_contains(f"HUD SkillDock visual integration contract: {label}", integration_text, needle, report)
    else:
        report.add("error", f"visual integration script missing: {rel(QA_VISUAL_INTEGRATION_SCRIPT)}")

    if not HUD_STATUS_ORBS_SCRIPT.exists():
        report.add("error", "HudStatusOrbs script missing")
    else:
        orbs_text = HUD_STATUS_ORBS_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("loads base seal texture", "AssetPaths.HUD_AUTO_SEAL_BASE"),
            ("loads shortcut badge texture", "AssetPaths.spell_shortcut_badge()"),
            ("base texture hit getter", "func get_base_texture_hit_count() -> int:"),
            ("seal texture hit getter", "func get_seal_texture_hit_count() -> int:"),
            ("key badge hit getter", "func get_key_badge_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"HudStatusOrbs texture contract: {label}", orbs_text, needle, report)
        for forbidden in ("draw_circle(", "draw_arc(", "draw_rect("):
            _require_text_absent("HudStatusOrbs should use image2 orb/key textures", orbs_text, forbidden, report)

    hp_bar_script = GAME_ROOT / "ui" / "components" / "hud_hp_bar.gd"
    resource_bar_script = GAME_ROOT / "ui" / "components" / "hud_resource_bar.gd"
    if not hp_bar_script.exists() or not resource_bar_script.exists():
        report.add("error", "HudHpBar/HudResourceBar scripts missing")
    else:
        hp_text = hp_bar_script.read_text(encoding="utf-8")
        resource_text = resource_bar_script.read_text(encoding="utf-8")
        for label, needle in (
            ("HP bar loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
            ("HP bar uses HP image2 fill", "AssetPaths.PROGRESS_HP"),
            ("HP bar uses HUD resource track", "AssetPaths.HUD_LEFT_RESOURCE_TRACK"),
            ("HP track hit getter", "func get_track_texture_hit_count() -> int:"),
            ("HP fill hit getter", "func get_fill_texture_hit_count() -> int:"),
            ("Resource bar exposes track hit getter", "func get_track_texture_hit_count() -> int:"),
            ("Resource bar exposes fill hit getter", "func get_fill_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"HudResourceBar/HpBar texture contract: {label}", hp_text + "\n" + resource_text, needle, report)
        for forbidden in ("draw_rect(", "draw_line(", "draw_circle(", "draw_arc("):
            _require_text_absent("HudHpBar should use image2 resource textures, not procedural geometry", hp_text, forbidden, report)

    if not HUD_COMPANION_ARTIFACT_PANEL_SCRIPT.exists():
        report.add("error", "HudCompanionArtifactPanel script missing")
    else:
        companion_text = HUD_COMPANION_ARTIFACT_PANEL_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("uses 96px pet image2 avatar", "AssetPaths.HUD_PET_HUO_YING_AVATAR_96"),
            ("uses 96px artifact image2 avatar", "AssetPaths.HUD_ARTIFACT_XUANYU_GOURD_96"),
            ("uses auto seal base texture", "AssetPaths.HUD_AUTO_SEAL_BASE"),
            ("uses cooldown sweep texture", "AssetPaths.spell_cooldown_sweep()"),
            ("pet texture hit getter", "func get_pet_texture_hit_count() -> int:"),
            ("artifact texture hit getter", "func get_artifact_texture_hit_count() -> int:"),
            ("base texture hit getter", "func get_base_texture_hit_count() -> int:"),
            ("charge texture hit getter", "func get_charge_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"HudCompanionArtifactPanel texture contract: {label}", companion_text, needle, report)
        for forbidden in ("draw_circle(", "draw_arc("):
            _require_text_absent("HudCompanionArtifactPanel should use image2 icon base/charge textures", companion_text, forbidden, report)

    if not HUD_COMBAT_RAIL_SCRIPT.exists():
        report.add("error", "HudCombatRail script missing")
    else:
        rail_text = HUD_COMBAT_RAIL_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("loads combo rail texture", "AssetPaths.COMBO_TRACK"),
            ("loads tick badge texture", "AssetPaths.spell_shortcut_badge()"),
            ("loads action marker texture", "AssetPaths.spell_cooldown_sweep()"),
            ("rail texture hit getter", "func get_rail_texture_hit_count() -> int:"),
            ("tick texture hit getter", "func get_tick_texture_hit_count() -> int:"),
            ("action texture hit getter", "func get_action_texture_hit_count() -> int:"),
            ("combo font size getter", "func get_combo_number_font_size() -> int:"),
            ("action font size getter", "func get_action_font_size() -> int:"),
            ("rail compact width", "custom_minimum_size = Vector2(144, 310)"),
            ("combo number no debug scale", "const COMBO_NUMBER_FONT_SIZE := 36"),
            ("action font secondary scale", "const ACTION_FEED_FONT_SIZE := 12"),
        ):
            _require_text_contains(f"HudCombatRail texture contract: {label}", rail_text, needle, report)
        for forbidden in (
            "RAIL_DEBUG_",
            "font_size, 64",
            "const RAIL_DEBUG_TEXT_MAX_SIZE",
            "Vector2(190, 360)",
            "Vector2(150, 300)",
            "Color(1.0, 0.86, 0.34)",
        ):
            _require_text_absent("HudCombatRail should stay compact instead of debug-sized", rail_text, forbidden, report)
        for forbidden in ("draw_line(", "draw_circle(", "draw_arc("):
            _require_text_absent("HudCombatRail should use image2 rail/tick/action textures", rail_text, forbidden, report)


def check_world_fx_asset_contract(report: Report) -> None:
    asset_paths_text = _asset_paths_text()
    for label, needle in (
        ("AssetPaths declares FX root", 'const FX_ROOT := SPRITE_ROOT + "fx/"'),
        ("AssetPaths declares weather decal table", "const WEATHER_DECALS := {"),
        ("AssetPaths routes storm weather decal alias", '"storm": FX_ROOT + "weather_decal_thunder_128.png"'),
        ("AssetPaths routes thunderstorm weather decal alias", '"thunderstorm": FX_ROOT + "weather_decal_thunder_128.png"'),
        ("AssetPaths exposes weather decal helper", "static func weather_decal(weather_id: String) -> String:"),
        ("AssetPaths declares weather overlay particle table", "const WEATHER_OVERLAY_PARTICLES := {"),
        ("AssetPaths routes thunderstorm weather particle alias", '"thunderstorm": FX_ROOT + "weather_particle_thunder_64x96.png"'),
        ("AssetPaths exposes weather overlay particle helper", "static func weather_overlay_particle(weather_id: String) -> String:"),
        ("AssetPaths declares enemy projectile trail table", "const ENEMY_PROJECTILE_TRAILS := {"),
        ("AssetPaths exposes enemy projectile trail helper", "static func enemy_projectile_trail(element: String = \"\", status: String = \"\") -> String:"),
        ("AssetPaths exposes player projectile trail helper", "static func projectile_trail(element: String = \"\", status: String = \"\") -> String:"),
        ("AssetPaths exposes enemy spawn telegraph helper", "static func enemy_spawn_telegraph(elite: bool = false) -> String:"),
        ("AssetPaths exposes enemy attack telegraph helper", "static func enemy_attack_telegraph(kind: String = \"line\") -> String:"),
        ("AssetPaths declares thunder warning texture", "const THUNDER_STRIKE_WARNING :="),
        ("AssetPaths declares thunder bolt texture", "const THUNDER_STRIKE_BOLT :="),
        ("AssetPaths declares enemy sniper telegraph texture", "const ENEMY_ATTACK_SNIPER :="),
    ):
        _require_text_contains(f"world FX AssetPaths contract: {label}", asset_paths_text, needle, report)

    if VFX_MANAGER.exists():
        manager_text = VFX_MANAGER.read_text(encoding="utf-8")
        for label, needle in (
            ("enemy spawn telegraph loads image2 texture", "AssetPaths.load_texture(AssetPaths.enemy_spawn_telegraph(elite))"),
            ("enemy attack telegraph loads image2 texture", "AssetPaths.load_texture(AssetPaths.enemy_attack_telegraph(kind))"),
            ("enemy attack telegraph supports texture draw", "draw_texture_rect("),
            ("enemy attack telegraph keeps kind", "marker.kind = kind"),
            ("reduced impact mark is texture sprite", "class ReducedImpactMark:\n\textends Sprite2D"),
            ("reduced impact loads impact frames", "var frames := _load_impact_frames(color, element, status)"),
            ("gold reward mote is texture sprite", "class GoldRewardMote:\n\t编辑extends Sprite2D".replace("编辑", "")),
            ("gold reward mote loads spirit stone icon", "texture = AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)"),
            ("gold reward mote exposes spawn count", "func get_gold_reward_mote_spawn_count() -> int:"),
            ("gold reward mote exposes texture hit count", "func get_gold_reward_mote_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"world FX VfxManager contract: {label}", manager_text, needle, report)
        for class_name, end_marker in (
            ("class SpawnTelegraph:", "\nclass AttackTelegraph:"),
            ("class AttackTelegraph:", "\nclass GoldRewardMote:"),
        ):
            start = manager_text.find(class_name)
            end = manager_text.find(end_marker, start)
            block = manager_text[start:end if end != -1 else len(manager_text)]
            if "draw_line(" in block:
                report.add("error", f"{class_name} should fail closed without procedural line fallback when image2 telegraph texture is missing")
        reduced_start = manager_text.find("class ReducedImpactMark:")
        reduced_end = manager_text.find("\nfunc should_reduce_motion", reduced_start)
        reduced_block = manager_text[reduced_start:reduced_end if reduced_end != -1 else len(manager_text)]
        for forbidden in ("draw_arc(", "draw_line(", "draw_circle(", "draw_rect("):
            if forbidden in reduced_block:
                report.add("error", f"ReducedImpactMark should use image2 impact texture, found `{forbidden}`")
        if "draw_colored_polygon(points" in manager_text:
            report.add("error", "GoldRewardMote should use image2 spirit-stone texture, not procedural polygon drawing")
    else:
        report.add("error", f"VFX manager missing: {rel(VFX_MANAGER)}")

    if ENEMY_SKILL_CONTROLLER.exists():
        skill_text = ENEMY_SKILL_CONTROLLER.read_text(encoding="utf-8")
        _require_text_contains(
            "enemy skill controller passes skill type into telegraph",
            skill_text,
            "VfxManager.spawn_enemy_attack_telegraph(owner_body.global_position, dir, length, duration, width, color, skill_type)",
            report,
        )
    else:
        report.add("error", f"enemy skill controller missing: {rel(ENEMY_SKILL_CONTROLLER)}")

    if WEATHER_OVERLAY.exists():
        overlay_text = WEATHER_OVERLAY.read_text(encoding="utf-8")
        for label, needle in (
            ("weather overlay loads image2 particle texture", "AssetPaths.load_texture(AssetPaths.weather_overlay_particle(key))"),
            ("weather overlay draws textured particles", "draw_texture_rect("),
            ("weather overlay exposes texture hit count", "func get_weather_particle_texture_hit_count() -> int:"),
            ("weather overlay exposes particle count", "func get_weather_particle_count() -> int:"),
        ):
            _require_text_contains(f"world FX WeatherOverlay contract: {label}", overlay_text, needle, report)
        for forbidden in ("func _draw_rain", "func _draw_snow", "func _draw_fog", "func _draw_streaks"):
            if forbidden in overlay_text:
                report.add("error", f"WeatherOverlay should not keep procedural weather shape fallback `{forbidden}` after image2 particle integration")
    else:
        report.add("error", f"weather overlay missing: {rel(WEATHER_OVERLAY)}")

    if COMBAT_FLOOR.exists():
        floor_text = COMBAT_FLOOR.read_text(encoding="utf-8")
        for label, needle in (
            ("combat floor loads weather decal texture", "AssetPaths.load_texture(AssetPaths.weather_decal(weather_id))"),
            ("combat floor draws weather decal sprite", "sprite.texture = texture"),
            ("combat floor preloads RunRng", 'const RunRng = preload("res://core/utils/run_rng.gd")'),
            ("combat floor normalizes weather aliases", "func _normalized_weather_id(weather_id: String) -> String:"),
            ("combat floor maps thunderstorm alias", '"storm", "thunderstorm":'),
            ("combat floor loads thunder warning image2 decal", "AssetPaths.THUNDER_STRIKE_WARNING"),
            ("combat floor loads thunder impact image2 decal", "AssetPaths.THUNDER_STRIKE_IMPACT"),
            ("combat floor loads thunder bolt image2 decal", "AssetPaths.THUNDER_STRIKE_BOLT"),
            ("combat floor loads thunder scorch image2 decal", "AssetPaths.THUNDER_STRIKE_SCORCH"),
            ("combat floor skips obstacle visual fallback", "skipped obstacle without image2 terrain prop texture"),
            ("combat floor skips weather decal fallback", "skipped weather ground cover without image2 decal"),
            ("combat floor skips thunder marker fallback", "skipped thunder strike marker because an image2 strike decal is missing"),
            ("combat floor caps tile detail coverage", "const FLOOR_DETAIL_MAX_COVERAGE := 0.28"),
            ("combat floor exposes tile detail alpha", "func get_floor_detail_alpha() -> float:"),
            ("combat floor exposes tile detail count", "func get_floor_detail_used_cell_count() -> int:"),
            ("combat floor uses sparse ink detail", "func _uses_floor_ink_detail(theme: Dictionary, x: int, y: int) -> bool:"),
            ("combat floor keeps weather floor detail low alpha", "func _floor_detail_modulate_for_weather(weather_id: String) -> Color:"),
        ):
            _require_text_contains(f"world FX CombatFloor contract: {label}", floor_text, needle, report)
        if "_weather_ground_root.z_index = -1" in floor_text:
            report.add("error", "WeatherGroundRoot z_index should not stay behind the floor after image2 decal integration")
        if "var floor := Color.WHITE" in floor_text or "_floor_layer.modulate = floor" in floor_text:
            report.add("error", "CombatFloor should not recolor FloorLayer as a full weather-washed ground plane")
        if "var floor_atlas := _atlas_coords_from_theme" in floor_text:
            report.add("error", "CombatFloor should not fill every FloorLayer cell with base floor atlas over image2 room background")
        for forbidden in (
            "var visual := ColorRect.new()",
            "var patch := Polygon2D.new()",
            "draw_circle(Vector2.ZERO, _radius",
            "draw_arc(Vector2.ZERO, _radius",
            "draw_polyline(bolt",
        ):
            if forbidden in floor_text:
                report.add("error", f"CombatFloor should not keep visible procedural fallback geometry: found `{forbidden}`")
    else:
        report.add("error", f"combat floor missing: {rel(COMBAT_FLOOR)}")


def check_long_term_record_contract(report: Report) -> None:
    if not SAVE_MANAGER.exists():
        report.add("error", f"save manager missing: {rel(SAVE_MANAGER)}")
        return
    save_text = SAVE_MANAGER.read_text(encoding="utf-8")
    for label, needle in (
        ("run history cap constant", "const RUN_HISTORY_LIMIT :="),
        ("build record cap constant", "const BUILD_RECORD_LIMIT :="),
        ("profile path helper", "func _profile_path() -> String:"),
        ("QA save path override", "--qa-save-path="),
        ("schema migration helper", "func _ensure_profile_schema() -> bool:"),
        ("run result API", "func record_run_result(summary: Dictionary) -> Dictionary:"),
        ("run records getter", "func get_run_records(limit: int = RUN_HISTORY_LIMIT) -> Array:"),
        ("build records getter", "func get_build_records(limit: int = BUILD_RECORD_LIMIT) -> Array:"),
        ("codex seen API", "func record_codex_seen(kind: String, id: String, payload: Dictionary = {}) -> bool:"),
        ("enemy kill API", "func record_enemy_kill(enemy_id: String, count: int = 1, payload: Dictionary = {}) -> bool:"),
        ("codex summary getter", "func get_codex_summary() -> Dictionary:"),
        ("lifetime summary text", "func format_lifetime_summary() -> String:"),
        ("run history default field", '"run_history": []'),
        ("build records default field", '"build_records": []'),
        ("codex default field", '"codex": {'),
        ("stats default field", '"stats": {'),
    ):
        _require_text_contains(f"long-term SaveManager contract: {label}", save_text, needle, report)
    for forbidden in ("history.append(summary)", "run_history.append(summary)"):
        if forbidden in save_text:
            report.add("error", f"SaveManager should sanitize run summaries before appending: found `{forbidden}`")

    if RUN_CONTEXT.exists():
        run_context_text = RUN_CONTEXT.read_text(encoding="utf-8")
        for label, needle in (
            ("run record builder", "func build_run_record(victory: bool) -> Dictionary:"),
            ("finalize writes record", "SaveManager.record_run_result(build_run_record(victory))"),
            ("duplicate finalize guard", "if _run_recorded:"),
            ("room codex sampling", "func record_room_for_codex(room: Dictionary, stage: Dictionary) -> void:"),
            ("affix codex sampling", "func record_affix_for_codex(affix_id: String) -> void:"),
            ("enemy kill codex sampling", "func record_enemy_kill_for_codex(enemy: Node) -> void:"),
            ("hidden chain codex sampling", "func record_hidden_chain_for_codex(chain_id: String) -> void:"),
            ("stable enemy id route", "enemy.has_method(\"get_codex_id\")"),
        ):
            _require_text_contains(f"long-term RunContext contract: {label}", run_context_text, needle, report)
    else:
        report.add("error", f"run context missing: {rel(RUN_CONTEXT)}")

    if TRAINING_DUMMY_SCRIPT.exists():
        enemy_text = TRAINING_DUMMY_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains("enemy exposes stable codex id", enemy_text, "func get_codex_id() -> String:", report)
        _require_text_contains("enemy id resolved from registry", enemy_text, "EnemySpawnRegistry.get_enemy_row_by_name(display_name)", report)
    else:
        report.add("error", f"training dummy script missing: {rel(TRAINING_DUMMY_SCRIPT)}")

    if ENEMY_SPAWN_REGISTRY.exists():
        registry_text = ENEMY_SPAWN_REGISTRY.read_text(encoding="utf-8")
        _require_text_contains("enemy registry supports name lookup", registry_text, "static func get_enemy_row_by_name(display_name: String) -> Dictionary:", report)
    else:
        report.add("error", f"enemy spawn registry missing: {rel(ENEMY_SPAWN_REGISTRY)}")

    if RUN_RESULT_PANEL.exists() and RUN_RESULT_PANEL_SCENE.exists():
        result_text = RUN_RESULT_PANEL.read_text(encoding="utf-8")
        result_scene_text = RUN_RESULT_PANEL_SCENE.read_text(encoding="utf-8")
        _require_text_contains("result panel formats epitaph", result_text, "func _format_epitaph_text(record: Dictionary) -> String:", report)
        _require_text_contains("result panel reads latest run record", result_text, "SaveManager.get_latest_run_record()", report)
        _require_text_contains("result panel displays 前世碑", result_text, "前世碑", report)
        for label, needle in (
            ("restart button uses image2 button asset", "UiHelpers.apply_button_asset(restart_button, true)"),
            ("restart button uses dao icon", "restart_button.icon = AssetPaths.load_texture(AssetPaths.status_icon(\"dao\"))"),
            ("shared modal veil is applied", "UiHelpers.apply_modal_veil(dimmer, 0.76)"),
            ("victory seal uses large dao heart asset", "AssetPaths.RUN_RESULT_VICTORY_SEAL"),
            ("result seal uses death soul disc", "AssetPaths.DEATH_SOUL_TOTEM_DISC"),
            ("result stats row updater", "func _update_stat_cards(rooms: int, combo: int, gold: int) -> void:"),
            ("long detail uses scroll container", 'name="DetailScroll" type="ScrollContainer"'),
            ("result seal scene node", 'name="ResultSealWrap" type="Control"'),
            ("result stats scene row", 'name="StatsRow" type="HBoxContainer"'),
            ("run result dimmer is texture veil", 'name="Dimmer" type="TextureRect"'),
            ("detail onready path targets scroll content", "@onready var detail_label: Label = $Panel/Margin/VBox/DetailScroll/Detail"),
        ):
            _require_text_contains(f"run result assetized failure-safe contract: {label}", result_text + "\n" + result_scene_text, needle, report)
        if 'name="Dimmer" type="ColorRect"' in result_scene_text:
            report.add("error", "RunResultPanel must not regress to a pure ColorRect dimmer")
        if "var icon_path := AssetPaths.status_icon(\"dao\") if victory" in result_text:
            report.add("error", "RunResult victory seal must not upscale 32px status_dao icon")
    else:
        report.add("error", "run result panel files missing")

    if EVENT_PANEL_SCRIPT.exists():
        event_text = EVENT_PANEL_SCRIPT.read_text(encoding="utf-8")
        for label, needle in (
            ("event choices derive karma from real effect payload", "func _choice_karma_key(choice: Dictionary) -> String:"),
            ("event choices map karma good", 'effect.contains("karma:good")'),
            ("event choices map karma evil", 'effect.contains("karma:evil")'),
            ("event choices map karma greed", 'effect.contains("karma:greed")'),
            ("event choices map explicit heart demon to rebellion icon", '"heart_demon":'),
            ("event choices map trial accept", 'effect.contains("trial_accept")'),
            ("event choices map trial leave", 'effect.contains("trial_leave")'),
            ("event weather art readability tint", "func _event_art_modulate(event: Dictionary) -> Color:"),
            ("event art semantic icon overlay", "func _event_icon_path(event: Dictionary) -> String:"),
            ("event icon image2 backing", 'art_icon_backing.texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("status_badge_backing"))'),
            ("event heart demon art expanded height", "return 250.0"),
            ("event weather art expanded height", 'return 230.0 if category in ["weather", "karma"] else 210.0'),
            ("event icon compact size", "art_icon.custom_minimum_size = Vector2(44, 44)"),
            ("event icon backing restrained alpha", "art_icon_backing.modulate = Color(0.72, 0.94, 0.86, 0.62)"),
            ("event weather icon route", "AssetPaths.weather_icon(str(event.get(\"weather\", \"thunder\")))"),
        ):
            _require_text_contains(f"event panel semantic icon contract: {label}", event_text, needle, report)
    else:
        report.add("error", f"event panel missing: {rel(EVENT_PANEL_SCRIPT)}")

    if HUD_SCRIPT.exists():
        hud_text = HUD_SCRIPT.read_text(encoding="utf-8")
        _require_text_contains("HUD codex reads lifetime summary", hud_text, "SaveManager.get_lifetime_summary()", report)
        _require_text_contains("HUD codex exposes lifetime items", hud_text, '"lifetime_items": _build_codex_lifetime_items(lifetime)', report)
        _require_text_contains("HUD codex exposes current build record", hud_text, "RunContext.get_current_build_snapshot()", report)
        hud_scene_text = (GAME_ROOT / "scenes" / "ui" / "hud.tscn").read_text(encoding="utf-8")
        for label, needle in (
            ("HUD learn feedback routes to rail only", "func _on_learn_feedback(text: String, accent: String = \"spell\") -> void:"),
            ("HUD learn feedback routes to rail", "combat_rail.push_action(_short_feedback(text.replace(\"\\n\", \" \")), color)"),
            ("HUD Boss health handler", "func _on_boss_health_changed(display_name: String, current: float, maximum: float, phase_index: int, phase_count: int, phase_name: String) -> void:"),
            ("HUD Boss phase tick layer", '_boss_phase_tick_layer.name = "BossPhaseTicks"'),
            ("HUD Boss phase tick renderer", "func _render_boss_phase_ticks(phase_count: int, phase_index: int) -> void:"),
            ("HUD Boss objective text includes BOSS", 'top_objective_text.text = "BOSS · %s · %s · 命元 %.0f/%.0f"'),
            ("HUD Boss objective wins over horde objective", "if _boss_objective_mode:\n\t\tcharacter_panel.hide_objective()\n\t\twave_label.text = _room_title if not _room_title.is_empty() else _boss_name\n\t\treturn\n\tif _horde_active"),
            ("HUD scene top objective anchor", 'name="TopObjectiveAnchor" type="Control"'),
        ):
            _require_text_contains(f"HUD feedback assetized contract: {label}", hud_text + "\n" + hud_scene_text, needle, report)
        for forbidden in (
            'name="LearnToastPanel"',
            'name="ScrollBg"',
            "learn_toast_panel",
            "learn_toast_bg",
            "_tick_learn_toast",
            "_position_learn_toast",
            "_set_learn_toast_rect",
            "AssetPaths.load_texture(AssetPaths.SCROLL_TOAST)",
            "learn_toast_bg.texture = toast_tex",
        ):
            if forbidden in hud_text or forbidden in hud_scene_text:
                report.add("error", f"HUD must not keep legacy LearnToast/scroll banner path: `{forbidden}`")
        if "_has_persistent_nameplate = is_boss or identity_elite or room_type == \"combat_hard\"" in enemy_text:
            report.add("error", "combat_hard enemies must not all get persistent world nameplates")
    else:
        report.add("error", f"HUD script missing: {rel(HUD_SCRIPT)}")

    if JADE_CODEX_OVERLAY.exists():
        codex_text = JADE_CODEX_OVERLAY.read_text(encoding="utf-8")
        _require_text_contains("Jade codex has 战绩 tab", codex_text, '"战绩"', report)
        _require_text_contains("Jade codex draws lifetime grid", codex_text, '_draw_stats_grid(font, center, "lifetime_items")', report)
        _require_text_contains("Jade codex displays current build", codex_text, "本局构筑", report)
        for label, needle in (
            ("loads panel ninepatch", "AssetPaths.PANEL_NINEPATCH"),
            ("loads gold divider", "AssetPaths.DIVIDER_GOLD"),
            ("loads tab button texture", "AssetPaths.BTN_SECONDARY"),
            ("loads section card texture", "AssetPaths.HUD_LEFT_OBJECTIVE_CARD"),
            ("loads five dao pattern texture", 'AssetPaths.combat_action_fx("dao_pattern_five")'),
            ("loads thunder dao pattern texture", 'AssetPaths.combat_action_fx("dao_pattern_thunder")'),
            ("loads status badge backing texture", 'AssetPaths.combat_action_fx("status_badge_backing")'),
            ("loads cooldown sweep texture", "AssetPaths.spell_cooldown_sweep()"),
            ("loads resource track texture", "AssetPaths.HUD_LEFT_RESOURCE_TRACK"),
            ("loads shortcut badge texture", "AssetPaths.spell_shortcut_badge()"),
            ("loads affix fire rune", "AssetPaths.HUD_AFFIX_RUNE_FIRE"),
            ("loads affix seal rune", "AssetPaths.HUD_AFFIX_RUNE_SEAL"),
            ("draws ninepatch texture regions", "func _draw_ninepatch_texture(texture: Texture2D, rect: Rect2, margin: float, tint: Color) -> void:"),
            ("uses assetized tab helper", "func _draw_codex_tab(rect: Rect2, active: bool, accent: Color"),
            ("uses assetized surface helper", "func _draw_codex_surface(rect: Rect2, accent: Color, warm: bool) -> void:"),
            ("uses assetized small card helper", "func _draw_small_codex_card(rect: Rect2, accent: Color) -> void:"),
            ("uses image2 pattern helper", "func _draw_pattern_disc(center: Vector2, diameter: float, tint: Color, alpha: float, texture: Texture2D) -> void:"),
            ("uses image2 badge helper", "func _draw_codex_badge(rect: Rect2, tint: Color, rune_key: String = \"\") -> void:"),
            ("uses image2 progress helper", "func _draw_charge_sweep(rect: Rect2, tint: Color, alpha: float) -> void:"),
            ("pattern texture hit getter", "func get_pattern_texture_hit_count() -> int:"),
            ("badge texture hit getter", "func get_badge_texture_hit_count() -> int:"),
            ("progress texture hit getter", "func get_progress_texture_hit_count() -> int:"),
        ):
            _require_text_contains(f"Jade codex assetized overlay contract: {label}", codex_text, needle, report)
        if "AssetPaths.MODAL_TITLE_BAR" in codex_text or "_title_bar_texture" in codex_text:
            report.add("error", "Jade codex must not draw the old empty 720px modal title bar; use the compact gold divider instead")
        for func_name in ("_draw_affix_mandala", "_draw_dao_ring", "_draw_pet_orbit", "_draw_artifact_core", "_draw_strategy_list"):
            block_start = codex_text.find(f"func {func_name}")
            block_end = codex_text.find("\nfunc ", block_start + 1) if block_start >= 0 else -1
            block = codex_text[block_start:block_end if block_end >= 0 else len(codex_text)] if block_start >= 0 else ""
            for forbidden in ("draw_circle(", "draw_arc(", "draw_line("):
                if forbidden in block:
                    report.add("error", f"Jade codex `{func_name}` should use image2 texture assets instead of procedural geometry: found `{forbidden}`")
        for forbidden in (
            "draw_rect(panel, Color(0.012",
            "draw_rect(rect, Color(0.03",
            "draw_rect(rect, Color(0.018",
            "draw_rect(rect, Color(0.035",
            "draw_rect(cell, Color(0.025",
            "draw_rect(row, Color(0.022",
            "draw_rect(rect, fallback_color",
            "draw_rect(rect, tint",
        ):
            if forbidden in codex_text:
                report.add("error", f"Jade codex should not regress to procedural panel/card/tab backgrounds: found `{forbidden}`")
        draw_rect_count = codex_text.count("draw_rect(")
        if draw_rect_count != 1 or "draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78), true)" not in codex_text:
            report.add("error", "Jade codex should only keep the single full-screen dim draw_rect; all visible UI surfaces must use image2 textures")
    else:
        report.add("error", f"jade codex overlay missing: {rel(JADE_CODEX_OVERLAY)}")

    if PAUSE_OVERLAY_SCRIPT.exists() and PAUSE_OVERLAY_SCENE.exists():
        pause_text = PAUSE_OVERLAY_SCRIPT.read_text(encoding="utf-8")
        pause_scene_text = PAUSE_OVERLAY_SCENE.read_text(encoding="utf-8")
        _require_text_contains("pause overlay reads lifetime summary", pause_text, "SaveManager.format_lifetime_summary()", report)
        _require_text_contains("pause overlay has lifetime label", pause_scene_text, "LifetimeLabel", report)
        for label, needle in (
            ("pause overlay styles buttons with image2 assets", "UiHelpers.apply_button_asset(button, false)"),
            ("pause overlay applies toggle visual state", "func _apply_toggle_button_state(button: Button) -> void:"),
            ("pause overlay uses segmented sprite style buttons", "_sprite_style_buttons = {"),
            ("pause overlay normal segment exists", 'NormalStyleButton" type="Button"'),
            ("pause overlay chibi segment exists", 'ChibiStyleButton" type="Button"'),
        ):
            _require_text_contains(f"pause overlay assetized control contract: {label}", pause_text + "\n" + pause_scene_text, needle, report)
        if "type=\"CheckButton\"" in pause_scene_text or "CheckButton" in pause_text:
            report.add("error", "Pause overlay should use assetized toggle Buttons, not Godot-native CheckButton")
        if "type=\"OptionButton\"" in pause_scene_text or "OptionButton" in pause_text:
            report.add("error", "Pause overlay should use segmented asset buttons, not Godot-native OptionButton")
    else:
        report.add("error", "pause overlay lifetime summary files missing")

    if RUN_SETUP_PANEL_SCRIPT.exists() and RUN_SETUP_PANEL_SCENE.exists():
        setup_text = RUN_SETUP_PANEL_SCRIPT.read_text(encoding="utf-8")
        setup_scene_text = RUN_SETUP_PANEL_SCENE.read_text(encoding="utf-8")
        for label, needle in (
            ("run setup shared modal veil", "UiHelpers.apply_modal_veil(dimmer, 0.52)"),
            ("run setup preview panel onready", "@onready var run_preview: PanelContainer"),
            ("run setup preview updater", "func _update_run_preview(def: Dictionary) -> void:"),
            ("run setup preview stat updater", "func _set_preview_stat(card: PanelContainer, text: String, tint: Color) -> void:"),
            ("run setup heart demon uses asset button", '@onready var heart_demon_check: Button'),
            ("run setup heart demon state helper", "func _apply_heart_demon_button_state() -> void:"),
            ("run setup seed input image2 styling", "func _apply_seed_input_chrome() -> void:"),
            ("run setup seed input uses secondary asset", "UiHelpers.make_button_texture_style(AssetPaths.BTN_SECONDARY"),
            ("run setup path icon route", "AssetPaths.path_icon(path_id)"),
            ("run setup path icon node", 'PathIcon"'),
            ("run setup path label node", 'PathLabel"'),
            ("run setup scene preview panel", 'name="RunPreview" type="PanelContainer"'),
            ("run setup scene preview stats", 'name="PreviewStats" type="HBoxContainer"'),
            ("run setup scene preview seal icon", 'name="PreviewSealIcon" type="TextureRect"'),
        ):
            _require_text_contains(f"run setup assetized control contract: {label}", setup_text + "\n" + setup_scene_text, needle, report)
        if "type=\"CheckButton\"" in setup_scene_text or "CheckButton" in setup_text:
            report.add("error", "RunSetupPanel should use assetized toggle Buttons, not Godot-native CheckButton")
        if 'name="Dimmer" type="ColorRect"' in setup_scene_text:
            report.add("error", "RunSetupPanel must not regress to a pure ColorRect dimmer")
    else:
        report.add("error", "run setup panel files missing")

    for wrapper in (QA_GAMEPLAY_WRAPPER, QA_RUN_FLOW_WRAPPER):
        if not wrapper.exists():
            report.add("error", f"QA wrapper missing: {rel(wrapper)}")
            continue
        wrapper_text = wrapper.read_text(encoding="utf-8")
        _require_text_contains(f"{wrapper.name} passes QA save path", wrapper_text, "--qa-save-path=", report)
        _require_text_contains(f"{wrapper.name} uses tmp/qa_saves", wrapper_text, "qa_saves", report)

    if QA_FLOW_UI_SCRIPT.exists() and QA_FLOW_UI_WRAPPER.exists() and QA_VISUAL_REGRESSION.exists():
        flow_text = QA_FLOW_UI_SCRIPT.read_text(encoding="utf-8")
        flow_wrapper_text = QA_FLOW_UI_WRAPPER.read_text(encoding="utf-8")
        regression_text = QA_VISUAL_REGRESSION.read_text(encoding="utf-8")
        combined = flow_text + "\n" + flow_wrapper_text + "\n" + regression_text
        for screenshot in (
            "flow_run_setup_heart_demon_1920.png",
            "flow_event_regular_1920.png",
            "flow_event_weather_1920.png",
            "flow_event_karma_1920.png",
            "flow_run_result_failure_1920.png",
            "flow_pause_confirm_1920.png",
        ):
            _require_text_contains(f"Flow UI branch screenshot contract: {screenshot}", combined, screenshot, report)
        for label, needle in (
            ("flow QA emits failure result", "EventBus.run_completed.emit(false)"),
            ("flow QA opens pause confirm", "end_button.pressed.emit()"),
            ("flow QA checks pause cancel", "Pause confirm cancel should hide ConfirmBox"),
            ("flow QA checks event art categories", 'expected_category == "regular"'),
            ("flow QA checks heart demon seed state", "_check_run_setup_heart_demon_contracts"),
        ):
            _require_text_contains(f"Flow UI branch semantic contract: {label}", flow_text, needle, report)
    else:
        report.add("error", "Flow UI visual QA files missing")

    if QA_COMBAT_OVERLAYS_SCRIPT.exists() and QA_COMBAT_OVERLAYS_WRAPPER.exists() and QA_VISUAL_REGRESSION.exists():
        overlay_text = QA_COMBAT_OVERLAYS_SCRIPT.read_text(encoding="utf-8")
        overlay_wrapper_text = QA_COMBAT_OVERLAYS_WRAPPER.read_text(encoding="utf-8")
        regression_text = QA_VISUAL_REGRESSION.read_text(encoding="utf-8")
        combined_overlay = overlay_text + "\n" + overlay_wrapper_text + "\n" + regression_text
        for label, needle in (
            ("combat overlay screenshot", "combat_overlays_1920.png"),
            ("combat overlay pass marker", "Combat overlays visual QA passed"),
            ("top announcement asserted", "TopAnnouncementOverlay should show critical announcement"),
            ("dao tradition asserted", "DaoTraditionOverlay banner should be visible"),
            ("dao tradition pattern texture asserted", "DaoTraditionOverlay corner patterns should use image2 ornament textures"),
            ("crit overlay asserted", "CritMomentOverlay slash should use image2 crit slash texture"),
            ("crit edge texture asserted", "CritMomentOverlay edge glow should use image2 edge textures"),
            ("combat feedback asserted", "CombatFeedbackLayer floaters should use image2 backing textures"),
        ):
            _require_text_contains(f"Combat overlays QA contract: {label}", combined_overlay, needle, report)
    else:
        report.add("error", "Combat overlays visual QA files missing")


def check_flow_ui_assetized_control_contract(report: Report) -> None:
    _check_shared_modal_veil_contract(report)

    if not PATH_CHOICE_PANEL_SCRIPT.exists() or not PATH_CHOICE_PANEL_SCENE.exists():
        report.add("error", "path choice panel files missing")
        return
    path_text = PATH_CHOICE_PANEL_SCRIPT.read_text(encoding="utf-8")
    path_scene_text = PATH_CHOICE_PANEL_SCENE.read_text(encoding="utf-8")
    for label, needle in (
        ("path choice uses image2 ninepatch panel cards", "UiHelpers.make_ninepatch_panel_style()"),
        ("path choice routes icons through AssetPaths", "AssetPaths.path_icon(path_id)"),
        ("path choice has card icon node", 'icon.name = "PathIcon"'),
        ("path choice has card title node", 'title.name = "PathTitle"'),
        ("path choice has card description node", 'desc.name = "PathDesc"'),
        ("path choice has risk tag node", 'tag.name = "PathRiskTag"'),
        ("path choice has asset enter button node", 'btn.name = "PathEnterButton"'),
        ("path choice styles enter button with image2 asset", "UiHelpers.apply_button_asset(btn, true)"),
        ("path choice names card margin for QA", 'margin.name = "CardMargin"'),
        ("path choice names card stack for QA", 'vbox.name = "CardVBox"'),
        ("path choice names card header for QA", 'row.name = "PathHeader"'),
        ("path choice has semantic tag helper", "func _path_tag_text(path_id: String) -> String:"),
    ):
        _require_text_contains(f"path choice assetized card contract: {label}", path_text, needle, report)
    for forbidden in (
        "func _apply_path_card_accent",
        "StyleBoxFlat.new()",
        "UiHelpers.apply_card_polish(card",
    ):
        if forbidden in path_text:
            report.add("error", f"PathChoicePanel should not regress to procedural/flat card styling: found `{forbidden}`")
    if 'type="GridContainer"' not in path_scene_text or "columns = 3" not in path_scene_text:
        report.add("error", "PathChoicePanel scene should use a 3-column GridContainer instead of a long horizontal shelf")
    if "offset_top = -260.0" not in path_scene_text or "offset_bottom = 260.0" not in path_scene_text:
        report.add("error", "PathChoicePanel scene should keep enough vertical space for a 3+2 card grid")
    if "offset_left = -560.0" not in path_scene_text or "offset_right = 560.0" not in path_scene_text:
        report.add("error", "PathChoicePanel scene should stay visually concentrated instead of spanning the whole 1920 viewport")
    if "custom_minimum_size = Vector2(320, 176)" not in path_text:
        report.add("error", "PathChoicePanel cards should be large enough for 1920 icon/text/button spacing")

    if PAUSE_OVERLAY_SCENE.exists():
        pause_text = PAUSE_OVERLAY_SCRIPT.read_text(encoding="utf-8") if PAUSE_OVERLAY_SCRIPT.exists() else ""
        pause_scene_text = PAUSE_OVERLAY_SCENE.read_text(encoding="utf-8")
        if "UiHelpers.apply_modal_veil(dimmer, 0.70)" not in pause_text:
            report.add("error", "PauseOverlay Dimmer should use shared modal veil alpha around 0.70, not a shallow gray veil")
        if '[node name="Dimmer" type="ColorRect" parent="."]' in pause_scene_text:
            report.add("error", "PauseOverlay Dimmer should not regress to a flat ColorRect")

    if not SHOP_PANEL_SCRIPT.exists() or not SHOP_PANEL_SCENE.exists():
        report.add("error", "shop panel files missing")
        return
    shop_text = SHOP_PANEL_SCRIPT.read_text(encoding="utf-8")
    shop_scene_text = SHOP_PANEL_SCENE.read_text(encoding="utf-8")
    for label, needle in (
        ("shop offer rows use image2 ninepatch card", "row.add_theme_stylebox_override(\"panel\", UiHelpers.make_ninepatch_panel_style())"),
        ("shop offer row icon node", 'icon.name = "OfferIcon"'),
        ("shop offer row cost icon node", 'cost_icon.name = "CostIcon"'),
        ("shop buy button has icon", "buy.icon = AssetPaths.load_texture(AssetPaths.ICON_SPIRIT_STONE)"),
        ("shop buy button uses image2 asset style", "UiHelpers.apply_button_asset(buy, true)"),
        ("shop leave button uses image2 asset style", "UiHelpers.apply_button_asset(leave, false)"),
        ("shop full-slot action factory", "func _make_shop_action_button(text: String, icon_path: String, primary: bool) -> Button:"),
        ("shop action buttons load icons", "button.icon = AssetPaths.load_texture(icon_path)"),
        ("shop full-slot hint panel has semantic icon", "func _make_full_slot_hint(text: String, icon_path: String) -> PanelContainer:"),
        ("shop full-slot hint icon loads image2 asset", "icon.texture = AssetPaths.load_texture(icon_path)"),
        ("shop full-slot uses stable footer actions", "footer_actions.add_child(seal)"),
        ("shop full-slot short footer label", 'var seal := _make_shop_action_button("封印"'),
        ("shop offer icon helper", "func _offer_icon_path(offer: Dictionary) -> String:"),
        ("shop offer icon reads tag element", "ElementUtils.key(int(tag.element))"),
        ("shop rare fallback avoids fire icon", "return AssetPaths.status_icon(\"dao\")"),
        ("shop regular fallback avoids fire icon", "return AssetPaths.status_icon(\"promoted\")"),
    ):
        _require_text_contains(f"shop panel assetized contract: {label}", shop_text, needle, report)
    for forbidden in (
        'else AssetPaths.ELEMENT_ICONS["fire"]',
        "UiHelpers.apply_card_polish(row",
    ):
        if forbidden in shop_text:
            report.add("error", f"ShopPanel should not regress to old fallback/card styling: found `{forbidden}`")
    if 'name="ContentScroll" type="ScrollContainer"' not in shop_scene_text or 'name="FooterActions" type="HBoxContainer"' not in shop_scene_text:
        report.add("error", "ShopPanel scene should use stable ContentScroll and FooterActions regions")
    if "offset_left = -400.0" not in shop_scene_text or "offset_right = 400.0" not in shop_scene_text:
        report.add("error", "ShopPanel scene should use a 1920-friendly 800px modal width for full-slot decisions")

    ui_fly_effects = GAME_ROOT / "vfx" / "ui_fly_effects.gd"
    if ui_fly_effects.exists():
        fly_text = ui_fly_effects.read_text(encoding="utf-8")
        for label, needle in (
            ("ui fly effects load asset paths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
            ("ui fly missing icon falls back to semantic image2 icon", "icon_path = AssetPaths.ICON_SPIRIT_STONE"),
            ("ui fly uses TextureRect ghost", "var ghost := TextureRect.new()"),
        ):
            _require_text_contains(f"UI fly effect assetized contract: {label}", fly_text, needle, report)
        if "ColorRect.new()" in fly_text:
            report.add("error", "UiFlyEffects should not use ColorRect fallback blocks for flying reward icons")
    else:
        report.add("error", "UiFlyEffects file missing")

    if not DEATH_MOMENT_SCRIPT.exists() or not DEATH_MOMENT_SCENE.exists():
        report.add("error", "death moment overlay files missing")
        return
    death_text = DEATH_MOMENT_SCRIPT.read_text(encoding="utf-8")
    death_scene_text = DEATH_MOMENT_SCENE.read_text(encoding="utf-8")
    for label, needle in (
        ("death moment loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
        ("death moment has full-screen vignette node", "@onready var vignette: TextureRect"),
        ("death moment has shared modal veil helper", "UiHelpers.apply_modal_veil(dimmer, 0.58)"),
        ("death moment has soul-field summary panel", "@onready var soul_field: PanelContainer"),
        ("death moment has player echo node", "@onready var player_echo: TextureRect"),
        ("death moment has totem disc node", "@onready var totem_disc: TextureRect"),
        ("death moment has soul seal node", "@onready var soul_seal: TextureRect"),
        ("death moment applies dedicated vignette texture", "AssetPaths.DEATH_MOMENT_VIGNETTE"),
        ("death moment applies player sprite style", "AssetPaths.PLAYER_STYLE_PATHS.get"),
        ("death moment applies dedicated soul totem texture", "AssetPaths.DEATH_SOUL_TOTEM_DISC"),
        ("death moment applies large dao seal texture", "AssetPaths.RUN_RESULT_VICTORY_SEAL"),
        ("death moment updates soul metrics", "func _update_soul_metrics(summary: Dictionary) -> void:"),
        ("death scene uses texture veil dimmer", 'name="Dimmer" type="TextureRect"'),
        ("death scene declares Vignette", 'name="Vignette" type="TextureRect"'),
        ("death scene declares SoulField", 'name="SoulField" type="PanelContainer"'),
        ("death scene declares MetricRow", 'name="MetricRow" type="HBoxContainer"'),
        ("death scene declares PlayerEcho", 'name="PlayerEcho" type="TextureRect"'),
        ("death scene declares TotemDisc", 'name="TotemDisc" type="TextureRect"'),
        ("death scene declares SoulSeal", 'name="SoulSeal" type="TextureRect"'),
    ):
        _require_text_contains(f"death moment asset contract: {label}", death_text + "\n" + death_scene_text, needle, report)
    for label, res_path, width, height in (
        ("death moment vignette", "res://assets/ui/death_moment_vignette_1920x1080.png", 1920, 1080),
        ("death soul totem disc", "res://assets/ui/death_soul_totem_disc_512.png", 512, 512),
    ):
        check_image(ImageRule(label, res_path, exact_width=width, exact_height=height), report)
    for forbidden in ("func _draw_body_fall", "func _draw_totem", "draw_circle(", "draw_line(", "draw_arc("):
        if forbidden in death_text:
            report.add("error", f"DeathMomentOverlay should not use procedural body/totem drawing as its main visual path: found `{forbidden}`")
    if "AssetPaths.RUN_RESULT_BACKDROP" in death_text:
        report.add("error", "DeathMomentOverlay should use dedicated death image2 assets, not the run-result backdrop")
    if 'name="Dimmer" type="ColorRect"' in death_scene_text:
        report.add("error", "DeathMomentOverlay must not regress to pure ColorRect dimmer")
    if 'AssetPaths.status_icon("dao")' in death_text:
        report.add("error", "DeathMomentOverlay must not upscale the 32px status_dao icon for SoulSeal")

    if not LEGACY_SELECT_SCRIPT.exists() or not LEGACY_SELECT_SCENE.exists():
        report.add("error", "legacy select panel files missing")
        return
    legacy_text = LEGACY_SELECT_SCRIPT.read_text(encoding="utf-8")
    legacy_scene_text = LEGACY_SELECT_SCENE.read_text(encoding="utf-8")
    for label, needle in (
        ("legacy select loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
        ("legacy select loads ElementUtils", 'const ElementUtils = preload("res://core/utils/element_utils.gd")'),
        ("legacy card has reward frame node", 'frame.name = "LegacyRewardFrame"'),
        ("legacy card uses reward frame texture", "AssetPaths.reward_card_frame(int(tag.quality))"),
        ("legacy card has type icon node", 'type_icon.name = "LegacyTypeIcon"'),
        ("legacy card has element icon node", 'element_icon.name = "LegacyElementIcon"'),
        ("legacy pick button has icon", "btn.icon = AssetPaths.load_texture(AssetPaths.status_icon(\"dao\"))"),
        ("legacy pick button uses image2 asset style", "UiHelpers.apply_button_asset(btn, true)"),
        ("legacy skip button uses image2 asset style", "UiHelpers.apply_button_asset(skip_button, false)"),
        ("legacy double-click guard", "var _closing := false"),
        ("legacy close disables pick buttons", "button.disabled = true"),
    ):
        _require_text_contains(f"legacy select assetized card contract: {label}", legacy_text + "\n" + legacy_scene_text, needle, report)
    for forbidden in ("StyleBoxFlat.new()", "UiHelpers.apply_card_polish(card"):
        if forbidden in legacy_text:
            report.add("error", f"LegacySelectPanel should not regress to flat/procedural legacy cards: found `{forbidden}`")
    if "offset_left = -440.0" not in legacy_scene_text or "offset_right = 440.0" not in legacy_scene_text:
        report.add("error", "LegacySelectPanel scene should keep a 1920-friendly 880px modal width")

    if not META_UPGRADE_PANEL_SCRIPT.exists() or not META_UPGRADE_PANEL_SCENE.exists():
        report.add("error", "meta upgrade panel files missing")
        return
    meta_text = META_UPGRADE_PANEL_SCRIPT.read_text(encoding="utf-8")
    meta_scene_text = META_UPGRADE_PANEL_SCENE.read_text(encoding="utf-8")
    for label, needle in (
        ("meta upgrade loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
        ("meta upgrade keeps polished modal shell", "UiHelpers.apply_panel_polish(panel)"),
        ("meta upgrade keeps compact header divider", "UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)"),
        ("meta upgrade has gold divider", "UiHelpers.add_gold_divider($Panel/Margin/VBox, $Panel/Margin/VBox/ListScroll)"),
        ("meta upgrade points icon uses dao seal", "points_icon.texture = AssetPaths.load_texture(AssetPaths.status_icon(\"dao\"))"),
        ("meta upgrade close button uses icon", "close_button.icon = AssetPaths.load_texture(AssetPaths.status_icon(\"dao\"))"),
        ("meta upgrade close button uses image2 asset style", "UiHelpers.apply_button_asset(close_button, false)"),
        ("meta upgrade row factory", "func _make_upgrade_row(row: Dictionary, points: int) -> PanelContainer:"),
        ("meta upgrade row uses image2 ninepatch", "UiHelpers.make_ninepatch_panel_style()"),
        ("meta upgrade row icon node", 'icon.name = "MetaUpgradeIcon"'),
        ("meta upgrade level pips node", 'pips.name = "MetaUpgradePips"'),
        ("meta upgrade cost icon node", 'cost_icon.name = "CostIcon"'),
        ("meta upgrade upgrade button node", 'btn.name = "MetaUpgradeButton"'),
        ("meta upgrade upgrade button uses icon", "btn.icon = AssetPaths.load_texture(AssetPaths.status_icon(\"dao\") if maxed else AssetPaths.ICON_SPIRIT_STONE)"),
        ("meta upgrade upgrade button uses image2 asset style", "UiHelpers.apply_button_asset(btn, true)"),
        ("meta upgrade semantic icon helper", "func _upgrade_icon_path(id: String, effect_key: String) -> String:"),
    ):
        _require_text_contains(f"meta upgrade assetized row contract: {label}", meta_text + "\n" + meta_scene_text, needle, report)
    for forbidden in (
        "StyleBoxFlat.new()",
        "UiHelpers.apply_card_polish(row_panel",
        'type="CheckButton"',
        'type="OptionButton"',
    ):
        if forbidden in meta_text or forbidden in meta_scene_text:
            report.add("error", f"MetaUpgradePanel should not regress to native/flat controls: found `{forbidden}`")
    if "offset_left = -410.0" not in meta_scene_text or "offset_right = 410.0" not in meta_scene_text:
        report.add("error", "MetaUpgradePanel scene should keep a 1920-friendly 820px modal width")
    if 'name="ListScroll" type="ScrollContainer"' not in meta_scene_text:
        report.add("error", "MetaUpgradePanel should keep upgrade rows inside a ScrollContainer")

    if not BREAKTHROUGH_PANEL_SCRIPT.exists() or not BREAKTHROUGH_PANEL_SCENE.exists():
        report.add("error", "breakthrough panel files missing")
        return
    breakthrough_text = BREAKTHROUGH_PANEL_SCRIPT.read_text(encoding="utf-8")
    breakthrough_scene_text = BREAKTHROUGH_PANEL_SCENE.read_text(encoding="utf-8")
    talent_text = TALENT_CARD_SCRIPT.read_text(encoding="utf-8") if TALENT_CARD_SCRIPT.exists() else ""
    talent_scene_text = TALENT_CARD_SCENE.read_text(encoding="utf-8") if TALENT_CARD_SCENE.exists() else ""
    asset_paths_text = _asset_paths_text()
    for label, needle in (
        ("breakthrough loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
        ("breakthrough keeps polished modal shell", "UiHelpers.apply_panel_polish(panel)"),
        ("breakthrough uses image2 overlay", "UiHelpers.wrap_with_panel_texture(panel, AssetPaths.BREAKTHROUGH_BG_OVERLAY)"),
        ("breakthrough loads full-screen backdrop", "AssetPaths.BREAKTHROUGH_BACKDROP"),
        ("breakthrough loads realm gate panel", "AssetPaths.REALM_GATE_PANEL"),
        ("breakthrough scene declares Backdrop", 'name="Backdrop" type="TextureRect"'),
        ("breakthrough scene declares RealmGate header", 'name="RealmGateHeader" type="TextureRect"'),
        ("breakthrough keeps compact header divider", "UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)"),
        ("breakthrough has gold divider", "UiHelpers.add_gold_divider($Panel/Margin/VBox, cards_box)"),
        ("breakthrough instantiates TalentCard scene", "const TALENT_CARD_SCENE = preload(\"res://ui/components/talent_card.tscn\")"),
        ("TalentCard frame texture kept unloaded", "frame_bg.texture = null"),
        ("TalentCard badge texture kept unloaded", "badge_icon.texture = null"),
        ("TalentCard realm icon route", "AssetPaths.talent_realm_icon(realm_level)"),
        ("TalentCard select button uses image2 asset style", "UiHelpers.apply_button_asset(select_button, true)"),
        ("TalentCard scene frame node", 'name="FrameBg" type="TextureRect"'),
        ("TalentCard scene badge node", 'name="BadgeIcon" type="TextureRect"'),
        ("TalentCard scene icon node", 'name="Icon" type="TextureRect"'),
        ("TalentCard scene select button", 'name="SelectButton" type="Button"'),
        ("TalentCard uses image2 ninepatch card style", "UiHelpers.make_ninepatch_panel_style()"),
    ):
        _require_text_contains(f"breakthrough assetized panel contract: {label}", breakthrough_text + "\n" + breakthrough_scene_text + "\n" + talent_text + "\n" + talent_scene_text, needle, report)
    if "custom_minimum_size = Vector2(32, 32)" not in talent_scene_text:
        report.add("error", "TalentCard realm icon should remain 32x32 to avoid blurry upscaled icons")
    if "func _lock_realm_icon_size() -> void:" not in talent_text:
        report.add("error", "TalentCard should lock runtime realm icon size so TextureRect layout cannot upscale it")
    if "icon.visible = false" not in talent_text:
        report.add("error", "TalentCard realm icon should stay hidden until dedicated larger non-blurry icons exist")
    if "func _lock_decor_size() -> void:" not in talent_text:
        report.add("error", "TalentCard should lock decorative frame/badge size so layout cannot stretch them behind text")
    for node_name in ("FrameBg", "BadgeIcon", "Icon"):
        node_match = re.search(r'\[node name="%s"[^]]*\](?P<body>.*?)(?=\n\[node |\Z)' % re.escape(node_name), talent_scene_text, re.S)
        if node_match is None or "visible = false" not in node_match.group("body"):
            report.add("error", f"TalentCard `{node_name}` must default to visible=false so small image2 symbols cannot appear as blurry card art")
    if "modulate = Color(1, 1, 1, 0.36)" not in talent_scene_text:
        report.add("error", "TalentCard scroll frame should be a subtle ornament, not a full-strength blurry card background")
    ui_asset_root = GAME_ROOT / "assets" / "ui"
    if "AssetPaths.TALENT_SCROLL" in talent_text or "AssetPaths.TALENT_BADGES" in talent_text:
        report.add("error", "TalentCard hidden decorative nodes must not load scroll/badge textures that can flash or be stretched behind text")
    if 'path="res://assets/ui/talent_scroll_210x200.png"' in talent_scene_text:
        report.add("error", "TalentCard scene must not preload talent_scroll texture for hidden FrameBg")
    if 'const BREAKTHROUGH_BACKDROP := UI_ROOT + "breakthrough_backdrop_no_emblem_v3_1920x1080.png"' not in asset_paths_text:
        report.add("error", "AssetPaths.BREAKTHROUGH_BACKDROP must use the v3 no-emblem asset name to avoid stale Godot import cache")
    for stale_name in (
        'BREAKTHROUGH_BACKDROP := UI_ROOT + "breakthrough_backdrop_no_emblem_v2_1920x1080.png"',
        'BREAKTHROUGH_BACKDROP := UI_ROOT + "breakthrough_backdrop_pure_1920x1080.png"',
        'BREAKTHROUGH_BACKDROP := UI_ROOT + "breakthrough_backdrop_safe_1920x1080.png"',
        'BREAKTHROUGH_BACKDROP := UI_ROOT + "breakthrough_backdrop_1920x1080.png"',
    ):
        if stale_name in asset_paths_text:
            report.add("error", f"Breakthrough backdrop still points at stale cached asset `{stale_name}`")
    backdrop_prompt_path = ui_asset_root / "breakthrough_backdrop_no_emblem_v3_1920x1080.prompt.txt"
    backdrop_prompt = backdrop_prompt_path.read_text(encoding="utf-8") if backdrop_prompt_path.exists() else ""
    for needle in ("clean dark central safe zone", "center 900x520 must be plain dark ink mist only", "no large five-element emblems", "no circular symbols", "no oversized icons behind the UI", "no glowing discs", "no icon-like symbols", "no element badges anywhere in the image"):
        if needle not in backdrop_prompt:
            report.add("error", f"Breakthrough backdrop prompt must forbid blurry oversized symbols: missing `{needle}`")
    for label, res_path, width, height in (
        ("breakthrough full-screen backdrop", "res://assets/ui/breakthrough_backdrop_no_emblem_v3_1920x1080.png", 1920, 1080),
        ("breakthrough realm gate panel", "res://assets/ui/realm_gate_panel_760x360.png", 760, 360),
    ):
        check_image(ImageRule(label, res_path, exact_width=width, exact_height=height), report)
    if 'name="RealmGateHeader" type="TextureRect" parent="Panel/Margin"' not in breakthrough_scene_text:
        report.add("error", "Breakthrough RealmGate should be a top header ornament under Panel/Margin, not a card-area background")
    for forbidden_node in (
        'name="RealmGate" type="TextureRect" parent="Panel/Margin"',
        'name="RealmGate" type="TextureRect" parent="Panel/Margin/VBox"',
        'name="CardReadabilityScrim" type="ColorRect" parent="Panel/Margin"',
    ):
        if forbidden_node in breakthrough_scene_text:
            report.add("error", f"Breakthrough card area should stay clean; found `{forbidden_node}`")
    if "realm_gate_header.modulate.a = 0.0" not in breakthrough_text:
        report.add("error", "Breakthrough realm gate header should be kept invisible until a non-blurry replacement is generated")
    for forbidden in (
        "StyleBoxFlat.new()",
        "UiHelpers.apply_card_polish(card",
    ):
        if forbidden in breakthrough_text or forbidden in breakthrough_scene_text or forbidden in talent_text:
            report.add("error", f"BreakthroughPanel/TalentCard should not regress to flat/procedural cards: found `{forbidden}`")

    if not WEAPON_MOD_PANEL_SCRIPT.exists() or not WEAPON_MOD_PANEL_SCENE.exists():
        report.add("error", "weapon mod choice panel files missing")
        return
    weapon_mod_text = WEAPON_MOD_PANEL_SCRIPT.read_text(encoding="utf-8")
    weapon_mod_scene_text = WEAPON_MOD_PANEL_SCENE.read_text(encoding="utf-8")
    for label, needle in (
        ("weapon mod choice loads AssetPaths", 'const AssetPaths = preload("res://assets/asset_paths.gd")'),
        ("weapon mod choice keeps polished modal shell", "UiHelpers.apply_panel_polish(panel)"),
        ("weapon mod choice keeps compact header divider", "UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)"),
        ("weapon mod choice has gold divider", "UiHelpers.add_gold_divider($Panel/Margin/VBox, cards_box)"),
        ("weapon mod card uses image2 ninepatch", "UiHelpers.make_ninepatch_panel_style()"),
        ("weapon mod card margin node", 'margin.name = "WeaponModCardMargin"'),
        ("weapon mod card stack node", 'box.name = "WeaponModCardVBox"'),
        ("weapon mod icon row node", 'icon_row.name = "WeaponModIconRow"'),
        ("weapon mod artifact icon node", 'artifact_icon.name = "WeaponModArtifactIcon"'),
        ("weapon mod semantic icon node", 'semantic_icon.name = "WeaponModSemanticIcon"'),
        ("weapon mod tag chips node", 'tags_box.name = "WeaponModTags"'),
        ("weapon mod select button node", 'button.name = "WeaponModSelectButton"'),
        ("weapon mod select button has icon", "button.icon = AssetPaths.load_texture(_mod_button_icon_path(mod))"),
        ("weapon mod select button uses image2 asset style", "UiHelpers.apply_button_asset(button, true)"),
        ("weapon mod semantic icon helper", "func _mod_icon_path(mod: Dictionary) -> String:"),
        ("weapon mod button icon helper", "func _mod_button_icon_path(mod: Dictionary) -> String:"),
        ("weapon mod scene title is Chinese", 'text = "本命器祭炼"'),
        ("weapon mod scene summary is Chinese", 'text = "择一缕铭纹入命"'),
    ):
        _require_text_contains(f"weapon mod choice assetized card contract: {label}", weapon_mod_text + "\n" + weapon_mod_scene_text, needle, report)
    for forbidden in (
        "UiHelpers.apply_card_polish(card",
        "StyleBoxFlat.new()",
        "Weapon Forge",
        "Choose one inscription",
    ):
        if forbidden in weapon_mod_text or forbidden in weapon_mod_scene_text:
            report.add("error", f"WeaponModChoicePanel should not regress to old/default styling: found `{forbidden}`")
    if "offset_left = -540.0" not in weapon_mod_scene_text or "offset_right = 540.0" not in weapon_mod_scene_text:
        report.add("error", "WeaponModChoicePanel scene should keep a 1920-friendly 1080px modal width")


def check_sprite_frame_bundles(report: Report) -> None:
    for slug in [
        "player_cultivator",
        "enemy_training_dummy",
        "enemy_berserker",
        "enemy_archer",
        "enemy_bomber",
    ]:
        check_frame_bundle(slug, "idle", 1, 32, report, severity="warning")

    actor_action_bundles = {
        "player_style_normal": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "player_style_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "pet_huo_ying": (("idle", 4, 16), ("walk", 4, 16), ("combat", 4, 16)),
        "enemy_style_normal_melee": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_style_normal_ranged": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_style_normal_elite": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_thunder_elite_ingame": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_style_chibi_melee": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_style_chibi_ranged": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_style_chibi_elite": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_thunder_elite_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_wild_wolf": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_crossbow_cultivator": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_shield_guard": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_sky_bat": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_mud_serpent": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_wind_mantis": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_furnace_golem": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_wild_wolf_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_crossbow_cultivator_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_shield_guard_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_sky_bat_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_mud_serpent_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_wind_mantis_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
        "enemy_furnace_golem_chibi": (("idle", 4, 32), ("walk", 4, 32), ("combat", 4, 32)),
    }
    for slug, actions in actor_action_bundles.items():
        for prefix, min_frames, min_size in actions:
            check_frame_bundle(slug, prefix, min_frames, min_size, report)

    for slug in [
        "projectile_fire",
        "projectile_thunder",
        "projectile_ice",
        "projectile_water",
        "projectile_wood",
        "projectile_earth",
        "projectile_generic",
        "projectile_chaos",
    ]:
        check_frame_bundle(slug, "fly", 1, 8, report)
    for slug in [
        "impact_fire",
        "impact_thunder",
        "impact_ice",
        "impact_water",
        "impact_wood",
        "impact_earth",
        "impact_generic",
        "impact_chaos",
    ]:
        check_frame_bundle(slug, "impact", 1, 16, report)


def iter_manifest_stages(data: Any) -> Iterable[tuple[str, dict[str, Any]]]:
    if isinstance(data, dict):
        if isinstance(data.get("stages"), list):
            for index, stage in enumerate(data["stages"]):
                if isinstance(stage, dict):
                    yield str(stage.get("id") or stage.get("stage_id") or index), stage
        elif isinstance(data.get("stages"), dict):
            for stage_id, stage in data["stages"].items():
                if isinstance(stage, dict):
                    yield str(stage_id), stage
        else:
            for stage_id, stage in data.items():
                if isinstance(stage, dict):
                    yield str(stage_id), stage


def resolve_manifest_asset(value: Any, stage_id: str, filename: str) -> Path:
    if isinstance(value, str) and value:
        if value.startswith("res://"):
            return res_to_path(value)
        p = Path(value)
        if p.is_absolute():
            return p
        return (MAP_MANIFEST.parent / p).resolve()
    return MAP_MANIFEST.parent / stage_id / filename


def check_map_manifest(report: Report) -> None:
    if not MAP_MANIFEST.exists():
        report.add("error", f"runtime map manifest missing: {rel(MAP_MANIFEST)}")
        return
    try:
        data = json.loads(MAP_MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.add("error", f"runtime map manifest JSON invalid: {exc}")
        return
    stages = list(iter_manifest_stages(data))
    if not stages:
        report.add("error", "runtime map manifest contains no stages")
        return
    for stage_id, stage in stages:
        fields = [
            ("room_background", "room_background.png", 1280, 720),
            ("tileset", "tileset.png", 128, 128),
            ("terrain_props", "terrain_props.png", 192, 192),
        ]
        for key, filename, min_width, min_height in fields:
            candidates = [key, f"{key}_path", f"{key}_asset", "background" if key == "room_background" else key]
            value = next((stage.get(candidate) for candidate in candidates if candidate in stage), "")
            path = resolve_manifest_asset(value, stage_id, filename)
            if not path.exists():
                report.add("error", f"map stage {stage_id}: missing {key} at {rel(path)}")
                continue
            size = png_size(path)
            if size is None:
                report.add("error", f"map stage {stage_id}: invalid PNG {rel(path)}")
            elif size[0] < min_width or size[1] < min_height:
                report.add("error", f"map stage {stage_id}: {key} too small, expected >= {min_width}x{min_height}, got {size[0]}x{size[1]} at {rel(path)}")


def main() -> int:
    report = Report()
    if not ASSET_PATHS.exists():
        report.add("error", f"missing {rel(ASSET_PATHS)}")
    else:
        check_asset_paths_refs(report)
    check_unified_image2_asset_traceability(report)

    for rule in mandatory_rules():
        check_image(rule, report)
    for rule in warning_rules():
        check_image(rule, report)
    check_runtime_actor_mappings(report)
    check_identity_weapon_contract(report)
    check_boss_dedicated_art_contract(report)
    check_dark_ink_vfx_toning(report)
    check_status_icon_contract(report)
    check_semantic_icon_route_contract(report)
    check_combat_action_fx_contract(report)
    check_overlay_ornament_fx_contract(report)
    check_hud_skill_dock_asset_contract(report)
    check_world_fx_asset_contract(report)
    check_affix_card_contract(report)
    check_affix_choice_layout_contract(report)
    check_long_term_record_contract(report)
    check_flow_ui_assetized_control_contract(report)
    check_sprite_frame_bundles(report)
    check_map_manifest(report)

    print("Visual Asset Coverage QA")
    print("========================")
    print(f"Errors: {len(report.errors)}")
    print(f"Warnings: {len(report.warnings)}")
    print(f"Info: {len(report.info)}")
    if report.errors:
        print("\nMust fix:")
        for item in report.errors:
            print(f"- {item}")
    if report.warnings:
        print("\nWarnings:")
        for item in report.warnings:
            print(f"- {item}")
    if report.info:
        print("\nInfo:")
        for item in report.info:
            print(f"- {item}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
