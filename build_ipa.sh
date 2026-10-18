#!/usr/bin/env bash
# =============================================================================
# SpeedX — one-shot iOS build (.ipa)
#
# Produces a REAL compiled app from Swift sources. On a Mac with Xcode 15+:
#   ./build_ipa.sh
#
# On GitHub Actions macOS runners this same script runs automatically on every
# push (see .github/workflows/build_ipa.yml) and the .ipa is saved as a workflow
# artifact.
#
# The .ipa is UNSIGNED — iOS will not install it as-is. Sign it on Windows with
# Sideloadly or AltStore (free Apple ID), or with Xcode (paid account).
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

BUILD="build"
IPA="$BUILD/SpeedX-unsigned.ipa"

echo "== SpeedX iOS build =="
xcodebuild -version

echo "==> Archive (device, unsigned; signing happens later on the installer side)"
xcodebuild \
    -project SpeedX.xcodeproj \
    -scheme SpeedX \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$BUILD/SpeedX.xcarchive" \
    archive \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    PRODUCT_NAME=SpeedX

APP="$(find "$BUILD/SpeedX.xcarchive/Products" -maxdepth 3 -type d -name 'SpeedX.app' -print -quit)"
if [ -z "$APP" ]; then
    echo "!! built SpeedX.app not found in archive" >&2
    exit 1
fi
echo "    built app: $APP"

echo "==> Package Payload/"
mkdir -p "$BUILD/Payload"
rm -rf "$BUILD/Payload/SpeedX.app"
cp -R "$APP" "$BUILD/Payload/SpeedX.app"

# the archive embeds an Info.plist; make sure nothing stale came along
rm -rf "$BUILD/Payload/SpeedX.app/_CodeSignature" 2>/dev/null || true

echo "==> Zip into $(basename "$IPA")"
rm -f "$IPA"
(
    cd "$BUILD"
    zip -qry "$(basename "$IPA")" Payload
)

echo "==> Self-checks on the artifact"
python3 scripts/verify_ipa.py "$IPA" || true

echo "==> Done: $IPA"
ls -l "$IPA"
