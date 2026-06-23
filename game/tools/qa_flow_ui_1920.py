from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - reported as a dependency issue.
    Image = None


ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "Godot_v4.6.3-stable_win64.exe"
REPORT = ROOT / "output" / "visual_qa" / "flow_ui_1920_report.txt"
SCREENSHOTS = [
    ROOT / "output" / "visual_qa" / "flow_run_setup_1920.png",
    ROOT / "output" / "visual_qa" / "flow_run_setup_heart_demon_1920.png",
    ROOT / "output" / "visual_qa" / "flow_event_panel_1920.png",
    ROOT / "output" / "visual_qa" / "flow_event_regular_1920.png",
    ROOT / "output" / "visual_qa" / "flow_event_weather_1920.png",
    ROOT / "output" / "visual_qa" / "flow_event_karma_1920.png",
    ROOT / "output" / "visual_qa" / "flow_run_result_1920.png",
    ROOT / "output" / "visual_qa" / "flow_run_result_failure_1920.png",
    ROOT / "output" / "visual_qa" / "flow_pause_overlay_1920.png",
    ROOT / "output" / "visual_qa" / "flow_pause_confirm_1920.png",
    ROOT / "output" / "visual_qa" / "flow_path_choice_1920.png",
    ROOT / "output" / "visual_qa" / "flow_shop_panel_1920.png",
    ROOT / "output" / "visual_qa" / "flow_shop_full_slots_1920.png",
    ROOT / "output" / "visual_qa" / "flow_death_moment_1920.png",
    ROOT / "output" / "visual_qa" / "flow_legacy_select_1920.png",
    ROOT / "output" / "visual_qa" / "flow_meta_upgrade_1920.png",
    ROOT / "output" / "visual_qa" / "flow_breakthrough_1920.png",
    ROOT / "output" / "visual_qa" / "flow_weapon_mod_choice_1920.png",
    ROOT / "output" / "visual_qa" / "flow_jade_codex_1920.png",
]
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
    log = LOG_DIR / f"qa_flow_ui_1920_{os.getpid()}_{int(time.time())}.log"
    for artifact in [REPORT, *SCREENSHOTS]:
        if artifact.exists():
            artifact.unlink()
    command = [
        str(GODOT),
        "--rendering-method",
        "gl_compatibility",
        "--path",
        "game",
        "--scene",
        "res://tools/qa_flow_ui_1920.tscn",
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
        if "Flow UI visual QA passed" not in report_text or "Exit code: 0" not in report_text:
            errors.append("Godot flow UI visual QA report did not pass")

    for screenshot in SCREENSHOTS:
        if not screenshot.exists():
            errors.append(f"Missing screenshot: {screenshot}")
            continue
        with Image.open(screenshot) as image:
            if image.size != EXPECTED_SIZE:
                errors.append(f"{screenshot.name} size is {image.size}, expected {EXPECTED_SIZE}")

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
