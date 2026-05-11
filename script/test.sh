#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SDKROOT:-}" && -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]]; then
  export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
fi

SWIFT_TEST_ARGS=()
CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_LIBS="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

if [[ -d "$CLT_FRAMEWORKS" ]]; then
  SWIFT_TEST_ARGS+=(
    -Xswiftc -F
    -Xswiftc "$CLT_FRAMEWORKS"
    -Xlinker -rpath
    -Xlinker "$CLT_FRAMEWORKS"
  )
fi

if [[ -d "$CLT_LIBS" ]]; then
  SWIFT_TEST_ARGS+=(
    -Xlinker -rpath
    -Xlinker "$CLT_LIBS"
  )
fi

swift test "${SWIFT_TEST_ARGS[@]}"
