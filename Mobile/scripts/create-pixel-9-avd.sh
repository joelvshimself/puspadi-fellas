#!/usr/bin/env bash
# Create the canonical Rollspot Pixel_9 AVD (Google Play, arm64). Idempotent.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android-adb.sh
source "$SCRIPT_DIR/android-adb.sh"

AVD_NAME="${ROLLSPOT_AVD_NAME:-Pixel_9}"
AVD_API="${ROLLSPOT_AVD_API:-36}"
IMAGE="system-images;android-${AVD_API};google_apis_playstore;arm64-v8a"

rollspot_resolve_android_sdk

CMDLINE="$SDK/cmdline-tools/latest/bin"
if [ ! -x "$CMDLINE/sdkmanager" ]; then
  CMDLINE="$SDK/cmdline-tools/bin"
fi
if [ ! -x "$CMDLINE/sdkmanager" ]; then
  echo "sdkmanager not found under $SDK/cmdline-tools. Install Android Studio SDK Command-line Tools." >&2
  exit 1
fi

export PATH="$CMDLINE:$PATH"

if avdmanager list avd 2>/dev/null | grep -q "Name: ${AVD_NAME}$"; then
  echo "AVD '${AVD_NAME}' already exists."
  echo "Next: $SCRIPT_DIR/start-pixel-9-emulator.sh"
  exit 0
fi

echo "Installing emulator packages (API ${AVD_API}, Google Play arm64)…"
yes | sdkmanager --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-${AVD_API}" \
  "$IMAGE"

DEVICE_ID="pixel_9"
if ! avdmanager list device 2>/dev/null | grep -q "id: ${DEVICE_ID} "; then
  DEVICE_ID="pixel"
fi

echo "Creating AVD '${AVD_NAME}' (device ${DEVICE_ID})…"
echo no | avdmanager create avd -n "$AVD_NAME" -k "$IMAGE" -d "$DEVICE_ID"

echo "Done. Start with: $SCRIPT_DIR/start-pixel-9-emulator.sh"
