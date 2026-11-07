---
name: nvision-fast-tv
description: N Vision Fast TV - set up an Android TV / Google TV / Partner TV+ box (debloat, N Vision home screen, N Vision AirPlay, HDMI-CEC, reboot check) driven by an interactive progress page instead of the chat. Use when Nil says "פסט טיווי ניל", "פסט טיווי", "fast tv nil", "nvision fast tv", "נ ויז'ן פסט טיווי", "תעשה פסט טיווי לטלוויזיה", or asks to set up / clean another Android TV or Partner box.
---

# N Vision Fast TV

This skill's folder is the kit (https://github.com/Nil5959/nvision-fast-tv). Follow `PROMPT.md` in it exactly,
from step 0 (skip the clone: run from this folder). Read it before the first command.

For Nil specifically:
- Talk in simple Hebrew; the page runs with `progress.py init he`.
- Nil hates chat back-and-forth and repeated confirmations: everything goes through the page's cards
  (`progress.py ask` + `wait`). Never ask in the chat what a card can ask.
- Home TVs (IPs change with DHCP: identify a box by `settings get global device_name` and its AirPlay `server_name`, never by IP alone): balcony "ממיר מרפסת" (done; Ethernet, was a static .128 that clashed with the living room, now DHCP .149, MAC 10:c2:5a:48:95:be), living room device_name "סלון" / "ממיר סלון" (done; was .154, now .128, MAC 60:3d:26:db:39:af), the other box device_name "TV – סלון" (cast) at last check .164.
  Fire TV Stick 4K Max (AFTKA) device_name "Nil's 2nd Fire TV", at last check .226: AirPlay only + apps trimmed to Netflix, YouTube, Partner TV, Spotify (done); this Mac's adb key is already trusted, so no Allow prompt.
  Same apps as the balcony, voice off, Partner TV+ opens at power-on. At the end, when Nil confirms on the finish card, `clean` deletes backups/leftovers and closes ADB.
- The AirPlay release APK is signed with the N Vision key in `~/.config/nvision/` (never commit it).
  The balcony box still has a debug-signed build: `fasttv.sh airplay` uninstalls and reinstalls it when the signature differs.
- Native Gradle builds fail in a path with spaces; build in a folder without spaces.
