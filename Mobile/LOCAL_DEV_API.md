# Local API on your Mac (iOS + Android)

Use this while **`api.rollspot.app` is not live** or you are developing against `wrangler dev`.

## iPhone hotspot

If the **Mac** uses the **iPhone’s Personal Hotspot** (Mac gets an IP like `172.20.10.x`), the **iPhone usually cannot call back to the Mac** on that network. The app will show “Could not connect to the server” even though the Mac has internet.

Pick one:

| Setup | Works for local API? |
|--------|----------------------|
| Mac + iPhone on **same home/office Wi‑Fi** | Yes — use [LAN steps](#ios-xcode-including-ffa-physical-iphone) below |
| Mac on iPhone hotspot, phone on **5G** | **No** (use tunnel below) |
| **Mac Internet Sharing** → iPhone joins the Mac’s Wi‑Fi/USB network | Often yes — then run `write-ios-local-api-url.sh` again |

### Tunnel (hotspot or 5G — phone reaches Mac via the internet)

1. Terminal A — API on the Mac:

   ```bash
   cd backend && npm run dev
   ```

2. Terminal B — public HTTPS URL (install once: `brew install cloudflared`):

   ```bash
   cd backend && npm run dev:tunnel
   ```

   Copy the `https://….trycloudflare.com` URL from the output.

3. Point the iOS app at that URL (gitignored):

   ```bash
   cd Mobile
   ./scripts/set-ios-api-base-url.sh https://YOUR-URL.trycloudflare.com
   ```

4. Xcode: **⇧⌘K** Clean, **Run** on the iPhone. Console should show that HTTPS URL.

The tunnel URL changes each time you restart `dev:tunnel`. Re-run step 3 when it changes.

---

## iOS (Xcode, including a physical iPhone)

Use this when Mac and iPhone are on the **same Wi‑Fi** (not hotspot-only).

**Sanity check:** On the iPhone, Safari → `http://YOUR_MAC_IP:8787` — you should get *some* response (even 404), not “server not found.”

1. **Write your Mac’s LAN URL** (gitignored — safe to keep on disk, not committed):

   ```bash
   cd Mobile
   ./scripts/write-ios-local-api-url.sh
   ```

   Or copy `Rollspot/Config/LocalAPIBaseURL.txt.example` → `Rollspot/Config/LocalAPIBaseURL.txt` and set  
   `http://YOUR_MAC_WIFI_IP:8787` (not `localhost` on a real device).

2. **Start the worker on the network** (phone must reach your Mac):

   ```bash
   cd backend
   npm run dev:lan
   ```

3. **Clean build folder** (⇧⌘K), then **Run** Debug from `Rollspot.xcodeproj`.  
   Debug reads `ROLLSPOT_API_BASE_URL` from `LocalAPI.xcconfig` (via `Debug.xcconfig`) into the app Info.plist.

4. Same Wi‑Fi as the Mac; allow port **8787** through the firewall if needed.

## Android emulator

Add to `Mobile/local.properties` (already gitignored):

```properties
rollspot.apiBaseUrl=http://10.0.2.2:8787
```

---

## Before you push / open a PR

**TODO — revert local-only setup:**

- [ ] **Do not commit** `Rollspot/Config/LocalAPI.xcconfig` or `LocalAPIBaseURL.txt` (gitignored; verify with `git status`).
- [ ] Remove any **Xcode scheme** env var `ROLLSPOT_API_BASE_URL` you added for local testing.
- [ ] Do **not** change `Info.plist` `ROLLSPOT_API_BASE_URL` away from production for the branch.
- [ ] `git status` should show **no** local API files or personal IP URLs.

Production builds use `https://api.rollspot.app` from Info.plist when the local file is absent.
