#!/bin/zsh
# End-to-end flows (Maestro) against a local backend, on an iOS simulator and/or an Android emulator.
#
#   cd backend && npm run dev          # local worker on :8787, places synced (see CLAUDE.md)
#   brew install maestro               # or https://maestro.mobile.dev
#   Mobile/e2e/run.sh android|ios [flow.yaml ...]
#
# Needs a debug build installed; set E2E_DEVICE when several devices are running. Flows 03+ sign in with E2E_EMAIL / E2E_PASSWORD (a verified local
# account) and leave reviews on the places below. Screenshots land in Mobile/e2e/out/<platform>.
cd "${0:A:h}"
platform=${1:?android or ios}; shift
flows=("$@")
(( $#flows )) || flows=(01-launch.yaml 02-search-place.yaml 03-contribute.yaml 04-continue-survey.yaml 05-edit-response.yaml 06-save.yaml 07-sign-out.yaml)
# E2E_DEVICE: an emulator serial or simulator UDID when more than one is running.
device=(${E2E_DEVICE:+--device $E2E_DEVICE})
if [[ $platform == android ]]; then app=com.rollspot.app; api=http://10.0.2.2:8787; adb ${E2E_DEVICE:+-s $E2E_DEVICE} reverse tcp:8787 tcp:8787 >/dev/null
else app=com.puspadifellas.app; api=http://localhost:8787; fi
lookup() { curl -s "http://localhost:8787/v1/places/search?q=$1&lat=-8.72&lng=115.17" | python3 -c "import json,sys;print(json.load(sys.stdin)['places'][0]['id'])"; }
export MAESTRO_CLI_NO_ANALYTICS=1
for flow in $flows; do
  place=$(lookup beachwalk)
  [[ $flow == 04-* ]] && place=$(lookup "discovery%20mall")
  [[ $flow == 06-* ]] && place=$(lookup "center%20of%20kuta")
  echo "== $platform $flow"
  maestro $device test --test-output-dir out/$platform -e APP_ID=$app -e API=$api -e PLACE=$place -e PLATFORM=$platform \
    -e EMAIL=${E2E_EMAIL:-design@rollspot.dev} -e PASSWORD=${E2E_PASSWORD:-Passw0rd!} $flow
done
