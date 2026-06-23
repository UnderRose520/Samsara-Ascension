#!/usr/bin/env python3
"""Generate a unified dark-ink xianxia visual slice for runtime assets.

This is a deterministic first-pass unification layer. It keeps existing
runtime filenames intact so Godot picks up the assets immediately, while
prompt files beside the assets define the later image-generation target.
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parent
UI_ROOT = ROOT / "assets" / "ui"
HUD_ROOT = UI_ROOT / "hud"
SPRITE_ROOT = ROOT / "assets" / "sprites"
FRAME_ROOT = SPRITE_ROOT / "frames"
MAP_ROOT = ROOT / "assets" / "maps"
OUT_ROOT = REPO_ROOT / "output" / "visual_style"

BG_SIZE = (1280, 720)
TAU = math.tau

INK = {
    "black": (6, 9, 10),
    "deep": (9, 18, 18),
    "panel": (13, 38, 34),
    "jade": (42, 146, 130),
    "jade_soft": (96, 205, 178),
    "gold": (196, 168, 106),
    "paper": (218, 226, 216),
    "ash": (87, 98, 98),
    "fire": (242, 89, 38),
    "water": (76, 202, 220),
    "thunder": (97, 155, 255),
    "wood": (84, 218, 124),
    "earth": (205, 162, 83),
    "chaos": (205, 80, 224),
    "soul": (151, 98, 238),
}


STAGE_STYLES = {
    "qi_refining_verdant": {
        "label": "炼气翠林",
        "base": (10, 31, 27),
        "mid": (20, 66, 51),
        "accent": INK["wood"],
        "secondary": INK["jade_soft"],
        "marks": "low jade moss veins and brushy spirit-grass stains",
    },
    "foundation_cavern": {
        "label": "筑基灵窟",
        "base": (8, 27, 33),
        "mid": (22, 61, 68),
        "accent": INK["water"],
        "secondary": INK["jade"],
        "marks": "wet stone washes and embedded jade mineral veins",
    },
    "golden_core_demon": {
        "label": "金丹魔域",
        "base": (23, 13, 24),
        "mid": (58, 30, 47),
        "accent": INK["chaos"],
        "secondary": INK["fire"],
        "marks": "blackened demon qi scars and restrained ember cracks",
    },
    "nascent_soul_ruins": {
        "label": "元婴遗墟",
        "base": (18, 23, 29),
        "mid": (54, 61, 63),
        "accent": INK["gold"],
        "secondary": INK["water"],
        "marks": "moonlit worn ruin stone and broken cold-gold formation lines",
    },
    "tribulation_thunder": {
        "label": "天劫雷台",
        "base": (10, 14, 25),
        "mid": (36, 47, 65),
        "accent": INK["thunder"],
        "secondary": INK["gold"],
        "marks": "storm-dark slate with blue thunder veins and cold-gold scars",
    },
}


ENEMY_SPECS = {
    "wild_wolf": {
        "display": "妖狼",
        "shape": "wolf",
        "accent": INK["wood"],
        "secondary": INK["jade_soft"],
        "prompt": "low crouching four-legged yao wolf, pointed ears, arched back, claw and fang threat silhouette",
    },
    "crossbow_cultivator": {
        "display": "弩修",
        "shape": "crossbow",
        "accent": INK["thunder"],
        "secondary": INK["gold"],
        "prompt": "lean rogue cultivator with hat and horizontal cloud crossbow, clear ranged silhouette",
    },
    "shield_guard": {
        "display": "护阵者",
        "shape": "shield",
        "accent": INK["earth"],
        "secondary": INK["jade_soft"],
        "prompt": "heavy formation guard with huge xuanwu shield covering the front, protector silhouette",
    },
    "sky_bat": {
        "display": "腐翼妖蝠",
        "shape": "bat",
        "accent": INK["soul"],
        "secondary": INK["thunder"],
        "prompt": "small flying corrupted bat with wide torn ink wings and glowing mouth threat",
    },
    "mud_serpent": {
        "display": "泥泽游蛇",
        "shape": "serpent",
        "accent": INK["earth"],
        "secondary": INK["water"],
        "prompt": "low S-shaped mud serpent, broad head, wet clay ridges and poison-mud mouth",
    },
    "wind_mantis": {
        "display": "风刃螳螂",
        "shape": "mantis",
        "accent": INK["wood"],
        "secondary": INK["thunder"],
        "prompt": "tall forward-leaning mantis yao with oversized sickle arms and cyan wind blade edges",
    },
    "furnace_golem": {
        "display": "火纹傀儡",
        "shape": "furnace",
        "accent": INK["fire"],
        "secondary": INK["gold"],
        "prompt": "stocky walking alchemy furnace golem, round furnace body, short stone arms, ember core",
    },
}


SPELL_ICONS = {
    "spell_q_fire_talisman_96.png": ("fire", "flame talisman bolt", "talisman"),
    "spell_e_jade_sword_array_96.png": ("thunder", "jade sword array", "sword"),
    "spell_r_thunder_fan_96.png": ("thunder", "thunder ice folding fan", "fan"),
    "spell_locked_jade_seal_96.png": ("jade", "sealed jade lock", "seal"),
    "spell_lie_yan_bolt_96.png": ("fire", "compact flame talisman bolt", "talisman"),
    "spell_yu_jian_thrust_96.png": ("water", "single jade sword thrust", "sword"),
    "spell_qi_fu_96.png": ("earth", "qi protection talisman", "seal"),
    "spell_summon_soul_96.png": ("chaos", "soul summoning lantern", "orb"),
    "spell_lei_chi_strike_96.png": ("thunder", "thunder pool strike", "bolt"),
    "spell_lei_chi_chain_96.png": ("thunder", "thunder chain", "chain"),
    "spell_xuan_bing_fan_96.png": ("water", "black ice folding fan", "fan"),
    "spell_xuan_bing_lance_96.png": ("water", "black ice lance", "spear"),
    "spell_hui_chun_jue_96.png": ("wood", "spring revival leaf seal", "leaf"),
}


PROMPT_HEADER = """Unified runtime art target for Samsara Ascension.
Style: 2D dark Chinese ink xianxia, black jade base, cold jade rim light, restrained old gold linework, high-saturation five-element particles only on gameplay signal parts.
Avoid: western fantasy, Diablo-like dark item render, photorealism, anime portrait mismatch, beige parchment dominance, purple-only palette, UI text, labels, watermark.
"""


@dataclass
class ActorStyle:
    slug: str
    kind: str
    accent: tuple[int, int, int]
    secondary: tuple[int, int, int]
    shape: str
    size: int
    prompt: str


def rgba(color: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return (color[0], color[1], color[2], alpha)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ensure_dirs() -> None:
    for path in (UI_ROOT, HUD_ROOT, SPRITE_ROOT, FRAME_ROOT, MAP_ROOT, OUT_ROOT):
        path.mkdir(parents=True, exist_ok=True)


def draw_glow_line(
    img: Image.Image,
    points: list[tuple[float, float]],
    color: tuple[int, int, int],
    *,
    width: int = 2,
    alpha: int = 150,
    blur: int = 6,
) -> None:
    if len(points) < 2:
        return
    if blur > 0:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).line(points, fill=rgba(color, max(20, alpha // 2)), width=width + blur, joint="curve")
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(max(1, blur // 2))))
    line = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(line).line(points, fill=rgba(color, alpha), width=width, joint="curve")
    img.alpha_composite(line)


def draw_ink_blob(
    img: Image.Image,
    center: tuple[float, float],
    radius: tuple[float, float],
    color: tuple[int, int, int],
    *,
    alpha: int,
    rng: random.Random,
    points: int = 18,
    blur: int = 0,
) -> None:
    cx, cy = center
    rx, ry = radius
    pts: list[tuple[float, float]] = []
    for i in range(points):
        angle = TAU * i / points
        wobble = rng.uniform(0.72, 1.22)
        pts.append((cx + math.cos(angle) * rx * wobble, cy + math.sin(angle) * ry * wobble))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=rgba(color, alpha))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)


def draw_vignette(img: Image.Image, alpha: int = 110) -> None:
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    for i in range(170):
        a = int(alpha * (i / 170) ** 1.25)
        draw.rectangle((i, int(i * 0.55), w - i, h - int(i * 0.55)), outline=a, width=2)
    dark = Image.new("RGBA", (w, h), rgba(INK["black"], 0))
    dark.putalpha(mask.filter(ImageFilter.GaussianBlur(10)))
    img.alpha_composite(dark)


def make_map_background(stage_id: str, info: dict) -> Image.Image:
    rng = random.Random(f"unified-map-{stage_id}")
    w, h = BG_SIZE
    img = Image.new("RGBA", BG_SIZE, rgba(info["base"]))
    draw = ImageDraw.Draw(img)

    for y in range(h):
        t = y / (h - 1)
        row = mix(info["base"], info["mid"], 0.25 + t * 0.55)
        draw.line((0, y, w, y), fill=rgba(row))

    for _ in range(10):
        cx = rng.randrange(-80, w + 80)
        cy = rng.randrange(40, h - 30)
        rx = rng.randrange(170, 420)
        ry = rng.randrange(38, 116)
        color = mix(info["base"], info["mid"], rng.uniform(0.45, 0.9))
        draw_ink_blob(img, (cx, cy), (rx, ry), color, alpha=rng.randrange(28, 72), rng=rng, points=16, blur=rng.randrange(12, 28))

    # Quiet center for gameplay readability.
    center = Image.new("RGBA", BG_SIZE, rgba(mix(info["base"], info["mid"], 0.55), 0))
    cdraw = ImageDraw.Draw(center)
    cdraw.ellipse((250, 145, 1030, 585), fill=rgba(mix(info["base"], info["mid"], 0.72), 78))
    img.alpha_composite(center.filter(ImageFilter.GaussianBlur(46)))

    # Low ground brush strokes and qi veins, mostly at edges.
    for _ in range(46):
        edge_bias = rng.choice(["top", "bottom", "left", "right", "any"])
        if edge_bias == "top":
            x = rng.randrange(40, w - 40)
            y = rng.randrange(40, 190)
        elif edge_bias == "bottom":
            x = rng.randrange(40, w - 40)
            y = rng.randrange(h - 190, h - 45)
        elif edge_bias == "left":
            x = rng.randrange(35, 240)
            y = rng.randrange(70, h - 70)
        elif edge_bias == "right":
            x = rng.randrange(w - 240, w - 35)
            y = rng.randrange(70, h - 70)
        else:
            x = rng.randrange(120, w - 120)
            y = rng.randrange(90, h - 90)
            if ((x - w / 2) ** 2 / (320**2) + (y - h / 2) ** 2 / (170**2)) < 1:
                continue
        length = rng.randrange(48, 160)
        angle = rng.uniform(-0.55, 0.55) + rng.choice([0, math.pi * 0.08, -math.pi * 0.08])
        pts = []
        for step in range(5):
            pts.append((
                x + math.cos(angle) * length * step / 4 + rng.randrange(-12, 13),
                y + math.sin(angle) * length * step / 4 + rng.randrange(-10, 11),
            ))
        color = info["accent"] if rng.random() < 0.65 else info["secondary"]
        draw_glow_line(img, pts, color, width=rng.randrange(1, 4), alpha=rng.randrange(45, 110), blur=rng.randrange(4, 12))

    # Old-gold hairlines, sparse and non-UI-like.
    for _ in range(13):
        x = rng.randrange(80, w - 80)
        y = rng.randrange(60, h - 60)
        if ((x - w / 2) ** 2 / (280**2) + (y - h / 2) ** 2 / (145**2)) < 1:
            continue
        pts = [(x + rng.randrange(-18, 19) * i, y + rng.randrange(-10, 11) * i) for i in range(4)]
        draw_glow_line(img, pts, INK["gold"], width=1, alpha=rng.randrange(35, 70), blur=4)

    noise = Image.effect_noise(BG_SIZE, 18).convert("L")
    noise_rgba = Image.merge("RGBA", (noise, noise, noise, noise.point(lambda v: int(v * 0.035))))
    img.alpha_composite(noise_rgba)
    draw_vignette(img, 120)
    return img.convert("RGB")


def make_tileset(info: dict) -> Image.Image:
    rng = random.Random(str(info["label"]) + "-tiles")
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    colors = [
        info["base"],
        mix(info["base"], info["mid"], 0.65),
        mix(info["base"], INK["black"], 0.38),
        mix(info["mid"], info["accent"], 0.18),
    ]
    for ty in range(4):
        for tx in range(4):
            c = colors[(tx + ty) % len(colors)]
            x0, y0 = tx * 32, ty * 32
            for y in range(32):
                for x in range(32):
                    n = rng.randrange(-7, 8)
                    draw.point((x0 + x, y0 + y), fill=rgba(tuple(max(0, min(255, v + n)) for v in c)))
            if tx == 2 and ty == 0:
                draw.rounded_rectangle((x0 + 6, y0 + 6, x0 + 27, y0 + 27), radius=6, fill=rgba(mix(c, INK["black"], 0.35)), outline=rgba(info["secondary"], 180), width=1)
            elif tx == 3 and ty == 0:
                draw_glow_line(img, [(x0 + 5, y0 + 23), (x0 + 15, y0 + 11), (x0 + 27, y0 + 18)], info["accent"], width=2, alpha=160, blur=3)
    return img


def make_terrain_props(info: dict) -> Image.Image:
    rng = random.Random(str(info["label"]) + "-props")
    img = Image.new("RGBA", (384, 384), (255, 0, 255, 0))
    for i in range(9):
        col, row = i % 3, i // 3
        x0, y0 = col * 128, row * 128
        cx, cy = x0 + 64 + rng.randrange(-6, 7), y0 + 64 + rng.randrange(-6, 7)
        if col == 0:
            pts = [(cx - 42 + k * 22, cy + rng.randrange(-12, 13)) for k in range(5)]
            draw_glow_line(img, pts, info["accent"], width=3, alpha=160, blur=8)
            draw_glow_line(img, pts, INK["black"], width=1, alpha=120, blur=0)
        elif col == 1:
            for _ in range(8):
                dx = rng.randrange(-28, 29)
                dy = rng.randrange(-18, 19)
                draw_glow_line(img, [(cx + dx, cy + dy + 14), (cx + dx + rng.randrange(-7, 8), cy + dy - rng.randrange(8, 22))], info["secondary"], width=2, alpha=140, blur=2)
        else:
            draw_ink_blob(img, (cx, cy), (rng.randrange(20, 34), rng.randrange(12, 24)), mix(info["base"], INK["black"], 0.35), alpha=230, rng=rng, points=9, blur=0)
            draw_glow_line(img, [(cx - 18, cy), (cx + 18, cy + rng.randrange(-4, 5))], info["secondary"], width=1, alpha=90, blur=2)
    return img


def write_maps() -> None:
    reference_base = OUT_ROOT / "runtime_map_style_base.png"
    source_candidates = [
        REPO_ROOT / "output" / "imagegen" / "dark_ink_particle_maps" / "thunderstorm_ink_particle_arena_1280x720.png",
        REPO_ROOT / "output" / "imagegen" / "dark_ink_particle_maps" / "storm_inkwash_brush_arena_dark_clear_localgrade_1280x720.png",
        REPO_ROOT / "output" / "imagegen" / "dark_ink_particle_maps" / "storm_inkwash_brush_arena_stronger_1280x720.png",
    ]
    source_base = next((path for path in source_candidates if path.exists()), None)
    if source_base:
        base_img = ImageOps.fit(Image.open(source_base).convert("RGB"), BG_SIZE, method=Image.Resampling.LANCZOS)
        reference_base.parent.mkdir(parents=True, exist_ok=True)
        base_img.save(reference_base)
    else:
        base_img = None
    for stage_id, info in STAGE_STYLES.items():
        stage_dir = MAP_ROOT / stage_id
        stage_dir.mkdir(parents=True, exist_ok=True)
        if base_img is not None:
            room_background = stylize_reference_map(base_img, stage_id, info)
        else:
            room_background = make_map_background(stage_id, info)
        room_background.save(stage_dir / "room_background.png")
        make_tileset(info).save(stage_dir / "tileset.png")
        make_terrain_props(info).save(stage_dir / "terrain_props.png")
        room_background.save(stage_dir / "qa_runtime_preview.png")
        prompt = (
            PROMPT_HEADER
            + f"\nAsset: foundation-only runtime combat map for {info['label']} ({stage_id}).\n"
            + f"Map marks: {info['marks']}.\n"
            + "Exact target: 1280x720 top-down battle background. Center 60 percent must remain low-noise and playable; edges carry ink atmosphere.\n"
        )
        (stage_dir / "room_background.prompt.txt").write_text(prompt, encoding="utf-8")
        (stage_dir / "tileset.prompt.txt").write_text(prompt + "\nTileset target: 4x4 32px top-down floor/blocker/deco tiles in the same style.\n", encoding="utf-8")
        (stage_dir / "terrain_props.prompt.txt").write_text(prompt + "\nTerrain prop target: 3x3 transparent low-ground detail atlas, no tall props.\n", encoding="utf-8")


def stylize_reference_map(base_img: Image.Image, stage_id: str, info: dict) -> Image.Image:
    rng = random.Random(f"stylize-reference-{stage_id}")
    src = ImageOps.fit(base_img.convert("RGB"), BG_SIZE, method=Image.Resampling.LANCZOS)
    gray = ImageOps.grayscale(src)
    # Keep the richer image2 brushwork, but pull it into the shared ink palette.
    dark = Image.new("RGB", BG_SIZE, info["base"])
    mid = Image.new("RGB", BG_SIZE, info["mid"])
    colorized = ImageOps.colorize(gray, black=info["base"], white=mix(info["mid"], INK["paper"], 0.22), mid=info["mid"], blackpoint=5, whitepoint=238, midpoint=132)
    blended = Image.blend(Image.blend(dark, mid, 0.45), colorized, 0.74).convert("RGBA")
    overlay = Image.new("RGBA", BG_SIZE, (0, 0, 0, 0))
    # Center readability wash.
    center = Image.new("RGBA", BG_SIZE, (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(center)
    cdraw.ellipse((265, 142, 1015, 574), fill=rgba(mix(info["base"], info["mid"], 0.72), 90))
    overlay.alpha_composite(center.filter(ImageFilter.GaussianBlur(58)))
    # Element identity at the edges and low cracks.
    for _ in range(34):
        x = rng.randrange(40, BG_SIZE[0] - 40)
        y = rng.randrange(40, BG_SIZE[1] - 40)
        if ((x - 640) ** 2 / (360**2) + (y - 360) ** 2 / (170**2)) < 1:
            if rng.random() < 0.78:
                continue
        length = rng.randrange(38, 132)
        angle = rng.uniform(-0.85, 0.85)
        pts = [
            (
                x + math.cos(angle) * length * t / 3 + rng.randrange(-11, 12),
                y + math.sin(angle) * length * t / 3 + rng.randrange(-9, 10),
            )
            for t in range(4)
        ]
        draw_glow_line(overlay, pts, info["accent"] if rng.random() < 0.72 else info["secondary"], width=rng.randrange(1, 4), alpha=rng.randrange(48, 116), blur=rng.randrange(4, 10))
    # Dark ink vignette harmonizes all stage variants.
    blended.alpha_composite(overlay)
    draw_vignette(blended, 130)
    return blended.convert("RGB")


def draw_actor_shape(draw: ImageDraw.ImageDraw, style: ActorStyle, frame: str, index: int, scale: float = 1.0) -> None:
    s = style.size
    cx = s / 2
    cy = s / 2 + (3 if style.kind == "pet" else 6)
    wobble = math.sin(index / 4 * TAU) * 2
    accent = rgba(style.accent, 235)
    secondary = rgba(style.secondary, 210)
    dark = rgba(INK["deep"], 245)
    outline = rgba(INK["black"], 245)
    gold = rgba(INK["gold"], 220)

    def pts(items: Iterable[tuple[float, float]]) -> list[tuple[float, float]]:
        return [(cx + x * scale, cy + y * scale + wobble) for x, y in items]

    shape = style.shape
    if shape in {"player", "cultivator"}:
        draw.ellipse((cx - 10, cy - 28 + wobble, cx + 10, cy - 8 + wobble), fill=dark, outline=gold, width=1)
        draw.polygon(pts([(-12, -10), (0, -20), (13, -9), (10, 17), (0, 25), (-11, 17)]), fill=rgba((214, 224, 214), 235), outline=outline)
        draw.line((cx - 2, cy - 14 + wobble, cx - 4, cy + 18 + wobble), fill=rgba(style.accent, 220), width=max(1, int(2 * scale)))
        draw.line((cx + 12, cy - 4 + wobble, cx + 26, cy - 18 + wobble), fill=secondary, width=max(2, int(3 * scale)))
        draw.line((cx + 16, cy - 1 + wobble, cx + 27, cy - 15 + wobble), fill=rgba((255, 255, 255), 170), width=1)
    elif shape == "pet":
        r = 8 * scale
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgba(style.accent, 230), outline=gold, width=1)
        draw.ellipse((cx - r * 1.5, cy - r * 0.2, cx - r * 0.2, cy + r * 0.9), fill=rgba(style.secondary, 88))
        draw.ellipse((cx + r * 0.2, cy - r * 0.2, cx + r * 1.5, cy + r * 0.9), fill=rgba(style.secondary, 88))
        draw.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=rgba((255, 244, 190), 245))
    elif shape == "wolf":
        draw.polygon(pts([(-25, 6), (-18, -9), (2, -13), (20, -5), (25, 7), (12, 13), (-12, 14)]), fill=dark, outline=outline)
        draw.polygon(pts([(13, -10), (20, -23), (24, -5)]), fill=dark, outline=outline)
        draw.polygon(pts([(-22, 2), (-34, -2), (-27, 10)]), fill=dark, outline=outline)
        draw.line((cx + 17, cy - 4 + wobble, cx + 28, cy - 14 + wobble), fill=accent, width=2)
        draw.line((cx - 20, cy + 10 + wobble, cx - 31, cy + 18 + wobble), fill=secondary, width=2)
    elif shape == "crossbow":
        draw.ellipse((cx - 8, cy - 25 + wobble, cx + 8, cy - 9 + wobble), fill=dark, outline=gold)
        draw.polygon(pts([(-12, -10), (9, -13), (14, 13), (0, 23), (-12, 12)]), fill=dark, outline=outline)
        draw.line((cx - 27, cy - 12 + wobble, cx + 27, cy - 12 + wobble), fill=secondary, width=4)
        draw.line((cx - 20, cy - 19 + wobble, cx + 20, cy - 5 + wobble), fill=accent, width=1)
        draw.line((cx + 6, cy - 12 + wobble, cx + 28, cy - 20 + wobble), fill=accent, width=2)
    elif shape == "shield":
        draw.polygon(pts([(-18, -18), (18, -18), (23, 5), (0, 28), (-23, 5)]), fill=rgba(mix(style.accent, INK["black"], 0.45), 245), outline=gold)
        draw.arc((cx - 17, cy - 14 + wobble, cx + 17, cy + 18 + wobble), 200, 340, fill=secondary, width=2)
        draw.ellipse((cx - 5, cy - 1 + wobble, cx + 5, cy + 9 + wobble), fill=accent)
        draw.rectangle((cx - 7, cy + 21 + wobble, cx + 7, cy + 27 + wobble), fill=dark)
    elif shape == "bat":
        draw.ellipse((cx - 9, cy - 7 + wobble, cx + 9, cy + 12 + wobble), fill=dark, outline=outline)
        draw.polygon(pts([(-8, -4), (-31, -21), (-26, 8), (-13, 4)]), fill=rgba(mix(style.accent, INK["black"], 0.55), 220), outline=secondary)
        draw.polygon(pts([(8, -4), (31, -21), (26, 8), (13, 4)]), fill=rgba(mix(style.accent, INK["black"], 0.55), 220), outline=secondary)
        draw.ellipse((cx - 3, cy - 2 + wobble, cx + 3, cy + 4 + wobble), fill=accent)
    elif shape == "serpent":
        points = pts([(-28, 10), (-14, -5), (2, 7), (16, -7), (28, 2)])
        draw.line(points, fill=rgba(mix(style.accent, INK["black"], 0.38), 245), width=12, joint="curve")
        draw.line(points, fill=secondary, width=3, joint="curve")
        draw.ellipse((cx + 19, cy - 11 + wobble, cx + 35, cy + 5 + wobble), fill=dark, outline=gold)
    elif shape == "mantis":
        draw.ellipse((cx - 8, cy - 22 + wobble, cx + 8, cy - 8 + wobble), fill=dark, outline=secondary)
        draw.polygon(pts([(-8, -5), (8, -7), (6, 22), (-6, 22)]), fill=rgba(mix(style.accent, INK["black"], 0.55), 235), outline=outline)
        draw.line((cx - 9, cy - 4 + wobble, cx - 30, cy - 25 + wobble), fill=accent, width=4)
        draw.line((cx + 9, cy - 4 + wobble, cx + 30, cy - 25 + wobble), fill=accent, width=4)
        draw.line((cx - 4, cy + 18 + wobble, cx - 18, cy + 30 + wobble), fill=secondary, width=2)
        draw.line((cx + 4, cy + 18 + wobble, cx + 18, cy + 30 + wobble), fill=secondary, width=2)
    elif shape == "furnace":
        draw.rounded_rectangle((cx - 19, cy - 22 + wobble, cx + 19, cy + 18 + wobble), radius=12, fill=dark, outline=gold, width=1)
        draw.ellipse((cx - 12, cy - 9 + wobble, cx + 12, cy + 15 + wobble), fill=rgba(mix(style.accent, INK["black"], 0.1), 220))
        draw.line((cx - 25, cy - 3 + wobble, cx - 38, cy + 9 + wobble), fill=rgba(mix(style.secondary, INK["black"], 0.25), 230), width=6)
        draw.line((cx + 25, cy - 3 + wobble, cx + 38, cy + 9 + wobble), fill=rgba(mix(style.secondary, INK["black"], 0.25), 230), width=6)
        draw.line((cx - 8, cy - 18 + wobble, cx + 8, cy - 18 + wobble), fill=style.accent, width=2)
    else:
        draw.ellipse((cx - 16, cy - 24 + wobble, cx + 16, cy + 20 + wobble), fill=dark, outline=gold, width=1)
        draw.line((cx - 18, cy - 10 + wobble, cx + 18, cy - 10 + wobble), fill=accent, width=3)

    if frame == "combat":
        a = 0.45 + index * 0.12
        ex = math.cos(a) * 24 * scale
        ey = math.sin(a) * 12 * scale
        draw.arc((cx - 28 * scale + ex * 0.15, cy - 28 * scale + ey * 0.15, cx + 28 * scale + ex * 0.15, cy + 28 * scale + ey * 0.15), 215, 315, fill=rgba(style.accent, 190), width=max(1, int(2 * scale)))
    elif frame == "walk":
        draw.ellipse((cx - 18 * scale, cy + 24 * scale + wobble, cx + 18 * scale, cy + 28 * scale + wobble), fill=rgba(style.accent, 48))
    else:
        draw.ellipse((cx - 15 * scale, cy + 24 * scale + wobble, cx + 15 * scale, cy + 27 * scale + wobble), fill=rgba(style.secondary, 38))


def make_actor_frame(style: ActorStyle, frame: str, index: int) -> Image.Image:
    img = Image.new("RGBA", (style.size, style.size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_actor_shape(draw, style, frame, index)
    return img


def write_actor_asset(style: ActorStyle, aliases: Iterable[str] = ()) -> None:
    static = make_actor_frame(style, "idle", 1)
    static.save(SPRITE_ROOT / f"{style.slug}_{style.size}.png")
    (SPRITE_ROOT / f"{style.slug}_{style.size}.prompt.txt").write_text(
        PROMPT_HEADER
        + f"\nAsset: {style.kind} runtime sprite `{style.slug}` at {style.size}x{style.size}.\n"
        + f"Subject: {style.prompt}.\nView: 3/4 top-down, readable at 64px, transparent PNG.\n",
        encoding="utf-8",
    )
    for alias in aliases:
        static.save(SPRITE_ROOT / alias)

    frame_dir = FRAME_ROOT / style.slug
    frame_dir.mkdir(parents=True, exist_ok=True)
    for prefix in ("idle", "walk", "combat"):
        for i in range(4):
            frame = make_actor_frame(style, prefix, i)
            frame.save(frame_dir / f"{prefix}_{i:02d}.png")


def write_actor_assets() -> None:
    player = ActorStyle("player_style_normal", "player", INK["jade_soft"], INK["gold"], "player", 64, "jade-robed sword cultivator, dark ink outline, cold jade meridian glow")
    player_chibi = ActorStyle("player_style_chibi", "player", INK["jade_soft"], INK["gold"], "cultivator", 64, "compact chibi jade-robed cultivator matching normal player palette")
    pet = ActorStyle("pet_huo_ying", "pet", INK["fire"], INK["jade_soft"], "pet", 32, "small huo-ying firefly pet, jade-fire body and old-gold core")
    boss = ActorStyle("enemy_thunder_elite_ingame", "boss", INK["thunder"], INK["gold"], "furnace", 64, "thunder tribulation guardian boss, dark armor silhouette, blue-white thunder core")
    boss_chibi = ActorStyle("enemy_thunder_elite_chibi", "boss", INK["thunder"], INK["gold"], "shield", 64, "chibi thunder tribulation boss with large crown shield silhouette")

    write_actor_asset(player, aliases=["player_cultivator_64.png"])
    write_actor_asset(ActorStyle("player_style_normal", "player", INK["jade_soft"], INK["gold"], "player", 128, player.prompt))
    write_actor_asset(player_chibi)
    write_actor_asset(ActorStyle("player_style_chibi", "player", INK["jade_soft"], INK["gold"], "cultivator", 128, player_chibi.prompt))
    write_actor_asset(pet)
    write_actor_asset(boss)
    write_actor_asset(ActorStyle("enemy_thunder_elite_ingame", "boss", INK["thunder"], INK["gold"], "furnace", 128, boss.prompt))
    write_actor_asset(boss_chibi)
    write_actor_asset(ActorStyle("enemy_thunder_elite_chibi", "boss", INK["thunder"], INK["gold"], "shield", 128, boss_chibi.prompt))

    # Archetype fallbacks remain useful, but now share the same visual language.
    fallbacks = {
        "enemy_style_normal_melee": ("wolf", INK["wood"], INK["jade_soft"], "normal melee enemy fallback"),
        "enemy_style_normal_ranged": ("crossbow", INK["thunder"], INK["gold"], "normal ranged enemy fallback"),
        "enemy_style_normal_elite": ("shield", INK["earth"], INK["jade_soft"], "normal elite enemy fallback"),
        "enemy_style_chibi_melee": ("wolf", INK["wood"], INK["jade_soft"], "chibi melee enemy fallback"),
        "enemy_style_chibi_ranged": ("crossbow", INK["thunder"], INK["gold"], "chibi ranged enemy fallback"),
        "enemy_style_chibi_elite": ("shield", INK["earth"], INK["jade_soft"], "chibi elite enemy fallback"),
        "enemy_training_dummy": ("shield", INK["earth"], INK["gold"], "training dummy placeholder in unified style"),
        "enemy_berserker": ("wolf", INK["fire"], INK["gold"], "legacy berserker fallback in unified style"),
        "enemy_archer": ("crossbow", INK["thunder"], INK["gold"], "legacy archer fallback in unified style"),
        "enemy_bomber": ("furnace", INK["fire"], INK["gold"], "legacy bomber fallback in unified style"),
    }
    for slug, (shape, accent, secondary, prompt) in fallbacks.items():
        write_actor_asset(ActorStyle(slug, "enemy", accent, secondary, shape, 64, prompt))
        if "style" in slug:
            write_actor_asset(ActorStyle(slug, "enemy", accent, secondary, shape, 128, prompt))

    for enemy_id, spec in ENEMY_SPECS.items():
        slug = f"enemy_{enemy_id}"
        write_actor_asset(ActorStyle(slug, "enemy", spec["accent"], spec["secondary"], spec["shape"], 64, spec["prompt"]))


def draw_icon_symbol(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], kind: str, color: tuple[int, int, int], secondary: tuple[int, int, int]) -> None:
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    r = min(x1 - x0, y1 - y0) * 0.34
    if kind == "talisman":
        draw.rounded_rectangle((cx - r * 0.48, cy - r * 0.78, cx + r * 0.48, cy + r * 0.78), radius=6, fill=rgba(mix(color, INK["black"], 0.28), 230), outline=rgba(INK["gold"], 220), width=2)
        draw.line((cx - r * 0.28, cy - r * 0.2, cx + r * 0.32, cy - r * 0.2), fill=rgba(secondary, 230), width=3)
        draw.line((cx, cy - r * 0.48, cx, cy + r * 0.44), fill=rgba(color, 230), width=3)
    elif kind == "sword":
        for dx in (-0.28, 0.0, 0.28):
            draw.line((cx + dx * r, cy + r * 0.75, cx + dx * r * 0.2, cy - r * 0.82), fill=rgba(color, 235), width=4)
            draw.line((cx + dx * r - 9, cy + r * 0.2, cx + dx * r + 9, cy + r * 0.2), fill=rgba(INK["gold"], 190), width=2)
    elif kind == "fan":
        for i in range(7):
            a = math.radians(205 + i * 22)
            draw.line((cx, cy + r * 0.45, cx + math.cos(a) * r * 1.05, cy + math.sin(a) * r * 1.05), fill=rgba(color, 230), width=4)
        draw.arc((cx - r, cy - r, cx + r, cy + r), 205, 335, fill=rgba(secondary, 230), width=5)
        draw.ellipse((cx - 5, cy + r * 0.35 - 5, cx + 5, cy + r * 0.35 + 5), fill=rgba(INK["gold"], 230))
    elif kind == "seal":
        draw.ellipse((cx - r * 0.82, cy - r * 0.82, cx + r * 0.82, cy + r * 0.82), fill=rgba(mix(INK["panel"], color, 0.16), 230), outline=rgba(INK["gold"], 190), width=3)
        draw.rounded_rectangle((cx - r * 0.28, cy - r * 0.16, cx + r * 0.28, cy + r * 0.42), radius=4, fill=rgba(INK["ash"], 230), outline=rgba(color, 210), width=2)
        draw.arc((cx - r * 0.28, cy - r * 0.5, cx + r * 0.28, cy + r * 0.08), 190, 350, fill=rgba(color, 210), width=3)
    elif kind == "orb":
        draw.ellipse((cx - r * 0.65, cy - r * 0.65, cx + r * 0.65, cy + r * 0.65), fill=rgba(color, 220), outline=rgba(INK["gold"], 200), width=2)
        draw.arc((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), 15, 330, fill=rgba(secondary, 200), width=3)
    elif kind == "bolt":
        draw.polygon([(cx - r * 0.12, cy - r), (cx + r * 0.34, cy - r * 0.1), (cx + r * 0.04, cy - r * 0.1), (cx + r * 0.18, cy + r), (cx - r * 0.34, cy + r * 0.02), (cx - r * 0.03, cy + r * 0.02)], fill=rgba(color, 235), outline=rgba(INK["paper"], 150))
    elif kind == "chain":
        for i in range(4):
            ox = (i - 1.5) * r * 0.34
            draw.ellipse((cx + ox - r * 0.22, cy - r * 0.18, cx + ox + r * 0.22, cy + r * 0.18), outline=rgba(color, 230), width=4)
        draw.line((cx - r * 0.62, cy, cx + r * 0.62, cy), fill=rgba(secondary, 210), width=2)
    elif kind == "spear":
        draw.line((cx - r * 0.5, cy + r * 0.6, cx + r * 0.55, cy - r * 0.72), fill=rgba(color, 235), width=5)
        draw.polygon([(cx + r * 0.55, cy - r * 0.72), (cx + r * 0.76, cy - r * 0.3), (cx + r * 0.34, cy - r * 0.45)], fill=rgba(secondary, 230))
    elif kind == "leaf":
        draw.ellipse((cx - r * 0.55, cy - r * 0.78, cx + r * 0.45, cy + r * 0.38), fill=rgba(color, 220), outline=rgba(INK["gold"], 190), width=2)
        draw.line((cx - r * 0.28, cy + r * 0.42, cx + r * 0.42, cy - r * 0.5), fill=rgba(secondary, 230), width=3)


def make_icon(size: int, element: str, subject: str, kind: str) -> Image.Image:
    palette = {
        "fire": INK["fire"],
        "water": INK["water"],
        "thunder": INK["thunder"],
        "wood": INK["wood"],
        "earth": INK["earth"],
        "chaos": INK["chaos"],
        "jade": INK["jade_soft"],
    }
    color = palette.get(element, INK["jade_soft"])
    secondary = INK["gold"] if element not in {"earth", "jade"} else INK["jade_soft"]
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    margin = int(size * 0.1)
    draw.ellipse((margin, margin, size - margin, size - margin), fill=rgba(mix(INK["panel"], color, 0.1), 230), outline=rgba(INK["gold"], 190), width=max(1, size // 32))
    draw.ellipse((margin + 7, margin + 7, size - margin - 7, size - margin - 7), outline=rgba(color, 115), width=max(1, size // 48))
    draw_icon_symbol(draw, (margin, margin, size - margin, size - margin), kind, color, secondary)
    img.alpha_composite(layer)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse((margin + 8, margin + 8, size - margin - 8, size - margin - 8), outline=rgba(color, 58), width=max(2, size // 16))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(max(2, size // 18))))
    img.alpha_composite(layer)
    return img


def write_icons() -> None:
    HUD_ROOT.mkdir(parents=True, exist_ok=True)
    for filename, (element, subject, kind) in SPELL_ICONS.items():
        make_icon(96, element, subject, kind).save(HUD_ROOT / filename)
        (HUD_ROOT / filename.replace(".png", ".prompt.txt")).write_text(
            PROMPT_HEADER
            + f"\nAsset: 96x96 HUD spell icon `{filename}`.\nSubject: {subject}. Shape language: circular jade seal plus {kind} symbol, transparent background, no western item render.\n",
            encoding="utf-8",
        )
    # Pet/artifact avatars in the same icon frame language.
    make_icon(64, "fire", "huo-ying pet avatar", "orb").save(HUD_ROOT / "pet_huo_ying_avatar_64.png")
    make_icon(96, "fire", "huo-ying pet avatar", "orb").save(HUD_ROOT / "pet_huo_ying_avatar_96.png")
    make_icon(64, "jade", "xuanyu gourd artifact pendant", "seal").save(HUD_ROOT / "artifact_xuanyu_gourd_pendant_64.png")
    make_icon(96, "jade", "xuanyu gourd artifact pendant", "seal").save(HUD_ROOT / "artifact_xuanyu_gourd_pendant_96.png")


def make_backdrop(seed: str, title: str) -> Image.Image:
    rng = random.Random(seed)
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), rgba(INK["deep"]))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        row = mix((5, 12, 14), (18, 48, 44), y / (h - 1))
        draw.line((0, y, w, y), fill=rgba(row))
    for _ in range(16):
        draw_ink_blob(
            img,
            (rng.randrange(-100, w + 100), rng.randrange(80, h - 80)),
            (rng.randrange(160, 480), rng.randrange(40, 180)),
            mix(INK["panel"], INK["jade"], rng.random() * 0.4),
            alpha=rng.randrange(25, 70),
            rng=rng,
            points=18,
            blur=rng.randrange(16, 42),
        )
    # Distant Chinese xianxia silhouettes, intentionally not western castle forms.
    for x in range(90, w, 250):
        base_y = rng.randrange(680, 890)
        color = rgba((5, 12, 13), rng.randrange(90, 155))
        draw.polygon([(x - 70, base_y), (x, base_y - rng.randrange(120, 260)), (x + 70, base_y), (x + 100, h), (x - 100, h)], fill=color)
        draw.line((x, base_y - 120, x, base_y - 230), fill=rgba(INK["gold"], 55), width=2)
    # Open center for panels.
    center = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(center)
    cdraw.ellipse((430, 180, 1490, 940), fill=rgba((13, 42, 37), 92))
    img.alpha_composite(center.filter(ImageFilter.GaussianBlur(72)))
    for _ in range(20):
        x = rng.randrange(80, w - 80)
        y = rng.randrange(80, h - 80)
        if 520 < x < 1400 and 220 < y < 860:
            continue
        pts = [(x + rng.randrange(-20, 21) * i, y + rng.randrange(-12, 13) * i) for i in range(4)]
        draw_glow_line(img, pts, rng.choice([INK["jade_soft"], INK["gold"], INK["thunder"]]), width=1, alpha=rng.randrange(45, 92), blur=5)
    draw_vignette(img, 170)
    return img.convert("RGB")


def write_backdrops() -> None:
    backdrop_jobs = [
        ("menu", "bg_main_menu_celestial_hall.png", "main menu celestial hall"),
        ("setup", "bg_run_setup_inner_court.png", "run setup inner cultivation court"),
        ("result", "bg_run_result_reincarnation_pool.png", "run result reincarnation pool"),
    ]
    for seed, filename, title in backdrop_jobs:
        make_backdrop(seed, title).save(UI_ROOT / filename)
        (UI_ROOT / filename.replace(".png", ".prompt.txt")).write_text(
            PROMPT_HEADER
            + f"\nAsset: 1920x1080 UI backdrop `{filename}`. Subject: {title}. Chinese xianxia ink palace/shrine, no western castle silhouettes, open center for UI.\n",
            encoding="utf-8",
        )

    # Wide event banner in the same style.
    banner = make_backdrop("event", "secret encounter").resize((1536, 384), Image.Resampling.LANCZOS)
    ImageOps.fit(banner, (1536, 384), method=Image.Resampling.LANCZOS).save(UI_ROOT / "event_illustration_secret_encounter.png")
    (UI_ROOT / "event_illustration_secret_encounter.prompt.txt").write_text(
        PROMPT_HEADER + "\nAsset: wide 1536x384 event illustration, secret jade ruin encounter, no characters, no western dungeon.\n",
        encoding="utf-8",
    )


def update_style_manifest() -> None:
    manifest = {
        "schema": "samsara_ascension.unified_ink_assets.v1",
        "style_name": "玄玉水墨·五行粒子",
        "standard_viewport": [1920, 1080],
        "runtime_goal": "remove western/dark-AI asset mismatch by routing maps, actors, pet, boss, enemy identities, and spell icons through one visual language",
        "palette": INK,
        "enemy_identity_assets": [f"game/assets/sprites/enemy_{enemy_id}_64.png" for enemy_id in ENEMY_SPECS],
        "map_assets": [f"game/assets/maps/{stage_id}/room_background.png" for stage_id in STAGE_STYLES],
        "notes": [
            "This deterministic pass is the runtime baseline and prompt contract.",
            "Later image2/gpt-image-2 refinements should overwrite the same filenames and preserve the prompt contracts.",
            "Five-element saturation is reserved for gameplay signal parts, not full-screen decorative color.",
        ],
    }
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    (OUT_ROOT / "unified_ink_assets_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ensure_dirs()
    write_maps()
    write_backdrops()
    write_actor_assets()
    write_icons()
    update_style_manifest()
    print("Generated unified dark-ink runtime asset pass.")
    print(f"Manifest: {(OUT_ROOT / 'unified_ink_assets_manifest.json').resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
