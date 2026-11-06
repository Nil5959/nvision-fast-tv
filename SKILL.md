---
name: fast-tv-nil
description: Clean up an Android TV box the way Nil's balcony box was done (debloat, Apple-TV-style home screen, self-built AirPlay receiver, close ADB) with a live progress screen. Use when Nil says "פסט טיווי ניל", "fast tv nil", "פאסט טיוי", "תעשה פסט טיווי לטלוויזיה", or asks to set up / clean another Android TV or Partner TV+ box at home.
---

# fast-tv-nil

Kit folder: this skill's folder (`~/.claude/skills/fast-tv-nil`, also https://github.com/Nil5959/fast-tv-nil).
Full recipe and safety rules: `PROMPT.md` (English) / `PROMPT-he.md` (Hebrew). Read `PROMPT.md` once before the first TV.

Talk to Nil in simple Hebrew. Nil hates manual steps and repeated confirmations: do everything yourself.
Ask only for what needs the remote (Developer options, USB debugging, "Allow") and for real choices.

## Run

1. `./fasttv.sh setup` (once per machine: clones cleanyourtv into `work/`, makes its venv, downloads the AirPlay APK).
2. Find the TV: `dns-sd -B _googlecast._tcp`, `dns-sd -B _androidtvremote2._tcp`, then `dns-sd -G v4 <host>.local`.
   On macOS the stock `adb` gets "No route to host" on the LAN: never use it, `fasttv.sh` uses cleanyourtv `tools/tv.py`.
   Not Android (Samsung Tizen, LG webOS, Roku, Fire TV): stop and say so.
3. Ask Nil in ONE question round, only what you don't know: room name for AirPlay, dock apps
   (default = balcony: Partner TV+, Netflix, YouTube, Spotify, Play Store), voice search kept or off (default off).
4. If port 5555 is closed, tell Nil exactly: Settings → Device Preferences → About → OK on "Build" 7 times →
   back → Developer options → USB debugging on (and network debugging if shown) → on the "Allow" window tick "always" and press Allow.
5. Open the progress screen: start `python3 -I progress.py serve 8765` in the background and open
   http://127.0.0.1:8765/ in the built-in browser (`preview_start` with that url).
6. `./fasttv.sh <ip> "<room>" auto` (connect, backup, anim, disable, launcher, airplay, cec, verify).
   Env: `DOCK="pkg pkg ..."` for other apps, `VOICE=on` to keep katniss.
   If a step fails, read its message on the page, fix, and re-run only that step: `./fasttv.sh <ip> "<room>" <step>`.
7. `./fasttv.sh <ip> "<room>" apps` lists user apps not in the dock. Uninstall the ones nobody uses
   (Nil's default: everything not in the dock) with `./fasttv.sh <ip> "<room>" uninstall <pkg...>`. Never system apps.
8. Look at each screenshot (`work/backups/<ip>/shots/`) yourself before moving on.
9. `./fasttv.sh <ip> "<room>" close`: ADB off, confirmed closed by `adb-closed.py`.
10. Short Hebrew summary for that TV: what was removed/disabled, room name, where the backup and `restore.sh` are.
    One TV at a time.

## Known gotchas
- Partner TV+ box = Technicolor S70PCI, Android 9, 32-bit, ~1.4 GB RAM. `cmd package set-home-activity` alone
  does not move Home there: `build-and-install.sh` disables the stock launcher after the new Home is confirmed.
- `pm disable pkg/Activity` (component) is refused for shell; `pm disable-user --user 0 pkg` works.
- One `pm` command per shell call. Wait ~15 s (`sync`) before reboot or disabled packages look re-enabled.
- AirPlay takes ~2 minutes after boot on a slow box before port 7000 answers.
- The AirPlay APK is signed with Nil's Mac debug key; a TV with another signature of it needs `pm uninstall` first.
- Gradle native builds fail in a path with spaces; keep `work/` here.
- Fake long-press OK: `sendevent` on the remote's `/dev/input/eventX`.
