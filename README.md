# fast-tv-nil

Say **"פסט טיווי ניל"** (or "fast tv nil") to Claude Code and it cleans up an Android TV box at home,
step by step, with a live progress page:

- backup + `restore.sh` before anything changes
- faster animations, Google TV recommendations off (voice search too, if unused)
- unused apps removed (after listing them)
- an Apple-TV-style home screen ([cleanyourtv](https://github.com/Gathin23/cleanyourtv) launcher + `theme-tvos/`)
- a free, self-built AirPlay receiver ([Nil5959/android-airplay-server](https://github.com/Nil5959/android-airplay-server)) named after the room
- reboot check, then network ADB closed

| File | What |
| --- | --- |
| `SKILL.md` | the Claude Code skill (install: `git clone https://github.com/Nil5959/fast-tv-nil ~/.claude/skills/fast-tv-nil`) |
| `PROMPT.md` / `PROMPT-he.md` | the full recipe, to paste into any coding assistant |
| `fasttv.sh` | one command per step: `./fasttv.sh <ip> "<room>" auto` |
| `progress.py` + `progress.html` | the progress page (`python3 progress.py serve`, then http://127.0.0.1:8765/) |
| `theme-tvos/` | the Apple-TV-style theme (wallpaper from cleanyourtv's `themes/glass`, MIT) |

Undo on a TV: `work/backups/<ip>/restore.sh` (USB debugging must be on again).

Credits: [cleanyourtv](https://github.com/Gathin23/cleanyourtv) by Gathin (MIT): launcher, tools and the safety rules
this prompt is based on. AirPlay: [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server) (GPL-3.0) and [UxPlay](https://github.com/FDH2/UxPlay).
