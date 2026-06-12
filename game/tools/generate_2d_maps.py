#!/usr/bin/env python3
"""Generate Godot 4 TileSet-compatible map assets per UIUX §9 stage themes."""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow is required: pip install Pillow", file=sys.stderr)
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
GAME_ROOT = SCRIPT_DIR.parent
OUTPUT_ROOT = GAME_ROOT / "assets" / "maps"

TILE_SIZE = 32
TILESET_COLS = 4
TILESET_SIZE = TILE_SIZE * TILESET_COLS  # 128
BG_WIDTH = 1280
BG_HEIGHT = 720

# UIUX §9 themes aligned with stages.csv (stage_index, stage_name, weather_id)
THEMES = [
    {
        "theme_id": "qi_refining_verdant",
        "theme_label": "炼气翠绿",
        "stage_index": 1,
        "stage_name": "初入仙途",
        "weather_id": "clear",
        "floor": (0x3A, 0x6B, 0x3A),
        "floor_alt": (0x4A, 0x7D, 0x48),
        "wall": (0x2A, 0x4F, 0x2C),
        "decoration": (0x7B, 0xC6, 0x7E),
        "bg_top": (0x1A, 0x2E, 0x1A),
        "bg_bottom": (0x5A, 0x8F, 0x5A),
        "accent": (0x7B, 0xC6, 0x7E),
        "pattern": "forest",
    },
    {
        "theme_id": "foundation_cavern",
        "theme_label": "筑基洞窟",
        "stage_index": 2,
        "stage_name": "秘境深处",
        "weather_id": "rain",
        "floor": (0x3A, 0x45, 0x52),
        "floor_alt": (0x4A, 0x58, 0x66),
        "wall": (0x28, 0x32, 0x3C),
        "decoration": (0x6A, 0xC8, 0xC4),
        "bg_top": (0x12, 0x18, 0x22),
        "bg_bottom": (0x3A, 0x5A, 0x62),
        "accent": (0x4E, 0xCD, 0xC4),
        "pattern": "stone",
    },
    {
        "theme_id": "golden_core_demon",
        "theme_label": "金丹魔域",
        "stage_index": 3,
        "stage_name": "渡劫前夕",
        "weather_id": "thunder",
        "floor": (0x2A, 0x1E, 0x38),
        "floor_alt": (0x3A, 0x28, 0x48),
        "wall": (0x18, 0x10, 0x28),
        "decoration": (0xA8, 0x55, 0xF7),
        "bg_top": (0x0A, 0x06, 0x14),
        "bg_bottom": (0x3A, 0x1A, 0x50),
        "accent": (0xB5, 0x7E, 0xDC),
        "pattern": "vignette",
    },
    {
        "theme_id": "nascent_soul_ruins",
        "theme_label": "元婴遗迹",
        "stage_index": 4,
        "stage_name": "焚心秘域",
        "weather_id": "fire",
        "floor": (0x3A, 0x32, 0x28),
        "floor_alt": (0x4A, 0x40, 0x34),
        "wall": (0x28, 0x22, 0x1A),
        "decoration": (0xFF, 0xD7, 0x00),
        "bg_top": (0x14, 0x10, 0x0C),
        "bg_bottom": (0x4A, 0x3A, 0x22),
        "accent": (0xF0, 0xD6, 0x8A),
        "pattern": "gold_lines",
    },
    {
        "theme_id": "tribulation_thunder",
        "theme_label": "渡劫雷劫",
        "stage_index": 5,
        "stage_name": "天劫试场",
        "weather_id": "wind",
        "floor": (0x2A, 0x2A, 0x38),
        "floor_alt": (0x3A, 0x3A, 0x4A),
        "wall": (0x18, 0x18, 0x28),
        "decoration": (0xFF, 0xD7, 0x00),
        "bg_top": (0x08, 0x08, 0x18),
        "bg_bottom": (0x2A, 0x2A, 0x50),
        "accent": (0xFF, 0xD7, 0x00),
        "pattern": "thunder",
    },
]

TILE_NAMES = ("floor", "floor_alt", "wall", "decoration")


def _clamp(v: int) -> int:
    return max(0, min(255, v))


def _vary(color: tuple[int, int, int], delta: int, rng: random.Random) -> tuple[int, int, int]:
    return tuple(_clamp(c + rng.randint(-delta, delta)) for c in color)


def _fill_noise(img: Image.Image, base: tuple[int, int, int], rng: random.Random, strength: int = 18) -> None:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            px[x, y] = _vary(base, strength, rng) + (255,)


def _draw_floor_tile(img: Image.Image, draw: ImageDraw.ImageDraw, theme: dict, rng: random.Random, alt: bool = False) -> None:
    base = theme["floor_alt"] if alt else theme["floor"]
    _fill_noise(img, base, rng, 14)
    if theme["pattern"] == "forest":
        for _ in range(6 if alt else 4):
            x, y = rng.randint(2, 28), rng.randint(2, 28)
            draw.ellipse((x, y, x + 3, y + 3), fill=_vary(theme["accent"], 8, rng))
    elif theme["pattern"] == "stone":
        for _ in range(5):
            x1, y1 = rng.randint(0, 24), rng.randint(0, 24)
            draw.rectangle((x1, y1, x1 + rng.randint(4, 10), y1 + rng.randint(3, 8)), outline=_vary(base, 20, rng))
    elif theme["pattern"] in ("vignette", "gold_lines", "thunder"):
        for _ in range(4):
            x, y = rng.randint(0, 30), rng.randint(0, 30)
            draw.point((x, y), fill=_vary(base, 25, rng))


def _draw_wall_tile(img: Image.Image, draw: ImageDraw.ImageDraw, theme: dict, rng: random.Random) -> None:
    base = theme["wall"]
    _fill_noise(img, base, rng, 12)
    draw.rectangle((0, 0, 31, 31), outline=_vary(theme["accent"], 10, rng), width=2)
    for i in range(0, 32, 8):
        draw.line((i, 0, i, 31), fill=_vary(base, 15, rng), width=1)
        draw.line((0, i, 31, i), fill=_vary(base, 15, rng), width=1)


def _draw_decoration_tile(img: Image.Image, draw: ImageDraw.ImageDraw, theme: dict, rng: random.Random) -> None:
    base = theme["floor"]
    _fill_noise(img, base, rng, 10)
    accent = theme["decoration"]
    pattern = theme["pattern"]
    if pattern == "forest":
        draw.polygon([(8, 28), (16, 8), (24, 28)], fill=accent)
        draw.rectangle((14, 24, 18, 28), fill=_vary(theme["wall"], 5, rng))
    elif pattern == "stone":
        draw.ellipse((10, 10, 22, 22), fill=accent, outline=_vary(accent, 20, rng))
        draw.line((16, 6, 16, 26), fill=_vary(accent, 15, rng), width=1)
    elif pattern == "vignette":
        for _ in range(10):
            x, y = rng.randint(4, 27), rng.randint(4, 27)
            draw.ellipse((x, y, x + 2, y + 2), fill=accent)
    elif pattern == "gold_lines":
        draw.line((4, 16, 28, 16), fill=accent, width=2)
        draw.line((16, 4, 16, 28), fill=_vary(accent, 8, rng), width=1)
        draw.arc((8, 8, 24, 24), 0, 180, fill=accent, width=1)
    elif pattern == "thunder":
        draw.polygon([(16, 6), (20, 14), (17, 14), (22, 26), (14, 16), (17, 16)], fill=accent)


def generate_tileset(theme: dict, rng: random.Random) -> Image.Image:
    sheet = Image.new("RGBA", (TILESET_SIZE, TILESET_SIZE), (0, 0, 0, 0))
    for index, name in enumerate(TILE_NAMES):
        tile = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 255))
        draw = ImageDraw.Draw(tile)
        if name == "floor":
            _draw_floor_tile(tile, draw, theme, rng, alt=False)
        elif name == "floor_alt":
            _draw_floor_tile(tile, draw, theme, rng, alt=True)
        elif name == "wall":
            _draw_wall_tile(tile, draw, theme, rng)
        else:
            _draw_decoration_tile(tile, draw, theme, rng)
        sheet.paste(tile, (index * TILE_SIZE, 0))
    return sheet


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def _gradient_background(theme: dict) -> Image.Image:
    img = Image.new("RGB", (BG_WIDTH, BG_HEIGHT))
    top, bottom = theme["bg_top"], theme["bg_bottom"]
    px = img.load()
    for y in range(BG_HEIGHT):
        t = y / (BG_HEIGHT - 1)
        row_color = tuple(_lerp(top[i], bottom[i], t) for i in range(3))
        for x in range(BG_WIDTH):
            px[x, y] = row_color
    return img


def _apply_texture(img: Image.Image, theme: dict, rng: random.Random) -> Image.Image:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    accent = theme["accent"]
    pattern = theme["pattern"]

    if pattern == "forest":
        for _ in range(120):
            x, y = rng.randint(0, BG_WIDTH - 1), rng.randint(0, BG_HEIGHT - 1)
            alpha = rng.randint(8, 28)
            r = rng.randint(20, 60)
            draw.ellipse((x, y, x + r, y + r), fill=(*accent, alpha))
    elif pattern == "stone":
        for _ in range(80):
            x1 = rng.randint(0, BG_WIDTH - 40)
            y1 = rng.randint(0, BG_HEIGHT - 30)
            w, h = rng.randint(30, 120), rng.randint(20, 80)
            draw.rectangle((x1, y1, x1 + w, y1 + h), outline=(*accent, rng.randint(10, 25)), width=1)
    elif pattern == "vignette":
        cx, cy = BG_WIDTH // 2, BG_HEIGHT // 2
        max_r = math.hypot(cx, cy)
        for y in range(0, BG_HEIGHT, 4):
            for x in range(0, BG_WIDTH, 4):
                d = math.hypot(x - cx, y - cy) / max_r
                alpha = int(90 * (d ** 1.6))
                if alpha > 0:
                    draw.rectangle((x, y, x + 3, y + 3), fill=(*theme["decoration"], min(alpha, 80)))
    elif pattern == "gold_lines":
        for x in range(0, BG_WIDTH, 160):
            draw.line((x, 0, x + 40, BG_HEIGHT), fill=(*accent, 18), width=1)
        for y in range(80, BG_HEIGHT, 120):
            draw.line((0, y, BG_WIDTH, y + 20), fill=(*accent, 14), width=1)
    elif pattern == "thunder":
        for _ in range(6):
            x = rng.randint(100, BG_WIDTH - 100)
            pts = [(x, 0)]
            cy = 0
            while cy < BG_HEIGHT:
                cy += rng.randint(40, 90)
                x += rng.randint(-50, 50)
                pts.append((x, min(cy, BG_HEIGHT)))
            draw.line(pts, fill=(*accent, rng.randint(12, 35)), width=rng.randint(1, 2))

    noise = Image.effect_noise(img.size, 12).convert("L")
    noise_rgba = Image.merge("RGBA", (noise, noise, noise, noise.point(lambda v: int(v * 0.08))))
    composed = Image.alpha_composite(img.convert("RGBA"), overlay)
    composed = Image.alpha_composite(composed, noise_rgba)
    return composed.convert("RGB")


def generate_room_background(theme: dict, rng: random.Random) -> Image.Image:
    base = _gradient_background(theme)
    return _apply_texture(base, theme, rng)


def build_metadata() -> dict:
    return {
        "tile_size": TILE_SIZE,
        "columns": TILESET_COLS,
        "tileset_size": TILE_SIZE,
        "atlas_size": [TILESET_SIZE, TILESET_SIZE],
        "tiles": [
            {"index": i, "name": name, "atlas_coords": [i, 0]}
            for i, name in enumerate(TILE_NAMES)
        ],
        "themes": [
            {
                "theme_id": t["theme_id"],
                "theme_label": t["theme_label"],
                "stage_index": t["stage_index"],
                "stage_name": t["stage_name"],
                "weather_id": t["weather_id"],
                "tileset": f"res://assets/maps/{t['theme_id']}/tileset.png",
                "room_background": f"res://assets/maps/{t['theme_id']}/room_background.png",
            }
            for t in THEMES
        ],
    }


def main() -> list[Path]:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    generated: list[Path] = []

    for theme in THEMES:
        theme_dir = OUTPUT_ROOT / theme["theme_id"]
        theme_dir.mkdir(parents=True, exist_ok=True)
        rng = random.Random(theme["stage_index"] * 1009)

        tileset_path = theme_dir / "tileset.png"
        generate_tileset(theme, rng).save(tileset_path)
        generated.append(tileset_path)

        bg_path = theme_dir / "room_background.png"
        generate_room_background(theme, rng).save(bg_path)
        generated.append(bg_path)

    meta_path = OUTPUT_ROOT / "tileset_metadata.json"
    meta_path.write_text(
        json.dumps(build_metadata(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    generated.append(meta_path)

    print(f"Generated {len(generated)} files under {OUTPUT_ROOT}")
    for path in generated:
        print(f"  {path.relative_to(GAME_ROOT)}")
    return generated


if __name__ == "__main__":
    main()
