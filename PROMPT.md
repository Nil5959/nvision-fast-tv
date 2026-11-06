# fast-tv-nil: the prompt

Paste this into Claude Code on a Mac on the same Wi-Fi as the TV, or just say "fast tv nil" / "פסט טיווי ניל"
if the `fast-tv-nil` skill is installed. Works on Android TV / Google TV boxes and sets, tested on the Partner TV+
box (Technicolor S70PCI, Android 9). Not for Samsung Tizen, LG webOS, Roku or Fire TV.

Based on the safety rules of [cleanyourtv](https://github.com/Gathin23/cleanyourtv)'s `PROMPT.md` (MIT).
The launcher, `tools/tv.py`, `tools/theme.sh`, `tools/adb-closed.py` and `build-and-install.sh` come from there.
AirPlay: [Nil5959/android-airplay-server](https://github.com/Nil5959/android-airplay-server), a GPL-3.0 fork of
[jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server).

---

Clean up my Android TV box at `<IP>` the way the balcony box was done. Room name for AirPlay: `<ROOM>`.
Work on the real device, verify every step with a screenshot pulled from the TV, and do everything yourself:
ask me only for what needs the remote and for real choices. Use `fasttv.sh` from the kit
(https://github.com/Nil5959/fast-tv-nil) for each step, and show progress on its progress page.

**Before you start, on the TV (only I can do this):** Settings → Device Preferences → About → press OK on
"Build" 7 times → back → Developer options → USB debugging on (and Network debugging if shown).
When "Allow USB debugging?" appears, tick "Always allow" and press Allow.

## 1. Connect
- Find the TV: `dns-sd -B _googlecast._tcp` / `_androidtvremote2._tcp`, `dns-sd -G v4 <host>.local`, ARP.
- Connect over ADB on port 5555 with cleanyourtv `tools/tv.py` (`TV_HOST=<ip>`). On macOS the stock `adb`
  gets "No route to host" on the LAN (Local Network privacy): don't debug it, use `tv.py`.
- If it isn't Android (no ADB, Tizen, webOS, Roku OS, Fire OS), stop and tell me.
- Check `ro.build.version.sdk` (launcher needs 26+) and `ro.product.cpu.abi` (AirPlay APK has armeabi-v7a and arm64-v8a).

## 2. Back up first
- Save `pm list packages -f / -d / -e / -3`, `getprop`, `settings list global|secure|system` and the current
  Home activity to `work/backups/<ip>/`, before changing anything.
- Write `restore.sh` there: re-enables everything you disable, sets animations back to 1, restores the old Home,
  and lists the uninstalled apps (they come back from the Play Store).

## 3. Animations
`window_animation_scale 0`, `transition_animation_scale 0`, `animator_duration_scale 0.5` (global settings).

## 4. Disable (never uninstall system packages)
- `pm disable-user --user 0`, one `pm` command per shell call, then check with `pm list packages -d`:
  - `com.google.android.tvrecommendations` (Google TV recommendations)
  - `com.google.android.leanbacklauncher.recommendations`
  - `com.google.android.katniss` (voice) **only if nobody uses voice search** - ask
  - the stock launcher (`com.google.android.tvlauncher`), **only after** the new launcher is confirmed as Home
- Never disable: the TV/input services, remote control and Bluetooth pairing, the keyboard, Play Store, Play Services,
  `com.android.systemui`, `com.android.shell`, `com.android.settings`, `com.android.tv.settings`, `android`,
  `com.android.providers.*`, the permission controller, the package installer, ext services/shared, module metadata,
  or anything the Partner TV+ app (`il.co.partnertv.atv`) depends on. If unsure what a package is, `dumpsys package` it, don't launch it.
- Don't launch packages whose name says factory / fac / AT / production.
- If `pm disable-user` is refused for everything, stop and tell me.

## 5. Uninstall unused user apps
- List `pm list packages -3`, show me the list minus the dock apps, launcher and AirPlay.
- Uninstall only the ones nobody uses (`pm uninstall --user 0 <pkg>`) and note them in `uninstalled.txt`.

## 6. Home screen
- Install the cleanyourtv launcher (`com.gathin.tvhome`) with `launcher/build-and-install.sh` (`SKIP_BUILD=1` if the
  APK is built). It sets it as Home and disables the stock launcher only after Home is confirmed.
  `cmd package set-home-activity` alone did not move Home on the Partner box.
- Confirm with `dumpsys activity activities | grep mFocusedApp` before saying it worked.
- Push the tvOS theme (`theme-tvos/`, `tools/theme.sh`) with this TV's `dock_apps`. Balcony:
  Partner TV+ `il.co.partnertv.atv`, Netflix `com.netflix.ninja`, YouTube `com.google.android.youtube.tv`,
  Spotify `com.spotify.tv.android`, Play Store `com.android.vending`; `single_row`, 5 `columns`,
  inputs and network pills hidden.

## 7. AirPlay
- Install `airplay-receiver.apk` from https://github.com/Nil5959/android-airplay-server/releases/latest
  (push it, then `pm install -r`; `adb install` can hang).
- Open it once (`am start -n io.github.jqssun.airplay/.MainActivity`) so it starts at boot.
- Set the room name:
  `am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key server_name --es value "<ROOM>"`
- When the iPhone disconnects, the receiver closes and the TV goes back to the previous app.

## 8. HDMI-CEC
`settings list global | grep hdmi_control`: `hdmi_control_enabled` must not be 0. On the balcony the Samsung remote
controls the box and the Partner remote turns the Samsung on.

## 9. Reboot and verify
- `sync`, wait about 15 seconds (Android writes package state ~10 s after a change), then reboot.
- After boot: Home is the new launcher, the AirPlay service answers on port 7000 (about 2 minutes on a slow box),
  and every package you disabled is still in `pm list packages -d`. Screenshot.
- Netflix / Live TV / HDMI give empty screenshots; use `dumpsys activity activities | grep -i ResumedActivity`.

## 10. Close ADB
- `settings put global adb_enabled 0`, then `tools/adb-closed.py <ip>` must say the port refuses the connection.
  Only that tool's answer counts.
- Tell me to turn USB debugging back on (Developer options) next time something needs changing.

## 11. Report
Short summary for this TV: model, what was disabled and uninstalled, dock apps, AirPlay name, where the backup
and `restore.sh` are.
