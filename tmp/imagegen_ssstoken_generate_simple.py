from __future__ import annotations

import base64
import json
import os
from pathlib import Path

import requests


API_KEY = os.environ.get("OPENAI_API_KEY", "").strip()
ENDPOINT = "https://api.ssstoken.net/v1/images/generations"
TIMEOUT_SECONDS = 300

JOBS = [
    {
        "prompt_file": Path("output/imagegen/samsara_jade_cultivator_hd_simple_prompt.txt"),
        "out_file": Path("output/imagegen/batch_hd/samsara_jade_cultivator_hd_simple.png"),
    },
    {
        "prompt_file": Path("output/imagegen/samsara_thunder_demon_general_hd_simple_prompt.txt"),
        "out_file": Path("output/imagegen/batch_hd/samsara_thunder_demon_general_hd_simple.png"),
    },
]


def extract_generation_prompt(text: str) -> str:
    marker = "Generation prompt:"
    if marker in text:
        return text.split(marker, 1)[1].strip()
    return text.strip()


def main() -> int:
    if not API_KEY:
        raise SystemExit("OPENAI_API_KEY is not set.")

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }

    for job in JOBS:
        prompt_text = job["prompt_file"].read_text(encoding="utf-8")
        payload = {
            "model": "gpt-image-2",
            "prompt": extract_generation_prompt(prompt_text),
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
        out_path = job["out_file"]
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(base64.b64decode(image_b64))
        print(f"Wrote {out_path}")

        meta_path = out_path.with_suffix(".response.json")
        meta_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Wrote {meta_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
