from __future__ import annotations

import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None


ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "Godot_v4.6.3-stable_win64.exe"
REPORT = ROOT / "output" / "visual_qa" / "enemy_identity_showcase_1920_report.txt"
SCREENSHOTS = [
    ROOT / "output" / "visual_qa" / "enemy_identity_showcase_normal_1920.png",
    ROOT / "output" / "visual_qa" / "enemy_identity_showcase_chibi_1920.png",
]
LOG = ROOT / "tmp" / "qa_enemy_identity_showcase_1920.log"
EXPECTED_SIZE = (1920, 1080)


def main() -> int:
    if not GODOT.exists():
        print(f"Missing Godot executable: {GODOT}")
        return 2
    if Image is None:
        print("Missing Pillow dependency. Install with: pip install pillow")
        return 2

    LOG.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(GODOT),
        "--path",
        "game",
        "--scene",
        "res://tools/qa_enemy_identity_showcase_1920.tscn",
        "--log-file",
        "../tmp/qa_enemy_identity_showcase_1920.log",
    ]
    result = subprocess.run(command, cwd=ROOT, check=False)
    errors: list[str] = []

    if not REPORT.exists():
        errors.append(f"Missing report: {REPORT}")
    else:
        report_text = REPORT.read_text(encoding="utf-8")
        print(report_text.rstrip())
        if "Enemy identity showcase QA passed" not in report_text or "Exit code: 0" not in report_text:
            errors.append("Godot enemy identity showcase report did not pass")

    for screenshot in SCREENSHOTS:
        if not screenshot.exists():
            errors.append(f"Missing screenshot: {screenshot}")
            continue
        with Image.open(screenshot) as image:
            if image.size != EXPECTED_SIZE:
                errors.append(f"Screenshot {screenshot.name} size is {image.size}, expected {EXPECTED_SIZE}")

    if result.returncode != 0:
        errors.append(f"Godot process returned {result.returncode}")

    if errors:
        if LOG.exists():
            print(f"\nGodot log: {LOG}")
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
