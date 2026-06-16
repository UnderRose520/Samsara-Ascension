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


IDENTITIES = {
    "normal": (
        "same Samsara Ascension jade-white female xianxia cultivator identity: elegant young cultivator, long dark ink hair, "
        "one jade-and-gold hair ornament, small forehead gem, white and pale-jade robes, few translucent teal ribbons, light gold trim, "
        "short slim jade sword held close to the body, clean HD hand-painted 2D fantasy RPG asset, crisp silhouette, simplified readable costume, "
        "not photorealistic, not 3D, not pixel art"
    ),
    "chibi": (
        "same Samsara Ascension cute Q-version jade-white female xianxia cultivator identity: two-and-a-half to three heads tall, "
        "large soft expressive head, long dark ink hair, simple jade hair ornament, small forehead gem, white and pale-jade robes, "
        "soft teal ribbons, light gold trim, very short jade sword held close to the body, clean HD hand-painted chibi fantasy RPG asset, "
        "rounded readable silhouette, simplified details, not photorealistic, not 3D, not pixel art"
    ),
}


def build_prompt(style: str) -> str:
    return (
        "Create one clean HD 2D game sprite attack animation sheet for a controllable player character.\n"
        "Sheet shape: exactly 2 rows by 3 columns, exactly 6 equal invisible cells, read left-to-right across the top row, "
        "then left-to-right across the bottom row.\n"
        f"Character: {IDENTITIES[style]}.\n"
        "Action: smooth compact sword combat body animation with six real pose phases. "
        "Frame 1 top-left: ready guard stance, sword low and close, knees soft, feet planted. "
        "Frame 2 top-middle: anticipation, torso twists back, sword draws tight across the chest, robe and ribbons begin to lag. "
        "Frame 3 top-right: attack begins with a small step, sword arm extends only halfway, weapon tip remains far inside the cell with large magenta padding. "
        "Frame 4 bottom-left: strike peak, compact diagonal cut close to the torso, no wide sword reach, no long blade trail, no detached slash. "
        "Frame 5 bottom-middle: follow-through, torso rotated, robe and ribbons swing with momentum but stay compact. "
        "Frame 6 bottom-right: recovery guard, body settles back toward ready stance, sword raised close near shoulder, loop can return to frame 1.\n"
        "Critical layout: the complete body plus sword must occupy only the central 50 to 55 percent of each cell. "
        "Leave very large flat magenta padding on all four sides in every single frame, especially frame 3 top-right. "
        "Keep the sword short and close. No hair, ribbon, robe, sleeve, sword, aura, or foot may approach or touch any cell edge.\n"
        "View and framing: full body visible, three-quarter RPG view from slightly above, feet/bottom anchor line stable in every cell, "
        "character centered in each cell, same body height and same pixel scale in every frame.\n"
        "Animation consistency: preserve the exact same character identity, costume colors, face/eyes, hair ornament, robe palette, sword design, "
        "and material language in every cell; only body pose, sword angle, clothing motion, hair/ribbon motion, and tiny attached qi accent may change.\n"
        "Containment: the entire character, sword, hair, sleeves, ribbons, robe hem, and any tiny attached aura must fit fully inside each cell; "
        "nothing may cross or touch a cell edge; no floating detached effects outside the main silhouette; no projectile, no impact burst, no large slash arc, no dust cloud.\n"
        "Background: 100 percent solid flat #FF00FF magenta chroma-key background only, no gradients, no texture, no floor, no cast shadow.\n"
        "Forbidden: text, labels, numbers, arrows, UI, watermark, borders, visible grid lines, extra characters, cropped feet, inconsistent scale, "
        "redesigned outfit, alternate character, photorealism, 3D render, pixel art."
    )


JOBS = [
    {"slug": "player_style_normal", "prompt": build_prompt("normal")},
    {"slug": "player_style_chibi", "prompt": build_prompt("chibi")},
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
        prompt_path = OUT_ROOT / f"{job['slug']}_combat_6f_prompt.txt"
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
        response = requests.post(ENDPOINT, headers=headers, json=payload, timeout=TIMEOUT_SECONDS)
        print(f"{job['slug']}_combat_6f_safe: HTTP {response.status_code}")
        response.raise_for_status()
        data = response.json()
        out_file = OUT_ROOT / f"{job['slug']}_combat_2x3_raw.png"
        out_file.write_bytes(base64.b64decode(data["data"][0]["b64_json"]))
        out_file.with_suffix(".response.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
