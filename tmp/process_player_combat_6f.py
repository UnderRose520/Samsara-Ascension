from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


JOBS = [
    ("player_style_normal", Path("output/imagegen/player_actions/player_style_normal_combat_2x3_raw.png")),
    ("player_style_chibi", Path("output/imagegen/player_actions/player_style_chibi_combat_2x3_raw.png")),
]


def remove_magenta(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    arr = np.array(rgba)
    rgb = arr[:, :, :3].astype(np.int16)
    magenta = np.array([255, 0, 255], dtype=np.int16)
    dist = np.abs(rgb - magenta).sum(axis=2)
    mask = dist < 90
    arr[mask, 3] = 0
    return Image.fromarray(arr, mode="RGBA")


def largest_component_bbox(alpha: np.ndarray) -> tuple[int, int, int, int] | None:
    h, w = alpha.shape
    seen = np.zeros((h, w), dtype=bool)
    best: tuple[int, int, int, int, int] | None = None
    ys, xs = np.nonzero(alpha > 0)
    points = list(zip(xs.tolist(), ys.tolist()))
    for sx, sy in points:
        if seen[sy, sx]:
            continue
        q: deque[tuple[int, int]] = deque([(sx, sy)])
        seen[sy, sx] = True
        min_x = max_x = sx
        min_y = max_y = sy
        area = 0
        while q:
            x, y = q.popleft()
            area += 1
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if nx < 0 or ny < 0 or nx >= w or ny >= h or seen[ny, nx] or alpha[ny, nx] == 0:
                    continue
                seen[ny, nx] = True
                q.append((nx, ny))
        if best is None or area > best[0]:
            best = (area, min_x, min_y, max_x + 1, max_y + 1)
    if best is None:
        return None
    _, x0, y0, x1, y1 = best
    return (x0, y0, x1, y1)


def process(slug: str, raw_path: Path) -> dict:
    raw = remove_magenta(Image.open(raw_path))
    rows, cols = 2, 3
    cell_size = 64
    cell_w = raw.width // cols
    cell_h = raw.height // rows
    cropped: list[Image.Image] = []
    frame_meta: list[dict] = []
    for row in range(rows):
        for col in range(cols):
            source_box = (col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)
            cell = raw.crop(source_box)
            alpha = np.array(cell.getchannel("A"))
            bbox = largest_component_bbox(alpha)
            edge_touch = False
            if bbox:
                x0, y0, x1, y1 = bbox
                pad = 4
                x0 = max(0, x0 - pad)
                y0 = max(0, y0 - pad)
                x1 = min(cell.width, x1 + pad)
                y1 = min(cell.height, y1 + pad)
                edge_touch = x0 <= 0 or y0 <= 0 or x1 >= cell.width or y1 >= cell.height
                cell = cell.crop((x0, y0, x1, y1))
            else:
                cell = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
            cropped.append(cell)
            frame_meta.append({"grid": [row, col], "source_box": source_box, "crop_bbox": bbox, "edge_touch": edge_touch})

    max_w = max(frame.width for frame in cropped)
    max_h = max(frame.height for frame in cropped)
    scale = min(cell_size / max_w, cell_size / max_h) * 0.86
    out_dir = Path("output/imagegen/player_actions/processed") / f"{slug}_combat_6f"
    out_dir.mkdir(parents=True, exist_ok=True)
    frames: list[Image.Image] = []
    for index, frame in enumerate(cropped):
        w = max(1, int(frame.width * scale))
        h = max(1, int(frame.height * scale))
        resized = frame.resize((w, h), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
        x = (cell_size - w) // 2
        y = cell_size - h - 4
        canvas.alpha_composite(resized, (x, y))
        canvas.save(out_dir / f"combat-{index + 1}.png")
        frames.append(canvas)
        frame_meta[index]["output_size"] = [w, h]
        frame_meta[index]["paste_position"] = [x, y]

    gif_path = out_dir / "animation.gif"
    frames[0].save(gif_path, save_all=True, append_images=frames[1:], duration=65, loop=0, disposal=2)
    meta = {
        "input": str(raw_path),
        "rows": rows,
        "cols": cols,
        "cell_size": cell_size,
        "fit_scale": 0.86,
        "align": "feet",
        "shared_scale": True,
        "frames": frame_meta,
        "edge_touch_frames": [item["grid"] for item in frame_meta if item["edge_touch"]],
    }
    (out_dir / "pipeline-meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return meta


def main() -> int:
    result = {slug: process(slug, raw_path) for slug, raw_path in JOBS}
    print(json.dumps({slug: meta["edge_touch_frames"] for slug, meta in result.items()}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
