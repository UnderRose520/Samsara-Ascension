from __future__ import annotations

import base64
import json
import os
from pathlib import Path

import requests


API_KEY = os.environ.get("OPENAI_API_KEY", "").strip()
ENDPOINT = "https://api.ssstoken.net/v1/images/generations"
TIMEOUT_SECONDS = 300


def extract_generation_prompt(text: str) -> str:
    marker = "Generation prompt:"
    if marker in text:
        return text.split(marker, 1)[1].strip()
    return text.strip()


def main() -> int:
    if not API_KEY:
        raise SystemExit("OPENAI_API_KEY is not set.")

    prompt_file = Path("output/imagegen/samsara_thunder_elite_ingame_prompt.txt")
    out_file = Path("output/imagegen/batch_hd/samsara_thunder_elite_ingame.png")

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }

    prompt_text = prompt_file.read_text(encoding="utf-8")
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
    print(f"{out_file.name}: HTTP {response.status_code}")
    response.raise_for_status()

    data = response.json()
    image_b64 = data["data"][0]["b64_json"]
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_bytes(base64.b64decode(image_b64))
    print(f"Wrote {out_file}")

    meta_path = out_file.with_suffix(".response.json")
    meta_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {meta_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
