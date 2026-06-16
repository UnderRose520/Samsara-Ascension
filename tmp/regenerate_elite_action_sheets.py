from __future__ import annotations

import base64
import json
import os
from pathlib import Path

import requests


API_KEY = os.environ.get("OPENAI_API_KEY", "").strip()
ENDPOINT = "https://api.ssstoken.net/v1/images/generations"
TIMEOUT_SECONDS = 300
OUT_ROOT = Path("output/imagegen/actor_actions")


IDENTITIES = {
    "enemy_style_normal_elite": (
        "normal style elite thunder demon general for Samsara Ascension: imposing armored xianxia demon, dark bronze armor, "
        "compact horned helm silhouette, short heavy polearm held close to the torso, tiny purple-blue thunder accents hugging the armor, "
        "clean HD hand-painted 2D fantasy RPG boss sprite, readable at small size, not cute, not photorealistic, not 3D, not pixel art"
    ),
    "enemy_style_chibi_elite": (
        "cute Q-version elite thunder demon general for Samsara Ascension: chibi armored thunder demon boss, oversized helm, tiny horns, "
        "dark bronze armor, short compact polearm held close to the torso, tiny purple-blue thunder accents hugging the armor, fierce cute expression, "
        "clean HD hand-painted chibi fantasy RPG sprite, not photorealistic, not 3D, not pixel art"
    ),
}


ACTION_PHASES = {
    "idle": (
        "top-left frame: neutral guard posture, feet planted, polearm vertical and close to the body. "
        "top-right frame: breathing inhale, shoulders rise, tiny thunder accents brighten tightly around armor. "
        "bottom-left frame: weight shifts to the opposite foot, cape cloth and helm tassel sway inward, polearm angle changes only slightly. "
        "bottom-right frame: settle back toward the first pose, thunder dims, loop returns naturally"
    ),
    "combat": (
        "top-left frame: compact attack wind-up, knees bend, torso coils, polearm pulled tight across the chest. "
        "top-right frame: short contained thrust or chop, body lunges a little but weapon tip remains well inside the cell. "
        "bottom-left frame: follow-through recoil, armor cloth and tassel swing, tiny attached thunder sparks stay close to the body. "
        "bottom-right frame: guard recovery pose, polearm close to shoulder, ready to loop back into combat"
    ),
}


def build_prompt(slug: str, action: str) -> str:
    return (
        "Create one clean HD 2D game sprite animation sheet.\n"
        "Sheet shape: exactly 2 rows by 2 columns, exactly 4 equal invisible cells, read left-to-right across rows.\n"
        f"Subject identity: {IDENTITIES[slug]}.\n"
        f"Action: {action}. The four frames must show real body pose changes, not only scaling, camera movement, glow changes, or sliding. "
        f"{ACTION_PHASES[action]}.\n"
        "Critical layout: the complete subject must occupy only the central 50 to 55 percent of each cell. Leave very large flat magenta padding "
        "on all four sides. Keep the polearm short and close. Keep horns, shoulders, weapon, cape, tassels, sparks, and feet far away from all cell edges. "
        "Do not let anything touch or approach the cell boundary.\n"
        "View and framing: full body visible, three-quarter RPG view from slightly above, centered in each cell, stable bottom/feet anchor line, "
        "same body height and same pixel scale in every frame.\n"
        "Animation consistency: preserve the exact same identity, silhouette family, palette, armor marks, face/eyes, helm, weapon design, and material language "
        "in every cell; only pose, compact cloth motion, weapon angle, and tiny attached thunder accents may change.\n"
        "Containment: the entire subject and any weapon, horn, hair, cape, tassel, sleeve, or tiny attached aura must fit fully inside each cell; "
        "nothing may cross or touch a cell edge; no detached projectile, no impact burst, no large slash arc, no long trail, no dust cloud.\n"
        "Background: 100 percent solid flat #FF00FF magenta chroma-key background only, no gradients, no texture, no floor, no cast shadow.\n"
        "Forbidden: text, labels, numbers, arrows, UI, watermark, borders, visible grid lines, extra characters, cropped body parts, inconsistent scale, "
        "redesigned subject, alternate forms, photorealism, 3D render, pixel art."
    )


JOBS = [
    {
        "slug": "enemy_style_normal_elite",
        "action": "idle",
        "prompt": build_prompt("enemy_style_normal_elite", "idle"),
    },
    {
        "slug": "enemy_style_normal_elite",
        "action": "combat",
        "prompt": build_prompt("enemy_style_normal_elite", "combat"),
    },
    {
        "slug": "enemy_style_chibi_elite",
        "action": "combat",
        "prompt": build_prompt("enemy_style_chibi_elite", "combat"),
    },
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
        slug = job["slug"]
        action = job["action"]
        prompt_path = OUT_ROOT / f"{slug}_{action}_prompt.txt"
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
        print(f"{slug}_{action}: HTTP {response.status_code}")
        response.raise_for_status()
        data = response.json()
        out_file = OUT_ROOT / f"{slug}_{action}_2x2_raw.png"
        out_file.write_bytes(base64.b64decode(data["data"][0]["b64_json"]))
        out_file.with_suffix(".response.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
