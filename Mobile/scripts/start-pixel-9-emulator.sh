#!/usr/bin/env bash
# Run from Terminal.app if the emulator crashes when started from an IDE agent.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android-adb.sh
source "$SCRIPT_DIR/android-adb.sh"

AVD_NAME="${ROLLSPOT_AVD_NAME:-Pixel_9}"
rollspot_resolve_android_sdk
LOG=/tmp/pixel_9_emulator.log
PIDFILE=/tmp/pixel_9_emulator.pid

"$ADB" start-server >/dev/null 2>&1 || true

if ! rollspot_avd_exists "$AVD_NAME"; then
  echo "AVD '${AVD_NAME}' not found." >&2
  echo "Create it first: $SCRIPT_DIR/create-pixel-9-avd.sh" >&2
  echo "Details: $ROLLSPOT_EMULATOR_DOC" >&2
  exit 1
fi

# Already booted?
if [ "$(rollspot_count_adb_devices)" != "0" ]; then
  serial="$(rollspot_primary_adb_serial)"
  if rollspot_wait_for_android_ready 30 60; then
    if [[ "${serial:-}" == emulator-* ]]; then
      rollspot_assert_expected_avd "$serial" "$AVD_NAME" || exit 1
    fi
    echo "Emulator already connected."
    exit 0
  fi
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "Emulator process running (pid $(cat "$PIDFILE")); waiting for adb…"
  rollspot_wait_for_android_ready 180 90
  exit 0
fi

if [ ! -x "$EMULATOR" ]; then
  echo "Emulator binary not found: $EMULATOR" >&2
  exit 1
fi

: > "$LOG"
nohup "$EMULATOR" \
  -avd "$AVD_NAME" \
  -gpu swiftshader_indirect \
  -dns-server 8.8.8.8,8.8.4.4 \
  -no-snapshot-save \
  -no-boot-anim \
  >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
echo "Started ${AVD_NAME} emulator (pid $(cat "$PIDFILE")). Log: $LOG"

rollspot_wait_for_android_ready 180 90
