from __future__ import annotations

import base64
import json
import os
from pathlib import Path

import requests


API_KEY = os.environ.get("OPENAI_API_KEY", "").strip()
ENDPOINT = "https://api.ssstoken.net/v1/images/generations"
TIMEOUT_SECONDS = 300

OUT_ROOT = Path("output/imagegen/player_actions")


STYLE_BASES = {
    "normal": (
        "same Samsara Ascension jade-white female xianxia cultivator identity: elegant young cultivator, "
        "long dark ink hair, one jade-and-gold hair ornament, small forehead gem, white and pale-jade robes, "
        "few translucent teal ribbons, light gold trim, slim jade sword kept close to the body, clean HD hand-painted "
        "2D fantasy RPG asset, crisp silhouette, simplified readable costume, not photorealistic, not 3D, not pixel art"
    ),
    "chibi": (
        "same Samsara Ascension cute chibi jade-white female xianxia cultivator identity: two-and-a-half to three heads tall, "
        "large soft expressive head, long dark ink hair, simple jade hair ornament, small forehead gem, white and pale-jade robes, "
        "soft teal ribbons, light gold trim, short jade sword kept close to the body, clean HD hand-painted chibi fantasy RPG asset, "
        "rounded readable silhouette, simplified details, not photorealistic, not 3D, not pixel art"
    ),
}


ACTION_PHASES = {
    "idle": (
        "top-left frame: calm neutral stance, feet planted, sword lowered close to side, relaxed shoulders. "
        "top-right frame: visible breathing inhale, chest and shoulders lift, robe sleeves rise slightly, teal ribbons float upward. "
        "bottom-left frame: qi gathers at the hands and sword hilt, knees soften, hair and ribbons sway to the side. "
        "bottom-right frame: exhale and settle back to the original stance, aura dims, robe hem falls; loop returns naturally to frame one"
    ),
    "walk": (
        "top-left frame: right foot forward and left foot back, body leaning slightly forward, sword balanced close to body. "
        "top-right frame: passing step, both feet near center, body rises, arms counter-swing, ribbons trail backward. "
        "bottom-left frame: left foot forward and right foot back, body weight clearly shifted, robe opens with the stride. "
        "bottom-right frame: passing step returning to neutral, body lowers slightly, arms counter-swing opposite; loop reads as walking"
    ),
    "combat": (
        "top-left frame: attack wind-up, knees bent, torso twists, sword hand draws the jade sword close across the body, off hand guarding. "
        "top-right frame: compact sword strike, body lunges forward, sword cuts diagonally but stays inside the body silhouette, no detached slash effect. "
        "bottom-left frame: follow-through, robe and ribbons swing from momentum, feet still grounded, sword remains close enough for fixed-cell gameplay. "
        "bottom-right frame: guard recovery stance, sword raised near shoulder, knees ready, torso returns toward idle; loop can hold during battle"
    ),
}


def build_prompt(style: str, action: str) -> str:
    style_note = STYLE_BASES[style]
    phase_note = ACTION_PHASES[action]
    scale_note = "around 60 to 65 percent of each cell" if style == "normal" else "around 55 to 60 percent of each cell"
    return (
        f"Create one clean HD 2D game sprite animation sheet for a controllable player character.\n"
        f"Sheet shape: exactly 2 rows by 2 columns, exactly 4 equal invisible cells, read left-to-right across rows.\n"
        f"Character: {style_note}.\n"
        f"Action: {action}. The four frames must show real pose changes, not only camera movement or scale changes. {phase_note}.\n"
        f"View and framing: full body visible, three-quarter RPG view from slightly above, feet/bottom anchor line stable in every cell, "
        f"character centered in each cell, same body height and same pixel scale in every frame, subject fills {scale_note}, generous margin on all sides.\n"
        f"Animation requirements: preserve the exact same character identity, costume colors, face/eyes, hair ornament, robe palette, sword design, "
        f"and material language in every cell; only the body pose, clothing motion, hair/ribbon motion, and compact attached qi accent may change.\n"
        f"Containment: the entire character, sword, hair, sleeves, ribbons, robe hem, and any tiny attached aura must fit fully inside each cell; "
        f"nothing may cross a cell edge; no floating detached effects outside the main silhouette; no projectile, no impact burst, no large slash arc, no dust cloud.\n"
        f"Background: 100 percent solid flat #FF00FF magenta chroma-key background only, no gradients, no texture, no floor, no cast shadow.\n"
        f"Forbidden: text, labels, numbers, arrows, UI, watermark, borders, visible grid lines, extra characters, cropped feet, inconsistent scale, "
        f"redesigned outfit, alternate character, photorealism, 3D render, pixel art."
    )


JOBS = [
    {
        "style": style,
        "action": action,
        "prompt": build_prompt(style, action),
        "out_file": OUT_ROOT / f"player_style_{style}_{action}_2x2_raw.png",
    }
    for style in ("normal", "chibi")
    for action in ("idle", "walk", "combat")
]


def main() -> int:
    if not API_KEY:
        raise SystemExit("OPENAI_API_KEY is not set.")

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    OUT_ROOT.mkdir(parents=True, exist_ok=True)

    for job in JOBS:
        prompt_path = OUT_ROOT / f"player_style_{job['style']}_{job['action']}_prompt.txt"
        prompt_path.write_text(job["prompt"], encoding="utf-8")
        payload = {
            "model": "gpt-image-2",
            "prompt": job["prompt"],
            "n": 1,
            "size": "1024x1024",
            "quality": "auto",
            "background": "auto",
            "output_format": "png",
            "moderation": "auto",
        }
        response = requests.post(
            ENDPOINT,
            headers=headers,
            json=payload,
            timeout=TIMEOUT_SECONDS,
        )
        print(f"{job['out_file'].name}: HTTP {response.status_code}")
        response.raise_for_status()
        data = response.json()
        image_b64 = data["data"][0]["b64_json"]
        job["out_file"].write_bytes(base64.b64decode(image_b64))
        response_path = job["out_file"].with_suffix(".response.json")
        response_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Wrote {job['out_file']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
