#!/usr/bin/env bash
# LAN IP for debug iOS when Mac and iPhone share the same Wi‑Fi (not iPhone hotspot — see LOCAL_DEV_API.md).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [ -z "$IP" ]; then
  IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [ -z "$IP" ]; then
  echo "Could not detect LAN IP (en0/en1)." >&2
  exit 1
fi

if [[ "$IP" == 172.20.* ]] || [[ "$IP" == 172.16.* ]]; then
  echo "⚠️  Your Mac IP is $IP — that often means iPhone Personal Hotspot." >&2
  echo "    The phone usually cannot reach the Mac on that network." >&2
  echo "    Use same Wi‑Fi for both, or a tunnel: Mobile/LOCAL_DEV_API.md#iphone-hotspot" >&2
  echo "" >&2
fi

"$SCRIPT_DIR/set-ios-api-base-url.sh" "http://${IP}:8787"
echo "Start the API: cd backend && npm run dev:lan"
