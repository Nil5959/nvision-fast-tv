# N Vision Fast TV: the prompt (for the AI assistant)

The person you are helping wants their Android TV / Google TV / Partner TV+ box set up like this:
faster, without the extras it doesn't need, an N Vision home screen with only their apps, and
N Vision AirPlay so an iPhone can mirror to it. **They should not have to talk to you in the chat:**
everything they need to do or choose happens on the progress page, and you read their clicks from it.
Answer in the language they wrote to you in (Hebrew → `he`, otherwise `en`).

Works on Android TV / Google TV 8.0+ (tested: Partner TV+ box, Technicolor S70PCI, Android 9).
Not for Samsung Tizen, LG webOS or Roku: if that's what they have, say so and stop.
**Fire TV (Fire OS)** gets a partial run: `time`, `anim`, removing unused user apps and N Vision AirPlay all work;
`disable` and `launcher` skip themselves (Fire OS keeps its own Home and refuses most `pm disable-user`). Use the card
`adb_fire` instead of `adb` (its answer counts as `adb`), and after `airplay` show the optional card `fire_privacy`
(ads/tracking switches that only exist in Amazon's menus). Fire TV's AirPlay uses the same on-screen code.

Credits: home screen and tools from [cleanyourtv](https://github.com/Gathin23/cleanyourtv) (MIT), whose own
`PROMPT.md` safety rules this follows. AirPlay: [Nil5959/nvision-airplay](https://github.com/Nil5959/nvision-airplay),
a GPL-3.0 fork of [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server) (UxPlay).

## 0. Get ready (no questions)
```
git clone https://github.com/Nil5959/nvision-fast-tv ~/nvision-fast-tv   # skip if this is already the folder
cd ~/nvision-fast-tv
./fasttv.sh setup            # clones cleanyourtv into work/, makes its venv, downloads the AirPlay APK
python3 -I progress.py init he        # or: en
python3 -I progress.py serve 8765     # in the background; leave it running
```
Open http://127.0.0.1:8765/ for them: the built-in browser pane if you have one, else `open` (macOS) /
`xdg-open` (Linux). Tell them in one sentence that everything continues on that page.
Needs only `git`, `python3` and `curl`: the home screen and AirPlay come ready-made from the GitHub releases, nothing is built.

## How the page works
- `python3 -I progress.py set <step> run|ok|fail|skip "<short note>"` before and after every step.
- `python3 -I progress.py ask <card>` shows a card (texts in `asks.he.json` / `asks.en.json`), then
  `python3 -I progress.py wait <card>` blocks until they press its button and prints their answer as JSON
  (exit 3 = still waiting after 9 minutes: just call `wait` again; never ask in the chat instead).
- Lists are filled at ask time: `progress.py ask tv '{"options":{"ip":[...]}}'`.
- `python3 -I progress.py clear` removes a card that is no longer needed (e.g. the TV accepted already).
- `fasttv.sh` already updates the page and pushes TV screenshots to it. Look at every screenshot yourself too.

## 1. Same network — card `wifi`
`set wifi run`, `ask wifi`, `wait wifi`, `set wifi ok`.

## 2. Which TV — card `tv`
`python3 -I find_tvs.py` (macOS `dns-sd`; ~30 s) gives the options. Ask `tv` with them, wait.
The answer is `{"ip": ..., "manual": ...}`: use `manual` if filled, else `ip`.
If nothing was found, ask `tv` with no options: they type the IP (TV: Settings → Network → the connection).

## 3. ADB on — cards `adb` then `allow`
- If port 5555 on the TV is closed: `set adb run`, `ask adb`, `wait adb`. Then poll the port every 5 s.
  Still closed after 2 minutes: show `adb` again.
- When the port is open: `ask allow`, and run `./fasttv.sh <ip> "" connect` in a loop until it connects
  (it waits on the TV's "Allow" prompt). Then `clear`, `set adb ok`.
- macOS: the stock `adb` binary gets "No route to host" on the LAN (Local Network privacy). Don't debug it:
  everything here uses cleanyourtv `tools/tv.py` (`TV_HOST=<ip>`).
- If it isn't Android (no ADB at all, Tizen, webOS, Roku OS): set `connect fail` with that note, tell them, stop.
  Fire OS (`ro.build.version.name` has "Fire OS", model `AFT*`): continue in the partial Fire TV mode described at the top.

## 3b. Already set up before? — `status` (always, right after connecting)
`./fasttv.sh <ip> "" status` reads the TV itself (any earlier run, from any computer, leaves its backup and a
`done.txt` in `/sdcard/nvision-fast-tv/` on the TV) and prints JSON: `done` per step, the current `room`, `dock`,
`voice_off`, `apps_left`, `airplay_version`. For every step that is already `true`: `set <step> ok "כבר נעשה"` /
"already done" and skip it. Re-run only what is `false` (e.g. AirPlay when a newer version is out).
If everything is done, tell them in one line and only offer the update steps. Be quick: no repeated questions.

## 4. Choices — card `choices`
If `status` found earlier choices, pre-tick them (`apps` = its `dock`, `room` = its `room`, voice per `voice_off`)
by passing the options with `"checked"` set and a `"value"` on the text field; if all of them are already set and
nothing else is missing, skip this card. Before asking, you may add apps that are installed on the TV to the `apps` options
(`pm list packages -3`, plus Netflix / YouTube / Play Store if present), keeping the defaults ticked.
The answer: `room` (AirPlay name; empty → the TV's own name), `apps` (dock, in order), `start_app` (the app that
opens at power-on and on wake, or `home`), `voice` (`on`/`off`). There is no AirPlay password: the iPhone gets a
4-digit code that pops up on the TV the first time it connects (like Apple TV).
Partner TV+ boxes already open Partner TV+ after a boot by themselves (`launch-after-boot` in the firmware's
`TchCustomizer`); `START_APP` adds the same on wake and on other TVs. `set choices ok "<room> · N apps"`.

## 5. The work (each line is one command; on failure read the note, fix, re-run only that step)
```
export DOCK="<apps, space separated>" VOICE=<on|off> START_APP=<package or home>
./fasttv.sh <ip> "<room>" backup      # packages, settings, getprop → work/backups/<ip>/ + restore.sh
./fasttv.sh <ip> "<room>" time        # clock: automatic time from time.google.com, checked against this computer
./fasttv.sh <ip> "<room>" anim        # window 0, transition 0, animator 0.5
./fasttv.sh <ip> "<room>" disable     # Google TV / leanback recommendations; katniss (voice) only if VOICE=off
./fasttv.sh <ip> "<room>" apps        # lists user-installed apps not on the dock → uninstall-options.json
```
Card `uninstall`: `progress.py ask uninstall "{\"options\":{\"remove\":$(cat work/backups/<ip>/uninstall-options.json)}}"`,
wait. Answer `"skip"` → `set uninstall skip`; else `./fasttv.sh <ip> "<room>" uninstall <the ticked packages>`.
```
./fasttv.sh <ip> "<room>" launcher   # cleanyourtv home + N Vision theme with DOCK; stock launcher off only after Home is confirmed
./fasttv.sh <ip> "<room>" airplay    # N Vision AirPlay (installs or updates), opened once, room name, on-screen code + overlay permission
./fasttv.sh <ip> "<room>" cec        # prints hdmi_control_*; fails if HDMI-CEC is off
```
Then card `cec` (the TV-side menus, Samsung Start Screen Options etc.): ask, wait (`skip` is fine).
```
./fasttv.sh <ip> "<room>" verify     # sync, wait 15 s, reboot; Home, AirPlay on port 7000 (up to ~2 min), disabled stay disabled
```

## 6. Finish — card `finish`
It asks whether everything works. `clean` (the default): `./fasttv.sh <ip> "<room>" clean` deletes the backups and
leftovers on the TV and on this computer, then turns ADB off; `tools/adb-closed.py` must report the port refuses.
`open`: leave everything as is, `set close ok "ADB נשאר פתוח"` / "ADB left open".
Then a short summary in the chat: model, what was disabled / removed, dock, AirPlay name, where the backup and
`restore.sh` are. More TVs: start again from step 2, one TV at a time.

## Safety rules (from cleanyourtv, keep them)
- Back up before changing anything. Disable with `pm disable-user --user 0`; never uninstall system packages.
- One `pm` command per shell call; check with `pm list packages -d`, not the exit code.
- Never disable: TV / input services, remote and Bluetooth pairing, keyboards, Play Store, Play Services,
  `com.android.systemui`, `.shell`, `.settings`, `com.android.tv.settings`, `android`, `com.android.providers.*`,
  permission controller, package installer, ext services / shared, module metadata, WebView, Cast
  (`com.google.android.apps.mediashell`) unless asked, and on Partner boxes anything `com.technicolor.*`,
  `com.marvell.*`, `com.synaptics.*`, `com.sharkfood.*`, `com.vayosoft.*`, or what `il.co.partnertv.atv` needs.
  Unsure what a package is? `dumpsys package <pkg>`; never launch it. Never open factory / fac / AT / production packages.
- Disable the stock launcher only after the new Home is confirmed (`build-and-install.sh` does this with rollback).
  `cmd package set-home-activity` alone did not move Home on the Partner box.
- Before a reboot: `sync` and wait ~15 s, or disabled packages look re-enabled.
- `adb install` can hang: push the APK and `pm install -r` (the scripts do).
- Netflix / Live TV / HDMI give black screenshots; a black screenshot can also mean the box is asleep
  (`dumpsys power | grep mWakefulness`). Check `dumpsys activity activities | grep -i ResumedActivity`.
- Shell can't disable single activities (`pm disable pkg/Activity`); hide tiles with the theme's `hidden_apps`.
- AirPlay only works when the iPhone and the TV are on the same subnet (one router, or the second router as an access point).
- A wrong clock (a box stuck on an old date) breaks HTTPS: Play Store, Google sign-in and streaming apps fail. Always run
  `time`. If it fails and the box can't even ping its router (`Destination Host Unreachable`), a reboot or re-plugging
  the network cable fixes it; seen on a Partner box whose `eth0` and bridge `ebr0` both held the same IP.
- N Vision AirPlay is in Hebrew by default, whatever the device language (Fire OS has no Hebrew). For English set
  `app_language` to `system` or `en` with the SettingsReceiver broadcast (`--es key app_language --es value system`).
- Web video from Safari plays on the TV when the site allows it; sites that block players outside the browser
  (Cloudflare checks, signed links) show a note on the TV and play on the phone instead. For web video the AirPlay
  button inside the player works best; then the phone can be locked.
- More device notes: `docs/partner-tv-plus.md`.
