from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "Godot_v4.6.3-stable_win64.exe"
REPORT = ROOT / "game" / "tools" / "gameplay_systems_qa_report.txt"
LOG = ROOT / "tmp" / "qa_gameplay_systems.log"
QA_SAVE = ROOT / "tmp" / "qa_saves" / "gameplay_profile.json"


def main() -> int:
    if not GODOT.exists():
        print(f"Missing Godot executable: {GODOT}")
        return 2

    LOG.parent.mkdir(parents=True, exist_ok=True)
    QA_SAVE.parent.mkdir(parents=True, exist_ok=True)
    if QA_SAVE.exists():
        QA_SAVE.unlink()
    command = [
        str(GODOT),
        "--headless",
        "--path",
        "game",
        "--scene",
        "res://tools/qa_gameplay_systems.tscn",
        "--log-file",
        "../tmp/qa_gameplay_systems.log",
        "--",
        f"--qa-save-path={QA_SAVE.as_posix()}",
    ]
    result = subprocess.run(command, cwd=ROOT, check=False)
    errors: list[str] = []

    if not REPORT.exists():
        errors.append(f"Missing report: {REPORT}")
    else:
        report_text = REPORT.read_text(encoding="utf-8")
        print(report_text.rstrip())
        if "Gameplay systems QA passed" not in report_text or "Exit code: 0" not in report_text:
            errors.append("Godot gameplay systems QA report did not pass")

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
