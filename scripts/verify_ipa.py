#!/usr/bin/env python3
"""Validate a built SpeedX .ipa — structure, Info.plist, Mach-O binary.

Intended to run on Windows after copying an .ipa out of any build system
(the macOS builder, GitHub Actions artifact, etc.).

Usage:  python verify_ipa.py path/to/SpeedX.ipa
"""
from __future__ import annotations

import plistlib
import struct
import sys
import zipfile
from pathlib import Path

EXPECTED_CPU = b"\x0c\x00\x00\x00"  # CPU_TYPE_ARM64 cputype field (little-endian)
failures: list[str] = []


def check(ok: bool, message: str) -> None:
    if not ok:
        failures.append(message)
    print(f"  {'ok  ' if ok else 'FAIL'}  {message}")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    ipa = Path(sys.argv[1])
    if not ipa.exists():
        print(f"file not found: {ipa}")
        return 2
    print(f"Verifying {ipa} ({ipa.stat().st_size:,} bytes)\n" + "-" * 60)

    try:
        with zipfile.ZipFile(ipa) as z:
            names = z.namelist()
            masthead = [n for n in names if n.count("/") == 2 and n.endswith(".app/") or n.endswith(".app")]
            apps = {n.split("/")[1] for n in names if n.startswith("Payload/") and n.split("/")[1].endswith(".app")}
            check(len(apps) == 1, f"exactly one .app bundle: {apps or 'none'}")
            app_name = sorted(apps)[0] if apps else ""
            app_prefix = f"Payload/{app_name}/"

            binaries = [n for n in names if n.startswith(app_prefix)
                        and "/" not in n[len(app_prefix):]
                        and not n.endswith("/")]
            exe = ipa.stem
            exe_candidates = [n for n in binaries if Path(n).name == app_name[:-4]]
            check(bool(exe_candidates), f"main executable present ({app_name[:-4]})")

            if exe_candidates:
                raw = z.read(exe_candidates[0])
                magic = raw[:4]
                # MH_MAGIC_64 = 0xfeedfacf (little-endian on disk)
                check(magic == b"\xcf\xfa\xed\xfe", "executable is a Mach-O 64-bit binary")
                if magic == b"\xcf\xfa\xed\xfe":
                    cputype = raw[4:8]
                    check(cputype == EXPECTED_CPU, "executable targets arm64 (iOS device)")
                check(len(raw) > 100_000, f"executable size sane ({len(raw):,} bytes)")

            plist_entry = app_prefix + "Info.plist"
            check(plist_entry in names, "embedded Info.plist present")
            if plist_entry in names:
                pl = plistlib.loads(z.read(plist_entry))
                check(isinstance(pl, dict), "embedded Info.plist parses")
                expected = {"CFBundleDisplayName": "SpeedX", "CFBundleIdentifier": None}
                display = pl.get("CFBundleDisplayName", pl.get("CFBundleName", ""))
                check(display == "SpeedX", f"bundle display name: {display!r}")
                check(bool(pl.get("NSLocationWhenInUseUsageDescription")),
                      "location usage description present")
                check("location" in (pl.get("UIBackgroundModes") or []),
                      "UIBackgroundModes contains 'location'")
                check(bool(pl.get("CFBundleShortVersionString")), "short version string present")
                check(bool(pl.get("CFBundleVersion")), "bundle version present")

            embedded = app_prefix + "embedded.mobileprovision"
            if embedded in names:
                print("  note  embedded.mobileprovision found — signed with a profile")
            else:
                print("  note  no embedded.mobileprovision (unsigned build — sign with"
                      " Sideloadly/AltStore/Xcode before installing)")
    except zipfile.BadZipFile:
        print("FAIL: not a zip archive — the .ipa is corrupt or misnamed.")
        return 1

    print("-" * 60)
    if failures:
        print(f"{len(failures)} problem(s):")
        for problem in failures:
            print(f"  - {problem}")
        return 1
    print("IPA structure looks correct.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
