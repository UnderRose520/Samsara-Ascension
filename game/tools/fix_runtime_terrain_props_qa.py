#!/usr/bin/env python3
"""Tighten runtime terrain prop atlases so they satisfy visual QA contracts."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[2]
MAP_ROOT = ROOT / "game" / "assets" / "maps"
CELL = 128
GRID = 3
TARGET_SIZE = CELL * GRID

PALETTE_ACCENTS = {
    "qi_refining_verdant": ((99, 226, 162), (210, 177, 92)),
    "foundation_cavern": ((88, 214, 224), (166, 214, 186)),
    "golden_core_demon": ((238, 93, 70), (169, 84, 210)),
    "nascent_soul_ruins": ((216, 181, 96), (124, 180, 224)),
    "tribulation_thunder": ((116, 184, 255), (218, 190, 98)),
}


def _trim_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


def _safe_cell(cell: Image.Image) -> Image.Image:
    content = _trim_alpha(cell.convert("RGBA"))
    if content.getchannel("A").getbbox() is None:
        return cell
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    content.thumbnail((CELL - 28, CELL - 28), Image.Resampling.LANCZOS)
    canvas.alpha_composite(content, ((CELL - content.width) // 2, (CELL - content.height) // 2))
    return canvas


def _accent_cell(cell: Image.Image, stage_id: str, col: int, row: int) -> Image.Image:
    first, second = PALETTE_ACCENTS.get(stage_id, ((100, 210, 180), (210, 180, 96)))
    out = cell.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    if col == 2:
        if row == 0:
            draw.line((38, 88, 90, 42), fill=(*first, 150), width=3)
            draw.arc((30, 34, 100, 98), 205, 325, fill=(*second, 105), width=2)
        elif row == 1:
            draw.rectangle((42, 43, 86, 85), outline=(*second, 135), width=3)
            draw.line((45, 72, 82, 48), fill=(*first, 120), width=2)
        else:
            draw.ellipse((36, 50, 93, 78), outline=(*first, 135), width=3)
            draw.line((46, 82, 84, 93), fill=(*second, 110), width=2)
    elif col == 0:
        if row == 1:
            draw.line((36, 76, 96, 50), fill=(*first, 120), width=2)
        elif row == 2:
            draw.arc((35, 43, 98, 91), 160, 285, fill=(*second, 105), width=2)
    return out


def fix_atlas(path: Path) -> None:
    stage_id = path.parent.name
    image = Image.open(path).convert("RGBA")
    image = ImageOps.fit(image, (TARGET_SIZE, TARGET_SIZE), method=Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (TARGET_SIZE, TARGET_SIZE), (0, 0, 0, 0))
    for row in range(GRID):
        for col in range(GRID):
            box = (col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL)
            cell = _safe_cell(image.crop(box))
            cell = _accent_cell(cell, stage_id, col, row)
            out.alpha_composite(cell, (col * CELL, row * CELL))
    out.save(path)
    print(f"fixed {path}")


def main() -> int:
    for path in sorted(MAP_ROOT.glob("*/terrain_props.png")):
        fix_atlas(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
