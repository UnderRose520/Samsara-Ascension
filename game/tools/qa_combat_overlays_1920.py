from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None


ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "Godot_v4.6.3-stable_win64.exe"
REPORT = ROOT / "output" / "visual_qa" / "combat_overlays_1920_report.txt"
SCREENSHOT = ROOT / "output" / "visual_qa" / "combat_overlays_1920.png"
LOG_DIR = ROOT / "tmp"
EXPECTED_SIZE = (1920, 1080)
GODOT_TIMEOUT_SECONDS = 180


def main() -> int:
    if not GODOT.exists():
        print(f"Missing Godot executable: {GODOT}")
        return 2
    if Image is None:
        print("Missing Pillow dependency. Install with: pip install pillow")
        return 2

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_DIR / f"qa_combat_overlays_1920_{os.getpid()}_{int(time.time())}.log"
    for artifact in (REPORT, SCREENSHOT):
        artifact.unlink(missing_ok=True)
    command = [
        str(GODOT),
        "--path",
        "game",
        "--scene",
        "res://tools/qa_combat_overlays_1920.tscn",
        "--log-file",
        f"../tmp/{log.name}",
    ]
    try:
        result = subprocess.run(command, cwd=ROOT, check=False, timeout=GODOT_TIMEOUT_SECONDS)
        process_returncode = result.returncode
    except subprocess.TimeoutExpired:
        process_returncode = None
    errors: list[str] = []

    if not REPORT.exists():
        errors.append(f"Missing report: {REPORT}")
    else:
        report_text = REPORT.read_text(encoding="utf-8")
        print(report_text.rstrip())
        if "Combat overlays visual QA passed" not in report_text or "Exit code: 0" not in report_text:
            errors.append("Godot combat overlays visual QA report did not pass")

    if not SCREENSHOT.exists():
        errors.append(f"Missing screenshot: {SCREENSHOT}")
    else:
        with Image.open(SCREENSHOT) as image:
            if image.size != EXPECTED_SIZE:
                errors.append(f"{SCREENSHOT.name} size is {image.size}, expected {EXPECTED_SIZE}")

    if process_returncode is None:
        errors.append(f"Godot process timed out after {GODOT_TIMEOUT_SECONDS}s")
    elif process_returncode != 0:
        errors.append(f"Godot process returned {process_returncode}")

    if errors:
        if log.exists():
            print(f"\nGodot log: {log}")
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
