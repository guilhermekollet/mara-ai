#!/bin/bash
# Builds Mara AI for a release and zips it into dist/, with a SHA-256 checksum next to it.
# Usage: scripts/package-release.sh 0.1.0
#
# The app is signed ad hoc and not notarized (the project has no paid Apple Developer account), so
# the first time someone opens it macOS asks them to allow it. README.md explains how.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/package-release.sh <version>}"
ARCH="$(uname -m)"

rm -rf dist
MARA_VERSION="$VERSION" MARA_SIGNING_IDENTITY="-" MARA_OUTPUT_DIR="dist" ./build.sh

ZIP="Mara-AI-$VERSION-macOS-$ARCH.zip"
# ditto keeps the bundle's permissions, symlinks and signature intact, unlike plain zip.
ditto -c -k --sequesterRsrc --keepParent "dist/Mara AI.app" "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256")

echo "Packaged: dist/$ZIP"
