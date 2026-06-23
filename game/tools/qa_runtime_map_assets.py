from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError as exc:  # pragma: no cover - dependency message path
    raise SystemExit("Pillow is required: pip install pillow") from exc


ROOT = Path(__file__).resolve().parents[2]
GAME_ROOT = ROOT / "game"
MANIFEST_PATH = GAME_ROOT / "assets" / "maps" / "runtime_scene_manifest.json"
COMBAT_FLOOR_PATH = GAME_ROOT / "scenes" / "rooms" / "combat_floor.gd"

FORBIDDEN_MANIFEST_KEYS = {
    "api_key",
    "authorization",
    "bearer",
    "endpoint",
    "image_endpoint",
    "token",
}
EXPECTED_BACKGROUND_SIZE = (1280, 720)
EXPECTED_TERRAIN_PROPS_SIZE = (384, 384)
EXPECTED_TILESET_SIZE = (128, 128)
EXPECTED_WORLD_BOUNDS = {"x": -640, "y": -352, "width": 1280, "height": 704}
EXPECTED_CAMERA_BOUNDS = {"x": -640, "y": -360, "width": 1280, "height": 720}
EXPECTED_PROP_SEMANTICS = {
    "water",
    "wet",
    "swamp",
    "fire",
    "dry",
    "rock",
    "ice",
    "thunder",
    "obstacle",
    "default",
}
EXPECTED_WEATHER_IDS = {"clear", "rain", "thunder", "fire", "wind", "fog", "snow", "sand"}
EXPECTED_TERRAIN_WEIGHT_KEYS = {"water", "wet", "swamp", "fire", "dry", "rock", "ice", "thunder"}
EXPECTED_TILESET_COORDS = {(0, 0), (1, 0), (2, 0), (3, 0)}
EXPECTED_TERRAIN_PROP_CELL_SIZE = 128
TERRAIN_PROP_MIN_ALPHA_COVERAGE = 0.02
TERRAIN_PROP_MAX_ALPHA_COVERAGE = 0.45
TERRAIN_PROP_MIN_EDGE_MARGIN = 6
TERRAIN_PROP_MIN_CELL_DIFF = 6.0
WEATHER_WEIGHT_RANGE = range(1, 11)
TERRAIN_WEIGHT_RANGE = range(1, 11)
SEMANTIC_ALLOWED_COORDS = {
    "water": {(0, 0), (0, 1), (1, 1)},
    "wet": {(0, 0), (0, 1), (1, 1)},
    "ice": {(0, 0), (0, 1), (1, 1)},
    "swamp": {(1, 0), (1, 1), (1, 2)},
    "fire": {(0, 2), (0, 1), (1, 1)},
    "dry": {(0, 2), (2, 1), (1, 1)},
    "rock": {(2, 0), (2, 1), (2, 2)},
    "obstacle": {(2, 0), (2, 1), (2, 2)},
    "thunder": {(0, 1), (0, 2), (1, 2)},
    "default": {(0, 0), (0, 1), (1, 1)},
}
THEME_TERRAIN_RULES = {
    "qi_refining_verdant": {"required": {"water", "swamp"}, "dominates": [("water", "fire")]},
    "foundation_cavern": {"required": {"water", "rock"}, "dominates": [("water", "ice")]},
    "golden_core_demon": {"required": {"fire"}, "dominates": [("fire", "water")]},
    "nascent_soul_ruins": {"required": {"rock"}, "dominates": [("rock", "water")]},
    "tribulation_thunder": {"required": {"thunder"}, "dominates": [("thunder", "fire")]},
}


def _failures() -> list[str]:
    failures: list[str] = []
    if not MANIFEST_PATH.exists():
        return [f"missing manifest: {MANIFEST_PATH}"]

    manifest_text = MANIFEST_PATH.read_text(encoding="utf-8")
    lower_text = manifest_text.lower()
    for key in FORBIDDEN_MANIFEST_KEYS:
        if key in lower_text:
            failures.append(f"manifest contains forbidden provider/secret field text: {key}")
    if "sk-" in lower_text:
        failures.append("manifest appears to contain an API key prefix")
    for stale in ("UIUX_轮回仙途_v2.0_像素风", "UI资产提示词_像素风"):
        if stale in manifest_text:
            failures.append(f"manifest still references stale pixel UI doc: {stale}")
    _check_combat_floor_atlas_guard(failures)

    try:
        manifest = json.loads(manifest_text)
    except json.JSONDecodeError as exc:
        return [f"manifest JSON parse failed: {exc}"]

    arena = manifest.get("arena", {})
    if arena.get("world_bounds") != EXPECTED_WORLD_BOUNDS:
        failures.append(f"world_bounds mismatch: {arena.get('world_bounds')}")
    if arena.get("camera_bounds") != EXPECTED_CAMERA_BOUNDS:
        failures.append(f"camera_bounds mismatch: {arena.get('camera_bounds')}")

    atlas = arena.get("terrain_prop_atlas", {})
    if atlas.get("cell_size") != 128 or atlas.get("grid") != [3, 3]:
        failures.append(f"terrain_prop_atlas mismatch: {atlas}")
    grid = atlas.get("grid", [0, 0])
    grid_w = int(grid[0]) if isinstance(grid, list) and len(grid) >= 2 else 0
    grid_h = int(grid[1]) if isinstance(grid, list) and len(grid) >= 2 else 0

    semantics = arena.get("terrain_prop_semantics", {})
    missing_semantics = sorted(EXPECTED_PROP_SEMANTICS - set(semantics.keys()))
    if missing_semantics:
        failures.append(f"terrain_prop_semantics missing: {missing_semantics}")
    for semantic, coords_list in semantics.items():
        if not isinstance(coords_list, list) or not coords_list:
            failures.append(f"terrain_prop_semantics.{semantic} missing or empty coords")
            continue
        for coords in coords_list:
            normalized = _normalize_atlas_coords(coords)
            if normalized is None:
                failures.append(f"terrain_prop_semantics.{semantic} has invalid coords: {coords}")
                continue
            x, y = normalized
            if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
                failures.append(f"terrain_prop_semantics.{semantic} coords out of atlas grid: {coords}")
            allowed = SEMANTIC_ALLOWED_COORDS.get(str(semantic))
            if allowed is not None and (x, y) not in allowed:
                failures.append(f"terrain_prop_semantics.{semantic} coords use wrong semantic cell: {coords}")

    stages = manifest.get("stages", [])
    if len(stages) != 5:
        failures.append(f"expected 5 stages, found {len(stages)}")

    for stage in stages:
        theme_id = str(stage.get("theme_id", ""))
        if not theme_id:
            failures.append("stage missing theme_id")
            continue
        weather_pool = stage.get("weather_pool", [])
        if not isinstance(weather_pool, list) or not weather_pool:
            failures.append(f"{theme_id}.weather_pool missing or empty")
        else:
            total_weather_weight = 0
            seen_weather_ids: set[str] = set()
            for entry in weather_pool:
                if not isinstance(entry, dict):
                    failures.append(f"{theme_id}.weather_pool contains non-object entry")
                    continue
                weather_id = str(entry.get("id", ""))
                raw_weight = entry.get("weight", 0)
                if not _is_plain_int(raw_weight):
                    failures.append(f"{theme_id}.weather_pool weight for {weather_id} must be an int: {raw_weight}")
                    continue
                weight = int(raw_weight)
                if weather_id not in EXPECTED_WEATHER_IDS:
                    failures.append(f"{theme_id}.weather_pool has unknown weather id: {weather_id}")
                if weather_id in seen_weather_ids:
                    failures.append(f"{theme_id}.weather_pool duplicates weather id: {weather_id}")
                seen_weather_ids.add(weather_id)
                if weight <= 0:
                    failures.append(f"{theme_id}.weather_pool has non-positive weight for {weather_id}: {weight}")
                if weight not in WEATHER_WEIGHT_RANGE:
                    failures.append(f"{theme_id}.weather_pool weight for {weather_id} outside 1..10: {weight}")
                total_weather_weight += max(weight, 0)
            if total_weather_weight <= 0:
                failures.append(f"{theme_id}.weather_pool total weight must be positive")
            fallback_weather = str(stage.get("weather_id", ""))
            if fallback_weather not in EXPECTED_WEATHER_IDS:
                failures.append(f"{theme_id}.weather_id unknown: {fallback_weather}")
            elif fallback_weather not in seen_weather_ids:
                failures.append(f"{theme_id}.weather_id {fallback_weather} must appear in weather_pool")

        terrain_weights = stage.get("terrain_feature_weights", {})
        if not isinstance(terrain_weights, dict) or not terrain_weights:
            failures.append(f"{theme_id}.terrain_feature_weights missing or empty")
        else:
            total_terrain_weight = 0
            for terrain_key, raw_weight in terrain_weights.items():
                terrain_key = str(terrain_key)
                if not _is_plain_int(raw_weight):
                    failures.append(f"{theme_id}.terrain_feature_weights weight for {terrain_key} must be an int: {raw_weight}")
                    continue
                weight = int(raw_weight)
                if terrain_key not in EXPECTED_TERRAIN_WEIGHT_KEYS:
                    failures.append(f"{theme_id}.terrain_feature_weights unknown key: {terrain_key}")
                if terrain_key not in semantics:
                    failures.append(f"{theme_id}.terrain_feature_weights key lacks terrain_prop_semantics: {terrain_key}")
                if weight <= 0:
                    failures.append(f"{theme_id}.terrain_feature_weights non-positive weight for {terrain_key}: {weight}")
                if weight not in TERRAIN_WEIGHT_RANGE:
                    failures.append(f"{theme_id}.terrain_feature_weights weight for {terrain_key} outside 1..10: {weight}")
                total_terrain_weight += max(weight, 0)
            if total_terrain_weight <= 0:
                failures.append(f"{theme_id}.terrain_feature_weights total weight must be positive")
            _check_theme_terrain_rules(theme_id, terrain_weights, failures)
        count_bias = stage.get("terrain_feature_count_bias", 0)
        if not isinstance(count_bias, int) or count_bias < 0 or count_bias > 4:
            failures.append(f"{theme_id}.terrain_feature_count_bias must be an int in 0..4, got {count_bias}")

        _check_tileset_coords(theme_id, stage, failures)

        for prop in stage.get("scenery_props", []):
            if not isinstance(prop, dict):
                failures.append(f"{theme_id}.scenery_props contains non-object entry")
                continue
            expected_atlas_path = str(stage.get("terrain_props", ""))
            if str(prop.get("atlas_path", "")) != expected_atlas_path:
                failures.append(f"{theme_id}.scenery_props.{prop.get('id', '<unnamed>')} atlas_path must match stage terrain_props")
            if int(prop.get("atlas_cell_size", 0)) != EXPECTED_TERRAIN_PROP_CELL_SIZE:
                failures.append(f"{theme_id}.scenery_props.{prop.get('id', '<unnamed>')} atlas_cell_size must be {EXPECTED_TERRAIN_PROP_CELL_SIZE}")
            coords = prop.get("atlas_coords", [])
            normalized = _normalize_atlas_coords(coords)
            if normalized is None:
                failures.append(f"{theme_id}.scenery_props.{prop.get('id', '<unnamed>')} has invalid atlas_coords: {coords}")
                continue
            x, y = normalized
            if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
                failures.append(f"{theme_id}.scenery_props.{prop.get('id', '<unnamed>')} atlas_coords out of grid: {coords}")
            _check_scenery_prop_geometry(theme_id, prop, arena, failures)

        for field, size in (
            ("room_background", EXPECTED_BACKGROUND_SIZE),
            ("terrain_props", EXPECTED_TERRAIN_PROPS_SIZE),
            ("tileset", EXPECTED_TILESET_SIZE),
        ):
            res_path = str(stage.get(field, ""))
            asset_path = _resolve_res_path(res_path)
            if not asset_path.exists():
                failures.append(f"{theme_id}.{field} missing: {res_path}")
                continue
            with Image.open(asset_path) as img:
                if img.size != size:
                    failures.append(f"{theme_id}.{field} size {img.size}, expected {size}")
                if field == "terrain_props" and "A" not in img.getbands():
                    failures.append(f"{theme_id}.terrain_props must include alpha channel")
                if field == "terrain_props":
                    _check_terrain_props_visual_semantics(theme_id, img.convert("RGBA"), semantics, failures)

        prompt_files = stage.get("prompt_files", {})
        background_prompt = _resolve_res_path(str(prompt_files.get("room_background", "")))
        terrain_prompt = _resolve_res_path(str(prompt_files.get("terrain_props", "")))
        if not background_prompt.exists():
            failures.append(f"{theme_id}.room_background prompt missing")
        else:
            prompt_text = background_prompt.read_text(encoding="utf-8")
            if "1920x1080" not in prompt_text and "1280x720" not in prompt_text:
                failures.append(f"{theme_id}.room_background prompt lacks 1920/1280 size contract")
            if "no characters" not in prompt_text.lower() or "no ui" not in prompt_text.lower():
                failures.append(f"{theme_id}.room_background prompt lacks no characters/no UI guard")
        if not terrain_prompt.exists():
            failures.append(f"{theme_id}.terrain_props prompt missing")
        else:
            prompt_text = terrain_prompt.read_text(encoding="utf-8")
            if "3x3" not in prompt_text or "128x128" not in prompt_text:
                failures.append(f"{theme_id}.terrain_props prompt lacks 3x3/128x128 contract")

    for stage in stages:
        if stage.get("theme_id") == "tribulation_thunder" and stage.get("weather_id") != "thunder":
            failures.append("tribulation_thunder weather_id must be thunder")

    camera_bounds = arena.get("camera_bounds", {})
    if camera_bounds.get("width", 0) > EXPECTED_BACKGROUND_SIZE[0] or camera_bounds.get("height", 0) > EXPECTED_BACKGROUND_SIZE[1]:
        failures.append("camera_bounds exceed room_background export size; add edge fill or larger export")

    return failures


def _resolve_res_path(res_path: str) -> Path:
    if res_path.startswith("res://"):
        return GAME_ROOT / res_path.removeprefix("res://")
    return ROOT / res_path


def _normalize_atlas_coords(coords: object) -> tuple[int, int] | None:
    if isinstance(coords, list) and len(coords) >= 2:
        if _is_plain_int(coords[0]) and _is_plain_int(coords[1]):
            return int(coords[0]), int(coords[1])
        return None
    if isinstance(coords, dict) and "x" in coords and "y" in coords:
        if _is_plain_int(coords["x"]) and _is_plain_int(coords["y"]):
            return int(coords["x"]), int(coords["y"])
    return None


def _is_plain_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _check_theme_terrain_rules(theme_id: str, terrain_weights: dict, failures: list[str]) -> None:
    rules = THEME_TERRAIN_RULES.get(theme_id, {})
    required = rules.get("required", set())
    missing = sorted(required - set(map(str, terrain_weights.keys())))
    if missing:
        failures.append(f"{theme_id}.terrain_feature_weights missing theme terrain keys: {missing}")
    for primary, secondary in rules.get("dominates", []):
        primary_weight = int(terrain_weights.get(primary, 0))
        secondary_weight = int(terrain_weights.get(secondary, 0))
        if secondary_weight > primary_weight:
            failures.append(
                f"{theme_id}.terrain_feature_weights {secondary} should not outweigh {primary}: "
                f"{secondary_weight}>{primary_weight}"
            )


def _check_tileset_coords(theme_id: str, stage: dict, failures: list[str]) -> None:
    fields = (
        "floor_atlas_coords",
        "floor_alt_atlas_coords",
        "obstacle_atlas_coords",
        "decoration_atlas_coords",
    )
    coords_by_field: dict[str, tuple[int, int]] = {}
    for field in fields:
        normalized = _normalize_atlas_coords(stage.get(field, []))
        if normalized is None:
            failures.append(f"{theme_id}.{field} has invalid coords: {stage.get(field)}")
            continue
        x, y = normalized
        if (x, y) not in EXPECTED_TILESET_COORDS:
            failures.append(f"{theme_id}.{field} coords must be in first-row tileset cells: {stage.get(field)}")
        coords_by_field[field] = normalized
    floor = coords_by_field.get("floor_atlas_coords")
    if floor is not None:
        for field in ("obstacle_atlas_coords", "decoration_atlas_coords"):
            if coords_by_field.get(field) == floor:
                failures.append(f"{theme_id}.{field} must not reuse floor_atlas_coords")


def _check_combat_floor_atlas_guard(failures: list[str]) -> None:
    if not COMBAT_FLOOR_PATH.exists():
        failures.append(f"missing CombatFloor runtime script: {COMBAT_FLOOR_PATH}")
        return
    text = COMBAT_FLOOR_PATH.read_text(encoding="utf-8")
    function_start = text.find("func _make_atlas_sprite")
    if function_start < 0:
        failures.append("CombatFloor is missing _make_atlas_sprite()")
        return
    next_function = text.find("\nfunc ", function_start + 1)
    function_text = text[function_start:] if next_function < 0 else text[function_start:next_function]
    if "Vector2i(3, 0)" in function_text:
        failures.append("CombatFloor._make_atlas_sprite() must not default atlas_coords to [3,0]; terrain_props is 3x3")
    if 'entry.get("atlas_coords", Vector2i(0, 0))' not in function_text:
        failures.append("CombatFloor._make_atlas_sprite() must default missing atlas_coords to [0,0]")
    for required in (
        "source_texture.get_size()",
        "clampi(atlas_coords.x",
        "clampi(atlas_coords.y",
    ):
        if required not in function_text:
            failures.append(f"CombatFloor._make_atlas_sprite() lacks atlas bounds guard: {required}")


def _check_scenery_prop_geometry(theme_id: str, prop: dict, arena: dict, failures: list[str]) -> None:
    prop_id = prop.get("id", "<unnamed>")
    position = prop.get("position", [])
    size = prop.get("size", [])
    modulate = prop.get("modulate", [])
    if not _is_number_pair(position):
        failures.append(f"{theme_id}.scenery_props.{prop_id} position must be [x, y] numbers")
    else:
        bounds = arena.get("world_bounds", EXPECTED_WORLD_BOUNDS)
        x, y = float(position[0]), float(position[1])
        min_x = float(bounds.get("x", EXPECTED_WORLD_BOUNDS["x"]))
        min_y = float(bounds.get("y", EXPECTED_WORLD_BOUNDS["y"]))
        max_x = min_x + float(bounds.get("width", EXPECTED_WORLD_BOUNDS["width"]))
        max_y = min_y + float(bounds.get("height", EXPECTED_WORLD_BOUNDS["height"]))
        if not (min_x <= x <= max_x and min_y <= y <= max_y):
            failures.append(f"{theme_id}.scenery_props.{prop_id} position outside world_bounds: {position}")
    if not _is_number_pair(size) or float(size[0]) <= 0 or float(size[1]) <= 0:
        failures.append(f"{theme_id}.scenery_props.{prop_id} size must be positive [w, h]")
    if not isinstance(modulate, list) or len(modulate) != 4 or not all(_is_number(v) for v in modulate):
        failures.append(f"{theme_id}.scenery_props.{prop_id} modulate must be [r, g, b, a]")
    elif any(float(v) < 0.0 or float(v) > 1.0 for v in modulate):
        failures.append(f"{theme_id}.scenery_props.{prop_id} modulate values must be in 0..1")


def _check_terrain_props_visual_semantics(theme_id: str, img: Image.Image, semantics: dict, failures: list[str]) -> None:
    if img.size != EXPECTED_TERRAIN_PROPS_SIZE:
        return
    cell_stats: dict[tuple[int, int], dict[str, object]] = {}
    for y in range(3):
        for x in range(3):
            cell = img.crop((
                x * EXPECTED_TERRAIN_PROP_CELL_SIZE,
                y * EXPECTED_TERRAIN_PROP_CELL_SIZE,
                (x + 1) * EXPECTED_TERRAIN_PROP_CELL_SIZE,
                (y + 1) * EXPECTED_TERRAIN_PROP_CELL_SIZE,
            ))
            alpha = cell.getchannel("A")
            bbox = alpha.getbbox()
            nonzero = sum(1 for value in alpha.getdata() if value > 8)
            coverage = nonzero / float(EXPECTED_TERRAIN_PROP_CELL_SIZE * EXPECTED_TERRAIN_PROP_CELL_SIZE)
            magenta_pixels = sum(
                1
                for r, g, b, a in cell.getdata()
                if a > 8 and abs(r - 255) <= 12 and g <= 12 and abs(b - 255) <= 12
            )
            if bbox is None:
                failures.append(f"{theme_id}.terrain_props cell [{x},{y}] is empty")
                continue
            left, top, right, bottom = bbox
            margin = min(left, top, EXPECTED_TERRAIN_PROP_CELL_SIZE - right, EXPECTED_TERRAIN_PROP_CELL_SIZE - bottom)
            cell_stats[(x, y)] = {
                "coverage": coverage,
                "margin": margin,
                "image": cell.resize((32, 32), Image.Resampling.LANCZOS),
            }
            if coverage < TERRAIN_PROP_MIN_ALPHA_COVERAGE:
                failures.append(
                    f"{theme_id}.terrain_props cell [{x},{y}] alpha coverage {coverage:.3f} "
                    f"< {TERRAIN_PROP_MIN_ALPHA_COVERAGE:.3f}"
                )
            if coverage > TERRAIN_PROP_MAX_ALPHA_COVERAGE:
                failures.append(
                    f"{theme_id}.terrain_props cell [{x},{y}] alpha coverage {coverage:.3f} "
                    f"> {TERRAIN_PROP_MAX_ALPHA_COVERAGE:.3f}; prop is too dense for combat readability"
                )
            if margin < TERRAIN_PROP_MIN_EDGE_MARGIN:
                failures.append(
                    f"{theme_id}.terrain_props cell [{x},{y}] edge margin {margin}px "
                    f"< {TERRAIN_PROP_MIN_EDGE_MARGIN}px"
                )
            if magenta_pixels > 4:
                failures.append(f"{theme_id}.terrain_props cell [{x},{y}] still contains opaque magenta key pixels")

    for semantic, coords_list in semantics.items():
        if not isinstance(coords_list, list):
            continue
        for coords in coords_list:
            normalized = _normalize_atlas_coords(coords)
            if normalized is not None and normalized not in cell_stats:
                failures.append(f"{theme_id}.terrain_prop_semantics.{semantic} points to visually empty cell: {coords}")

    cells = sorted(cell_stats.items())
    for index, (first_coords, first) in enumerate(cells):
        first_image = first.get("image")
        if not isinstance(first_image, Image.Image):
            continue
        for second_coords, second in cells[index + 1:]:
            second_image = second.get("image")
            if not isinstance(second_image, Image.Image):
                continue
            diff = ImageChops.difference(first_image, second_image)
            mean_diff = sum(ImageStat.Stat(diff).mean) / 4.0
            if mean_diff < TERRAIN_PROP_MIN_CELL_DIFF:
                failures.append(
                    f"{theme_id}.terrain_props cells {first_coords} and {second_coords} are too similar "
                    f"(mean diff {mean_diff:.2f} < {TERRAIN_PROP_MIN_CELL_DIFF:.2f})"
                )


def _is_number_pair(value: object) -> bool:
    return isinstance(value, list) and len(value) >= 2 and _is_number(value[0]) and _is_number(value[1])


def _is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def main() -> int:
    failures = _failures()
    if failures:
        print("runtime map asset QA failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("runtime map asset QA passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
