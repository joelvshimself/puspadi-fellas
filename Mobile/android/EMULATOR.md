# Android emulator (Pixel_9 + Wi‑Fi)

Use this workflow **before** Gradle installs, API debugging, or “no internet” rabbit holes.

Rollspot’s standard AVD matches the window title **Android Emulator - Pixel_9:5554**.

## Canonical device

| Setting | Value |
|--------|--------|
| AVD name | `Pixel_9` (exact spelling) |
| Hardware | Pixel 9 |
| System image | **Google Play** (`google_apis_playstore`), **arm64-v8a**, API **≥ 36** |
| Wi‑Fi in guest OS | **AndroidWifi** (connected by default on Play images) |

Do not use a random AVD or a non–Play Store image for day-to-day Rollspot Android work.

## One-time: create the AVD

### Script (recommended)

```bash
Mobile/scripts/create-pixel-9-avd.sh
```

Override API level if needed: `ROLLSPOT_AVD_API=36 Mobile/scripts/create-pixel-9-avd.sh`

### Android Studio

1. **Device Manager** → **Create Virtual Device**
2. Phone → **Pixel 9** → Next
3. **Play Store** tab → pick API 36+ arm64 image → Download if needed
4. Finish with AVD name **`Pixel_9`**

### CLI (manual)

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
sdkmanager "platform-tools" "emulator" "platforms;android-36" \
  "system-images;android-36;google_apis_playstore;arm64-v8a"
echo no | avdmanager create avd -n Pixel_9 -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_9
```

If `pixel_9` is unknown, use `-d pixel` instead.

## Every session (required)

1. Start the canonical emulator (waits for boot **and** network):

   ```bash
   export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
   Mobile/scripts/start-pixel-9-emulator.sh
   ```

2. Install the debug app:

   ```bash
   Mobile/scripts/install-android-debug.sh
   ```

**Or one command** (start + install + **open the app**; create AVD first time with `--create-avd`):

```bash
Mobile/scripts/run-android-debug.sh
Mobile/scripts/run-android-debug.sh --create-avd   # first machine only
```

Do **not** run `./gradlew :androidApp:installDebug` until the start script prints **Android ready** and **Emulator network OK**.

## Verify Wi‑Fi

On the emulator: **Settings → Network & internet → Internet** — Wi‑Fi **AndroidWifi** should be connected.

From your Mac (SDK `adb` is enough; PATH optional):

```bash
"$HOME/Library/Android/sdk/platform-tools/adb" shell ping -c 1 8.8.8.8
```

## If network still fails

Try in order:

1. Quit other emulators; only **Pixel_9** should be connected (`adb devices`).
2. Turn off VPN on the Mac.
3. **Device Manager → Pixel_9 → ⋮ → Cold Boot Now** (or Wipe Data once).
4. `adb kill-server && adb start-server`, then `start-pixel-9-emulator.sh` again.
5. Read `/tmp/pixel_9_emulator.log` if the emulator process exits.

The start script passes **`-dns-server 8.8.8.8,8.8.4.4`** to reduce DNS issues on virtual **AndroidWifi**.

## Wrong emulator connected

`install-android-debug.sh` expects the running emulator’s AVD name to be **`Pixel_9`**. Close other AVDs and restart with `start-pixel-9-emulator.sh`.

## Physical USB device

USB debugging bypasses this doc; scripts only enforce the **Pixel_9** name for `emulator-*` serials.
