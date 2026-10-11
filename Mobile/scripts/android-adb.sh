# shellcheck shell=bash
# Shared Android SDK / adb helpers (source from other scripts; do not execute directly).

ROLLSPOT_AVD_NAME="${ROLLSPOT_AVD_NAME:-Pixel_9}"
ROLLSPOT_EMULATOR_DOC="Mobile/android/EMULATOR.md"

rollspot_resolve_android_sdk() {
  SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  export ANDROID_HOME="$SDK"
  ADB="$SDK/platform-tools/adb"
  EMULATOR="$SDK/emulator/emulator"
  export PATH="$SDK/platform-tools:$SDK/emulator:$PATH"
}

rollspot_primary_adb_serial() {
  rollspot_resolve_android_sdk
  "$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}'
}

rollspot_emulator_avd_name() {
  local serial="$1"
  rollspot_resolve_android_sdk
  # Emulator console prints "OK" on a second line; do not strip all newlines or names become "Pixel_9OK".
  "$ADB" -s "$serial" emu avd name 2>/dev/null | head -n1 | tr -d '\r'
}

rollspot_avd_exists() {
  local name="${1:-$ROLLSPOT_AVD_NAME}"
  rollspot_resolve_android_sdk
  local avdmanager="$SDK/cmdline-tools/latest/bin/avdmanager"
  if [ ! -x "$avdmanager" ]; then
    avdmanager="$SDK/cmdline-tools/bin/avdmanager"
  fi
  if [ ! -x "$avdmanager" ]; then
    return 2
  fi
  "$avdmanager" list avd 2>/dev/null | grep -q "Name: ${name}$"
}

# Ping from guest OS; returns 0 when a probe succeeds.
rollspot_emulator_network_ok() {
  local serial="$1"
  rollspot_resolve_android_sdk
  if "$ADB" -s "$serial" shell ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    return 0
  fi
  if "$ADB" -s "$serial" shell ping -c 1 -W 2 100.64.0.3 >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

rollspot_wait_for_network() {
  local serial="$1"
  local max_seconds="${2:-90}"
  local elapsed=0
  rollspot_resolve_android_sdk

  while [ "$elapsed" -lt "$max_seconds" ]; do
    if rollspot_emulator_network_ok "$serial"; then
      echo "Emulator network OK ($serial)."
      return 0
    fi
    if [ "$elapsed" -eq 0 ]; then
      echo "Waiting for emulator network / AndroidWifi (up to ${max_seconds}s)…"
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done

  echo "Emulator network check failed (ping from guest OS)." >&2
  echo "See $ROLLSPOT_EMULATOR_DOC — Wi‑Fi / VPN / cold boot." >&2
  return 1
}

rollspot_assert_expected_avd() {
  local serial="$1"
  local expected="${2:-$ROLLSPOT_AVD_NAME}"
  case "$serial" in
    emulator-*)
      local name
      name="$(rollspot_emulator_avd_name "$serial")"
      if [ "$name" != "$expected" ]; then
        echo "Wrong emulator: AVD '$name' (expected '$expected')." >&2
        echo "Quit other emulators and run: Mobile/scripts/start-pixel-9-emulator.sh" >&2
        echo "Details: $ROLLSPOT_EMULATOR_DOC" >&2
        return 1
      fi
      ;;
  esac
  return 0
}

# Wait until at least one adb device is online, booted, and network probe passes.
rollspot_wait_for_android_ready() {
  local max_seconds="${1:-180}"
  local network_seconds="${2:-90}"
  rollspot_resolve_android_sdk
  if [ ! -x "$ADB" ]; then
    echo "Android SDK platform-tools not found at $ADB" >&2
    echo "Install Android Studio SDK or set ANDROID_HOME." >&2
    return 1
  fi

  "$ADB" start-server >/dev/null 2>&1 || true

  local elapsed=0
  while [ "$elapsed" -lt "$max_seconds" ]; do
    local serial
    serial="$(rollspot_primary_adb_serial)"
    if [ -n "$serial" ]; then
      local boot
      boot="$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
      if [ "$boot" = "1" ]; then
        if rollspot_wait_for_network "$serial" "$network_seconds"; then
          local avd_name=""
          if [[ "$serial" == emulator-* ]]; then
            avd_name="$(rollspot_emulator_avd_name "$serial")"
          fi
          if [ -n "$avd_name" ]; then
            echo "Android ready ($serial, AVD $avd_name)."
          else
            echo "Android ready ($serial)."
          fi
          return 0
        fi
        return 1
      fi
    fi
    if [ "$elapsed" -eq 0 ]; then
      echo "Waiting for emulator to finish booting (up to ${max_seconds}s)…"
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done

  echo "Timed out waiting for a ready Android device." >&2
  echo "Try: $ADB kill-server && $ADB start-server" >&2
  echo "Log: /tmp/pixel_9_emulator.log" >&2
  echo "Details: $ROLLSPOT_EMULATOR_DOC" >&2
  return 1
}

rollspot_count_adb_devices() {
  rollspot_resolve_android_sdk
  "$ADB" start-server >/dev/null 2>&1 || true
  "$ADB" devices | awk 'NR>1 && $2=="device" {print $1}' | wc -l | tr -d ' '
}

# Call before Gradle install: correct AVD (emulators only) + quick network check.
rollspot_prepare_install_target() {
  local serial
  serial="$(rollspot_primary_adb_serial)"
  if [ -z "$serial" ]; then
    echo "No adb device in 'device' state." >&2
    echo "Run: Mobile/scripts/start-pixel-9-emulator.sh" >&2
    echo "Details: $ROLLSPOT_EMULATOR_DOC" >&2
    return 1
  fi
  rollspot_assert_expected_avd "$serial" || return 1
  if [[ "$serial" == emulator-* ]]; then
    rollspot_wait_for_network "$serial" 30 || return 1
  fi
  return 0
}

ROLLSPOT_ANDROID_PACKAGE="${ROLLSPOT_ANDROID_PACKAGE:-com.rollspot.app}"
ROLLSPOT_ANDROID_ACTIVITY="${ROLLSPOT_ANDROID_ACTIVITY:-.MainActivity}"

rollspot_launch_rollspot_app() {
  local serial
  serial="$(rollspot_primary_adb_serial)"
  if [ -z "$serial" ]; then
    echo "No device to launch app on." >&2
    return 1
  fi
  rollspot_resolve_android_sdk
  "$ADB" -s "$serial" shell am start -n "${ROLLSPOT_ANDROID_PACKAGE}/${ROLLSPOT_ANDROID_ACTIVITY}" >/dev/null
  echo "Launched Rollspot on $serial."
}
