#!/usr/bin/env bash
# Install the debug APK on a running emulator or USB device. Safe to run from any directory.
set -euo pipefail

MOBILE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android-adb.sh
source "$SCRIPT_DIR/android-adb.sh"

cd "$MOBILE_ROOT"

if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
  for candidate in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    /opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
  do
    if [ -x "$candidate/bin/java" ]; then
      export JAVA_HOME="$candidate"
      break
    fi
  done
fi

if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
  if [ -x /usr/libexec/java_home ]; then
    export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
  fi
fi

if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
  echo "No JDK found. Install Android Studio, or: brew install openjdk@25" >&2
  echo "Then run: export JAVA_HOME=\"/Applications/Android Studio.app/Contents/jbr/Contents/Home\"" >&2
  exit 1
fi

echo "Using JAVA_HOME=$JAVA_HOME"

WAIT="${ROLLSPOT_ADB_WAIT:-0}"
# Extra Gradle args (avoid empty-array expansion with `set -u` on macOS bash 3.2).
INSTALL_GRADLE_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --wait) WAIT=1 ;;
    *) INSTALL_GRADLE_ARGS+=("$arg") ;;
  esac
done

rollspot_resolve_android_sdk
if [ ! -x "$ADB" ]; then
  echo "adb not found at $ADB — install Android SDK platform-tools." >&2
  exit 1
fi

if [ "$(rollspot_count_adb_devices)" = "0" ]; then
  if [ "$WAIT" = "1" ]; then
    rollspot_wait_for_android_ready 180 90 || exit 1
  else
    echo "No emulator or USB device ready (adb needs state 'device', not offline)." >&2
    echo "Read $ROLLSPOT_EMULATOR_DOC first, then:" >&2
    echo "  $MOBILE_ROOT/scripts/run-android-debug.sh" >&2
    exit 1
  fi
fi

rollspot_prepare_install_target || exit 1

rollspot_gradlew_install_debug() {
  if [ "${#INSTALL_GRADLE_ARGS[@]}" -gt 0 ]; then
    "$MOBILE_ROOT/gradlew" :androidApp:installDebug "${INSTALL_GRADLE_ARGS[@]}"
  else
    "$MOBILE_ROOT/gradlew" :androidApp:installDebug
  fi
}

install_log="$(mktemp -t rollspot_gradle_install)"
if ! rollspot_gradlew_install_debug 2>&1 | tee "$install_log"; then
  if grep -qE 'configuration-cache\.lock|Timeout waiting to lock Configuration Cache' "$install_log"; then
    echo "Gradle configuration cache locked — stopping daemons and retrying once…" >&2
    "$MOBILE_ROOT/gradlew" --stop >/dev/null 2>&1 || true
    sleep 2
    rollspot_gradlew_install_debug || exit 1
  else
    exit 1
  fi
fi
rm -f "$install_log"

rollspot_launch_rollspot_app
