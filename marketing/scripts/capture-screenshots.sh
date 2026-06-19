#!/usr/bin/env bash
#
# Reproducible App Store screenshot capture for CleanShots.
#
# Builds the app, boots an iOS 27 simulator at an App Store device size,
# seeds the photo library with near-duplicate images so the dedupe screens
# have real content, grants Photos access, and launches the app. Navigation
# to each screen is done by hand (or via computer-use); capture exact
# device-resolution PNGs with:
#
#   xcrun simctl io <UDID> screenshot out.png
#
# App Store device sizes used:
#   6.9" iPhone  -> iPhone 17 Pro Max   (1320 x 2868)
#   13"  iPad    -> iPad Pro 13-inch M5 (2064 x 2752)
#
# Usage: marketing/scripts/capture-screenshots.sh [iphone|ipad]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KIND="${1:-iphone}"
BUNDLE_ID="com.vnaidu.CleanShots"
SEED_DIR="$(mktemp -d)"

case "$KIND" in
  iphone) DEVICE="iPhone 17 Pro Max" ;;
  ipad)   DEVICE="iPad Pro 13-inch (M5)" ;;
  *) echo "usage: $0 [iphone|ipad]"; exit 1 ;;
esac

# Newest iOS 27 simulator UDID for the chosen device.
UDID="$(xcrun simctl list devices available | awk -v d="$DEVICE" '
  /-- iOS 27/{ios=1} /-- iOS/ && !/27/{ios=0}
  ios && index($0, d){ if (match($0,/\(([0-9A-F-]{36})\)/)) { print substr($0,RSTART+1,36); exit } }')"
[ -n "$UDID" ] || { echo "No iOS 27 '$DEVICE' simulator found"; exit 1; }
echo "Using $DEVICE ($UDID)"

echo "Generating seed images…"
swift "$ROOT/marketing/scripts/generate-seed-images.swift" "$SEED_DIR"

echo "Building app…"
xcodebuild build -project "$ROOT/CleanShots.xcodeproj" -scheme CleanShots \
  -destination "platform=iOS Simulator,id=$UDID" -quiet
APP="$(find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator/CleanShots.app' -maxdepth 8 2>/dev/null | head -1)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl addmedia "$UDID" "$SEED_DIR"/*.png
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant photos "$BUNDLE_ID" || true
open -a Simulator --args -CurrentDeviceUDID "$UDID"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo
echo "Ready. Navigate the app, then capture screens with:"
echo "  xcrun simctl io $UDID screenshot marketing/screenshots/<name>.png"
