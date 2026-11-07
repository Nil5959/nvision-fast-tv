<p align="center"><img src="logo-mark.svg" width="96" alt="N Vision"></p>
<h1 align="center">N VISION · Fast TV</h1>

<p align="center">Set up an Android TV / Google TV / Partner TV+ box in minutes: faster, cleaner, an N Vision home
screen with only your apps, and free AirPlay from your iPhone. Your AI assistant does the work; you follow one page.</p>

![The N Vision home screen on a Partner TV+ box](docs/home-screenshot.png)

## How to use it

On a computer on the **same Wi-Fi as the TV**, open [Claude Code](https://claude.com/claude-code) and paste:

```
Set up my Android TV with N Vision Fast TV: clone https://github.com/Nil5959/nvision-fast-tv and follow its PROMPT.md exactly.
```

בעברית:

```
תתקין לי את N Vision Fast TV על הטלוויזיה: תוריד את https://github.com/Nil5959/nvision-fast-tv ותעשה בדיוק מה שכתוב ב-PROMPT-he.md
```

Nothing to install first: the assistant downloads this kit, and the home screen and AirPlay come ready-made from the releases.

A progress page opens in your browser. It shows exactly what to press on the TV remote (turning on Developer options
and USB debugging, pressing Allow), lets you pick your apps, the room name and the app that opens at power-on, and shows
each step with a screenshot from the TV. You never have to type in the chat.

## What it does

1. Backs up the TV's state first and writes a `restore.sh` that undoes everything.
2. Speeds up animations, turns off Google TV recommendations (and voice search if you don't use it).
3. Removes apps you don't use (you tick them on the page; reinstall any time from the Play Store).
4. Installs the [cleanyourtv](https://github.com/Gathin23/cleanyourtv) home screen with the N Vision theme and your apps.
5. Installs [N Vision AirPlay](https://github.com/Nil5959/nvision-airplay): named after the room, starts with the TV,
   shows a 4-digit code over the picture when an iPhone connects (first time only, or every time from Settings), goes back to what you were watching when it disconnects, green/red status button.
   Starting AirPlay while the TV is off turns it on (HDMI-CEC); on a Samsung it turns it back off when the iPhone leaves.
6. Checks HDMI-CEC (one remote for TV and box), reboots, and verifies it all.
7. Knows what was already done on a TV (run it again any time: it only does what is missing).
8. When you confirm everything works, deletes the backups and leftovers and closes ADB.

Fire TV: a partial run (speed, clean-up and N Vision AirPlay; Fire OS keeps its own home screen). Not for Samsung Tizen, LG webOS or Roku.

## Just the AirPlay app, without a computer (Fire TV or any Android TV)

1. On the TV, turn on installing from unknown apps (Fire TV: Settings → My Fire TV → Developer options → Apps from Unknown Sources; to see Developer options, press OK 7 times on the device name under About).
2. Install the free **Downloader** app (by AFTVnews) from the TV's app store.
3. In Downloader, type this address and install:
   `github.com/Nil5959/nvision-airplay/releases/latest/download/nvision-airplay.apk`
4. Open **N Vision AirPlay** once. From then on it starts with the TV; on the iPhone: Control Center → Screen Mirroring → the TV, and type the code that pops up.
5. Optional, so AirPlay can turn the TV on: Settings → Accessibility → turn on **N Vision AirPlay** (it only presses Home; it reads nothing).

בעברית: מתקינים בטלוויזיה את Downloader, מקלידים את הכתובת למעלה, ופותחים את N Vision AirPlay פעם אחת.

## Files

| | |
| --- | --- |
| `PROMPT.md` / `PROMPT-he.md` | the instructions your assistant follows |
| `SKILL.md` | the same as a Claude Code skill: `git clone https://github.com/Nil5959/nvision-fast-tv ~/.claude/skills/nvision-fast-tv` |
| `fasttv.sh` | one command per step: `./fasttv.sh <ip> "<room>" <step>` |
| `progress.py`, `progress.html`, `asks.*.json` | the progress page and its cards |
| `find_tvs.py` | finds the TVs on your network |
| `theme-nvision/` | the N Vision home-screen theme |
| `docs/partner-tv-plus.md` | notes from a real Partner TV+ box |

Undo on a TV: `work/backups/<ip>/restore.sh`.

## Credits and licenses

- Home screen, ADB tools and the safety rules: [cleanyourtv](https://github.com/Gathin23/cleanyourtv) by Gathin, MIT.
- AirPlay: [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server), GPL-3.0, based on
  [UxPlay](https://github.com/FDH2/UxPlay); the N Vision fork is [Nil5959/nvision-airplay](https://github.com/Nil5959/nvision-airplay), GPL-3.0.
- This kit: MIT (see `LICENSE`). N Vision name and logo © N Vision.
