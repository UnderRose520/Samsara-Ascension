from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
SPRITE_ROOT = ROOT / "assets" / "sprites"
FRAME_ROOT = SPRITE_ROOT / "frames"
GIF_ROOT = SPRITE_ROOT / "gifs"


ACTOR_SOURCES = {
    "player_cultivator": "player_cultivator_64.png",
    "enemy_berserker": "enemy_berserker_64.png",
    "enemy_archer": "enemy_archer_64.png",
    "enemy_bomber": "enemy_bomber_64.png",
}

PROJECTILE_SOURCES = {
    "projectile_fire": "projectile_fire_16.png",
    "projectile_thunder": "projectile_thunder_16.png",
    "projectile_ice": "projectile_ice_16.png",
    "projectile_water": "projectile_water_16.png",
    "projectile_generic": "projectile_generic_16.png",
    "projectile_chaos": "projectile_chaos_16.png",
}


def _load_source(filename: str) -> Image.Image:
    return Image.open(SPRITE_ROOT / filename).convert("RGBA")


def _canvas_like(image: Image.Image) -> Image.Image:
    return Image.new("RGBA", image.size, (0, 0, 0, 0))


def _offset(image: Image.Image, x: int, y: int) -> Image.Image:
    frame = _canvas_like(image)
    frame.alpha_composite(image, (x, y))
    return frame


def _scale_about_center(image: Image.Image, scale: float) -> Image.Image:
    if scale == 1.0:
        return image.copy()
    width, height = image.size
    scaled_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    scaled = image.resize(scaled_size, Image.Resampling.NEAREST)
    frame = _canvas_like(image)
    frame.alpha_composite(scaled, ((width - scaled.width) // 2, (height - scaled.height) // 2))
    return frame


def _transform_actor(
    image: Image.Image,
    x: int = 0,
    y: int = 0,
    glow_alpha: int = 0,
    scale: float = 1.0,
    angle: float = 0.0,
    brightness: float = 1.0,
) -> Image.Image:
    width, height = image.size
    body = image.convert("RGBA")
    if scale != 1.0:
        scaled_size = (max(1, round(width * scale)), max(1, round(height * scale)))
        body = body.resize(scaled_size, Image.Resampling.LANCZOS)
    if angle != 0.0:
        body = body.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    if brightness != 1.0:
        body = ImageEnhance.Brightness(body).enhance(brightness)

    frame = Image.new("RGBA", image.size, (0, 0, 0, 0))
    px = (width - body.width) // 2 + x
    py = (height - body.height) // 2 + y
    if glow_alpha > 0:
        glow = _tint_alpha(body, (255, 218, 122, glow_alpha))
        frame.alpha_composite(glow, (px, py + 1))
    frame.alpha_composite(body, (px, py))
    return frame


def _tint_alpha(image: Image.Image, rgba: tuple[int, int, int, int]) -> Image.Image:
    alpha = image.getchannel("A")
    tint = Image.new("RGBA", image.size, rgba)
    tint.putalpha(alpha.point(lambda value: int(value * (rgba[3] / 255.0))))
    return tint


def _actor_frame(image: Image.Image, x: int, y: int, glow_alpha: int, scale: float = 1.0) -> Image.Image:
    return _transform_actor(image, x, y, glow_alpha, scale)


def _projectile_frame(image: Image.Image, angle: int, brightness: float, scale: float) -> Image.Image:
    rotated = image.rotate(angle, resample=Image.Resampling.NEAREST, expand=False)
    boosted = ImageEnhance.Brightness(rotated).enhance(brightness)
    return _scale_about_center(boosted, scale)


def _impact_frame(image: Image.Image, scale: float, alpha_factor: float, brightness: float) -> Image.Image:
    frame = _scale_about_center(ImageEnhance.Brightness(image).enhance(brightness), scale)
    alpha = frame.getchannel("A").point(lambda value: int(value * alpha_factor))
    frame.putalpha(alpha)
    return frame


def _save_frames(slug: str, prefix: str, frames: list[Image.Image], gif_duration_ms: int) -> list[str]:
    out_dir = FRAME_ROOT / slug
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for index, frame in enumerate(frames):
        path = out_dir / f"{prefix}_{index:02d}.png"
        frame.save(path)
        paths.append(path.relative_to(ROOT).as_posix())

    GIF_ROOT.mkdir(parents=True, exist_ok=True)
    gif_path = GIF_ROOT / f"{slug}_{prefix}.gif"
    frames[0].save(
        gif_path,
        save_all=True,
        append_images=frames[1:],
        duration=gif_duration_ms,
        loop=0,
        disposal=2,
    )
    paths.append(gif_path.relative_to(ROOT).as_posix())
    return paths


def generate() -> dict:
    manifest: dict = {
        "source": "Existing project PNG assets derived from docs/UI asset prompts.",
        "note": (
            "Legacy deterministic runtime animation derivatives. "
            "Styled player, enemy, training dummy, and pet action frames are intentionally excluded "
            "because they are generated from dedicated 2x2 action sheets."
        ),
        "actors": {},
        "projectiles": {},
        "impacts": {},
    }

    actor_offsets = [(0, 0, 0, 1.0), (0, -1, 38, 1.0), (0, -2, 58, 1.02), (0, -1, 32, 1.0)]
    walk_offsets = [(-2, -1, 16, 0.99, -3.5, 1.0), (2, -2, 26, 1.01, 2.0, 1.02), (-2, -1, 20, 0.99, 3.0, 1.0), (2, 0, 14, 1.01, -2.0, 0.98)]
    combat_offsets = [(-2, 1, 10, 0.98, -6.0, 0.94), (2, -2, 48, 1.03, 2.5, 1.08), (4, -1, 58, 1.05, 7.0, 1.12), (0, 0, 22, 1.0, -1.5, 1.0)]
    for slug, filename in ACTOR_SOURCES.items():
        src = _load_source(filename)
        frames = [_actor_frame(src, x, y, glow, scale) for x, y, glow, scale in actor_offsets]
        actor_entry = {
            "idle": {
                "fps": 6,
                "frames": _save_frames(slug, "idle", frames, 140),
            }
        }
        if slug.startswith("player_style_"):
            walk_frames = [
                _transform_actor(src, x, y, glow, scale, angle, brightness)
                for x, y, glow, scale, angle, brightness in walk_offsets
            ]
            combat_frames = [
                _transform_actor(src, x, y, glow, scale, angle, brightness)
                for x, y, glow, scale, angle, brightness in combat_offsets
            ]
            actor_entry["walk"] = {
                "fps": 8,
                "frames": _save_frames(slug, "walk", walk_frames, 100),
            }
            actor_entry["combat"] = {
                "fps": 10,
                "frames": _save_frames(slug, "combat", combat_frames, 80),
            }
        manifest["actors"][slug] = actor_entry

    projectile_phases = [(0, 1.0, 1.0), (90, 1.12, 1.08), (180, 1.0, 1.0), (270, 0.92, 0.94)]
    impact_phases = [(0.70, 1.0, 1.35), (1.00, 0.85, 1.5), (1.28, 0.55, 1.25), (1.55, 0.20, 0.85)]
    for slug, filename in PROJECTILE_SOURCES.items():
        src = _load_source(filename)
        fly_frames = [_projectile_frame(src, angle, brightness, scale) for angle, brightness, scale in projectile_phases]
        impact_frames = [_impact_frame(src, scale, alpha, brightness) for scale, alpha, brightness in impact_phases]
        manifest["projectiles"][slug] = {
            "action": "fly",
            "fps": 12,
            "frames": _save_frames(slug, "fly", fly_frames, 80),
        }
        impact_slug = slug.replace("projectile_", "impact_")
        manifest["impacts"][impact_slug] = {
            "action": "impact",
            "fps": 14,
            "frames": _save_frames(impact_slug, "impact", impact_frames, 70),
        }

    manifest_path = FRAME_ROOT / "animation_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    result = generate()
    actor_count = len(result["actors"])
    projectile_count = len(result["projectiles"])
    impact_count = len(result["impacts"])
    print(f"Generated {actor_count} actor loops, {projectile_count} projectile loops, {impact_count} impact loops.")
