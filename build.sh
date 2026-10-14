#!/bin/bash
# Builds Mara AI and assembles "build/Mara AI.app" (macOS only grants the screen-recording
# permission to a real app bundle, so `swift run` is not enough).
#
# Signing: set MARA_SIGNING_IDENTITY to a code-signing identity from your keychain to keep the
# same signature across builds, so macOS stops asking for the permission after every rebuild.
# `scripts/create-signing-cert.sh` creates a local one. Without it the app is signed ad hoc.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Mara AI.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MaraAI "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"

IDENTITY="${MARA_SIGNING_IDENTITY:-Mara AI Local Signing}"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi

echo "Built: $APP"
echo "Open it with: open \"$APP\""
