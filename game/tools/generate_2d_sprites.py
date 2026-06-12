#!/usr/bin/env python3
"""Generate Godot-ready PNG UI/sprites per docs/UIUX_轮回仙途_v1.0.md §11."""

from __future__ import annotations

import struct
import subprocess
import sys
import zlib
from pathlib import Path
from typing import Callable, List, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[1]
UI_OUT = ROOT / "assets" / "ui"
SPRITE_OUT = ROOT / "assets" / "sprites"

# --- Color tokens (UIUX §3.1; 金碧仙宫 jade-palace palette) ---
TOKENS = {
    "bg.deep": "#06140F",
    "bg.panel": "#0F2A22",
    "bg.panel_alt": "#1B4438",
    "text.primary": "#F0ECE4",
    "text.secondary": "#C4B69C",
    "text.muted": "#8A8278",
    "accent.gold": "#FFD700",
    "accent.gold_soft": "#F0D68A",
    "elem.fire": "#FF6B35",
    "elem.water": "#4ECDC4",
    "elem.thunder": "#FFD700",
    "elem.wood": "#7BC67E",
    "elem.earth": "#C4A35A",
    "elem.chaos": "#B57EDC",
    "quality.common": "#B0B0B0",
    "quality.rare": "#4E9AF1",
    "quality.epic": "#A855F7",
    "quality.legendary": "#F59E0B",
    "quality.dao": "#EF4444",
    "state.hp": "#E85D5D",
    "state.hp_end": "#FF8A7A",
    "state.mana": "#5B9BD5",
    "state.mana_end": "#7EC8FF",
    "state.buff": "#7BC67E",
    "state.debuff": "#C45C5C",
}

RGBA = Tuple[int, int, int, int]
ColorFn = Callable[[int, int], RGBA]

GENERATED: List[Path] = []


def hex_to_rgba(hex_str: str, alpha: int = 255) -> RGBA:
    h = hex_str.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha


def blend(a: RGBA, b: RGBA, t: float) -> RGBA:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))  # type: ignore


def lerp_color(c0: RGBA, c1: RGBA, t: float) -> RGBA:
    return blend(c0, c1, max(0.0, min(1.0, t)))


# ---------------------------------------------------------------------------
# Pillow backend
# ---------------------------------------------------------------------------
try:
    from PIL import Image, ImageDraw

    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False
    Image = ImageDraw = None  # type: ignore


def ensure_pillow() -> bool:
    global HAS_PILLOW, Image, ImageDraw
    if HAS_PILLOW:
        return True
    print("Pillow not found; installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image as _Image
    from PIL import ImageDraw as _ImageDraw

    Image = _Image
    ImageDraw = _ImageDraw
    HAS_PILLOW = True
    return True


def save_rgba_pillow(pixels: Sequence[Sequence[RGBA]], path: Path) -> None:
    h = len(pixels)
    w = len(pixels[0]) if h else 0
    img = Image.new("RGBA", (w, h))
    flat = [c for row in pixels for c in row]
    img.putdata(flat)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    GENERATED.append(path)


def save_image_pillow(img: "Image.Image", path: Path) -> None:  # noqa: F821
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    GENERATED.append(path)


# ---------------------------------------------------------------------------
# Pure PNG fallback (RGBA)
# ---------------------------------------------------------------------------
def save_rgba_raw(pixels: Sequence[Sequence[RGBA]], path: Path) -> None:
    h = len(pixels)
    w = len(pixels[0]) if h else 0
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b, a = pixels[y][x]
            raw.extend((r, g, b, a))
    compressed = zlib.compress(bytes(raw), 9)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
        _chunk(f, b"IHDR", ihdr)
        _chunk(f, b"IDAT", compressed)
        _chunk(f, b"IEND", b"")
    GENERATED.append(path)


def _chunk(f, tag: bytes, data: bytes) -> None:
    f.write(struct.pack(">I", len(data)))
    f.write(tag)
    f.write(data)
    f.write(struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def new_canvas(w: int, h: int, fill: RGBA) -> List[List[RGBA]]:
    return [[fill for _ in range(w)] for _ in range(h)]


def set_px(buf: List[List[RGBA]], x: int, y: int, c: RGBA) -> None:
    h, w = len(buf), len(buf[0])
    if 0 <= x < w and 0 <= y < h:
        existing = buf[y][x]
        if c[3] >= 255:
            buf[y][x] = c
        elif c[3] > 0:
            buf[y][x] = blend(existing, c, c[3] / 255.0)


def fill_rect(buf: List[List[RGBA]], x0: int, y0: int, x1: int, y1: int, c: RGBA) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            set_px(buf, x, y, c)


def fill_circle(buf: List[List[RGBA]], cx: int, cy: int, r: int, c: RGBA) -> None:
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                set_px(buf, x, y, c)


def draw_line(buf: List[List[RGBA]], x0: int, y0: int, x1: int, y1: int, c: RGBA, thick: int = 1) -> None:
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    x, y = x0, y0
    while True:
        for oy in range(-thick // 2, thick // 2 + 1):
            for ox in range(-thick // 2, thick // 2 + 1):
                set_px(buf, x + ox, y + oy, c)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy


def save_rgba(buf: List[List[RGBA]], path: Path) -> None:
    if HAS_PILLOW:
        save_rgba_pillow(buf, path)
    else:
        save_rgba_raw(buf, path)


def pil_fill_rounded_rect(
    draw: "ImageDraw.ImageDraw",  # noqa: F821
    xy: Tuple[int, int, int, int],
    radius: int,
    fill: RGBA,
) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------
def gen_panel_ninepatch() -> None:
    """256×256 scroll panel with gold corner accents."""
    w, h = 256, 256
    panel = hex_to_rgba(TOKENS["bg.panel"])
    gold = hex_to_rgba(TOKENS["accent.gold"])
    stroke = (255, 255, 255, 20)
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 0, w, h, panel)
    margin = 32
    fill_rect(buf, margin, margin, w - margin, h - margin, hex_to_rgba(TOKENS["bg.panel_alt"], 80))
    for x in range(1, w - 1):
        set_px(buf, x, 1, stroke)
        set_px(buf, x, h - 2, stroke)
    for y in range(1, h - 1):
        set_px(buf, 1, y, stroke)
        set_px(buf, w - 2, y, stroke)

    # Continuous carved gold frame (9-slice edge regions stretch cleanly)
    gold_soft = hex_to_rgba(TOKENS["accent.gold_soft"], 160)
    fi = 6
    for x in range(fi, w - fi):
        set_px(buf, x, fi, gold)
        set_px(buf, x, h - fi - 1, gold)
        set_px(buf, x, fi + 1, gold_soft)
        set_px(buf, x, h - fi - 2, gold_soft)
    for y in range(fi, h - fi):
        set_px(buf, fi, y, gold)
        set_px(buf, w - fi - 1, y, gold)
        set_px(buf, fi + 1, y, gold_soft)
        set_px(buf, w - fi - 2, y, gold_soft)

    corner_len = 28
    thick = 3
    jade = hex_to_rgba("#4FD6B8")
    corners = [(8, 8, 1, 1), (w - 9, 8, -1, 1), (8, h - 9, 1, -1), (w - 9, h - 9, -1, -1)]
    for ox, oy, sx, sy in corners:
        draw_line(buf, ox, oy, ox + sx * corner_len, oy, gold, thick)
        draw_line(buf, ox, oy, ox, oy + sy * corner_len, gold, thick)
        # jade inlay gem at each corner
        fill_circle(buf, ox + sx * 3, oy + sy * 3, 3, jade)
        set_px(buf, ox + sx * 3, oy + sy * 3, (220, 255, 245, 255))

    save_rgba(buf, UI_OUT / "panel_ninepatch_256.png")


def gen_scroll_toast_banner() -> None:
    """520×72 horizontal scroll banner for learn/rebind toasts."""
    w, h = 520, 72
    panel = hex_to_rgba(TOKENS["bg.panel"])
    gold = hex_to_rgba(TOKENS["accent.gold"])
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 0, w, h, panel)
    for y in range(2, h - 2):
        for x in range(8, w - 8):
            if (x + y) % 11 == 0:
                set_px(buf, x, y, (255, 255, 255, 8))
    margin = 14
    fill_rect(buf, margin, margin + 4, w - margin, h - margin - 4, hex_to_rgba(TOKENS["bg.panel_alt"], 90))
    for x in range(6, w - 6):
        set_px(buf, x, 3, gold)
        set_px(buf, x, h - 4, gold)
    corner_len = 22
    for ox, oy, sx, sy in [(10, 10, 1, 1), (w - 11, 10, -1, 1), (10, h - 11, 1, -1), (w - 11, h - 11, -1, -1)]:
        draw_line(buf, ox, oy, ox + sx * corner_len, oy, gold, 2)
        draw_line(buf, ox, oy, ox, oy + sy * corner_len, gold, 2)
    save_rgba(buf, UI_OUT / "scroll_toast_520x72.png")


def _paper_noise(buf: List[List[RGBA]], x0: int, y0: int, x1: int, y1: int, strength: int = 10) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x * 7 + y * 13) % 17 == 0:
                r, g, b, a = buf[y][x]
                set_px(buf, x, y, (min(255, r + strength), min(255, g + strength), min(255, b + strength), a))


def gen_hud_panel_bg() -> None:
    """320×448 left HUD side panel with gold accent spine."""
    w, h = 320, 448
    panel = hex_to_rgba(TOKENS["bg.panel"])
    alt = hex_to_rgba(TOKENS["bg.panel_alt"], 110)
    gold = hex_to_rgba(TOKENS["accent.gold"])
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 0, w, h, panel)
    fill_rect(buf, 0, 0, 5, h, (gold[0], gold[1], gold[2], 180))
    fill_rect(buf, 5, 0, 7, h, (gold[0], gold[1], gold[2], 60))
    fill_rect(buf, 12, 8, w - 8, h - 8, alt)
    _paper_noise(buf, 12, 8, w - 8, h - 8, 8)
    for y in range(8, h - 8, 64):
        draw_line(buf, 16, y, w - 12, y, (255, 255, 255, 12), 1)
    corner_len = 20
    for ox, oy, sx, sy in [(10, 10, 1, 1), (w - 11, 10, -1, 1), (10, h - 11, 1, -1), (w - 11, h - 11, -1, -1)]:
        draw_line(buf, ox, oy, ox + sx * corner_len, oy, gold, 2)
        draw_line(buf, ox, oy, ox, oy + sy * corner_len, gold, 2)
    save_rgba(buf, UI_OUT / "hud_panel_bg_320x448.png")


def gen_modal_title_bar() -> None:
    """720×52 modal title strip with center glow."""
    w, h = 720, 52
    gold = hex_to_rgba(TOKENS["accent.gold"])
    soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    buf = new_canvas(w, h, (0, 0, 0, 0))
    for x in range(w):
        t = abs(x - w * 0.5) / (w * 0.5)
        a = int(40 + (1.0 - t) * 80)
        set_px(buf, x, h // 2, (gold[0], gold[1], gold[2], a))
        set_px(buf, x, h // 2 + 1, (soft[0], soft[1], soft[2], a // 2))
    draw_line(buf, 24, 8, 120, 8, gold, 2)
    draw_line(buf, w - 120, 8, w - 24, 8, gold, 2)
    draw_line(buf, 24, h - 9, w - 24, h - 9, (gold[0], gold[1], gold[2], 100), 1)
    for cx in (48, w - 48):
        fill_circle(buf, cx, 10, 3, gold)
    save_rgba(buf, UI_OUT / "modal_title_bar_720x52.png")


def gen_divider_gold() -> None:
    w, h = 256, 2
    gold = hex_to_rgba(TOKENS["accent.gold"])
    muted = hex_to_rgba(TOKENS["text.secondary"], 80)
    buf = new_canvas(w, h, (0, 0, 0, 0))
    for x in range(w):
        t = 1.0 - abs(x - w * 0.5) / (w * 0.5)
        c = lerp_color(muted, gold, t * 0.85)
        set_px(buf, x, 0, c)
        set_px(buf, x, 1, (c[0], c[1], c[2], c[3] // 2))
    save_rgba(buf, UI_OUT / "divider_gold_256x2.png")


def gen_path_icons() -> None:
    paths = [
        ("combat", TOKENS["elem.fire"], _draw_sword_icon),
        ("rest", TOKENS["elem.wood"], _draw_lotus_icon),
        ("shop", TOKENS["accent.gold"], _draw_coin_icon),
        ("event", TOKENS["elem.chaos"], _draw_scroll_icon),
        ("elite", TOKENS["quality.legendary"], _draw_skull_icon),
    ]
    for name, color_hex, drawer in paths:
        buf = new_canvas(48, 48, (0, 0, 0, 0))
        bg = hex_to_rgba(TOKENS["bg.panel_alt"])
        fill_circle(buf, 24, 24, 22, bg)
        stroke = hex_to_rgba(color_hex)
        for a in range(0, 360, 12):
            import math
            rad = math.radians(a)
            x = 24 + int(21 * math.cos(rad))
            y = 24 + int(21 * math.sin(rad))
            set_px(buf, x, y, (stroke[0], stroke[1], stroke[2], 90))
        drawer(buf, hex_to_rgba(color_hex))
        save_rgba(buf, UI_OUT / f"path_{name}_48.png")


def _draw_sword_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 24, 8, 24, 34, c, 3)
    draw_line(buf, 16, 22, 32, 22, lerp_color(c, (255, 255, 255, 255), 0.3), 2)
    fill_rect(buf, 20, 34, 28, 38, lerp_color(c, hex_to_rgba("#5A4030"), 0.3))


def _draw_lotus_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_circle(buf, 24, 28, 6, lerp_color(c, (255, 255, 255, 255), 0.2))
    for ox in (-8, 0, 8):
        fill_circle(buf, 24 + ox, 20, 7, c)


def _draw_coin_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_circle(buf, 24, 24, 12, c)
    draw_line(buf, 18, 24, 30, 24, hex_to_rgba(TOKENS["bg.panel"]), 2)
    draw_line(buf, 24, 18, 24, 30, hex_to_rgba(TOKENS["bg.panel"]), 2)


def _draw_scroll_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_rect(buf, 14, 14, 34, 34, c)
    draw_line(buf, 18, 18, 30, 18, hex_to_rgba(TOKENS["text.primary"]), 1)
    draw_line(buf, 18, 24, 28, 24, hex_to_rgba(TOKENS["text.primary"]), 1)
    draw_line(buf, 18, 30, 26, 30, hex_to_rgba(TOKENS["text.primary"]), 1)


def _draw_skull_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_circle(buf, 24, 22, 10, c)
    fill_circle(buf, 20, 20, 2, hex_to_rgba(TOKENS["bg.deep"]))
    fill_circle(buf, 28, 20, 2, hex_to_rgba(TOKENS["bg.deep"]))
    draw_line(buf, 20, 28, 28, 28, hex_to_rgba(TOKENS["bg.deep"]), 2)


def gen_event_banner() -> None:
    """640×160 xianxia mist landscape placeholder."""
    w, h = 640, 160
    deep = hex_to_rgba(TOKENS["bg.deep"])
    panel = hex_to_rgba(TOKENS["bg.panel"])
    gold = hex_to_rgba(TOKENS["accent.gold_soft"], 120)
    buf = new_canvas(w, h, (0, 0, 0, 0))
    for y in range(h):
        t = y / h
        row_c = lerp_color(deep, panel, t * 0.9)
        for x in range(w):
            set_px(buf, x, y, row_c)
    # mountains
    mountain = hex_to_rgba(TOKENS["bg.panel_alt"])
    pts = [(0, 120), (80, 70), (160, 110), (260, 50), (360, 95), (480, 40), (560, 80), (640, 110), (640, 160), (0, 160)]
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            t = s / steps
            x = int(x0 + (x1 - x0) * t)
            y = int(y0 + (y1 - y0) * t)
            fill_rect(buf, x, y, x + 2, h, mountain)
    # mist bands
    for band_y in (90, 105, 118):
        for x in range(0, w, 2):
            set_px(buf, x, band_y, (200, 210, 220, 25))
    # moon
    fill_circle(buf, 540, 36, 14, gold)
    for x in range(8, w - 8):
        set_px(buf, x, 2, (gold[0], gold[1], gold[2], 40))
    save_rgba(buf, UI_OUT / "event_banner_640x160.png")


def gen_talent_scroll_frame() -> None:
    w, h = 210, 200
    gold = hex_to_rgba(TOKENS["accent.gold"])
    panel = hex_to_rgba(TOKENS["bg.panel"])
    inner = hex_to_rgba(TOKENS["bg.panel_alt"], 180)
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 4, 0, w - 4, h, panel)
    fill_rect(buf, 0, 12, 8, h - 12, gold)
    fill_rect(buf, w - 8, 12, w, h - 12, gold)
    fill_rect(buf, 10, 10, w - 10, h - 10, inner)
    _paper_noise(buf, 12, 12, w - 12, h - 12, 6)
    for y in (8, h - 9):
        draw_line(buf, 12, y, w - 12, y, gold, 2)
    save_rgba(buf, UI_OUT / "talent_scroll_210x200.png")


def gen_pet_avatar_ring() -> None:
    size = 40
    gold = hex_to_rgba(TOKENS["accent.gold"])
    buf = new_canvas(size, size, (0, 0, 0, 0))
    cx, cy, r = size // 2, size // 2, 17
    for a in range(0, 360, 3):
        import math
        rad = math.radians(a)
        x = cx + int(r * math.cos(rad))
        y = cy + int(r * math.sin(rad))
        set_px(buf, x, y, gold)
    fill_circle(buf, cx, cy, 14, (0, 0, 0, 0))
    save_rgba(buf, UI_OUT / "pet_avatar_ring_40.png")


def gen_combo_track() -> None:
    w, h = 256, 8
    bg = hex_to_rgba(TOKENS["bg.panel_alt"])
    c0 = hex_to_rgba(TOKENS["elem.fire"])
    c1 = hex_to_rgba(TOKENS["accent.gold"])
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 0, w, h, bg)
    for x in range(w):
        t = x / max(1, w - 1)
        fill_rect(buf, x, 1, x + 1, h - 1, lerp_color(c0, c1, t))
    save_rgba(buf, UI_OUT / "combo_track_256x8.png")


def gen_element_icons() -> None:
    elements = [
        ("fire", TOKENS["elem.fire"], _draw_fire_icon),
        ("water", TOKENS["elem.water"], _draw_water_icon),
        ("thunder", TOKENS["elem.thunder"], _draw_thunder_icon),
        ("wood", TOKENS["elem.wood"], _draw_wood_icon),
        ("earth", TOKENS["elem.earth"], _draw_earth_icon),
        ("chaos", TOKENS["elem.chaos"], _draw_chaos_icon),
    ]
    for name, color_hex, drawer in elements:
        buf = new_canvas(32, 32, (0, 0, 0, 0))
        drawer(buf, hex_to_rgba(color_hex))
        save_rgba(buf, UI_OUT / f"elem_{name}_32.png")


def _draw_fire_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    pts = [(16, 6), (22, 18), (18, 26), (14, 26), (10, 18)]
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        draw_line(buf, x0, y0, x1, y1, c, 2)
    fill_circle(buf, 16, 20, 4, lerp_color(c, (255, 255, 255, 255), 0.4))


def _draw_water_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    for cx in (11, 16, 21):
        fill_circle(buf, cx, 14, 4, c)
    draw_line(buf, 8, 22, 24, 22, c, 2)
    draw_line(buf, 10, 26, 22, 26, lerp_color(c, (255, 255, 255, 255), 0.3), 1)


def _draw_thunder_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    bolt = [(18, 5), (12, 17), (16, 17), (10, 27), (20, 14), (15, 14), (22, 5)]
    for i in range(len(bolt) - 1):
        draw_line(buf, bolt[i][0], bolt[i][1], bolt[i + 1][0], bolt[i + 1][1], c, 2)


def _draw_wood_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 16, 26, 16, 12, lerp_color(c, hex_to_rgba("#5A4030"), 0.4), 2)
    fill_circle(buf, 16, 10, 7, c)
    fill_circle(buf, 11, 14, 4, lerp_color(c, (255, 255, 255, 255), 0.2))
    fill_circle(buf, 21, 14, 4, lerp_color(c, (255, 255, 255, 255), 0.2))


def _draw_earth_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_rect(buf, 8, 18, 24, 26, c)
    for x in range(8, 25, 4):
        draw_line(buf, x, 18, x + 2, 14, lerp_color(c, (255, 255, 255, 255), 0.15), 1)
    draw_line(buf, 8, 26, 24, 26, lerp_color(c, hex_to_rgba("#3D3220"), 0.3), 2)


def _draw_chaos_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_circle(buf, 16, 16, 10, (c[0], c[1], c[2], 60))
    for angle_i in range(5):
        import math

        a = angle_i * 2 * math.pi / 5 - math.pi / 2
        x0 = 16 + int(4 * math.cos(a))
        y0 = 16 + int(4 * math.sin(a))
        x1 = 16 + int(11 * math.cos(a))
        y1 = 16 + int(11 * math.sin(a))
        draw_line(buf, x0, y0, x1, y1, c, 2)


def gen_quality_frames() -> None:
    qualities = [
        ("common", TOKENS["quality.common"], 1),
        ("rare", TOKENS["quality.rare"], 1),
        ("epic", TOKENS["quality.epic"], 2),
        ("legendary", TOKENS["quality.legendary"], 2),
        ("dao", TOKENS["quality.dao"], 2),
    ]
    w, h = 220, 280
    for name, color_hex, border in qualities:
        buf = new_canvas(w, h, (0, 0, 0, 0))
        qc = hex_to_rgba(color_hex)
        panel = hex_to_rgba(TOKENS["bg.panel"])
        inner = hex_to_rgba(TOKENS["bg.panel_alt"], 200)
        for b in range(border):
            fill_rect(buf, b, b, w - b, h - b, qc)
        fill_rect(buf, border + 2, border + 2, w - border - 2, h - border - 2, panel)
        fill_rect(buf, 12, 12, w - 12, h - 12, inner)
        if name in ("legendary", "dao"):
            gold = hex_to_rgba(TOKENS["accent.gold"])
            draw_line(buf, 6, 6, 40, 6, gold, 1)
            draw_line(buf, w - 40, h - 7, w - 6, h - 7, gold, 1)
        if name == "dao":
            for i in range(0, w, 8):
                t = i / w
                c = lerp_color(qc, hex_to_rgba(TOKENS["accent.gold"]), abs(0.5 - t) * 0.6)
                set_px(buf, i, 0, c)
                set_px(buf, i, h - 1, c)
        save_rgba(buf, UI_OUT / f"quality_{name}_220x280.png")


def gen_spell_icons() -> None:
    spells = [
        ("q_fire", TOKENS["elem.fire"], _draw_fire_icon, False),
        ("e_thunder", TOKENS["elem.thunder"], _draw_thunder_icon, False),
        ("r_water", TOKENS["elem.water"], _draw_water_icon, False),
        ("q_locked", TOKENS["elem.fire"], _draw_fire_icon, True),
        ("e_locked", TOKENS["elem.thunder"], _draw_thunder_icon, True),
        ("r_locked", TOKENS["elem.water"], _draw_water_icon, True),
        ("slot_empty", TOKENS["text.muted"], None, False),
        ("slot_locked", TOKENS["text.muted"], None, True),
    ]
    size = 40
    for name, color_hex, drawer, locked in spells:
        buf = new_canvas(size, size, (0, 0, 0, 0))
        bg = hex_to_rgba(TOKENS["bg.panel_alt"])
        fill_rect(buf, 2, 2, size - 2, size - 2, bg)
        stroke = (255, 255, 255, 18)
        for x in range(2, size - 2):
            set_px(buf, x, 2, stroke)
            set_px(buf, x, size - 3, stroke)
        if drawer:
            drawer(buf, hex_to_rgba(color_hex))
        if locked:
            muted = hex_to_rgba(TOKENS["text.muted"], 140)
            fill_rect(buf, 4, 4, size - 4, size - 4, muted)
            _draw_lock(buf, size // 2, size // 2 + 2)
        save_rgba(buf, UI_OUT / f"spell_{name}_40.png")


def _draw_lock(buf: List[List[RGBA]], cx: int, cy: int) -> None:
    c = hex_to_rgba(TOKENS["text.primary"])
    draw_line(buf, cx - 5, cy - 2, cx - 5, cy - 6, c, 2)
    draw_line(buf, cx + 5, cy - 2, cx + 5, cy - 6, c, 2)
    draw_line(buf, cx - 5, cy - 6, cx + 5, cy - 6, c, 2)
    fill_rect(buf, cx - 7, cy - 2, cx + 8, cy + 8, c)


def gen_progress_bars() -> None:
    """9-slice strips: 64×16 with rounded ends (bar height 12px content)."""
    gen_progress_bar(
        "progress_hp_9slice.png",
        hex_to_rgba(TOKENS["bg.panel_alt"]),
        hex_to_rgba(TOKENS["state.hp"]),
        hex_to_rgba(TOKENS["state.hp_end"]),
    )
    gen_progress_bar(
        "progress_mana_9slice.png",
        hex_to_rgba(TOKENS["bg.panel_alt"]),
        hex_to_rgba(TOKENS["state.mana"]),
        hex_to_rgba(TOKENS["state.mana_end"]),
    )


def gen_progress_bar(filename: str, bg: RGBA, c0: RGBA, c1: RGBA) -> None:
    w, h = 64, 16
    if HAS_PILLOW:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        pil_fill_rounded_rect(draw, (0, 2, w, h - 2), 4, bg)
        for x in range(8, w - 8):
            t = (x - 8) / max(1, w - 16)
            pil_fill_rounded_rect(draw, (x, 4, x + 1, h - 4), 0, lerp_color(c0, c1, t))
        pil_fill_rounded_rect(draw, (0, 2, 8, h - 2), 4, c0)
        pil_fill_rounded_rect(draw, (w - 8, 2, w, h - 2), 4, c1)
        save_image_pillow(img, UI_OUT / filename)
    else:
        buf = new_canvas(w, h, (0, 0, 0, 0))
        fill_rect(buf, 0, 2, w, h - 2, bg)
        for x in range(8, w - 8):
            t = (x - 8) / max(1, w - 16)
            fill_rect(buf, x, 4, x + 1, h - 4, lerp_color(c0, c1, t))
        save_rgba(buf, UI_OUT / filename)


def gen_weather_icons() -> None:
    weathers = [
        ("clear", _draw_weather_clear),
        ("rain", _draw_weather_rain),
        ("thunder", _draw_weather_thunder),
        ("fire", _draw_weather_fire),
        ("wind", _draw_weather_wind),
        ("fog", _draw_weather_fog),
        ("snow", _draw_weather_snow),
        ("sand", _draw_weather_sand),
    ]
    for name, drawer in weathers:
        buf = new_canvas(32, 32, (0, 0, 0, 0))
        drawer(buf)
        save_rgba(buf, UI_OUT / f"weather_{name}_32.png")


def _draw_weather_clear(buf: List[List[RGBA]]) -> None:
    c = hex_to_rgba(TOKENS["accent.gold"])
    fill_circle(buf, 22, 10, 6, c)
    for i in range(8):
        import math

        a = i * math.pi / 4
        draw_line(buf, 22, 10, 22 + int(10 * math.cos(a)), 10 + int(10 * math.sin(a)), c, 1)


def _draw_weather_rain(buf: List[List[RGBA]]) -> None:
    c = hex_to_rgba(TOKENS["elem.water"])
    fill_circle(buf, 22, 8, 5, (c[0], c[1], c[2], 180))
    for ox in (8, 14, 20, 26):
        draw_line(buf, ox, 16, ox - 2, 26, c, 1)


def _draw_weather_thunder(buf: List[List[RGBA]]) -> None:
    _draw_weather_rain(buf)
    _draw_thunder_icon(buf, hex_to_rgba(TOKENS["elem.thunder"]))


def _draw_weather_fire(buf: List[List[RGBA]]) -> None:
    _draw_fire_icon(buf, hex_to_rgba(TOKENS["elem.fire"]))
    fill_circle(buf, 22, 8, 7, hex_to_rgba(TOKENS["accent.gold"], 200))


def _draw_weather_wind(buf: List[List[RGBA]]) -> None:
    c = hex_to_rgba(TOKENS["elem.wood"])
    for y, x0 in ((10, 6), (16, 8), (22, 5)):
        draw_line(buf, x0, y, 28, y, c, 2)
        set_px(buf, 28, y - 1, c)
        set_px(buf, 27, y + 1, c)


def _draw_weather_fog(buf: List[List[RGBA]]) -> None:
    c = hex_to_rgba(TOKENS["text.muted"])
    for y in (12, 18, 24):
        draw_line(buf, 6, y, 26, y, (c[0], c[1], c[2], 160), 2)


def _draw_weather_snow(buf: List[List[RGBA]]) -> None:
    c = hex_to_rgba(TOKENS["elem.water"])
    fill_circle(buf, 20, 8, 4, (200, 220, 255, 255))
    for pos in ((10, 18), (18, 22), (24, 16), (14, 26)):
        fill_circle(buf, pos[0], pos[1], 2, c)


def _draw_weather_sand(buf: List[List[RGBA]]) -> None:
    c = hex_to_rgba(TOKENS["elem.earth"])
    for y in range(14, 28, 3):
        draw_line(buf, 4, y, 28, y + 1, (c[0], c[1], c[2], 120), 1)
    fill_circle(buf, 24, 10, 5, c)


def gen_dao_heart_icons() -> None:
    hearts = [
        ("ask", TOKENS["elem.water"], "问道"),
        ("enlighten", TOKENS["accent.gold"], "悟道"),
        ("prove", TOKENS["quality.dao"], "证道"),
    ]
    for name, accent_hex, _label in hearts:
        buf = new_canvas(128, 128, (0, 0, 0, 0))
        bg = hex_to_rgba(TOKENS["bg.panel"])
        accent = hex_to_rgba(accent_hex)
        gold = hex_to_rgba(TOKENS["accent.gold"])
        fill_rect(buf, 8, 8, 120, 120, bg)
        for b in range(3):
            fill_rect(buf, 8 + b, 8 + b, 120 - b, 120 - b, (gold[0], gold[1], gold[2], 40 + b * 20))
        fill_circle(buf, 64, 52, 28, (accent[0], accent[1], accent[2], 90))
        fill_circle(buf, 64, 52, 18, accent)
        if name == "ask":
            draw_line(buf, 64, 40, 64, 58, hex_to_rgba(TOKENS["text.primary"]), 3)
            fill_circle(buf, 64, 66, 3, hex_to_rgba(TOKENS["text.primary"]))
        elif name == "enlighten":
            for i in range(6):
                import math

                a = i * math.pi / 3
                draw_line(
                    buf,
                    64,
                    52,
                    64 + int(24 * math.cos(a)),
                    52 + int(24 * math.sin(a)),
                    gold,
                    2,
                )
        else:
            draw_line(buf, 48, 68, 80, 36, gold, 3)
            draw_line(buf, 48, 36, 80, 68, gold, 3)
        save_rgba(buf, UI_OUT / f"dao_heart_{name}_128.png")


def _draw_pixel_sprite(buf: List[List[RGBA]], pixels: str, palette: dict[str, RGBA], scale: int = 1) -> None:
    rows = pixels.strip().split("\n")
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            c = palette.get(ch, (255, 0, 255, 255))
            for dy in range(scale):
                for dx in range(scale):
                    set_px(buf, x * scale + dx, y * scale + dy, c)


def gen_player_sprite() -> None:
    """64×64 top-down xianxia cultivator."""
    palette = {
        "R": hex_to_rgba("#8B2942"),
        "G": hex_to_rgba(TOKENS["elem.wood"]),
        "S": hex_to_rgba(TOKENS["text.primary"]),
        "H": hex_to_rgba("#3D2314"),
        "B": hex_to_rgba(TOKENS["elem.water"]),
        "K": hex_to_rgba(TOKENS["bg.deep"]),
    }
    art = """
................
......SSSS......
.....SHHHHS.....
....SHHHHHS.....
...SSRRRRSS.....
..SSRRRRRRSS....
..SRRRRRRRRS....
..SRRBBBBRRS....
..SSRRRRRRSS....
...SSSSSSSS.....
....SS..SS......
....BB..BB......
.....B..B.......
................
"""
    buf = new_canvas(64, 64, (0, 0, 0, 0))
    _draw_pixel_sprite(buf, art, palette, 4)
    save_rgba(buf, SPRITE_OUT / "player_cultivator_64.png")


def gen_enemy_sprites() -> None:
    enemies = {
        "training_dummy": ("""
....YYYY....
...YYYYYY...
..YYYYYYYY..
..YYYYYYYY..
...YYYYYY...
....YYYY....
....YYYY....
....YYYY....
....YYYY....
....YYYY....
""", {"Y": hex_to_rgba(TOKENS["elem.earth"]), "B": hex_to_rgba("#5A4030")}),
        "berserker": ("""
....RRRR....
...RRRRRR...
..RRRRRRRR..
..RRWWWWRR..
..RRRRRRRR..
...RRRRRR...
....RRRR....
....RR..RR..
....RR..RR..
....RR..RR..
""", {"R": hex_to_rgba(TOKENS["quality.dao"]), "W": hex_to_rgba(TOKENS["text.primary"])}),
        "archer": ("""
....GGGG....
...GGGGGG...
..GGGGGGGG..
..GGBBBBGG..
..GGGGGGGG..
...GG..GG...
....GGGG....
....GGGG....
....GG..GG..
....GG..GG..
""", {"G": hex_to_rgba(TOKENS["elem.wood"]), "B": hex_to_rgba(TOKENS["bg.panel_alt"])}),
        "bomber": ("""
....OOOO....
...OOOOOO...
..OOOOOOOO..
..OOYYYYOO..
..OOOOOOOO..
...OOOOOO...
....OOOO....
....OO..OO..
....OO..OO..
....OO..OO..
""", {"O": hex_to_rgba(TOKENS["elem.fire"]), "Y": hex_to_rgba(TOKENS["accent.gold"])}),
    }
    for name, (art, palette) in enemies.items():
        buf = new_canvas(64, 64, (0, 0, 0, 0))
        _draw_pixel_sprite(buf, art, palette, 4)
        save_rgba(buf, SPRITE_OUT / f"enemy_{name}_64.png")


def gen_projectile_sprites() -> None:
    projectiles = {
        "fire": (TOKENS["elem.fire"], True),
        "thunder": (TOKENS["elem.thunder"], False),
        "ice": (TOKENS["elem.water"], True),
        "water": (TOKENS["elem.water"], True),
        "generic": (TOKENS["accent.gold"], True),
        "chaos": (TOKENS["elem.chaos"], True),
    }
    for name, (color_hex, glow) in projectiles.items():
        buf = new_canvas(16, 16, (0, 0, 0, 0))
        c = hex_to_rgba(color_hex)
        if glow:
            fill_circle(buf, 8, 8, 6, (c[0], c[1], c[2], 80))
        fill_circle(buf, 8, 8, 4, c)
        if name == "thunder":
            _draw_thunder_icon(buf, c)
        save_rgba(buf, SPRITE_OUT / f"projectile_{name}_16.png")


def gen_pet_huo_ying() -> None:
    palette = {
        "F": hex_to_rgba(TOKENS["elem.fire"]),
        "Y": hex_to_rgba(TOKENS["accent.gold"]),
        "B": hex_to_rgba("#1A0A00"),
    }
    art = """
....FFFF....
...FFFFFF...
..FFYYFFYF..
..FFFFFFFF..
...FFFFFF...
....FFFF....
...FF..FF...
...FF..FF...
"""
    buf = new_canvas(32, 32, (0, 0, 0, 0))
    _draw_pixel_sprite(buf, art, palette, 2)
    save_rgba(buf, SPRITE_OUT / "pet_huo_ying_32.png")


def main() -> int:
    ensure_pillow()
    UI_OUT.mkdir(parents=True, exist_ok=True)
    SPRITE_OUT.mkdir(parents=True, exist_ok=True)

    print("Generating UI assets...")
    gen_panel_ninepatch()
    gen_scroll_toast_banner()
    gen_hud_panel_bg()
    gen_modal_title_bar()
    gen_divider_gold()
    gen_path_icons()
    gen_event_banner()
    gen_talent_scroll_frame()
    gen_pet_avatar_ring()
    gen_combo_track()
    gen_element_icons()
    gen_quality_frames()
    gen_spell_icons()
    gen_progress_bars()
    gen_weather_icons()
    gen_dao_heart_icons()

    print("Generating sprite assets...")
    gen_player_sprite()
    gen_enemy_sprites()
    gen_projectile_sprites()
    gen_pet_huo_ying()

    print(f"\nDone — {len(GENERATED)} files written.")
    for p in sorted(GENERATED):
        print(f"  {p.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
