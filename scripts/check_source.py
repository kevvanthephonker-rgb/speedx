#!/usr/bin/env python3
"""Static sanity checks for the SpeedX iOS project. Runs anywhere Python runs.

Checks that:
  * every .swift file on disk is referenced by project.pbxproj (and no phantom refs)
  * every .swift file has balanced braces/parens
  * Info.plist parses and carries the keys Core Location needs
  * the asset catalog + AppIcon reference files that actually exist
  * build_ipa.sh and the GitHub workflow are present and syntactically sane
"""
from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBX = ROOT / "SpeedX.xcodeproj" / "project.pbxproj"
SRC = ROOT / "SpeedX"

failures: list[str] = []
checks = 0


def check(ok: bool, message: str) -> None:
    global checks
    checks += 1
    if not ok:
        failures.append(message)
    print(f"  {'ok  ' if ok else 'FAIL'}  {message}")


def main() -> int:
    print("SpeedX source audit\n" + "-" * 60)

    swift_files = sorted(p for p in SRC.glob("*.swift"))
    check(len(swift_files) >= 6, f"found {len(swift_files)} swift sources in SpeedX/")

    pbx_text = PBX.read_text(encoding="utf-8") if PBX.exists() else ""
    if pbx_text:
        for swift in swift_files:
            check(swift.name in pbx_text, f"pbxproj references {swift.name}")
            text = swift.read_text(encoding="utf-8")
            check(text.count("{") == text.count("}"), f"{swift.name} braces balanced")
            check(text.count("(") == text.count(")"), f"{swift.name} parens balanced")
        referenced = set(re.findall(r"path = (\S+\.swift);", pbx_text))
        for name in sorted(referenced):
            check((SRC / name).exists(), f"referenced file exists on disk: {name}")
    else:
        failures.append("project.pbxproj missing/unreadable")
        print("  FAIL  project.pbxproj missing")

    # Info.plist requirements
    info_path = SRC / "Info.plist"
    if info_path.exists():
        try:
            ET.parse(info_path)
            plist_text = info_path.read_text(encoding="utf-8")
            for key in ("NSLocationWhenInUseUsageDescription",
                        "UIBackgroundModes",
                        "UILaunchScreen",
                        "UISupportedInterfaceOrientations",
                        "CFBundleDisplayName"):
                check(key in plist_text, f"Info.plist contains {key}")
        except ET.ParseError as exc:
            failures.append(f"Info.plist XML parse error: {exc}")
            print(f"  FAIL  Info.plist XML parse error: {exc}")
    else:
        failures.append("Info.plist missing")

    # Asset catalog
    catalog = ROOT / "Resources" / "Assets.xcassets"
    assets_json = catalog / "Contents.json"
    icon_json = catalog / "AppIcon.appiconset" / "Contents.json"
    check(assets_json.exists(), "Assets.xcassets/Contents.json exists")
    if icon_json.exists():
        data = json.loads(icon_json.read_text(encoding="utf-8"))
        for image in data.get("images", []):
            icon_file = image.get("filename")
            if icon_file:
                icon_path = icon_json.parent / icon_file
                check(icon_path.exists() and icon_path.stat().st_size > 1000,
                      f"app icon {icon_file} exists ({icon_path.stat().st_size:,} bytes)")

    # Build automation
    check((ROOT / "build_ipa.sh").exists(), "build_ipa.sh present")
    workflow = ROOT / ".github" / "workflows" / "build_ipa.yml"
    check(workflow.exists(), "GitHub Actions workflow present")
    if workflow.exists():
        wf_text = workflow.read_text(encoding="utf-8")
        check("macos-" in wf_text, "workflow targets a macOS runner")
        check("build_ipa.sh" in wf_text, "workflow invokes build_ipa.sh")

    print("-" * 60)
    if failures:
        print(f"{len(failures)} problem(s):")
        for problem in failures:
            print(f"  - {problem}")
        return 1
    print(f"All {checks} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
