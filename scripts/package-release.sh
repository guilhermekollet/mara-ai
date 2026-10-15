#!/bin/bash
# Builds Mara AI for a release and zips it into dist/, with a SHA-256 checksum next to it.
# Usage: scripts/package-release.sh 0.1.0
#
# The app is not notarized (the project has no paid Apple Developer account), so the first time
# someone opens it macOS asks them to allow it; README.md explains how. The Release workflow signs
# it with the project's self-signed certificate (MARA_SIGNING_IDENTITY), which keeps macOS's
# recording permission across updates, and signs the zip for the updater (MARA_UPDATE_PRIVATE_KEY).
# Without them the app is signed ad hoc and the zip is not signed for updates.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/package-release.sh <version>}"
ARCH="$(uname -m)"

rm -rf dist
MARA_VERSION="$VERSION" MARA_SIGNING_IDENTITY="${MARA_SIGNING_IDENTITY:--}" MARA_UPDATES=1 \
  MARA_OUTPUT_DIR="dist" ./build.sh

ZIP="Mara-AI-$VERSION-macOS-$ARCH.zip"
# ditto keeps the bundle's permissions, symlinks and signature intact, unlike plain zip.
ditto -c -k --sequesterRsrc --keepParent "dist/Mara AI.app" "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256")

# The signature the updater checks before installing, made with the key that matches the public
# key in Updater.swift.
if [[ -n "${MARA_UPDATE_PRIVATE_KEY:-}" ]]; then
  PUBLIC_KEY="$(sed -n 's/.*static let publicKey = "\(.*\)".*/\1/p' Sources/MaraAI/Updater.swift)"
  swift scripts/sign-update.swift "dist/$ZIP" --expect "$PUBLIC_KEY"
fi

echo "Packaged: dist/$ZIP"
