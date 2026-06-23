#!/usr/bin/env python3
"""Generate replacement runtime combat maps for Samsara Ascension.

This keeps the playable contract simple: foundation-only arena backgrounds,
Godot TileMap-compatible tilesets, runtime stage metadata, and QA previews.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import math
import os
import random
import sys
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


SCRIPT_DIR = Path(__file__).resolve().parent
GAME_ROOT = SCRIPT_DIR.parent
MAP_ROOT = GAME_ROOT / "assets" / "maps"

BG_SIZE = (1280, 720)
TILE_SIZE = 32
TILESET_SIZE = 128
PROP_PACK_SIZE = (384, 384)
PROP_CELL_SIZE = 128
TAU = math.tau
WORLD_BOUNDS = {"x": -640, "y": -352, "width": 1280, "height": 704}
CAMERA_BOUNDS = {"x": -640, "y": -360, "width": 1280, "height": 720}
SSSTOKEN_IMAGE_ENDPOINT = "https://api.ssstoken.net/v1/images/generations"
DEFAULT_IMAGE_MODEL = "gpt-image-2"
DEFAULT_IMAGE_SIZE = "1024x1024"
ENV_API_KEYS = ("SSSTOKEN_API_KEY", "OPENAI_API_KEY")
MAGENTA = (255, 0, 255)
WINDOWS_USER_ENV_PATH = "Environment"
WINDOWS_MACHINE_ENV_PATH = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"


STAGES = [
    {
        "stage_index": 1,
        "theme_id": "qi_refining_verdant",
        "theme_label": "炼气翠林",
        "stage_name": "初入仙途",
        "weather_id": "clear",
        "palette": {
            "sky": (18, 45, 31),
            "ground": (52, 103, 61),
            "ground_alt": (73, 132, 72),
            "path": (120, 101, 68),
            "rim": (139, 215, 130),
            "dark": (31, 67, 41),
            "glow": (188, 255, 179),
        },
        "motif": "verdant spirit-grass battlefield with soft mossy terrain",
        "floor_pattern": "meadow",
        "decoration_density": 26,
    },
    {
        "stage_index": 2,
        "theme_id": "foundation_cavern",
        "theme_label": "筑基灵窟",
        "stage_name": "秘境深处",
        "weather_id": "rain",
        "palette": {
            "sky": (13, 22, 32),
            "ground": (48, 65, 76),
            "ground_alt": (62, 82, 94),
            "path": (70, 86, 93),
            "rim": (76, 211, 205),
            "dark": (25, 35, 45),
            "glow": (119, 244, 235),
        },
        "motif": "wet foundation cavern with jade veins and shallow reflective stone floor",
        "floor_pattern": "cavern",
        "decoration_density": 22,
    },
    {
        "stage_index": 3,
        "theme_id": "golden_core_demon",
        "theme_label": "金丹魔域",
        "stage_name": "渡劫前夜",
        "weather_id": "thunder",
        "palette": {
            "sky": (15, 8, 26),
            "ground": (47, 32, 69),
            "ground_alt": (67, 40, 91),
            "path": (82, 46, 61),
            "rim": (194, 96, 255),
            "dark": (27, 16, 43),
            "glow": (255, 125, 198),
        },
        "motif": "demonic golden-core battlefield with purple qi scars in the ground",
        "floor_pattern": "demon",
        "decoration_density": 24,
    },
    {
        "stage_index": 4,
        "theme_id": "nascent_soul_ruins",
        "theme_label": "元婴遗迹",
        "stage_name": "焚心秘境",
        "weather_id": "fire",
        "palette": {
            "sky": (30, 20, 13),
            "ground": (71, 58, 42),
            "ground_alt": (91, 74, 49),
            "path": (111, 83, 45),
            "rim": (250, 205, 92),
            "dark": (44, 34, 24),
            "glow": (255, 226, 123),
        },
        "motif": "ancient nascent-soul ruin with worn stone and scattered gold fragments",
        "floor_pattern": "ruins",
        "decoration_density": 28,
    },
    {
        "stage_index": 5,
        "theme_id": "tribulation_thunder",
        "theme_label": "天劫雷台",
        "stage_name": "天劫试场",
        "weather_id": "thunder",
        "palette": {
            "sky": (8, 10, 29),
            "ground": (42, 45, 65),
            "ground_alt": (59, 61, 86),
            "path": (69, 72, 96),
            "rim": (255, 216, 71),
            "dark": (20, 22, 41),
            "glow": (255, 243, 151),
        },
        "motif": "floating tribulation thunder battlefield with storm-lit fractured slate",
        "floor_pattern": "thunder",
        "decoration_density": 30,
    },
]


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _jitter(color: tuple[int, int, int], amount: int, rng: random.Random) -> tuple[int, int, int]:
    return tuple(max(0, min(255, c + rng.randint(-amount, amount))) for c in color)


def _draw_soft_ellipse(
    base: Image.Image,
    bbox: tuple[int, int, int, int],
    color: tuple[int, int, int],
    alpha: int,
    blur: int = 12,
) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(bbox, fill=(*color, alpha))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def _draw_glow_line(
    base: Image.Image,
    points: list[tuple[float, float]],
    color: tuple[int, int, int],
    *,
    width: int,
    alpha: int,
    glow: int = 0,
) -> None:
    if len(points) < 2:
        return
    if glow > 0:
        glow_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow_layer).line(points, fill=(*color, max(10, alpha // 2)), width=width + glow, joint="curve")
        base.alpha_composite(glow_layer.filter(ImageFilter.GaussianBlur(max(1, glow // 2))))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).line(points, fill=(*color, alpha), width=width, joint="curve")
    base.alpha_composite(layer)


def _draw_irregular_blob(
    base: Image.Image,
    center: tuple[float, float],
    radius: tuple[float, float],
    color: tuple[int, int, int],
    *,
    rng: random.Random,
    alpha: int,
    points: int = 18,
    blur: int = 0,
) -> None:
    cx, cy = center
    rx, ry = radius
    pts: list[tuple[float, float]] = []
    for i in range(points):
        angle = TAU * i / points
        wobble = rng.uniform(0.78, 1.18)
        pts.append((cx + math.cos(angle) * rx * wobble, cy + math.sin(angle) * ry * wobble))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=(*color, alpha))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)


def _draw_ground_band(
    base: Image.Image,
    start_y: float,
    color: tuple[int, int, int],
    *,
    rng: random.Random,
    alpha: int,
    width: float,
    slope: float,
    roughness: float = 34.0,
    blur: int = 12,
) -> None:
    """Paint a broad non-circular terrain band across the arena."""
    pts_top: list[tuple[float, float]] = []
    pts_bottom: list[tuple[float, float]] = []
    steps = 9
    for i in range(steps + 1):
        x = -80 + (BG_SIZE[0] + 160) * i / steps
        center_y = start_y + (x - BG_SIZE[0] * 0.5) * slope + rng.uniform(-roughness, roughness)
        pts_top.append((x, center_y - width * rng.uniform(0.42, 0.58)))
        pts_bottom.append((x, center_y + width * rng.uniform(0.42, 0.58)))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts_top + list(reversed(pts_bottom)), fill=(*color, alpha))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)


def _draw_corner_depth(base: Image.Image, color: tuple[int, int, int]) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    w, h = base.size
    for i in range(120):
        alpha = int(1 + i * 0.62)
        draw.rectangle((i, i, w - i, h - i), outline=(*color, alpha))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2)))


def _scatter_floor_detail(
    img: Image.Image,
    stage: dict,
    rng: random.Random,
    *,
    count: int,
) -> None:
    p = stage["palette"]
    draw = ImageDraw.Draw(img)
    pattern = stage["floor_pattern"]
    for _ in range(count):
        x = rng.randrange(70, BG_SIZE[0] - 70)
        y = rng.randrange(55, BG_SIZE[1] - 55)
        if rng.random() < 0.45 and (x - 640) ** 2 / (260**2) + (y - 360) ** 2 / (150**2) < 1:
            continue
        alpha = rng.randrange(22, 74)
        if pattern == "meadow":
            draw.line((x, y, x + rng.randrange(-10, 12), y - rng.randrange(8, 18)), fill=(*p["rim"], alpha), width=1)
        elif pattern == "cavern":
            draw.line((x, y, x + rng.randrange(12, 44), y + rng.randrange(-8, 12)), fill=(*p["rim"], alpha), width=1)
            if rng.random() < 0.28:
                draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(*p["glow"], alpha + 30))
        elif pattern == "demon":
            draw.line((x, y, x + rng.randrange(-36, 38), y + rng.randrange(-18, 20)), fill=(*p["glow"], alpha), width=rng.randrange(1, 3))
        elif pattern == "ruins":
            draw.rectangle((x, y, x + rng.randrange(14, 52), y + rng.randrange(3, 9)), fill=(*p["rim"], alpha))
        else:
            pts = [(x, y), (x + rng.randrange(-14, 18), y + rng.randrange(18, 36)), (x + rng.randrange(-6, 22), y + rng.randrange(18, 40))]
            draw.line(pts, fill=(*p["glow"], alpha), width=1)


def _draw_foundation_background(stage: dict, rng: random.Random) -> Image.Image:
    palette = stage["palette"]
    img = Image.new("RGBA", BG_SIZE, (*palette["ground"], 255))
    draw = ImageDraw.Draw(img)

    # Painterly gradient foundation: quieter center, stronger mood at edges.
    for y in range(BG_SIZE[1]):
        t = y / max(1, BG_SIZE[1] - 1)
        row = _mix(palette["sky"], palette["ground"], min(1.0, t * 1.16))
        draw.line((0, y, BG_SIZE[0], y), fill=(*row, 255))

    # Directional ground masses avoid player-centered halos while still giving depth.
    _draw_ground_band(img, 230, palette["dark"], rng=rng, alpha=54, width=170, slope=-0.10, blur=20)
    _draw_ground_band(img, 360, palette["ground_alt"], rng=rng, alpha=72, width=148, slope=0.08, blur=16)
    _draw_ground_band(img, 505, palette["path"], rng=rng, alpha=44, width=118, slope=-0.06, blur=18)
    for x0 in range(-40, BG_SIZE[0], 185):
        y0 = rng.randrange(95, BG_SIZE[1] - 95)
        x1 = x0 + rng.randrange(90, 210)
        y1 = y0 + rng.randrange(-48, 49)
        _draw_glow_line(img, [(x0, y0), (x1, y1)], palette["ground_alt"], width=rng.randrange(8, 18), alpha=rng.randrange(18, 36), glow=14)

    # Theme-specific outer land forms that stay non-colliding background art.
    pattern = stage["floor_pattern"]
    if pattern == "meadow":
        for center in ((190, 132), (1085, 118), (1010, 590), (230, 610)):
            _draw_irregular_blob(img, center, (150, 62), palette["ground_alt"], rng=rng, alpha=78, points=14, blur=18)
    elif pattern == "cavern":
        for center in ((210, 150), (1090, 150), (250, 590), (1040, 610)):
            _draw_irregular_blob(img, center, (180, 82), palette["dark"], rng=rng, alpha=112, points=13, blur=10)
    elif pattern == "demon":
        for center in ((260, 170), (1000, 185), (1030, 585), (260, 585)):
            _draw_irregular_blob(img, center, (190, 72), palette["path"], rng=rng, alpha=70, points=12, blur=20)
    elif pattern == "ruins":
        for center in ((240, 165), (1030, 170), (1025, 585), (245, 580)):
            _draw_irregular_blob(img, center, (170, 64), palette["path"], rng=rng, alpha=88, points=10, blur=8)
    elif pattern == "thunder":
        for center in ((205, 150), (1080, 152), (1040, 594), (228, 590)):
            _draw_irregular_blob(img, center, (175, 66), palette["ground_alt"], rng=rng, alpha=78, points=12, blur=16)

    # Keep the combat floor quiet: no rings, radial lines, symbols, or UI-like marks.

    detail_count = {
        "meadow": 150,
        "cavern": 118,
        "demon": 86,
        "ruins": 96,
        "thunder": 92,
    }.get(pattern, 110)
    _scatter_floor_detail(img, stage, rng, count=detail_count)

    noise = Image.effect_noise(BG_SIZE, 18).convert("L")
    noise_layer = Image.merge("RGBA", (noise, noise, noise, noise.point(lambda v: int(v * 0.05))))
    img.alpha_composite(noise_layer)

    # Keep center readability via low-contrast linear texture instead of a circular glow.
    for y in range(230, 505, 42):
        tint = _mix(palette["ground"], palette["glow"], 0.12)
        _draw_glow_line(img, [(315, y + rng.randrange(-12, 13)), (965, y + rng.randrange(-12, 13))], tint, width=2, alpha=10, glow=8)
    _draw_corner_depth(img, palette["dark"])
    return img.convert("RGB")


def _draw_tile(draw: ImageDraw.ImageDraw, origin: tuple[int, int], fill: tuple[int, int, int], rng: random.Random) -> None:
    x0, y0 = origin
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            draw.point((x0 + x, y0 + y), fill=_jitter(fill, 10, rng))


def _image_from_bytes(raw: bytes) -> Image.Image:
    return Image.open(io.BytesIO(raw)).convert("RGBA")


def _load_image_response(payload: dict, *, timeout: int = 300) -> Image.Image:
    data = payload.get("data", [])
    if not isinstance(data, list) or not data:
        raise RuntimeError("image API response did not include data[0]")
    first = data[0]
    if not isinstance(first, dict):
        raise RuntimeError("image API response data[0] was not an object")
    b64_value = first.get("b64_json") or first.get("base64") or first.get("image")
    if isinstance(b64_value, str) and b64_value:
        if b64_value.startswith("data:"):
            b64_value = b64_value.split(",", 1)[1]
        return _image_from_bytes(base64.b64decode(b64_value))
    url = first.get("url")
    if isinstance(url, str) and url:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return _image_from_bytes(response.read())
    raise RuntimeError("image API response did not include b64_json or url")


def _request_generated_image(
    prompt: str,
    *,
    api_key: str,
    endpoint: str,
    model: str,
    size: str,
    timeout: int,
) -> Image.Image:
    body = {
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": size,
        "quality": "auto",
        "background": "auto",
        "output_format": "png",
        "moderation": "auto",
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"image API returned HTTP {exc.code}: {detail[:600]}") from exc
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise RuntimeError("image API response was not a JSON object")
    return _load_image_response(parsed, timeout=timeout)


def _fit_image(image: Image.Image, size: tuple[int, int], *, mode: str) -> Image.Image:
    if mode == "contain":
        fitted = ImageOps.contain(image.convert("RGBA"), size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.alpha_composite(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
        return canvas
    return ImageOps.fit(image.convert("RGBA"), size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def _chroma_key_magenta(image: Image.Image) -> Image.Image:
    """Convert generated magenta prop-pack gutters to alpha for runtime atlas use."""
    src = image.convert("RGBA")
    pixels = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            magenta_distance = abs(r - MAGENTA[0]) + abs(g - MAGENTA[1]) + abs(b - MAGENTA[2])
            if magenta_distance <= 58 and r > 190 and b > 190 and g < 96:
                pixels[x, y] = (r, g, b, 0)
            elif r > 160 and b > 160 and g < 130:
                pixels[x, y] = (min(r, 180), max(g, 40), min(b, 180), a)
    return src


def _api_key_from_env() -> str:
    for name in ENV_API_KEYS:
        value = os.environ.get(name, "").strip()
        if value:
            return value
    if os.name == "nt":
        try:
            import winreg
        except ImportError:
            return ""
        registry_locations = (
            (winreg.HKEY_CURRENT_USER, WINDOWS_USER_ENV_PATH),
            (winreg.HKEY_LOCAL_MACHINE, WINDOWS_MACHINE_ENV_PATH),
        )
        for name in ENV_API_KEYS:
            for root, subkey in registry_locations:
                try:
                    with winreg.OpenKey(root, subkey) as key:
                        value, _value_type = winreg.QueryValueEx(key, name)
                except OSError:
                    continue
                if isinstance(value, str) and value.strip():
                    return value.strip()
    return ""


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate runtime map backgrounds, tilesets, manifest metadata, and QA previews."
    )
    parser.add_argument(
        "--provider",
        choices=["auto", "ssstoken", "procedural"],
        default="auto",
        help="Visual asset provider. auto uses SSSToken when SSSTOKEN_API_KEY or OPENAI_API_KEY is set.",
    )
    parser.add_argument("--image-endpoint", default=SSSTOKEN_IMAGE_ENDPOINT)
    parser.add_argument("--image-model", default=DEFAULT_IMAGE_MODEL)
    parser.add_argument("--image-size", default=DEFAULT_IMAGE_SIZE)
    parser.add_argument("--image-timeout", type=int, default=300)
    parser.add_argument(
        "--no-fallback",
        action="store_true",
        help="Fail instead of falling back to local procedural art when the remote image provider is unavailable.",
    )
    return parser.parse_args()


def _should_use_remote(args: argparse.Namespace, api_key: str) -> bool:
    if args.provider == "procedural":
        return False
    if api_key:
        return True
    if args.provider == "ssstoken":
        raise RuntimeError("SSSTOKEN provider selected but SSSTOKEN_API_KEY/OPENAI_API_KEY is not set")
    return False


def _make_visual_assets(
    stage: dict,
    rng: random.Random,
    *,
    use_remote: bool,
    api_key: str,
    args: argparse.Namespace,
) -> tuple[Image.Image, Image.Image, Image.Image, str]:
    if not use_remote:
        return (
            _draw_foundation_background(stage, rng),
            _draw_tileset(stage, rng),
            _chroma_key_magenta(_draw_terrain_props(stage, rng)),
            "procedural_fallback",
        )
    try:
        background = _request_generated_image(
            _background_prompt(stage),
            api_key=api_key,
            endpoint=args.image_endpoint,
            model=args.image_model,
            size=args.image_size,
            timeout=args.image_timeout,
        )
        tileset = _request_generated_image(
            _tileset_prompt(stage),
            api_key=api_key,
            endpoint=args.image_endpoint,
            model=args.image_model,
            size=args.image_size,
            timeout=args.image_timeout,
        )
        terrain_props = _request_generated_image(
            _terrain_props_prompt(stage),
            api_key=api_key,
            endpoint=args.image_endpoint,
            model=args.image_model,
            size=args.image_size,
            timeout=args.image_timeout,
        )
        return (
            _fit_image(background, BG_SIZE, mode="cover").convert("RGB"),
            _fit_image(tileset, (TILESET_SIZE, TILESET_SIZE), mode="contain"),
            _chroma_key_magenta(_fit_image(terrain_props, PROP_PACK_SIZE, mode="contain")),
            "ssstoken_gpt_image_2",
        )
    except Exception as exc:
        if args.no_fallback:
            raise
        print(f"warning: image provider failed for {stage['theme_id']}; using procedural fallback: {exc}", file=sys.stderr)
        return (
            _draw_foundation_background(stage, rng),
            _draw_tileset(stage, rng),
            _chroma_key_magenta(_draw_terrain_props(stage, rng)),
            "procedural_fallback",
        )


def _background_prompt(stage: dict) -> str:
    return f"""SYSTEM ROLE
You are a senior 2D environment art director for a shipped Godot 4 action roguelite. Create one production-ready map foundation asset only; obey the runtime layer separation contract exactly.

PROJECT CONTEXT
Game: Samsara Ascension / 轮回仙途, Chinese xianxia cultivation roguelite, top-down survivors-like combat.
Runtime: the PNG will be center-cropped and resized to 1280x720; collision, props, enemies, pickups, spawn zones, and camera bounds are loaded separately from runtime_scene_manifest.json.
Realm/stage: {stage['theme_label']} / {stage['stage_name']}.
Theme motif: {stage['motif']}.

ART DIRECTION
Style: clean hand-painted HD 2D game map, readable at 1280x720, dark Chinese cultivation fantasy, elegant but functional, not retro pixel art, not noisy AI texture.
Camera: top-down with a slight 3/4 painterly material read; flat enough for a TileMap overlay and enemy silhouettes.
Composition: large open combat floor, visually quiet playable center, darker atmospheric edges, asymmetric terrain masses, subtle paths or worn flow lines that guide movement without looking like UI.
Terrain detail: include foundation-level material variation only: moss, damp stone, scorched cracks, jade veins, worn ruin slabs, lightning fractures, shallow puddle stains, dust, sand, leaf litter, mineral flecks, faint qi residue. Keep details low and embedded in the ground.
Lighting: soft environmental glow from the realm palette, no hard spotlight, no centered halo, no ritual target circle.
Product design intent: every run should feel like a different cultivation trial. Leave broad negative space for dense enemies, make edges tell the realm story, and create enough local terrain variation that randomized larger rooms still feel authored rather than stretched.

LAYER CONTRACT
This is a foundation/background layer. It may show ground material, low terrain markings, floor patterns, path scars, shallow embedded detail, and non-colliding terrain boundaries.
It must not bake any runtime-controlled object.

STRICT EXCLUSIONS
No player, enemies, NPCs, bosses, pets, projectiles, pickups, chests, doors, gates, signs, tall props, trees, buildings, crates, barrels, pillars, rocks that look collidable, walls, fences, stairs, UI, labels, text, arrows, numbers, minimap graphics, circular ritual diagrams, radial target rings, camera-centered halo, or baked collision objects.

OUTPUT
One square PNG source image, no transparency required, no border, no frame, no text.
"""


def _tileset_prompt(stage: dict) -> str:
    return f"""SYSTEM ROLE
You are creating a tiny production Godot TileSet atlas for a top-down xianxia combat arena. Prioritize readability after downscaling.

PROJECT CONTEXT
Game: Samsara Ascension / 轮回仙途.
Realm/stage: {stage['theme_label']} / {stage['stage_name']}.
Theme motif: {stage['motif']}.
Runtime: output will be resized to 128x128 and sliced as four 32x32 atlas cells across the top row.

STRICT ATLAS LAYOUT
Create a square source image whose TOP ROW contains exactly four visually separated tile concepts from left to right:
1. floor: base ground material
2. floor_alt: alternate ground with subtle variation
3. obstacle/blocker: compact collidable terrain marker such as a ritual stone, broken slab, thorny root, jade boulder, or thunder slate
4. decoration: compact non-colliding terrain detail such as spirit grass, qi crack, jade vein, ash glyph fragment, gold dust, or lightning trace
The rest of the image should be empty, transparent-looking, or visually simple so it does not introduce extra atlas concepts.

ART DIRECTION
Clean hand-painted HD xianxia game asset, readable at 32px, crisp silhouette, restrained texture, strong material identity matching the realm. No chunky retro pixels.
Keep the four concepts consistent in scale, palette, lighting direction, and top-down perspective.

STRICT EXCLUSIONS
No text, labels, UI, characters, enemies, weapons, projectiles, full room composition, large scenery, or extra tile rows with additional concepts.

OUTPUT
One square PNG source image.
"""


def _terrain_props_prompt(stage: dict) -> str:
    return f"""SYSTEM ROLE
You are generating a transparent prop pack for runtime terrain details in a top-down Godot 4 combat arena. Use the rules of a professional game prop sheet: consistent scale, clean silhouettes, no edge touching, and no unrelated objects.

PROJECT CONTEXT
Game: Samsara Ascension / 轮回仙途, Chinese xianxia cultivation roguelite.
Realm/stage: {stage['theme_label']} / {stage['stage_name']}.
Theme motif: {stage['motif']}.
Runtime: this sheet will be resized to 384x384 and sliced into a 3x3 grid of 128x128 cells. Props are rendered separately from the background and may be tinted or scaled by runtime_scene_manifest.json.

STRICT SHEET LAYOUT
Create exactly 9 compact terrain-detail props arranged in a clean 3x3 grid.
Each prop must stay centered inside its own invisible 128x128 cell with generous padding; no prop may touch or cross a cell edge.
Use a solid #FF00FF magenta background across the entire sheet for chroma-key/alpha postprocessing.
Do not draw visible grid lines, labels, numbers, captions, borders, or cell guides.

ROW-MAJOR CELL LIST AND RUNTIME SEMANTICS
1. [0,0] thin embedded wet qi crack or elemental vein, horizontal/diagonal, flat on ground
2. [1,0] small moss, spirit grass, ash, or mineral cluster
3. [2,0] compact non-colliding stone/slab/debris accent
4. [0,1] alternate glowing vein or elemental trace
5. [1,1] shallow stain, puddle rim, scorch, dust swirl, or wind streak
6. [2,1] compact low debris or unreadable glyph fragment embedded flat in the ground
7. [0,2] compact realm-specific elemental scar or aura residue
8. [1,2] alternate low ground ornament with a different silhouette
9. [2,2] alternate stone/slab/debris accent for obstacle-adjacent dressing

ART DIRECTION
Clean hand-painted HD xianxia map-prop style, top-down with slight 3/4 material read, readable at small sizes, matching the realm palette and lighting. These are low terrain details, not tall props.
Make silhouettes varied and useful for random placement: some horizontal, some diagonal, some round, some narrow. Keep them subtle enough not to obscure combat.
The pack should add tactical readability and atmosphere to larger randomized rooms: cracks suggest danger history, grass/minerals suggest realm identity, stains and aura residue break repetition, but every prop remains flat and non-colliding.

STRICT EXCLUSIONS
No player, enemies, NPCs, bosses, pets, projectiles, weapons, pickups, chests, doors, gates, signs, trees, buildings, crates, barrels, UI, labels, text, arrows, large walls, tall pillars, large rocks, collision-critical blockers, or full room backgrounds.

OUTPUT
One square PNG prop sheet, solid #FF00FF background, exactly nine compact props.
"""


def _draw_tileset(stage: dict, rng: random.Random) -> Image.Image:
    p = stage["palette"]
    img = Image.new("RGBA", (TILESET_SIZE, TILESET_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    _draw_tile(draw, (0, 0), p["ground"], rng)
    _draw_tile(draw, (32, 0), p["ground_alt"], rng)
    _draw_tile(draw, (64, 0), p["dark"], rng)
    _draw_tile(draw, (96, 0), p["ground"], rng)

    # Floor alternates with small material cues that survive nearest filtering.
    for ox in (0, 32):
        for _ in range(10):
            x, y = ox + rng.randrange(3, 29), rng.randrange(3, 29)
            if stage["floor_pattern"] in ("ruins", "thunder"):
                draw.line((x, y, x + rng.randrange(-7, 8), y + rng.randrange(-4, 6)), fill=(*_jitter(p["rim"], 16, rng), 190), width=1)
            else:
                draw.ellipse((x, y, x + rng.randrange(2, 5), y + rng.randrange(2, 5)), fill=(*_jitter(p["rim"], 18, rng), 210))

    # Obstacle/blocker tile: compact ritual stone, readable as a collision body.
    stone = [(80, 3), (94, 10), (91, 27), (72, 30), (65, 16), (70, 6)]
    draw.polygon(stone, fill=(*_jitter(p["dark"], 10, rng), 255), outline=(*p["rim"], 230))
    draw.line((71, 14, 91, 18), fill=(*p["ground_alt"], 160), width=1)
    draw.line((76, 8, 83, 27), fill=(*p["rim"], 130), width=1)
    draw.ellipse((78, 12, 86, 20), outline=(*p["glow"], 190), width=1)

    # Decoration tile: compact material motif, consistent with the background.
    cx, cy = 112, 16
    if stage["floor_pattern"] == "meadow":
        draw.line((103, 25, 110, 9), fill=(*p["glow"], 230), width=2)
        draw.line((112, 25, 118, 10), fill=(*p["rim"], 210), width=1)
        draw.line((121, 25, 116, 14), fill=(*p["glow"], 180), width=1)
    elif stage["floor_pattern"] == "cavern":
        draw.line((101, 18, 123, 11), fill=(*p["glow"], 235), width=2)
        draw.ellipse((108, 11, 116, 19), outline=(*p["rim"], 255), width=1)
    elif stage["floor_pattern"] == "demon":
        draw.line((101, 9, 123, 24), fill=(*p["glow"], 240), width=2)
        draw.line((106, 24, 119, 6), fill=(*p["rim"], 190), width=1)
    elif stage["floor_pattern"] == "ruins":
        draw.rectangle((102, 8, 122, 23), outline=(*p["rim"], 240), width=1)
        draw.line((106, 16, 118, 16), fill=(*p["glow"], 230), width=2)
    else:
        draw.line((cx - 5, 7, cx + 2, 16, cx - 1, 16, cx + 6, 27), fill=(*p["glow"], 255), width=2)
        draw.line((102, 22, 121, 8), fill=(*p["rim"], 160), width=1)
    return img


def _draw_terrain_props(stage: dict, rng: random.Random) -> Image.Image:
    p = stage["palette"]
    img = Image.new("RGBA", PROP_PACK_SIZE, (*MAGENTA, 255))
    draw = ImageDraw.Draw(img)
    for index in range(9):
        col = index % 3
        row = index // 3
        ox = col * PROP_CELL_SIZE
        oy = row * PROP_CELL_SIZE
        cx = ox + PROP_CELL_SIZE // 2 + rng.randrange(-8, 9)
        cy = oy + PROP_CELL_SIZE // 2 + rng.randrange(-8, 9)
        if index % 3 == 0:
            pts = []
            for i in range(5):
                x = cx - 44 + i * 22 + rng.randrange(-5, 6)
                y = cy + rng.randrange(-14, 15)
                pts.append((x, y))
            _draw_glow_line(img, pts, p["glow"], width=3, alpha=180, glow=8)
            _draw_glow_line(img, pts, p["dark"], width=1, alpha=170, glow=0)
        elif index % 3 == 1:
            for _ in range(7):
                x = cx + rng.randrange(-28, 29)
                y = cy + rng.randrange(-18, 19)
                draw.line((x, y + 16, x + rng.randrange(-7, 8), y - rng.randrange(8, 20)), fill=(*_jitter(p["rim"], 18, rng), 220), width=2)
        else:
            radius = (rng.randrange(20, 34), rng.randrange(12, 24))
            _draw_irregular_blob(img, (cx, cy), radius, p["dark"], rng=rng, alpha=230, points=10, blur=0)
            _draw_irregular_blob(img, (cx + 3, cy - 2), (radius[0] * 0.62, radius[1] * 0.5), p["ground_alt"], rng=rng, alpha=130, points=8, blur=0)
    return img


def _decorative_cells(stage: dict, rng: random.Random) -> list[list[int]]:
    cells: list[list[int]] = []
    density = stage["decoration_density"]
    attempts = 0
    while len(cells) < density and attempts < density * 20:
        attempts += 1
        x = rng.randrange(-18, 19)
        y = rng.randrange(-9, 10)
        if abs(x) < 3 and abs(y) < 3:
            continue
        if [x, y] in cells:
            continue
        cells.append([x, y])
    return cells


def _zone(center: tuple[int, int], size: tuple[int, int], zone_id: str, weight: float = 1.0) -> dict:
    return {
        "id": zone_id,
        "center": [center[0], center[1]],
        "size": [size[0], size[1]],
        "weight": weight,
    }


def _stage_runtime_hooks(stage: dict) -> dict:
    idx = stage["stage_index"]
    prop_atlas = f"res://assets/maps/{stage['theme_id']}/terrain_props.png"
    if idx == 1:
        pattern = "edge_pockets"
        props = [
            {"id": "grass_cluster_w", "position": [-420, -170], "size": [64, 48], "atlas_path": prop_atlas, "atlas_coords": [1, 0], "atlas_cell_size": 128, "modulate": [0.76, 1.0, 0.78, 0.64]},
            {"id": "grass_cluster_e", "position": [410, 165], "size": [58, 42], "atlas_path": prop_atlas, "atlas_coords": [1, 1], "atlas_cell_size": 128, "modulate": [0.76, 1.0, 0.78, 0.58]},
            {"id": "moss_stone_n", "position": [180, -245], "size": [54, 42], "atlas_path": prop_atlas, "atlas_coords": [2, 0], "atlas_cell_size": 128, "modulate": [0.9, 1.0, 0.86, 0.46]},
        ]
    elif idx == 2:
        pattern = "lane_gates"
        props = [
            {"id": "jade_vein_nw", "position": [-455, -208], "size": [82, 36], "atlas_path": prop_atlas, "atlas_coords": [0, 0], "atlas_cell_size": 128, "modulate": [0.68, 1.0, 0.98, 0.58]},
            {"id": "wet_stone_se", "position": [392, 220], "size": [62, 46], "atlas_path": prop_atlas, "atlas_coords": [2, 1], "atlas_cell_size": 128, "modulate": [0.78, 0.9, 1.0, 0.46]},
            {"id": "jade_vein_e", "position": [485, -92], "size": [68, 30], "atlas_path": prop_atlas, "atlas_coords": [0, 1], "atlas_cell_size": 128, "modulate": [0.68, 1.0, 0.98, 0.52]},
        ]
    elif idx == 3:
        pattern = "broken_columns"
        props = [
            {"id": "demon_scar_w", "position": [-405, 94], "size": [88, 34], "atlas_path": prop_atlas, "atlas_coords": [0, 0], "atlas_cell_size": 128, "modulate": [1.0, 0.58, 0.86, 0.58]},
            {"id": "demon_stone_ne", "position": [334, -218], "size": [58, 50], "atlas_path": prop_atlas, "atlas_coords": [2, 2], "atlas_cell_size": 128, "modulate": [1.0, 0.72, 0.95, 0.44]},
            {"id": "demon_scar_s", "position": [35, 268], "size": [96, 30], "atlas_path": prop_atlas, "atlas_coords": [0, 2], "atlas_cell_size": 128, "modulate": [1.0, 0.58, 0.86, 0.5]},
        ]
    elif idx == 4:
        pattern = "corner_shrines"
        props = [
            {"id": "ruin_slab_nw", "position": [-475, -228], "size": [76, 42], "atlas_path": prop_atlas, "atlas_coords": [2, 0], "atlas_cell_size": 128, "modulate": [1.0, 0.88, 0.62, 0.46]},
            {"id": "ruin_slab_se", "position": [455, 234], "size": [82, 38], "atlas_path": prop_atlas, "atlas_coords": [2, 1], "atlas_cell_size": 128, "modulate": [1.0, 0.88, 0.62, 0.44]},
            {"id": "gold_trace_e", "position": [365, -50], "size": [76, 26], "atlas_path": prop_atlas, "atlas_coords": [0, 1], "atlas_cell_size": 128, "modulate": [1.0, 0.9, 0.46, 0.54]},
        ]
    else:
        pattern = "boss_clear"
        props = [
            {"id": "thunder_slate_w", "position": [-485, 185], "size": [84, 42], "atlas_path": prop_atlas, "atlas_coords": [2, 0], "atlas_cell_size": 128, "modulate": [1.0, 0.94, 0.55, 0.44]},
            {"id": "storm_trace_ne", "position": [420, -222], "size": [78, 28], "atlas_path": prop_atlas, "atlas_coords": [0, 0], "atlas_cell_size": 128, "modulate": [1.0, 0.95, 0.64, 0.58]},
            {"id": "storm_trace_s", "position": [-28, 278], "size": [94, 28], "atlas_path": prop_atlas, "atlas_coords": [0, 2], "atlas_cell_size": 128, "modulate": [1.0, 0.95, 0.64, 0.48]},
        ]

    spawn_zones = [
        _zone((-445, -210), (250, 116), "north_west", 1.0),
        _zone((445, -210), (250, 116), "north_east", 1.0),
        _zone((-470, 170), (230, 132), "south_west", 0.86),
        _zone((470, 170), (230, 132), "south_east", 0.86),
        _zone((0, -286), (330, 70), "north_lane", 0.74),
    ]
    return {
        "layout_profile": {
            "profile_id": pattern,
            "preferred_pattern": pattern,
            "obstacle_count_bias": min(2, max(0, idx - 2)),
            "min_spacing_bias": 8 + idx * 2,
            "template_bias": ["pillar", "rock"] if idx >= 3 else ["rock", "pillar", "crate"],
            "collision_padding": 10 + idx,
        },
        "spawn_zones": spawn_zones,
        "no_spawn_zones": [
            _zone((0, 0), (250, 180), "center_safe", 1.0),
            _zone((0, 120), (220, 150), "player_recovery", 1.0),
            _zone((0, -55), (170, 120), "boss_entry", 1.0),
        ],
        "safe_zones": [
            _zone((0, 0), (210, 150), "central_foothold", 1.0),
            _zone((0, 120), (190, 132), "player_spawn", 1.0),
        ],
        "scenery_props": props,
    }


def _write_prompt(stage_dir: Path, stage: dict) -> None:
    (stage_dir / "room_background.prompt.txt").write_text(_background_prompt(stage), encoding="utf-8")
    (stage_dir / "tileset.prompt.txt").write_text(_tileset_prompt(stage), encoding="utf-8")
    (stage_dir / "terrain_props.prompt.txt").write_text(_terrain_props_prompt(stage), encoding="utf-8")


def _terrain_prop_semantics() -> dict:
    return {
        "water": [[0, 0], [0, 1], [1, 1]],
        "wet": [[0, 0], [0, 1], [1, 1]],
        "swamp": [[1, 0], [1, 1], [1, 2]],
        "fire": [[0, 2], [0, 1], [1, 1]],
        "dry": [[0, 2], [2, 1], [1, 1]],
        "rock": [[2, 0], [2, 1], [2, 2]],
        "ice": [[0, 0], [0, 1], [1, 1]],
        "thunder": [[0, 1], [0, 2], [1, 2]],
        "obstacle": [[2, 0], [2, 1], [2, 2]],
        "default": [[0, 0], [1, 1], [2, 2]],
    }


def _preview(background: Image.Image, stage: dict, cells: list[list[int]]) -> Image.Image:
    p = stage["palette"]
    img = background.convert("RGBA")
    draw = ImageDraw.Draw(img)
    for x, y, w, h in [(-210, -80, 48, 48), (205, 70, 56, 44), (0, -180, 42, 54), (0, 185, 42, 54)]:
        px = 640 + x
        py = 360 + y
        draw.rounded_rectangle((px - w / 2, py - h / 2, px + w / 2, py + h / 2), radius=8, fill=(*p["dark"], 155), outline=(*p["rim"], 120), width=1)
    return img.convert("RGB")


def _build_runtime_manifest(stage_entries: list[dict], asset_source: str, args: argparse.Namespace) -> dict:
    if asset_source == "ssstoken_gpt_image_2":
        note = (
            "Visible map assets were requested from an environment-configured image generation provider. "
            "Prompt files are saved beside every visible map asset."
        )
    else:
        note = (
            "Visible map assets were generated locally with the Pillow procedural fallback. Prompt files "
            "are saved beside every visible map asset so the same filenames can be replaced by image outputs."
        )
    return {
        "schema": "samsara_ascension.runtime_scene_manifest.v1",
        "generated_from": [
            "GDD_轮回仙途_v7.0.md",
            "docs/UIUX_全新暗色水墨五行粒子_v1.0.md",
            "docs/mimo_ui_master_index.md",
            "game/tools/generate_runtime_maps.py",
        ],
        "pipeline": {
            "skill": "generate2dmap",
            "map_mode": "scene_mode",
            "visual_model": "tilemap_plus_foundation_background",
            "runtime_object_model": "foundation_background_plus_tileset_plus_transparent_terrain_props_plus_obstacle_bodies_plus_scene_hooks",
            "collision_model": "obstacle_bodies_with_manifest_spawn_bounds",
            "engine_target": "Godot_TileMap",
            "visual_asset_source": asset_source,
            "runtime_assets": ["room_background", "tileset", "terrain_props", "spawn_zones", "safe_zones", "no_spawn_zones", "scenery_props"],
            "metadata_only_assets": ["qa_preview", "prompt_files", "tileset_metadata.json"],
            "note": note,
        },
        "arena": {
            "viewport_size": [1280, 720],
            "tile_size": 32,
            "tilemap_cells": [40, 22],
            "terrain_prop_atlas": {
                "cell_size": PROP_CELL_SIZE,
                "grid": [3, 3],
                "runtime_alpha_source": "terrain_props.png is saved with alpha after magenta chroma-key cleanup",
            },
            "terrain_prop_semantics": _terrain_prop_semantics(),
            "world_bounds": WORLD_BOUNDS,
            "player_spawn": [0, 0],
            "enemy_spawn_policy": {
                "type": "ring_around_player",
                "min_radius": 220,
                "max_radius": 460,
                "avoid_center_radius": 96,
            },
            "camera_bounds": CAMERA_BOUNDS,
        },
        "stages": stage_entries,
    }


def _build_tileset_metadata() -> dict:
    return {
        "tile_size": 32,
        "columns": 4,
        "tileset_size": 32,
        "atlas_size": [128, 128],
        "tiles": [
            {"index": 0, "name": "floor", "atlas_coords": [0, 0]},
            {"index": 1, "name": "floor_alt", "atlas_coords": [1, 0]},
            {"index": 2, "name": "obstacle", "atlas_coords": [2, 0]},
            {"index": 3, "name": "decoration", "atlas_coords": [3, 0]},
        ],
        "themes": [
            {
                "theme_id": stage["theme_id"],
                "theme_label": stage["theme_label"],
                "stage_index": stage["stage_index"],
                "stage_name": stage["stage_name"],
                "weather_id": stage["weather_id"],
                "tileset": f"res://assets/maps/{stage['theme_id']}/tileset.png",
                "room_background": f"res://assets/maps/{stage['theme_id']}/room_background.png",
                "terrain_props": f"res://assets/maps/{stage['theme_id']}/terrain_props.png",
            }
            for stage in STAGES
        ],
    }


def main() -> None:
    args = _parse_args()
    api_key = _api_key_from_env()
    try:
        use_remote = _should_use_remote(args, api_key)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)

    MAP_ROOT.mkdir(parents=True, exist_ok=True)
    stage_entries: list[dict] = []
    rendered_stages: list[dict] = []
    generated: list[Path] = []
    asset_sources: set[str] = set()

    for stage in STAGES:
        rng = random.Random(stage["stage_index"] * 7919)
        stage_dir = MAP_ROOT / stage["theme_id"]
        stage_dir.mkdir(parents=True, exist_ok=True)

        background, tileset, terrain_props, stage_asset_source = _make_visual_assets(
            stage,
            rng,
            use_remote=use_remote,
            api_key=api_key,
            args=args,
        )
        asset_sources.add(stage_asset_source)
        cells = _decorative_cells(stage, rng)

        bg_path = stage_dir / "room_background.png"
        tileset_path = stage_dir / "tileset.png"
        props_path = stage_dir / "terrain_props.png"
        preview_path = stage_dir / "qa_runtime_preview.png"

        generated.extend([bg_path, tileset_path, props_path, preview_path])
        entry = {
                "stage_index": stage["stage_index"],
                "theme_id": stage["theme_id"],
                "theme_label": stage["theme_label"],
                "stage_name": stage["stage_name"],
                "weather_id": stage["weather_id"],
                "tileset": f"res://assets/maps/{stage['theme_id']}/tileset.png",
                "room_background": f"res://assets/maps/{stage['theme_id']}/room_background.png",
                "terrain_props": f"res://assets/maps/{stage['theme_id']}/terrain_props.png",
                "qa_preview": f"res://assets/maps/{stage['theme_id']}/qa_runtime_preview.png",
                "floor_pattern": stage["floor_pattern"],
                "floor_atlas_coords": [0, 0],
                "floor_alt_atlas_coords": [1, 0],
                "obstacle_atlas_coords": [2, 0],
                "decoration_atlas_coords": [3, 0],
                "decoration_cells": cells,
                "prompt_files": {
                    "room_background": f"res://assets/maps/{stage['theme_id']}/room_background.prompt.txt",
                    "tileset": f"res://assets/maps/{stage['theme_id']}/tileset.prompt.txt",
                    "terrain_props": f"res://assets/maps/{stage['theme_id']}/terrain_props.prompt.txt",
                },
        }
        entry.update(_stage_runtime_hooks(stage))
        stage_entries.append(entry)
        rendered_stages.append({
            "stage": stage,
            "stage_dir": stage_dir,
            "background": background,
            "tileset": tileset,
            "terrain_props": terrain_props,
            "preview": _preview(background, stage, cells),
            "bg_path": bg_path,
            "tileset_path": tileset_path,
            "props_path": props_path,
            "preview_path": preview_path,
        })

    manifest_source = "ssstoken_gpt_image_2" if asset_sources == {"ssstoken_gpt_image_2"} else "procedural_fallback"
    for rendered in rendered_stages:
        rendered["background"].save(rendered["bg_path"])
        rendered["tileset"].save(rendered["tileset_path"])
        rendered["terrain_props"].save(rendered["props_path"])
        rendered["preview"].save(rendered["preview_path"])
        _write_prompt(rendered["stage_dir"], rendered["stage"])

    (MAP_ROOT / "runtime_scene_manifest.json").write_text(
        json.dumps(_build_runtime_manifest(stage_entries, manifest_source, args), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (MAP_ROOT / "tileset_metadata.json").write_text(
        json.dumps(_build_tileset_metadata(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    generated.extend([MAP_ROOT / "runtime_scene_manifest.json", MAP_ROOT / "tileset_metadata.json"])
    print(f"Generated {len(generated)} map files under {MAP_ROOT}")
    for path in generated:
        print(f"  {path.relative_to(GAME_ROOT)}")


if __name__ == "__main__":
    main()
