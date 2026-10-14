#!/bin/bash
# Builds Mara AI and assembles "build/Mara AI.app" (macOS only grants the screen-recording
# permission to a real app bundle, so `swift run` is not enough).
#
# Signing: set MARA_SIGNING_IDENTITY to a code-signing identity from your keychain to keep the
# same signature across builds, so macOS stops asking for the permission after every rebuild.
# `scripts/create-signing-cert.sh` creates a local one. Without it, or with MARA_SIGNING_IDENTITY=-,
# the app is signed ad hoc.
#
# Releases (scripts/package-release.sh) also set MARA_VERSION, stamped into the bundle's
# Info.plist, and MARA_OUTPUT_DIR, so packaging never replaces the app you are running from build/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="${MARA_OUTPUT_DIR:-build}/Mara AI.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MaraAI "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
if [[ -n "${MARA_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARA_VERSION" "$APP/Contents/Info.plist"
fi

IDENTITY="${MARA_SIGNING_IDENTITY:-Mara AI Local Signing}"
if [[ "$IDENTITY" != "-" ]] && security find-identity -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi

echo "Built: $APP"
echo "Open it with: open \"$APP\""
