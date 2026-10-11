#!/usr/bin/env bash
# Copy Contribute flow PNGs from iOS Assets.xcassets into Android drawable-nodpi.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XC="$ROOT/Rollspot/Resources/Assets.xcassets"
OUT="$ROOT/android/app/src/main/res/drawable-nodpi"
mkdir -p "$OUT"

copy() {
  local ios_name="$1"
  local android_name="$2"
  local src
  src=$(find "$XC" -path "*${ios_name}.imageset*" -name "*.png" 2>/dev/null | head -1)
  if [[ -z "$src" ]]; then
    echo "WARN: missing $ios_name" >&2
    return
  fi
  cp "$src" "$OUT/${android_name}.png"
  echo "OK $android_name"
}

copy "Entrance Mall Asset" contribute_entrance_mall
copy "Lobby Asset" contribute_lobby
copy "Basement Asset" contribute_basement
copy "Elevator Question Asset" contribute_elevator_question
copy "Toilet Survey Asset" contribute_toilet_survey
copy "Thank You Asset" contribute_thank_you
copy "Onboarding Contribute Asset" contribute_onboarding
copy "Ramp Icon" chip_ramp
copy "Handrail Icon" chip_handrail
copy "Automatic Doors Icon" chip_automatic_doors
copy "Review - Security Assistance" chip_security_assistance
copy "Review - Wheelchair Available" chip_wheelchair_available
copy "Review - Elevators" chip_elevator
copy "Review - Disabled Parking" chip_disabled_parking

echo "Done → $OUT"
