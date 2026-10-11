#!/usr/bin/env bash
# Start Pixel_9 emulator (if needed), install debug APK, launch Rollspot.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for arg in "$@"; do
  if [ "$arg" = "--create-avd" ]; then
    "$SCRIPT_DIR/create-pixel-9-avd.sh"
  fi
done

"$SCRIPT_DIR/start-pixel-9-emulator.sh"
"$SCRIPT_DIR/install-android-debug.sh"
