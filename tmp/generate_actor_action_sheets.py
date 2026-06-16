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


ACTORS = {
    "enemy_style_normal_melee": {
        "runtime_slug": "enemy_style_normal_melee",
        "fit": 0.90,
        "identity": (
            "normal style melee enemy for Samsara Ascension: corrupted xianxia raider, dark red and iron armor plates, "
            "ragged black hair, compact heavy blade or claw weapon held close, angular hostile silhouette, clean HD hand-painted "
            "2D fantasy RPG sprite, readable at small size, not cute, not photorealistic, not 3D, not pixel art"
        ),
    },
    "enemy_style_normal_ranged": {
        "runtime_slug": "enemy_style_normal_ranged",
        "fit": 0.90,
        "identity": (
            "normal style ranged enemy for Samsara Ascension: corrupted xianxia spell archer, dark teal and ash robe, "
            "small bow or talisman focus kept close to the body, narrow agile silhouette, clean HD hand-painted 2D fantasy RPG sprite, "
            "readable at small size, not cute, not photorealistic, not 3D, not pixel art"
        ),
    },
    "enemy_style_normal_elite": {
        "runtime_slug": "enemy_style_normal_elite",
        "fit": 0.86,
        "identity": (
            "normal style elite thunder demon general for Samsara Ascension: imposing armored xianxia demon, dark bronze armor, "
            "crackling purple-blue thunder accents kept tight to the body, horned helm silhouette, heavy polearm held close, "
            "clean HD hand-painted 2D fantasy RPG boss sprite, readable at small size, not cute, not photorealistic, not 3D, not pixel art"
        ),
    },
    "enemy_style_chibi_melee": {
        "runtime_slug": "enemy_style_chibi_melee",
        "fit": 0.90,
        "identity": (
            "cute Q-version melee enemy for Samsara Ascension: chibi corrupted xianxia raider, big head, small body, dark red armor, "
            "tiny blade kept close, mischievous hostile expression, rounded but readable silhouette, clean HD hand-painted chibi fantasy RPG sprite, "
            "not photorealistic, not 3D, not pixel art"
        ),
    },
    "enemy_style_chibi_ranged": {
        "runtime_slug": "enemy_style_chibi_ranged",
        "fit": 0.90,
        "identity": (
            "cute Q-version ranged enemy for Samsara Ascension: chibi corrupted xianxia spell archer, big head, small body, dark teal robe, "
            "tiny bow or talisman focus kept close, sly hostile expression, rounded readable silhouette, clean HD hand-painted chibi fantasy RPG sprite, "
            "not photorealistic, not 3D, not pixel art"
        ),
    },
    "enemy_style_chibi_elite": {
        "runtime_slug": "enemy_style_chibi_elite",
        "fit": 0.86,
        "identity": (
            "cute Q-version elite thunder demon general for Samsara Ascension: chibi armored thunder demon boss, oversized helm, tiny horns, "
            "dark bronze armor, compact purple-blue thunder accents, small polearm kept close, fierce cute expression, clean HD hand-painted "
            "chibi fantasy RPG sprite, not photorealistic, not 3D, not pixel art"
        ),
    },
    "enemy_training_dummy": {
        "runtime_slug": "enemy_training_dummy",
        "fit": 0.88,
        "identity": (
            "training dummy enemy for Samsara Ascension: straw and wood practice puppet with red cloth talisman strips, simple round target mark, "
            "short wooden arms, compact readable silhouette, clean HD hand-painted 2D fantasy RPG sprite, not photorealistic, not 3D, not pixel art"
        ),
    },
    "pet_huo_ying": {
        "runtime_slug": "pet_huo_ying",
        "fit": 0.86,
        "identity": (
            "Huo Ying fire lotus pet for Samsara Ascension: small floating cute fire-lotus spirit, orange golden petals, tiny ember core face, "
            "soft flame leaf shapes, friendly magical companion, clean HD hand-painted 2D fantasy RPG sprite, readable at 32 to 64 pixel scale, "
            "not photorealistic, not 3D, not pixel art"
        ),
    },
}


ACTION_PHASES = {
    "idle": (
        "top-left frame: neutral ready posture, body settled. "
        "top-right frame: visible breathing or energy inhale, shoulders or core lifts, small attached aura brightens. "
        "bottom-left frame: weight shifts to the opposite side, cloth, hair, petals, arms, or weapon sway clearly. "
        "bottom-right frame: settle back toward the first pose, aura dims, loop returns naturally"
    ),
    "walk": (
        "top-left frame: first stride, front limb or leading side moves forward, body leans in travel direction. "
        "top-right frame: passing step, body rises, rear limb or trailing side catches up, cloth or petals trail backward. "
        "bottom-left frame: opposite stride, other limb or side moves forward, weight clearly shifts. "
        "bottom-right frame: passing step returning toward neutral, body lowers slightly; loop reads as movement"
    ),
    "combat": (
        "top-left frame: attack wind-up or casting wind-up, body crouches or coils, weapon/focus/energy pulls close. "
        "top-right frame: compact strike, swipe, shot release, or magic pulse, body lunges or snaps forward while all effects stay tight. "
        "bottom-left frame: follow-through with clear recoil and cloth/hair/flame momentum, no wide detached effect. "
        "bottom-right frame: guard or recovery pose, ready to loop back into combat"
    ),
}


def build_prompt(actor_key: str, action: str) -> str:
    actor = ACTORS[actor_key]
    fill = "about 55 to 62 percent" if "elite" in actor_key else "about 58 to 66 percent"
    if actor_key == "pet_huo_ying":
        fill = "about 50 to 58 percent"
    return (
        "Create one clean HD 2D game sprite animation sheet.\n"
        "Sheet shape: exactly 2 rows by 2 columns, exactly 4 equal invisible cells, read left-to-right across rows.\n"
        f"Subject identity: {actor['identity']}.\n"
        f"Action: {action}. The four frames must show real body pose changes, not only scaling, camera movement, glow changes, or sliding. "
        f"{ACTION_PHASES[action]}.\n"
        "View and framing: full body visible, three-quarter RPG view from slightly above, centered in each cell, stable bottom/feet anchor line "
        f"when grounded, same body height and same pixel scale in every frame, subject fills {fill} of each cell with generous magenta margin.\n"
        "Animation consistency: preserve the exact same identity, silhouette family, palette, face/eyes or core face, costume/armor marks, weapon or focus, "
        "and material language in every cell; only pose, compact clothing motion, limbs, hair, petals, weapon angle, and small attached aura may change.\n"
        "Containment: the entire subject and any weapon, horn, petal, hair, sleeve, tail, talisman, or tiny attached aura must fit fully inside each cell; "
        "nothing may cross a cell edge; no detached projectile, no impact burst, no large slash arc, no long trail, no dust cloud.\n"
        "Background: 100 percent solid flat #FF00FF magenta chroma-key background only, no gradients, no texture, no floor, no cast shadow.\n"
        "Forbidden: text, labels, numbers, arrows, UI, watermark, borders, visible grid lines, extra characters, cropped body parts, inconsistent scale, "
        "redesigned subject, alternate forms, photorealism, 3D render, pixel art."
    )


JOBS = [
    {
        "actor": actor_key,
        "runtime_slug": actor["runtime_slug"],
        "fit": actor["fit"],
        "action": action,
        "prompt": build_prompt(actor_key, action),
        "out_file": OUT_ROOT / f"{actor['runtime_slug']}_{action}_2x2_raw.png",
    }
    for actor_key, actor in ACTORS.items()
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
        prompt_path = OUT_ROOT / f"{job['runtime_slug']}_{job['action']}_prompt.txt"
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

    manifest = [
        {
            "runtime_slug": job["runtime_slug"],
            "action": job["action"],
            "fit": job["fit"],
            "raw": job["out_file"].as_posix(),
        }
        for job in JOBS
    ]
    (OUT_ROOT / "generation_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
