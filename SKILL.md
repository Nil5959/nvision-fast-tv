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
- Home TVs: balcony `192.168.1.128` "ממיר מרפסת" (done), `192.168.1.164` "ממיר סלון", `192.168.1.154` "ממיר חדר".
  Same apps as the balcony, voice off, Partner TV+ opens at power-on. At the end, when Nil confirms on the finish card, `clean` deletes backups/leftovers and closes ADB.
- The AirPlay release APK is signed with the N Vision key in `~/.config/nvision/` (never commit it).
  The balcony box still has a debug-signed build: `fasttv.sh airplay` uninstalls and reinstalls it when the signature differs.
- Native Gradle builds fail in a path with spaces; build in a folder without spaces.
