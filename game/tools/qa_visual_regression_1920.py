from __future__ import annotations

import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - reported as a dependency issue.
    Image = None
    ImageDraw = None
    ImageFont = None


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "output" / "visual_qa"
REGRESSION_REPORT = OUT_DIR / "visual_regression_1920_report.md"
CONTACT_SHEET = OUT_DIR / "visual_regression_1920_contact_sheet.png"
LEGACY_CONTACT_SHEET = OUT_DIR / "visual_qa_contact_sheet.png"
EXPECTED_SIZE = (1920, 1080)

QA_STEPS = [
    {
        "name": "Flow UI",
        "command": [sys.executable, "game/tools/qa_flow_ui_1920.py"],
        "report": OUT_DIR / "flow_ui_1920_report.txt",
        "pass_marker": "Flow UI visual QA passed",
        "screenshots": [
            ("Run Setup", OUT_DIR / "flow_run_setup_1920.png"),
            ("Run Setup Heart Demon", OUT_DIR / "flow_run_setup_heart_demon_1920.png"),
            ("Event Panel", OUT_DIR / "flow_event_panel_1920.png"),
            ("Event Regular", OUT_DIR / "flow_event_regular_1920.png"),
            ("Event Weather", OUT_DIR / "flow_event_weather_1920.png"),
            ("Event Karma", OUT_DIR / "flow_event_karma_1920.png"),
            ("Run Result", OUT_DIR / "flow_run_result_1920.png"),
            ("Run Result Failure", OUT_DIR / "flow_run_result_failure_1920.png"),
            ("Pause Overlay", OUT_DIR / "flow_pause_overlay_1920.png"),
            ("Pause Confirm", OUT_DIR / "flow_pause_confirm_1920.png"),
            ("Path Choice", OUT_DIR / "flow_path_choice_1920.png"),
            ("Shop Panel", OUT_DIR / "flow_shop_panel_1920.png"),
            ("Shop Full Slots", OUT_DIR / "flow_shop_full_slots_1920.png"),
            ("Death Moment", OUT_DIR / "flow_death_moment_1920.png"),
            ("Legacy Select", OUT_DIR / "flow_legacy_select_1920.png"),
            ("Meta Upgrade", OUT_DIR / "flow_meta_upgrade_1920.png"),
            ("Breakthrough", OUT_DIR / "flow_breakthrough_1920.png"),
            ("Weapon Mod Choice", OUT_DIR / "flow_weapon_mod_choice_1920.png"),
            ("Jade Codex", OUT_DIR / "flow_jade_codex_1920.png"),
        ],
    },
    {
        "name": "Reward Cards",
        "command": [sys.executable, "game/tools/qa_reward_cards_1920.py"],
        "report": OUT_DIR / "reward_cards_1920_report.txt",
        "pass_marker": "Reward card visual QA passed",
        "screenshots": [
            ("Reward Cards", OUT_DIR / "reward_cards_1920.png"),
            ("Reward Full Slot", OUT_DIR / "reward_full_slot_actions_1920.png"),
        ],
    },
    {
        "name": "Combat Integration",
        "command": [sys.executable, "game/tools/qa_visual_integration_1920.py"],
        "report": OUT_DIR / "combat_visual_integration_1920_report.txt",
        "pass_marker": "Visual integration QA passed",
        "screenshots": [
            ("Combat Integration", OUT_DIR / "combat_visual_integration_1920.png"),
            ("Map S1 Clear", OUT_DIR / "map_matrix_stage1_qi_refining_verdant_clear_1920.png"),
            ("Map S1 Rain", OUT_DIR / "map_matrix_stage1_qi_refining_verdant_rain_1920.png"),
            ("Map S1 Fog", OUT_DIR / "map_matrix_stage1_qi_refining_verdant_fog_1920.png"),
            ("Map S2 Rain", OUT_DIR / "map_matrix_stage2_foundation_cavern_rain_1920.png"),
            ("Map S2 Fog", OUT_DIR / "map_matrix_stage2_foundation_cavern_fog_1920.png"),
            ("Map S2 Thunder", OUT_DIR / "map_matrix_stage2_foundation_cavern_thunder_1920.png"),
            ("Map S3 Fire", OUT_DIR / "map_matrix_stage3_golden_core_demon_fire_1920.png"),
            ("Map S3 Thunder", OUT_DIR / "map_matrix_stage3_golden_core_demon_thunder_1920.png"),
            ("Map S3 Sand", OUT_DIR / "map_matrix_stage3_golden_core_demon_sand_1920.png"),
            ("Map S4 Fire", OUT_DIR / "map_matrix_stage4_nascent_soul_ruins_fire_1920.png"),
            ("Map S4 Fog", OUT_DIR / "map_matrix_stage4_nascent_soul_ruins_fog_1920.png"),
            ("Map S4 Snow", OUT_DIR / "map_matrix_stage4_nascent_soul_ruins_snow_1920.png"),
            ("Map S5 Thunder", OUT_DIR / "map_matrix_stage5_tribulation_thunder_thunder_1920.png"),
            ("Map S5 Rain", OUT_DIR / "map_matrix_stage5_tribulation_thunder_rain_1920.png"),
            ("Map S5 Wind", OUT_DIR / "map_matrix_stage5_tribulation_thunder_wind_1920.png"),
        ],
    },
    {
        "name": "Combat Overlays",
        "command": [sys.executable, "game/tools/qa_combat_overlays_1920.py"],
        "report": OUT_DIR / "combat_overlays_1920_report.txt",
        "pass_marker": "Combat overlays visual QA passed",
        "screenshots": [
            ("Combat Overlays", OUT_DIR / "combat_overlays_1920.png"),
        ],
    },
    {
        "name": "Enemy Identity Showcase",
        "command": [sys.executable, "game/tools/qa_enemy_identity_showcase_1920.py"],
        "report": OUT_DIR / "enemy_identity_showcase_1920_report.txt",
        "pass_marker": "Enemy identity showcase QA passed",
        "screenshots": [
            ("Enemy Identity Normal", OUT_DIR / "enemy_identity_showcase_normal_1920.png"),
            ("Enemy Identity Chibi", OUT_DIR / "enemy_identity_showcase_chibi_1920.png"),
        ],
    },
]


def main() -> int:
    if Image is None or ImageDraw is None or ImageFont is None:
        print("Missing Pillow dependency. Install with: pip install pillow")
        return 2

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    expected_paths = _expected_output_paths()
    for path in expected_paths:
        path.unlink(missing_ok=True)

    started_at = time.time()
    report_lines: list[str] = [
        "# Visual Regression 1920x1080",
        "",
        f"- Started: {datetime.now().isoformat(timespec='seconds')}",
        f"- Root: `{ROOT}`",
        "- Mode: real Godot window rendering, not headless dummy rendering",
        "",
    ]

    errors: list[str] = []
    step_results: list[dict] = []
    for step in QA_STEPS:
        print(f"\n=== {step['name']} ===")
        step_result = _run_step(step)
        step_results.append(step_result)
        if step_result["stdout"].strip():
            print(step_result["stdout"].rstrip())
        if step_result["stderr"].strip():
            print(step_result["stderr"].rstrip(), file=sys.stderr)
        errors.extend(step_result["errors"])

    screenshot_results = _inspect_screenshots(started_at)
    for result in screenshot_results:
        if result["errors"]:
            errors.extend(result["errors"])

    if not errors:
        _build_contact_sheet(screenshot_results, CONTACT_SHEET)
        _build_contact_sheet(screenshot_results, LEGACY_CONTACT_SHEET)

    _write_regression_report(report_lines, step_results, screenshot_results, errors)

    if errors:
        print(f"\nVisual regression FAILED. Report: {REGRESSION_REPORT}")
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("\nVisual regression PASSED")
    print(f"Report: {REGRESSION_REPORT}")
    print(f"Contact sheet: {CONTACT_SHEET}")
    return 0


def _expected_output_paths() -> list[Path]:
    paths = [REGRESSION_REPORT, CONTACT_SHEET, LEGACY_CONTACT_SHEET]
    for step in QA_STEPS:
        paths.append(step["report"])
        for _label, screenshot in step["screenshots"]:
            paths.append(screenshot)
    return paths


def _run_step(step: dict) -> dict:
    result = subprocess.run(
        step["command"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    errors: list[str] = []
    report_text = ""
    report_path: Path = step["report"]
    if report_path.exists():
        report_text = report_path.read_text(encoding="utf-8")
    else:
        errors.append(f"{step['name']} missing report: {report_path}")

    if result.returncode != 0:
        errors.append(f"{step['name']} command returned {result.returncode}")
    if step["pass_marker"] not in report_text or "Exit code: 0" not in report_text:
        errors.append(f"{step['name']} report did not contain pass markers")

    return {
        "name": step["name"],
        "command": " ".join(step["command"]),
        "returncode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "report": report_path,
        "report_text": report_text,
        "errors": errors,
    }


def _inspect_screenshots(started_at: float) -> list[dict]:
    results: list[dict] = []
    for step in QA_STEPS:
        for label, path in step["screenshots"]:
            entry = {
                "label": label,
                "path": path,
                "size": None,
                "mtime": None,
                "fresh": False,
                "non_black_ratio": 0.0,
                "bright_ratio": 0.0,
                "unique_color_buckets": 0,
                "errors": [],
            }
            if not path.exists():
                entry["errors"].append(f"{label} missing screenshot: {path}")
                results.append(entry)
                continue

            entry["mtime"] = path.stat().st_mtime
            entry["fresh"] = entry["mtime"] >= started_at
            if not entry["fresh"]:
                entry["errors"].append(f"{label} screenshot was not refreshed: {path}")

            with Image.open(path) as image:
                entry["size"] = image.size
                if image.size != EXPECTED_SIZE:
                    entry["errors"].append(f"{label} size is {image.size}, expected {EXPECTED_SIZE}")
                stats = _sample_image_stats(image.convert("RGBA"))
                entry.update(stats)

            if entry["non_black_ratio"] < 0.50:
                entry["errors"].append(f"{label} appears too blank/dark")
            if entry["unique_color_buckets"] < 18:
                entry["errors"].append(f"{label} has low visual diversity")
            results.append(entry)
    return results


def _sample_image_stats(image: Image.Image) -> dict:
    total = 0
    non_black = 0
    bright = 0
    buckets: set[tuple[int, int, int]] = set()
    width, height = image.size
    step = 12
    for y in range(0, height, step):
        for x in range(0, width, step):
            r, g, b, a = image.getpixel((x, y))
            luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            total += 1
            if luminance > 0.025 and a > 25:
                non_black += 1
            if luminance > 0.42:
                bright += 1
            buckets.add((r // 32, g // 32, b // 32))
    return {
        "non_black_ratio": non_black / max(total, 1),
        "bright_ratio": bright / max(total, 1),
        "unique_color_buckets": len(buckets),
    }


def _build_contact_sheet(screenshots: list[dict], output_path: Path) -> None:
    thumb_size = (608, 342)
    label_height = 46
    gap = 22
    margin = 28
    columns = 2
    rows = (len(screenshots) + columns - 1) // columns
    sheet_width = margin * 2 + columns * thumb_size[0] + (columns - 1) * gap
    sheet_height = margin * 2 + rows * (thumb_size[1] + label_height) + (rows - 1) * gap
    sheet = Image.new("RGB", (sheet_width, sheet_height), (12, 16, 22))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for index, screenshot in enumerate(screenshots):
        col = index % columns
        row = index // columns
        x = margin + col * (thumb_size[0] + gap)
        y = margin + row * (thumb_size[1] + label_height + gap)
        with Image.open(screenshot["path"]) as image:
            thumb = image.convert("RGB").resize(thumb_size, Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x, y + label_height))
        label = (
            f"{screenshot['label']} | "
            f"{screenshot['size'][0]}x{screenshot['size'][1]} | "
            f"nonblack {screenshot['non_black_ratio']:.3f} | "
            f"colors {screenshot['unique_color_buckets']}"
        )
        draw.rectangle((x, y, x + thumb_size[0], y + label_height - 1), fill=(20, 28, 38))
        draw.text((x + 14, y + 14), label, fill=(223, 230, 220), font=font)
        draw.rectangle(
            (x, y + label_height, x + thumb_size[0] - 1, y + label_height + thumb_size[1] - 1),
            outline=(96, 124, 138),
            width=2,
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def _write_regression_report(
    report_lines: list[str],
    step_results: list[dict],
    screenshot_results: list[dict],
    errors: list[str],
) -> None:
    status = "FAILED" if errors else "PASSED"
    report_lines.extend(
        [
            f"## Status: {status}",
            "",
            "## Godot QA Steps",
            "",
        ]
    )
    for result in step_results:
        report_lines.extend(
            [
                f"### {result['name']}",
                "",
                f"- Command: `{result['command']}`",
                f"- Return code: `{result['returncode']}`",
                f"- Report: `{result['report']}`",
                f"- Result: {'PASS' if not result['errors'] else 'FAIL'}",
                "",
            ]
        )
        if result["report_text"].strip():
            report_lines.extend(["```text", result["report_text"].strip(), "```", ""])

    report_lines.extend(["## Screenshots", ""])
    for result in screenshot_results:
        size = result["size"] or ("missing", "missing")
        report_lines.extend(
            [
                f"### {result['label']}",
                "",
                f"- Path: `{result['path']}`",
                f"- Size: `{size[0]}x{size[1]}`",
                f"- Refreshed this run: `{result['fresh']}`",
                f"- Non-black ratio: `{result['non_black_ratio']:.3f}`",
                f"- Bright ratio: `{result['bright_ratio']:.3f}`",
                f"- Unique color buckets: `{result['unique_color_buckets']}`",
                f"- Result: {'PASS' if not result['errors'] else 'FAIL'}",
                "",
            ]
        )
        if result["errors"]:
            report_lines.extend(["Errors:"])
            report_lines.extend([f"- {error}" for error in result["errors"]])
            report_lines.append("")

    report_lines.extend(
        [
            "## Artifacts",
            "",
            f"- Contact sheet: `{CONTACT_SHEET}`",
            f"- Compatibility contact sheet: `{LEGACY_CONTACT_SHEET}`",
            f"- Regression report: `{REGRESSION_REPORT}`",
            "",
        ]
    )

    if errors:
        report_lines.extend(["## Errors", ""])
        report_lines.extend([f"- {error}" for error in errors])
        report_lines.append("")

    REGRESSION_REPORT.write_text("\n".join(report_lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
