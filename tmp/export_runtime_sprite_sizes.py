from __future__ import annotations

from pathlib import Path

from PIL import Image


JOBS = [
    {
        "src": Path("output/imagegen/batch_hd/samsara_jade_cultivator_hd_simple_alpha.png"),
        "targets": [
            Path("game/assets/sprites/player_cultivator_jade_simple_128.png"),
            Path("game/assets/sprites/player_cultivator_jade_simple_64.png"),
        ],
        "sizes": [128, 64],
    },
    {
        "src": Path("output/imagegen/batch_hd/samsara_thunder_demon_general_hd_simple_alpha.png"),
        "targets": [
            Path("game/assets/sprites/enemy_thunder_demon_simple_128.png"),
            Path("game/assets/sprites/enemy_thunder_demon_simple_64.png"),
        ],
        "sizes": [128, 64],
    },
]


def fit_square(img: Image.Image, size: int) -> Image.Image:
    src = img.convert("RGBA")
    w, h = src.size
    scale = min(size / w, size / h)
    new_w = max(1, int(round(w * scale)))
    new_h = max(1, int(round(h * scale)))
    resized = src.resize((new_w, new_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - new_w) // 2
    y = size - new_h
    canvas.alpha_composite(resized, (x, y))
    return canvas


def main() -> int:
    for job in JOBS:
        src_img = Image.open(job["src"])
        for target, size in zip(job["targets"], job["sizes"]):
            out = fit_square(src_img, size)
            target.parent.mkdir(parents=True, exist_ok=True)
            out.save(target)
            print(f"Wrote {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
