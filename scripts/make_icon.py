#!/usr/bin/env python3
"""Render the SpeedX app icon (1024x1024, dark + neon green) with no dependencies.

Draws the same motif as the in-app dial: dark charcoal base, full neon gauge
arc with the gap at the BOTTOM (starts 135 deg screen-clockwise from east,
sweeps 270 deg to 45 deg), needle at a 72 km/h reading and hub, so the
home-screen icon reads as "speedometer" and matches SpeedometerGauge.

Note: iOS masks the icon into its own squircle, so we fill the full square.

Writes:  Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
Also writes a small preview copy to build/icon-preview/ for quick visual checks.
"""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
ARC_INNER = 440.0
ARC_OUTER = 496.0
ARC_RADIUS = (ARC_INNER + ARC_OUTER) / 2
ARC_HALF = (ARC_OUTER - ARC_INNER) / 2
ARC_START_DEG = 135.0  # screen coords (y down): 0 deg = east, 90 deg = south
ARC_SWEEP_DEG = 270.0
NEEDLE_VALUE = 72.0    # km/h reading shown on the 0..90 dial
NEEDLE_WIDTH = 18.0
NEEDLE_OUTER = 452.0
NEON = (0x30, 0xFF, 0x7A)
BASE = (0x0A, 0x0F, 0x11)


def gauge_max_kmh() -> float:
    return 90.0


def chunk(tag: str, payload: bytes) -> bytes:
    return (struct.pack(">I", len(payload)) + tag.encode() + payload
            + struct.pack(">I", zlib.crc32(tag.encode() + payload) & 0xFFFFFFFF))


def write_png(out: Path, size: int, pixels: bytes) -> None:
    raw = b"".join(b"\x00" + pixels[y * size * 3:(y + 1) * size * 3] for y in range(size))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    out.write_bytes(b"\x89PNG\r\n\x1a\n"
                    + chunk("IHDR", ihdr)
                    + chunk("IDAT", zlib.compress(raw, 9))
                    + chunk("IEND", b""))


def cap_center(angle_deg: float) -> tuple[float, float]:
    a = math.radians(angle_deg)
    return (SIZE / 2 + ARC_RADIUS * math.cos(a), SIZE / 2 + ARC_RADIUS * math.sin(a))


CAP_START = cap_center(ARC_START_DEG)                 # 0 km/h end
CAP_END = cap_center(ARC_START_DEG + ARC_SWEEP_DEG)   # max-speed end
NEEDLE_ANGLE = math.radians(ARC_START_DEG + ARC_SWEEP_DEG * NEEDLE_VALUE / gauge_max_kmh())


def render() -> bytes:
    cx = cy = SIZE / 2
    cos_a, sin_a = math.cos(NEEDLE_ANGLE), math.sin(NEEDLE_ANGLE)
    buf = bytearray(SIZE * SIZE * 3)

    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            r, g, b = BASE

            # subtle radial vignette towards the edges
            vig = max(0.0, 1.0 - dist / (SIZE * 0.85))
            r *= 0.35 + 0.65 * vig
            g *= 0.35 + 0.65 * vig
            b *= 0.35 + 0.65 * vig

            # gauge band with soft edges (gap at the bottom, like the in-app dial)
            angle = math.degrees(math.atan2(dy, dx)) % 360.0
            rel = (angle - ARC_START_DEG) % 360.0
            in_arc = rel <= ARC_SWEEP_DEG
            if in_arc and ARC_INNER <= dist <= ARC_OUTER:
                depth = (dist - ARC_INNER) / (ARC_OUTER - ARC_INNER)
                gw = min(1.0, 0.15 + min(depth, 1.0 - depth) * 14)
                r += NEON[0] * gw
                g += NEON[1] * gw
                b += NEON[2] * gw
            elif in_arc and ARC_INNER - 50 <= dist <= ARC_OUTER + 50:
                # soft glow halo just inside/outside the band
                halo = 1.0 - min(abs(dist - ARC_RADIUS) - ARC_HALF, 50.0) / 50.0
                r += NEON[0] * 0.10 * halo
                g += NEON[1] * 0.10 * halo
                b += NEON[2] * 0.10 * halo
            elif ARC_INNER - 50 <= dist <= ARC_OUTER + 50:
                for cap_x, cap_y in (CAP_START, CAP_END):
                    cd = math.hypot(x - cap_x, y - cap_y)
                    if cd <= ARC_HALF:
                        edge = 1.0 - cd / ARC_HALF
                        gw = min(1.0, 0.15 + edge * 12)
                        r += NEON[0] * gw
                        g += NEON[1] * gw
                        b += NEON[2] * gw
                        break

            # needle capsule (rotated frame), pointing up-right at "72 km/h"
            nx = dx * cos_a + dy * sin_a
            ny = -dx * sin_a + dy * cos_a
            if 0 <= nx <= NEEDLE_OUTER and abs(ny) <= NEEDLE_WIDTH / 2:
                taper = 1.0 if nx < NEEDLE_OUTER - 90 else max(0.2, 1.0 - (nx - (NEEDLE_OUTER - 90)) / 90)
                r += NEON[0] * taper
                g += NEON[1] * taper
                b += NEON[2] * taper
                if nx > NEEDLE_OUTER - 55 and abs(ny) <= 13:
                    r, g, b = 0xFF, 0xFF, 0xFF

            # hub: dark fill, neon ring, white centre dot
            if dist < 52:
                r, g, b = 0x10, 0x16, 0x18
                if abs(dist - 44) < 5:
                    r, g, b = NEON
                if dist < 14:
                    r, g, b = 0xFF, 0xFF, 0xFF

            i = (y * SIZE + x) * 3
            buf[i] = min(int(r), 255)
            buf[i + 1] = min(int(g), 255)
            buf[i + 2] = min(int(b), 255)

    return bytes(buf)


def main() -> None:
    here = Path(__file__).resolve().parent
    icon_dir = here.parent / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
    icon_dir.mkdir(parents=True, exist_ok=True)
    pixels = render()
    out = icon_dir / "AppIcon.png"
    write_png(out, SIZE, pixels)
    print(f"wrote {out} ({out.stat().st_size:,} bytes)")

    previews = here.parent / "build" / "icon-preview"
    previews.mkdir(parents=True, exist_ok=True)
    small = previews / "AppIcon@64.png"
    step = SIZE // 64
    tiny = bytearray(64 * 64 * 3)
    for y in range(64):
        for x in range(64):
            i = (y * 64 + x) * 3
            j = (y * step * SIZE + x * step) * 3
            tiny[i:i + 3] = pixels[j:j + 3]
    write_png(small, 64, bytes(tiny))
    print(f"wrote {small}")


if __name__ == "__main__":
    main()
