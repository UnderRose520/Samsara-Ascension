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
    # --- Ink-Pixel Hybrid palette (玄玉鎏金) ---
    "ink.dark": "#0a0f0f",
    "ink.mid": "#1a2428",
    "ink.light": "#2a3638",
    "ink.gold": "#c4a86a",
    "ink.jade": "#3d7a6e",
    "ink.thunder": "#5b8cce",
    "ink.fire": "#d4743e",
    "ink.frost": "#d8e8f0",
    "ink.blood": "#8b2020",
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
def _gold_frame_ramp() -> dict:
    """Beveled metallic gold frame profile keyed by distance from the nearest edge.
    Stays within the 32px ninepatch margin so 9-slice edges stretch uniformly."""
    edge = hex_to_rgba("#5A4A1E")        # dark outer rim
    gold = hex_to_rgba(TOKENS["accent.gold"])
    bright = hex_to_rgba("#FFE680")      # bevel highlight
    soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    groove = hex_to_rgba("#0C241D")      # dark jade groove between the two gold lines
    inner = hex_to_rgba(TOKENS["accent.gold_soft"], 200)
    inner2 = hex_to_rgba(TOKENS["accent.gold_soft"], 90)
    return {0: edge, 1: gold, 2: bright, 3: gold, 4: soft, 5: groove, 6: groove, 7: inner, 8: inner2}


def _draw_gold_frame(buf, w, h, ramp) -> None:
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            c = ramp.get(d)
            if c is not None:
                set_px(buf, x, y, c)


def gen_panel_ninepatch() -> None:
    """256×256 jade panel with an ornate beveled gold frame + jade corner inlays."""
    w, h = 256, 256
    panel = hex_to_rgba(TOKENS["bg.panel"])
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 0, w, h, panel)
    _draw_gold_frame(buf, w, h, _gold_frame_ramp())
    # jade corner inlay gems sitting on the inner gold line
    jade = hex_to_rgba("#4FD6B8")
    jade_hi = (224, 255, 246, 255)
    for cxp, cyp in [(9, 9), (w - 10, 9), (9, h - 10), (w - 10, h - 10)]:
        fill_circle(buf, cxp, cyp, 4, hex_to_rgba("#0C241D"))
        fill_circle(buf, cxp, cyp, 3, jade)
        set_px(buf, cxp, cyp, jade_hi)
    save_rgba(buf, UI_OUT / "panel_ninepatch_256.png")


def _save_transparent_pil(img: "Image.Image", path: Path) -> None:  # noqa: F821
    save_image_pillow(img.convert("RGBA"), path)


def _draw_rounded_frame(
    img: "Image.Image",  # noqa: F821
    xy: Tuple[int, int, int, int],
    radius: int,
    fill: RGBA,
    outline: RGBA,
    width: int = 2,
) -> None:
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def _draw_cloud_scroll(buf: List[List[RGBA]], x0: int, y: int, length: int, c: RGBA, mirror: bool = False) -> None:
    step = -1 if mirror else 1
    start = x0
    end = x0 + step * length
    draw_line(buf, start, y, end, y, c, 1)
    for i in range(0, length, 18):
        cx = x0 + step * i
        draw_line(buf, cx, y, cx + step * 8, y - 5, c, 1)
        draw_line(buf, cx + step * 8, y - 5, cx + step * 15, y - 1, c, 1)
        draw_line(buf, cx, y, cx + step * 8, y + 5, c, 1)
        draw_line(buf, cx + step * 8, y + 5, cx + step * 15, y + 1, c, 1)


def gen_bg_jade_palace() -> None:
    """1920×1080 jade palace hall, center-weighted and dark enough for setup UI."""
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), hex_to_rgba(TOKENS["bg.deep"]))
    draw = ImageDraw.Draw(img, "RGBA")
    top = hex_to_rgba("#02100C")
    bottom = hex_to_rgba("#12382E")
    for y in range(h):
        t = y / max(1, h - 1)
        draw.line((0, y, w, y), fill=lerp_color(top, bottom, t))
    # distant mountains and cloud layer through the rear arch.
    for i, color in enumerate([(50, 110, 100, 90), (42, 86, 84, 95), (28, 62, 58, 120)]):
        base = 640 + i * 80
        pts = [(0, h), (0, base), (250, base - 120), (460, base - 30), (720, base - 160), (980, base - 60),
               (1240, base - 190), (1460, base - 70), (1700, base - 150), (w, base - 40), (w, h)]
        draw.polygon(pts, fill=color)
    for y in (515, 565, 620):
        draw.ellipse((-200, y - 45, 600, y + 65), fill=(210, 230, 220, 26))
        draw.ellipse((520, y - 35, 1540, y + 55), fill=(210, 230, 220, 22))
        draw.ellipse((1220, y - 50, 2100, y + 60), fill=(210, 230, 220, 20))
    gold = hex_to_rgba(TOKENS["accent.gold"])
    gold_soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    jade = hex_to_rgba(TOKENS["bg.panel_alt"])
    # palace columns.
    for cx in (210, 430, 1490, 1710):
        draw.rounded_rectangle((cx - 52, 145, cx + 52, 965), radius=28, fill=(12, 58, 48, 210), outline=gold, width=5)
        draw.rectangle((cx - 72, 125, cx + 72, 165), fill=gold_soft, outline=gold, width=3)
        draw.rectangle((cx - 76, 940, cx + 76, 995), fill=gold_soft, outline=gold, width=3)
        for yy in range(210, 890, 105):
            draw.arc((cx - 42, yy, cx + 42, yy + 72), 200, 340, fill=(255, 215, 0, 135), width=3)
    # arch and floor.
    draw.arc((360, 90, 1560, 1280), 180, 360, fill=gold, width=10)
    draw.rectangle((360, 365, 1560, 386), fill=(255, 215, 0, 90))
    draw.polygon([(220, 1080), (600, 690), (1320, 690), (1700, 1080)], fill=(4, 32, 26, 220), outline=(255, 215, 0, 90))
    for x in range(360, 1580, 120):
        draw.line((x, 1080, 860 + (x - 360) * 0.15, 690), fill=(255, 215, 0, 35), width=2)
    for y in range(720, 1060, 70):
        draw.line((250, y, 1670, y), fill=(255, 215, 0, 26), width=2)
    # central safe area subtle glow behind modal.
    draw.ellipse((540, 230, 1380, 920), fill=(20, 90, 72, 45))
    # lanterns.
    for lx in (640, 1280):
        draw.line((lx, 150, lx, 250), fill=gold_soft, width=3)
        draw.ellipse((lx - 32, 245, lx + 32, 325), fill=(255, 206, 78, 145), outline=gold, width=3)
    # dark crop-tolerant vignette.
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay, "RGBA")
    for i in range(28):
        a = int(i * 5)
        od.rectangle((i * 18, i * 10, w - i * 18, h - i * 10), outline=(0, 0, 0, a), width=18)
    img = Image.alpha_composite(img, overlay)
    _save_transparent_pil(img, UI_OUT / "bg_jade_palace_hall.png")


def gen_breakthrough_bg_overlay() -> None:
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h), hex_to_rgba("#080313"))
    draw = ImageDraw.Draw(img, "RGBA")
    for y in range(h):
        t = y / max(1, h - 1)
        draw.line((0, y, w, y), fill=lerp_color(hex_to_rgba("#070514"), hex_to_rgba("#153B31"), t))
    cx, cy = w // 2, h // 2
    for r in range(440, 60, -38):
        a = int(10 + (440 - r) * 0.08)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(78, 205, 196, a), width=5)
    for i in range(18):
        angle = i * 20
        import math
        rad = math.radians(angle)
        draw.line((cx, cy, cx + int(780 * math.cos(rad)), cy + int(440 * math.sin(rad))), fill=(255, 215, 0, 28), width=2)
    _save_transparent_pil(img, UI_OUT / "breakthrough_bg_overlay.png")


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
    """320×448 left HUD panel texture — subtle jade paper only.
    The frame/spine come from HudStyles.left_scroll_panel + the AccentStripe node,
    so no hard gold spine or corner brackets are baked in here."""
    w, h = 320, 448
    panel = hex_to_rgba(TOKENS["bg.panel"])
    alt = hex_to_rgba(TOKENS["bg.panel_alt"], 85)
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 0, w, h, panel)
    fill_rect(buf, 10, 8, w - 8, h - 8, alt)
    _paper_noise(buf, 10, 8, w - 8, h - 8, 7)
    for y in range(8, h - 8, 64):
        draw_line(buf, 14, y, w - 12, y, (255, 255, 255, 8), 1)
    save_rgba(buf, UI_OUT / "hud_panel_bg_320x448.png")


def gen_modal_title_bar() -> None:
    """720×52 modal title strip — subtle centered soft-gold divider under the title."""
    w, h = 720, 52
    soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    buf = new_canvas(w, h, (0, 0, 0, 0))
    for x in range(w):
        t = max(0.0, 1.0 - abs(x - w * 0.5) / (w * 0.5))
        a = int(110 * t)
        set_px(buf, x, h - 10, (soft[0], soft[1], soft[2], a))
        set_px(buf, x, h - 9, (soft[0], soft[1], soft[2], a // 2))
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


def gen_decorative_frames_and_buttons() -> None:
    # Dao-heart card frame.
    w, h = 168, 200
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 2, 2, w - 2, h - 2, hex_to_rgba(TOKENS["bg.panel_alt"]))
    _draw_gold_frame(buf, w, h, {0: hex_to_rgba("#5A4A1E"), 1: hex_to_rgba(TOKENS["accent.gold"]), 2: hex_to_rgba(TOKENS["accent.gold_soft"]), 7: hex_to_rgba(TOKENS["accent.gold"], 150)})
    _paper_noise(buf, 10, 10, w - 10, h - 10, 7)
    for cx, cy in [(10, 10), (w - 11, 10), (10, h - 11), (w - 11, h - 11)]:
        fill_circle(buf, cx, cy, 3, hex_to_rgba(TOKENS["elem.water"]))
    save_rgba(buf, UI_OUT / "dao_heart_card_frame.png")

    # Talent scroll hover highlight.
    gen_talent_scroll_frame()
    base = Image.open(UI_OUT / "talent_scroll_210x200.png").convert("RGBA")
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow, "RGBA")
    d.rounded_rectangle((1, 1, base.width - 2, base.height - 2), radius=10, outline=(255, 215, 0, 145), width=5)
    d.rounded_rectangle((7, 7, base.width - 8, base.height - 8), radius=7, outline=(255, 246, 170, 105), width=2)
    _save_transparent_pil(Image.alpha_composite(base, glow), UI_OUT / "talent_scroll_210x200_highlight.png")

    # Title ornament.
    w, h = 640, 48
    buf = new_canvas(w, h, (0, 0, 0, 0))
    gold = hex_to_rgba(TOKENS["accent.gold"])
    soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    cy = h // 2
    draw_line(buf, 42, cy, w // 2 - 24, cy, gold, 2)
    draw_line(buf, w - 42, cy, w // 2 + 24, cy, gold, 2)
    _draw_cloud_scroll(buf, 46, cy, 220, soft)
    _draw_cloud_scroll(buf, w - 46, cy, 220, soft, True)
    fill_circle(buf, w // 2, cy, 8, hex_to_rgba(TOKENS["elem.water"]))
    fill_circle(buf, w // 2, cy, 4, hex_to_rgba("#E8FFF8"))
    save_rgba(buf, UI_OUT / "setup_title_ornament.png")

    # Buttons.
    def button(path: str, size: Tuple[int, int], primary: bool) -> None:
        bw, bh = size
        img = Image.new("RGBA", size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(img, "RGBA")
        if primary:
            for y in range(bh):
                t = abs(y - bh / 2) / (bh / 2)
                c = lerp_color(hex_to_rgba("#C58D11"), hex_to_rgba(TOKENS["accent.gold"]), 1.0 - t * 0.65)
                draw.line((4, y, bw - 5, y), fill=c)
            draw.rounded_rectangle((2, 2, bw - 3, bh - 3), radius=8, outline=hex_to_rgba("#2E2206"), width=2)
            draw.rounded_rectangle((7, 7, bw - 8, bh - 8), radius=5, outline=(255, 248, 184, 110), width=1)
        else:
            draw.rounded_rectangle((1, 1, bw - 2, bh - 2), radius=7, fill=hex_to_rgba(TOKENS["bg.panel"], 210), outline=hex_to_rgba(TOKENS["text.secondary"], 210), width=1)
            draw.line((8, 4, bw - 8, 4), fill=(255, 215, 0, 70), width=1)
            draw.line((8, bh - 5, bw - 8, bh - 5), fill=(255, 215, 0, 50), width=1)
        _save_transparent_pil(img, UI_OUT / path)
    button("btn_primary_gold_360x48.png", (360, 48), True)
    button("btn_secondary_360x40.png", (360, 40), False)

    # Couplet panels.
    for name in ("left", "right"):
        cw, ch = 48, 240
        buf = new_canvas(cw, ch, (0, 0, 0, 0))
        fill_rect(buf, 5, 6, cw - 5, ch - 6, hex_to_rgba(TOKENS["bg.panel_alt"]))
        fill_rect(buf, 3, 0, cw - 3, 18, gold)
        fill_rect(buf, 3, ch - 18, cw - 3, ch, gold)
        _draw_gold_frame(buf, cw, ch, {0: hex_to_rgba("#5A4A1E"), 1: gold, 2: soft})
        save_rgba(buf, UI_OUT / f"couplet_panel_{name}.png")


def gen_hud_dedicated_frames() -> None:
    # Weather panel.
    w, h = 280, 120
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 2, 2, w - 2, h - 2, hex_to_rgba(TOKENS["bg.panel"], 220))
    _draw_gold_frame(buf, w, h, {0: hex_to_rgba("#4A3A13"), 1: hex_to_rgba(TOKENS["accent.gold"]), 2: hex_to_rgba(TOKENS["accent.gold_soft"]), 7: hex_to_rgba(TOKENS["accent.gold"], 100)})
    save_rgba(buf, UI_OUT / "hud_weather_panel_280x120.png")

    # Skill dock frame.
    w, h = 360, 80
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 4, 10, w - 4, h - 6, hex_to_rgba(TOKENS["bg.panel"], 210))
    gold = hex_to_rgba(TOKENS["accent.gold"])
    soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    draw_line(buf, 24, 14, w - 24, 14, gold, 2)
    draw_line(buf, 24, h - 10, w - 24, h - 10, soft, 1)
    for cx in (96, 180, 264):
        fill_circle(buf, cx, 41, 30, (255, 215, 0, 42))
        fill_circle(buf, cx, 41, 23, (15, 42, 34, 205))
    save_rgba(buf, UI_OUT / "hud_spell_dock_frame.png")

    # Boss banner.
    w, h = 640, 80
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 3, 4, w - 3, h - 4, hex_to_rgba(TOKENS["bg.panel"], 230))
    _draw_gold_frame(buf, w, h, {0: hex_to_rgba("#4A3A13"), 1: gold, 2: soft, 6: hex_to_rgba(TOKENS["accent.gold"], 90)})
    fill_circle(buf, w // 2, h // 2, 9, hex_to_rgba(TOKENS["elem.water"]))
    _draw_cloud_scroll(buf, 52, h // 2, 200, soft)
    _draw_cloud_scroll(buf, w - 52, h // 2, 200, soft, True)
    save_rgba(buf, UI_OUT / "boss_banner_640x80.png")

    # Enemy HP.
    w, h = 56, 12
    buf = new_canvas(w, h, (0, 0, 0, 0))
    fill_rect(buf, 0, 2, w, h - 2, (0, 0, 0, 150))
    for x in range(2, w - 2):
        fill_rect(buf, x, 4, x + 1, h - 4, lerp_color(hex_to_rgba(TOKENS["state.hp"]), hex_to_rgba(TOKENS["state.hp_end"]), x / w))
    save_rgba(buf, UI_OUT / "enemy_hp_bar_9slice.png")


def gen_tags_and_badges() -> None:
    tags = [
        ("tag_common.png", 64, 24, TOKENS["quality.common"]),
        ("tag_rare.png", 64, 24, TOKENS["quality.rare"]),
        ("tag_epic.png", 64, 24, TOKENS["quality.epic"]),
        ("tag_ice.png", 80, 20, TOKENS["elem.water"]),
        ("tag_thunder.png", 80, 20, TOKENS["elem.thunder"]),
        ("tag_fire.png", 80, 20, TOKENS["elem.fire"]),
    ]
    for filename, w, h, color in tags:
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        _draw_rounded_frame(img, (1, 1, w - 2, h - 2), 5, hex_to_rgba(TOKENS["bg.panel"], 180), hex_to_rgba(color), 1)
        _save_transparent_pil(img, UI_OUT / filename)

    # Talent effect badges.
    specs = [
        ("attack", TOKENS["elem.fire"], _draw_sword_icon),
        ("defense", TOKENS["elem.earth"], _draw_shield_icon),
        ("spirit", TOKENS["elem.water"], _draw_lotus_icon),
        ("utility", TOKENS["elem.chaos"], _draw_scroll_icon),
    ]
    for name, color, drawer in specs:
        buf = new_canvas(24, 24, (0, 0, 0, 0))
        fill_circle(buf, 12, 12, 11, hex_to_rgba(TOKENS["bg.panel"], 220))
        drawer(buf, hex_to_rgba(color))
        save_rgba(buf, UI_OUT / f"talent_badge_{name}.png")

    # Corner and training badges.
    buf = new_canvas(32, 32, (0, 0, 0, 0))
    gold = hex_to_rgba(TOKENS["accent.gold_soft"])
    for y in range(1, 31):
        for x in range(31 - y, 31):
            set_px(buf, x, y, gold)
    draw_line(buf, 20, 13, 24, 18, hex_to_rgba(TOKENS["bg.panel"]), 2)
    draw_line(buf, 24, 18, 30, 8, hex_to_rgba(TOKENS["bg.panel"]), 2)
    save_rgba(buf, UI_OUT / "badge_owned_32.png")

    img = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
    _draw_rounded_frame(img, (1, 1, 46, 14), 4, hex_to_rgba(TOKENS["bg.panel"], 180), hex_to_rgba(TOKENS["elem.water"]), 1)
    _save_transparent_pil(img, UI_OUT / "badge_training_48x16.png")


def _draw_shield_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    pts = [(12, 4), (20, 8), (18, 18), (12, 22), (6, 18), (4, 8)]
    for i in range(len(pts)):
        draw_line(buf, pts[i][0], pts[i][1], pts[(i + 1) % len(pts)][0], pts[(i + 1) % len(pts)][1], c, 2)


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


def gen_large_and_realm_icons() -> None:
    large = [
        ("ice", TOKENS["elem.water"], _draw_large_snowflake),
        ("thunder", TOKENS["elem.thunder"], _draw_large_lightning),
        ("fire", TOKENS["elem.fire"], _draw_large_flame),
    ]
    for name, color, drawer in large:
        buf = new_canvas(80, 80, (0, 0, 0, 0))
        drawer(buf, hex_to_rgba(color))
        save_rgba(buf, UI_OUT / f"elem_{name}_large_80.png")

    realms = [
        (1, TOKENS["elem.wood"], _draw_wood_icon),
        (2, TOKENS["elem.earth"], _draw_earth_icon),
        (3, TOKENS["elem.fire"], _draw_fire_icon),
        (4, TOKENS["elem.thunder"], _draw_thunder_icon),
        (5, TOKENS["elem.chaos"], _draw_chaos_icon),
    ]
    for idx, color, drawer in realms:
        buf = new_canvas(48, 48, (0, 0, 0, 0))
        fill_circle(buf, 24, 24, 22, hex_to_rgba(TOKENS["bg.panel"], 220))
        fill_circle(buf, 24, 24, 18, (hex_to_rgba(color)[0], hex_to_rgba(color)[1], hex_to_rgba(color)[2], 45))
        # Draw the existing 32px icon centered inside 48px canvas by drawing to temp.
        tmp = new_canvas(32, 32, (0, 0, 0, 0))
        drawer(tmp, hex_to_rgba(color))
        for y in range(32):
            for x in range(32):
                if tmp[y][x][3]:
                    set_px(buf, x + 8, y + 8, tmp[y][x])
        save_rgba(buf, UI_OUT / f"talent_icon_realm_{idx}.png")


def _draw_large_snowflake(buf: List[List[RGBA]], c: RGBA) -> None:
    import math
    cx, cy = 40, 40
    fill_circle(buf, cx, cy, 28, (c[0], c[1], c[2], 35))
    for i in range(6):
        a = i * math.pi / 3
        x1 = cx + int(30 * math.cos(a))
        y1 = cy + int(30 * math.sin(a))
        draw_line(buf, cx, cy, x1, y1, c, 2)
        for off in (-0.55, 0.55):
            bx = cx + int(18 * math.cos(a))
            by = cy + int(18 * math.sin(a))
            draw_line(buf, bx, by, bx + int(9 * math.cos(a + off)), by + int(9 * math.sin(a + off)), c, 1)


def _draw_large_lightning(buf: List[List[RGBA]], c: RGBA) -> None:
    pts = [(48, 8), (28, 40), (42, 40), (28, 72), (58, 32), (44, 32), (60, 8)]
    for i in range(len(pts) - 1):
        draw_line(buf, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], c, 5)
        draw_line(buf, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], (255, 255, 255, 170), 1)


def _draw_large_flame(buf: List[List[RGBA]], c: RGBA) -> None:
    pts = [(40, 8), (58, 42), (48, 72), (32, 72), (22, 44), (32, 28)]
    for i in range(len(pts)):
        draw_line(buf, pts[i][0], pts[i][1], pts[(i + 1) % len(pts)][0], pts[(i + 1) % len(pts)][1], c, 4)
    fill_circle(buf, 40, 52, 12, hex_to_rgba(TOKENS["accent.gold"]))


def gen_functional_icons() -> None:
    # Spirit stone, heal, dodge.
    icon_specs = [
        ("icon_spirit_stone_32.png", 32, TOKENS["accent.gold"], _draw_gem_icon),
        ("icon_heal_32.png", 32, TOKENS["elem.water"], _draw_lotus_icon),
        ("icon_dodge_32.png", 32, TOKENS["elem.water"], _draw_dodge_icon),
        ("icon_reroll_24.png", 24, TOKENS["accent.gold"], _draw_reroll_icon),
        ("icon_skip_24.png", 24, TOKENS["text.secondary"], _draw_skip_icon),
        ("icon_heart_demon_trial_24.png", 24, TOKENS["quality.dao"], _draw_demon_eye_icon),
        ("bt_slot_arrow_32.png", 32, TOKENS["accent.gold"], _draw_arrow_icon),
    ]
    for filename, size, color, drawer in icon_specs:
        buf = new_canvas(size, size, (0, 0, 0, 0))
        drawer(buf, hex_to_rgba(color))
        save_rgba(buf, UI_OUT / filename)

    karma_specs = [
        ("good", TOKENS["accent.gold"], _draw_good_dot),
        ("evil", TOKENS["state.debuff"], _draw_evil_dot),
        ("greed", TOKENS["quality.legendary"], _draw_greed_dot),
        ("rebellion", TOKENS["elem.chaos"], _draw_rebellion_dot),
        ("dao_heart", TOKENS["accent.gold"], _draw_dao_star_dot),
    ]
    for name, color, drawer in karma_specs:
        buf = new_canvas(16, 16, (0, 0, 0, 0))
        drawer(buf, hex_to_rgba(color))
        save_rgba(buf, UI_OUT / f"karma_{name}_16.png")


def _draw_gem_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    pts = [(16, 3), (27, 12), (22, 28), (10, 28), (5, 12)]
    for i in range(len(pts)):
        draw_line(buf, pts[i][0], pts[i][1], pts[(i + 1) % len(pts)][0], pts[(i + 1) % len(pts)][1], c, 2)
    fill_circle(buf, 16, 15, 6, (c[0], c[1], c[2], 120))


def _draw_dodge_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 4, 22, 24, 10, c, 2)
    draw_line(buf, 8, 26, 28, 15, (c[0], c[1], c[2], 120), 1)
    fill_circle(buf, 20, 12, 4, c)


def _draw_reroll_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 6, 8, 16, 8, c, 2)
    draw_line(buf, 16, 8, 14, 5, c, 2)
    draw_line(buf, 18, 16, 8, 16, c, 2)
    draw_line(buf, 8, 16, 10, 19, c, 2)


def _draw_skip_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 5, 7, 13, 12, c, 2)
    draw_line(buf, 13, 12, 5, 17, c, 2)
    draw_line(buf, 13, 7, 21, 12, c, 2)
    draw_line(buf, 21, 12, 13, 17, c, 2)


def _draw_demon_eye_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 4, 12, 12, 7, c, 2)
    draw_line(buf, 12, 7, 20, 12, c, 2)
    draw_line(buf, 4, 12, 12, 17, c, 2)
    draw_line(buf, 12, 17, 20, 12, c, 2)
    fill_circle(buf, 12, 12, 3, hex_to_rgba(TOKENS["elem.chaos"]))


def _draw_arrow_icon(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 6, 16, 24, 16, c, 2)
    draw_line(buf, 24, 16, 18, 10, c, 2)
    draw_line(buf, 24, 16, 18, 22, c, 2)


def _draw_good_dot(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_circle(buf, 8, 8, 6, (245, 245, 230, 210))
    fill_circle(buf, 8, 8, 3, c)


def _draw_evil_dot(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 8, 2, 12, 8, c, 2)
    draw_line(buf, 12, 8, 8, 14, c, 2)
    draw_line(buf, 8, 14, 4, 8, c, 2)
    draw_line(buf, 4, 8, 8, 2, c, 2)


def _draw_greed_dot(buf: List[List[RGBA]], c: RGBA) -> None:
    fill_circle(buf, 8, 8, 6, c)
    draw_line(buf, 5, 8, 11, 8, hex_to_rgba(TOKENS["bg.panel"]), 1)


def _draw_rebellion_dot(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 8, 14, 8, 3, c, 2)
    draw_line(buf, 8, 3, 4, 8, c, 2)
    draw_line(buf, 8, 3, 12, 8, c, 2)


def _draw_dao_star_dot(buf: List[List[RGBA]], c: RGBA) -> None:
    draw_line(buf, 8, 1, 8, 15, c, 1)
    draw_line(buf, 1, 8, 15, 8, c, 1)
    draw_line(buf, 4, 4, 12, 12, c, 1)
    draw_line(buf, 12, 4, 4, 12, c, 1)
    fill_circle(buf, 8, 8, 3, c)


def gen_event_illustration() -> None:
    w, h = 560, 96
    buf = new_canvas(w, h, hex_to_rgba(TOKENS["bg.deep"]))
    for y in range(h):
        c = lerp_color(hex_to_rgba("#06140F"), hex_to_rgba("#1B4438"), y / h)
        fill_rect(buf, 0, y, w, y + 1, c)
    mountain = hex_to_rgba(TOKENS["bg.panel_alt"])
    for i, ybase in enumerate((74, 66, 58)):
        c = (mountain[0], mountain[1], mountain[2], 170 - i * 35)
        pts = [(0, h), (40, ybase), (98, ybase - 18), (160, ybase + 6), (238, ybase - 24), (330, ybase + 8), (430, ybase - 20), (w, ybase + 2), (w, h)]
        for j in range(len(pts) - 1):
            draw_line(buf, pts[j][0], pts[j][1], pts[j + 1][0], pts[j + 1][1], c, 2)
    for y in (54, 66, 78):
        draw_line(buf, 20, y, w - 20, y, (220, 235, 225, 28), 2)
    gold = hex_to_rgba(TOKENS["accent.gold_soft"])
    draw_line(buf, 270, 72, 290, 58, gold, 1)
    draw_line(buf, 290, 58, 310, 72, gold, 1)
    save_rgba(buf, UI_OUT / "event_illustration_560x96.png")


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
    import math

    hearts = [
        ("ask", TOKENS["elem.water"]),
        ("enlighten", TOKENS["accent.gold"]),
        ("prove", TOKENS["quality.dao"]),
    ]
    gold = hex_to_rgba(TOKENS["accent.gold"])
    gold_soft = hex_to_rgba(TOKENS["accent.gold_soft"])
    light = hex_to_rgba(TOKENS["text.primary"])
    for name, accent_hex in hearts:
        buf = new_canvas(128, 128, (0, 0, 0, 0))
        accent = hex_to_rgba(accent_hex)
        cx, cy, r = 64, 62, 42
        # circular medallion: soft accent halo -> dark jade disc -> gold double ring
        fill_circle(buf, cx, cy, r, (accent[0], accent[1], accent[2], 40))
        fill_circle(buf, cx, cy, r - 5, hex_to_rgba(TOKENS["bg.panel"]))
        for a in range(0, 360, 2):
            rad = math.radians(a)
            for rr in (r - 5, r - 4, r - 3):
                set_px(buf, cx + int(rr * math.cos(rad)), cy + int(rr * math.sin(rad)), gold)
            set_px(buf, cx + int((r - 9) * math.cos(rad)), cy + int((r - 9) * math.sin(rad)), gold_soft)
        if name == "ask":
            _draw_taiji(buf, cx, cy, 24, accent, hex_to_rgba(TOKENS["bg.deep"]), light)
        elif name == "enlighten":
            fill_circle(buf, cx, cy, 11, gold)
            fill_circle(buf, cx, cy, 7, gold_soft)
            for i in range(12):
                a = i * math.pi / 6
                draw_line(
                    buf,
                    cx + int(16 * math.cos(a)), cy + int(16 * math.sin(a)),
                    cx + int(26 * math.cos(a)), cy + int(26 * math.sin(a)),
                    gold, 2,
                )
        else:
            _draw_crossed_swords(buf, cx, cy, gold, accent, light)
        save_rgba(buf, UI_OUT / f"dao_heart_{name}_128.png")


def _draw_taiji(buf, cx, cy, r, light_c, dark_c, eye_c) -> None:
    half = r // 2
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 > r * r:
                continue
            top_d = (x - cx) ** 2 + (y - (cy - half)) ** 2
            bot_d = (x - cx) ** 2 + (y - (cy + half)) ** 2
            if top_d <= half * half:
                c = light_c
            elif bot_d <= half * half:
                c = dark_c
            elif x < cx:
                c = light_c
            else:
                c = dark_c
            set_px(buf, x, y, (c[0], c[1], c[2], 255))
    fill_circle(buf, cx, cy - half, 3, dark_c)
    fill_circle(buf, cx, cy + half, 3, eye_c)


def _draw_crossed_swords(buf, cx, cy, gold, accent, light) -> None:
    for dx in (-1, 1):
        # blade
        draw_line(buf, cx - dx * 18, cy + 20, cx + dx * 18, cy - 20, light, 3)
        draw_line(buf, cx - dx * 18, cy + 20, cx + dx * 18, cy - 20, gold, 1)
        # cross-guard near the hilt (bottom)
        draw_line(buf, cx - dx * 22, cy + 14, cx - dx * 12, cy + 24, gold, 2)
        # pommel
        fill_circle(buf, cx - dx * 20, cy + 22, 3, gold)


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


# ---------------------------------------------------------------------------
# Ink-Pixel Hybrid assets (水墨像素融合风)
# ---------------------------------------------------------------------------

def gen_ink_pixel_player() -> None:
    """64×64 ink-pixel cultivator silhouette with golden meridian lines."""
    palette = {
        "K": hex_to_rgba(TOKENS["ink.dark"]),    # 墨玄 - silhouette body
        "D": hex_to_rgba(TOKENS["ink.mid"]),     # 淡墨 - edge/robe
        "T": hex_to_rgba(TOKENS["ink.light"]),   # 雾灰 - flowing robe tips
        "G": hex_to_rgba(TOKENS["ink.gold"]),     # 冷金 - meridian lines
        "J": hex_to_rgba(TOKENS["ink.jade"]),     # 玉青 - spiritual energy
        "B": hex_to_rgba(TOKENS["ink.thunder"]),  # 雷蓝 - sword glow
        "R": hex_to_rgba(TOKENS["ink.fire"]),     # 炎橙 - sword body
        "W": hex_to_rgba(TOKENS["ink.frost"]),    # 霜白 - eyes/highlight
    }
    # 16×16 template, 4x scale = 64×64
    # Character: sword cultivator standing, right hand holding sword, left hand in sword seal
    art = """
......WK......
.....WKKW.....
....KKKKKK....
....KGGGKK....
.....KGGK.....
....RGGGGR....
...RRGBGGR....
...R.KKKK.R...
..TT.KGGK.TT..
..T..KG.GK..T.
.....K..K.....
....KK..KK....
....KK..KK....
...DDDDDDDD...
...DDD..DDD...
...TT....TT...
"""
    buf = new_canvas(64, 64, (0, 0, 0, 0))
    _draw_pixel_sprite(buf, art, palette, 4)
    save_rgba(buf, SPRITE_OUT / "player_ink_pixel_64.png")

    # 128×128 variant (2x of the 64px version)
    buf128 = new_canvas(128, 128, (0, 0, 0, 0))
    _draw_pixel_sprite(buf128, art, palette, 8)
    save_rgba(buf128, SPRITE_OUT / "player_ink_pixel_128.png")


def gen_ink_pixel_enemy_variants() -> None:
    """Ink-pixel enemy sprites: berserker, archer, bomber, elite."""
    enemies = {
        "berserker": ("""
....RRRR....
...RRRRRR...
..RRRRRRRR..
..RRWWWWRR..
..RRRRRRRR..
...RRRRRR...
....RRRR....
....RR.RR...
....RR.RR...
....RR.RR...
""", {
            "R": hex_to_rgba(TOKENS["ink.dark"]),
            "W": hex_to_rgba(TOKENS["ink.fire"]),
            "G": hex_to_rgba(TOKENS["ink.gold"]),
        }),
        "archer": ("""
....DDDD....
...DDDDDD...
..DDDDDDDD..
..DDJJJJDD..
..DDDDDDDD..
...DD..DD...
....DDDD....
....DDDD....
....DD.DD...
....DD.DD...
""", {
            "D": hex_to_rgba(TOKENS["ink.mid"]),
            "J": hex_to_rgba(TOKENS["ink.jade"]),
            "G": hex_to_rgba(TOKENS["ink.gold"]),
        }),
        "bomber": ("""
....BBBB....
...BBBBBB...
..BBBBBBBB..
..BBYYYYBB..
..BBBBBBBB..
...BBBBBB...
....BBBB....
....BB.BB...
....BB.BB...
....BB.BB...
""", {
            "B": hex_to_rgba(TOKENS["ink.thunder"]),
            "Y": hex_to_rgba(TOKENS["ink.fire"]),
            "G": hex_to_rgba(TOKENS["ink.gold"]),
        }),
        "elite": ("""
...GKKKKG...
..GKKKKKKG..
..KKKKKKKK..
..KKWWWKKK..
..KKKKKKKK..
..GKKKKKKG..
...GKKKKG...
....KK.KK...
....KK.KK...
....KK.KK...
""", {
            "K": hex_to_rgba(TOKENS["ink.dark"]),
            "G": hex_to_rgba(TOKENS["ink.gold"]),
            "W": hex_to_rgba(TOKENS["ink.frost"]),
        }),
    }
    for name, (art, pal) in enemies.items():
        buf = new_canvas(64, 64, (0, 0, 0, 0))
        _draw_pixel_sprite(buf, art, pal, 4)
        save_rgba(buf, SPRITE_OUT / f"enemy_ink_{name}_64.png")


def gen_ink_pixel_projectiles() -> None:
    """Ink-pixel projectile sprites: talisman, ink drop, lightning stroke."""
    projectiles = {
        "talisman": ("""
..G..
.GGG.
GJGJG
.GGG.
..G..
""", {
            "G": hex_to_rgba(TOKENS["ink.gold"]),
            "J": hex_to_rgba(TOKENS["ink.jade"]),
        }),
        "ink_drop": ("""
..K..
.KKK.
KKKKK
KKKKK
.KKK.
..K..
""", {
            "K": hex_to_rgba(TOKENS["ink.dark"]),
        }),
        "lightning": ("""
..B..
.BBB.
BBBBB
.BBB.
..B..
""", {
            "B": hex_to_rgba(TOKENS["ink.thunder"]),
        }),
        "fire_bolt": ("""
..R..
.RRR.
RRRRR
.RRR.
..R..
""", {
            "R": hex_to_rgba(TOKENS["ink.fire"]),
        }),
        "frost_shard": ("""
..W..
.WWW.
WWWWW
.WWW.
..W..
""", {
            "W": hex_to_rgba(TOKENS["ink.frost"]),
        }),
    }
    for name, (art, pal) in projectiles.items():
        buf = new_canvas(16, 16, (0, 0, 0, 0))
        _draw_pixel_sprite(buf, art, pal, 2)
        save_rgba(buf, SPRITE_OUT / f"projectile_ink_{name}_16.png")


def gen_ink_pixel_pet() -> None:
    """32×32 ink-pixel fire pet (jade firefly)."""
    palette = {
        "J": hex_to_rgba(TOKENS["ink.jade"]),
        "G": hex_to_rgba(TOKENS["ink.gold"]),
        "K": hex_to_rgba(TOKENS["ink.dark"]),
    }
    art = """
....JJJJ....
...JJJJJJ...
..JJJGGJJJ..
..JJJJJJJJ..
...JJJJJJ...
....JJJJ....
...JJ..JJ...
...JJ..JJ...
"""
    buf = new_canvas(32, 32, (0, 0, 0, 0))
    _draw_pixel_sprite(buf, art, palette, 2)
    save_rgba(buf, SPRITE_OUT / "pet_ink_jade_32.png")


MAP_OUT = ROOT / "assets" / "maps"


def _ink_wash_background(w: int, h: int, base_color: RGBA, accent_color: RGBA,
                          crack_color: RGBA, stage_seed: int = 0) -> List[List[RGBA]]:
    """Generate an ink-wash style background with procedural noise and cracks."""
    import random
    rng = random.Random(stage_seed)
    buf = new_canvas(w, h, base_color)

    # Ink wash gradient: darker at edges, lighter in center
    cx, cy = w // 2, h // 2
    max_dist = (cx ** 2 + cy ** 2) ** 0.5
    for y in range(h):
        for x in range(w):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            t = dist / max_dist
            # Darken edges
            edge_darken = int(t * 40)
            r = max(0, base_color[0] - edge_darken)
            g = max(0, base_color[1] - edge_darken)
            b = max(0, base_color[2] - edge_darken)
            # Add subtle ink variation
            noise = rng.randint(-8, 8)
            r = max(0, min(255, r + noise))
            g = max(0, min(255, g + noise))
            b = max(0, min(255, b + noise))
            set_px(buf, x, y, (r, g, b, 255))

    # Ink cracks / veins (like the existing map style)
    for _ in range(12):
        x = rng.randint(0, w - 1)
        y = rng.randint(0, h - 1)
        length = rng.randint(40, 120)
        angle = rng.uniform(0, 6.28)
        for step in range(length):
            nx = int(x + step * 0.8 * __import__('math').cos(angle))
            ny = int(y + step * 0.8 * __import__('math').sin(angle))
            # Crack with slight randomness
            nx += rng.randint(-2, 2)
            ny += rng.randint(-2, 2)
            thickness = max(1, 3 - step // 30)
            for dy in range(-thickness, thickness + 1):
                for dx in range(-thickness, thickness + 1):
                    alpha = max(0, 180 - step * 2)
                    set_px(buf, nx + dx, ny + dy,
                           (crack_color[0], crack_color[1], crack_color[2], alpha))
            angle += rng.uniform(-0.3, 0.3)

    # Accent glow spots (jade/gold energy pools)
    for _ in range(6):
        gx = rng.randint(w // 4, 3 * w // 4)
        gy = rng.randint(h // 4, 3 * h // 4)
        gr = rng.randint(15, 40)
        for dy in range(-gr, gr + 1):
            for dx in range(-gr, gr + 1):
                d = (dx ** 2 + dy ** 2) ** 0.5
                if d < gr:
                    alpha = int(60 * (1.0 - d / gr))
                    set_px(buf, gx + dx, gy + dy,
                           (accent_color[0], accent_color[1], accent_color[2], alpha))

    return buf


def gen_ink_pixel_maps() -> None:
    """Generate ink-pixel style map backgrounds for all 4 stages."""
    stages = [
        ("qi_refining_verdant", (18, 32, 28), (61, 122, 110), (90, 160, 140), 42),
        ("golden_core_demon", (25, 18, 14), (212, 116, 62), (196, 168, 106), 77),
        ("nascent_soul_ruins", (20, 22, 30), (91, 140, 206), (160, 180, 210), 123),
        ("tribulation_thunder", (14, 16, 24), (196, 168, 106), (91, 140, 206), 256),
    ]
    MAP_OUT.mkdir(parents=True, exist_ok=True)
    for stage_id, base, accent, crack, seed in stages:
        stage_dir = MAP_OUT / stage_id
        stage_dir.mkdir(parents=True, exist_ok=True)
        bg = _ink_wash_background(1280, 720, base, accent, crack, seed)
        save_rgba(bg, stage_dir / "room_background_ink.png")
        # Tileset: 128×128 (4×4 grid of 32px tiles) with ink texture
        tile_buf = new_canvas(128, 128, (0, 0, 0, 0))
        tile_rng = random.Random(seed + 100)
        tile_colors = [
            base,
            (base[0] + 8, base[1] + 8, base[2] + 8, 255),
            (base[0] - 5, base[1] - 5, base[2] - 5, 255),
            (accent[0] // 3 + base[0] // 3 * 2,
             accent[1] // 3 + base[1] // 3 * 2,
             accent[2] // 3 + base[2] // 3 * 2, 255),
        ]
        for ty in range(4):
            for tx in range(4):
                tc = tile_colors[(tx + ty) % len(tile_colors)]
                for dy in range(32):
                    for dx in range(32):
                        noise = tile_rng.randint(-6, 6)
                        r = max(0, min(255, tc[0] + noise))
                        g = max(0, min(255, tc[1] + noise))
                        b = max(0, min(255, tc[2] + noise))
                        set_px(tile_buf, tx * 32 + dx, ty * 32 + dy, (r, g, b, 255))
        save_rgba(tile_buf, stage_dir / "tileset_ink.png")


def gen_ink_pixel_talent_icons() -> None:
    """Generate ink-pixel talent/breakthrough selection icons."""
    icons = {
        "attack": {
            "bg": hex_to_rgba(TOKENS["ink.dark"]),
            "fg": hex_to_rgba(TOKENS["ink.fire"]),
            "accent": hex_to_rgba(TOKENS["ink.gold"]),
            "symbol": """
....GG....
...GGGG...
..GRRRRG..
..RRRRRR..
..RRRRRR..
..GRRRRG..
...GGGG...
....GG....
""",
        },
        "defense": {
            "bg": hex_to_rgba(TOKENS["ink.dark"]),
            "fg": hex_to_rgba(TOKENS["ink.jade"]),
            "accent": hex_to_rgba(TOKENS["ink.gold"]),
            "symbol": """
...GGGG...
..GJJJG..
..JJJJJ..
..JGGGJ..
..JJJJJ..
..GJJJG..
...GGGG...
""",
        },
        "spirit": {
            "bg": hex_to_rgba(TOKENS["ink.dark"]),
            "fg": hex_to_rgba(TOKENS["ink.thunder"]),
            "accent": hex_to_rgba(TOKENS["ink.gold"]),
            "symbol": """
....GG....
...GBBG...
..GBBBBG..
..BBBBBB..
..GBBBBG..
...GBBG...
....GG....
""",
        },
        "utility": {
            "bg": hex_to_rgba(TOKENS["ink.dark"]),
            "fg": hex_to_rgba(TOKENS["ink.frost"]),
            "accent": hex_to_rgba(TOKENS["ink.gold"]),
            "symbol": """
...GGGG...
..GWWWWG..
..WWWWWW..
..WGGGW..
..WWWWWW..
..GWWWWG..
...GGGG...
""",
        },
        "realm": {
            "bg": hex_to_rgba(TOKENS["ink.dark"]),
            "fg": hex_to_rgba(TOKENS["ink.gold"]),
            "accent": hex_to_rgba(TOKENS["ink.jade"]),
            "symbol": """
....GG....
...GJJG...
..GJJJJG..
..JJJJJJ..
..GJJJJG..
...GJJG...
....GG....
""",
        },
    }
    UI_OUT.mkdir(parents=True, exist_ok=True)
    for name, cfg in icons.items():
        buf = new_canvas(64, 64, cfg["bg"])
        # Draw circular bg with slight gradient
        for y in range(64):
            for x in range(64):
                d = ((x - 32) ** 2 + (y - 32) ** 2) ** 0.5
                if d < 28:
                    edge_fade = max(0.0, 1.0 - (d / 28.0) ** 2)
                    r = int(cfg["bg"][0] * (0.6 + 0.4 * edge_fade))
                    g = int(cfg["bg"][1] * (0.6 + 0.4 * edge_fade))
                    b = int(cfg["bg"][2] * (0.6 + 0.4 * edge_fade))
                    set_px(buf, x, y, (r, g, b, 255))
        # Draw symbol
        palette = {
            "G": cfg["accent"],
            "R": cfg["fg"],
            "J": cfg["fg"],
            "B": cfg["fg"],
            "W": cfg["fg"],
        }
        _draw_pixel_sprite(buf, cfg["symbol"], palette, 4)
        # Gold ring border
        for y in range(64):
            for x in range(64):
                d = ((x - 32) ** 2 + (y - 32) ** 2) ** 0.5
                if 27 <= d <= 29:
                    set_px(buf, x, y, cfg["accent"])
        save_rgba(buf, UI_OUT / f"talent_icon_ink_{name}_64.png")


def main() -> int:
    ensure_pillow()
    UI_OUT.mkdir(parents=True, exist_ok=True)
    SPRITE_OUT.mkdir(parents=True, exist_ok=True)

    print("Generating UI assets...")
    gen_bg_jade_palace()
    gen_breakthrough_bg_overlay()
    gen_panel_ninepatch()
    gen_decorative_frames_and_buttons()
    gen_scroll_toast_banner()
    gen_hud_panel_bg()
    gen_hud_dedicated_frames()
    gen_modal_title_bar()
    gen_divider_gold()
    gen_tags_and_badges()
    gen_path_icons()
    gen_event_banner()
    gen_event_illustration()
    gen_talent_scroll_frame()
    gen_pet_avatar_ring()
    gen_combo_track()
    gen_element_icons()
    gen_large_and_realm_icons()
    gen_functional_icons()
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
