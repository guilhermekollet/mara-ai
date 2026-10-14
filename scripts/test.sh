#!/bin/bash
# Runs the test suite. With Xcode selected, plain `swift test` works. With only the Command Line
# Tools, Swift needs to be pointed at the Testing framework that ships inside them.
set -euo pipefail
cd "$(dirname "$0")/.."

if xcode-select -p | grep -q "CommandLineTools"; then
  FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"
  swift test -Xswiftc -F -Xswiftc "$FRAMEWORKS" -Xlinker -rpath -Xlinker "$FRAMEWORKS" "$@"
else
  swift test "$@"
fi
