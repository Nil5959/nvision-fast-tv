#!/usr/bin/env bash
# N Vision Fast TV: set up an Android TV box the way Nil's balcony box was done, step by step, with a live progress page.
#
#   fasttv.sh <tv ip> "<airplay room name>" <step> [args]
#
# Steps, in the usual order (each one can be run again on its own):
#   status     what is already done on this TV (by any earlier run, from any computer): prints JSON, marks the page
#   setup      clone cleanyourtv into work/ (for its tools), make its venv, download the home-screen and AirPlay APKs
#   connect    reach the TV over ADB and print model / Android / ABI
#   backup     save packages, getprop, settings to work/backups/<ip>/ and write restore.sh there
#   anim       animations: window 0, transition 0, animator 0.5
#   disable    pm disable-user: Google TV / leanback recommendations, and katniss when VOICE=off (default)
#   apps       list user-installed apps that are not on the keep list (candidates to uninstall)
#   uninstall  <pkg...> uninstall exactly these user apps (only ones `apps` listed)
#   launcher   install the cleanyourtv launcher as Home (stock launcher disabled only after Home is confirmed)
#              and push the N Vision theme with DOCK="pkg pkg ..." (default: the balcony dock)
#   airplay    install N Vision AirPlay, open it once, set the room name (and PASSWORD if set)
#   time       fix the TV clock: automatic time from time.google.com; checks it against this computer's clock
#   cec        print the HDMI-CEC settings
#   verify     sync, reboot, then check Home, AirPlay (port 7000) and that disabled packages stayed disabled
#   close      only if the user chose it: settings put global adb_enabled 0, confirmed with adb-closed.py
#   clean      the TV works and the user confirmed: delete the backups and leftovers (on the TV and here), then close
#   sleep      put the box (and over CEC the TV) to sleep
#   auto       connect backup time anim disable launcher airplay cec verify   (not uninstall, not close)
#
# Env: VOICE=on keeps katniss. DOCK overrides the dock apps. START_APP opens that app at power-on.
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
WORK="$KIT/work"
CYT="$WORK/cleanyourtv"
PY="$CYT/tools/venv/bin/python"
PROG="python3 -I $KIT/progress.py"
AIRPLAY_APK="$WORK/nvision-airplay.apk"
AIRPLAY_URL="https://github.com/Nil5959/nvision-airplay/releases/latest/download/nvision-airplay.apk"
AIRPLAY_VERSION="0.0.36-nv9"   # the release fasttv.sh installs; an older one on the TV counts as "update"
HOME_APK="$CYT/launcher/app/build/outputs/apk/release/app-release.apk"   # ready-made, from this kit's release
HOME_URL="https://github.com/Nil5959/nvision-fast-tv/releases/latest/download/nvision-home.apk"
DEFAULT_DOCK="il.co.partnertv.atv com.netflix.ninja com.google.android.youtube.tv com.spotify.tv.android com.android.vending"
DOCK="${DOCK:-$DEFAULT_DOCK}"
VOICE="${VOICE:-off}"
KEEP="$DOCK com.gathin.tvhome io.github.jqssun.airplay"

IP="${1:-}"; ROOM="${2:-}"; STEP="${3:-}"
if [ "$IP" = setup ]; then STEP=setup; fi
[ -n "$STEP" ] || { sed -n '2,24p' "$0"; exit 2; }
shift 3 2>/dev/null || shift $#
BK="$WORK/backups/$IP"
export TV_HOST="$IP"

tv() { "$PY" -I "$CYT/tools/tv.py" "$@"; }
ONTV=/sdcard/nvision-fast-tv   # state kept on the TV itself, so a run from another computer knows what was done
mark() { tv "mkdir -p $ONTV && echo '$1 $(date +%F)' >> $ONTV/done.txt" >/dev/null 2>&1 || true; }
step() { $PROG set "$1" "$2" "${3:-}" >/dev/null 2>&1 || true; }
shot() {  # shot <name> [KEY...]: screenshot into the backup folder and onto the progress page
  local f="$BK/shots/$1.png"; shift; mkdir -p "$BK/shots"
  if tv --screenshot "$f" "$@" >/dev/null 2>&1; then $PROG shot "$f" >/dev/null 2>&1 || true; echo "screenshot: $f"; fi
}
is_fire() { tv 'getprop ro.product.manufacturer' 2>/dev/null | tr -d '\r' | grep -qi amazon; }   # Fire TV: Fire OS keeps its own Home
has() { tv "pm list packages $1" 2>/dev/null | tr -d '\r' | grep -qx "package:$1"; }
wait_tv() {  # wait until ADB answers again, up to $1 seconds
  local end=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    if tv 'echo up' 2>/dev/null | grep -q up; then return 0; fi
    sleep 5
  done
  return 1
}
port_open() { "$PY" -I -c "import socket,sys; s=socket.socket(); s.settimeout(2); sys.exit(0 if s.connect_ex(('$IP',$1))==0 else 1)"; }

do_setup() {
  mkdir -p "$WORK"
  if [ ! -d "$CYT/.git" ]; then git clone -q https://github.com/Gathin23/cleanyourtv "$CYT"; else git -C "$CYT" pull -q --ff-only || true; fi
  if [ ! -x "$PY" ]; then python3 -m venv "$CYT/tools/venv" && "$CYT/tools/venv/bin/pip" install -q -r "$CYT/tools/requirements.txt"; fi
  curl -fsSL -o "$AIRPLAY_APK.part" "$AIRPLAY_URL" && mv "$AIRPLAY_APK.part" "$AIRPLAY_APK"
  mkdir -p "$(dirname "$HOME_APK")"
  curl -fsSL -o "$HOME_APK.part" "$HOME_URL" && mv "$HOME_APK.part" "$HOME_APK"
  echo "setup ok: $CYT, $AIRPLAY_APK"
}

do_connect() {
  step connect run "מתחבר ל-$IP"
  local out; out="$(tv --probe 2>&1)" || { step connect fail "אין חיבור. צריך USB debugging ולאשר Allow בטלוויזיה"; echo "$out"; return 1; }
  echo "$out"
  local abi; abi="$(tv 'getprop ro.product.cpu.abi' | tr -d '\r')"
  local model; model="$(tv 'getprop ro.product.model' | tr -d '\r')"
  $PROG tv "$IP" "$ROOM" "$model" >/dev/null 2>&1 || true
  step connect ok "$model · Android $(tv 'getprop ro.build.version.release' | tr -d '\r') · $abi"
}

do_backup() {
  step backup run "שומר רשימות והגדרות"
  if [ -f "$BK/packages_all.txt" ]; then step backup ok "גיבוי ראשון נשמר כבר: $BK"; return 0; fi   # never overwrite the first, clean snapshot
  if tv "ls $ONTV/backup/packages_all.txt" 2>/dev/null | grep -q packages_all; then   # an earlier run, maybe from another computer
    mkdir -p "$BK"
    for f in $(tv "ls $ONTV/backup" | tr -d '\r'); do tv --pull "$ONTV/backup/$f" "$BK/$f" >/dev/null; done
    chmod +x "$BK/restore.sh" 2>/dev/null || true
    step backup ok "הגיבוי המקורי נמצא בטלוויזיה והועתק"; return 0
  fi
  mkdir -p "$BK"
  tv 'pm list packages -f' > "$BK/packages_all.txt"
  tv 'pm list packages -d' > "$BK/packages_disabled.txt"
  tv 'pm list packages -e' > "$BK/packages_enabled.txt"
  tv 'pm list packages -3' > "$BK/packages_3rd.txt"
  tv 'getprop' > "$BK/getprop.txt"
  for ns in global secure system; do tv "settings list $ns" > "$BK/settings_$ns.txt"; done
  tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | tail -n 1 | tr -d '\r' > "$BK/home_before.txt"
  touch "$BK/kit-disabled.txt" "$BK/uninstalled.txt"
  cat > "$BK/restore.sh" <<EOF
#!/bin/sh
# Undo N Vision Fast TV on $IP: re-enable what it disabled, animations back to 1, stock Home back.
# Apps in uninstalled.txt come back from the Play Store. Needs USB debugging on again.
cd "\$(dirname "\$0")"
export TV_HOST=$IP
K="\$(cd "\$(dirname "\$0")/../../.." && pwd)"   # the kit folder, wherever it is now
T="\$K/work/cleanyourtv/tools/venv/bin/python -I \$K/work/cleanyourtv/tools/tv.py"
while read -r p; do [ -n "\$p" ] && \$T "pm enable \$p"; done < kit-disabled.txt
for k in window_animation_scale transition_animation_scale animator_duration_scale; do \$T "settings put global \$k 1"; done
\$T "cmd package set-home-activity --user 0 \$(cat home_before.txt)"
echo "uninstalled (reinstall from Play Store if wanted):"; cat uninstalled.txt
EOF
  chmod +x "$BK/restore.sh"
  tv "mkdir -p $ONTV/backup" >/dev/null
  for f in "$BK"/*.txt "$BK/restore.sh"; do tv --push "$f" "$ONTV/backup/$(basename "$f")" >/dev/null 2>&1 || true; done
  step backup ok "$(grep -c . "$BK/packages_all.txt") חבילות · restore.sh מוכן"
  echo "backup: $BK"
}

do_anim() {
  step anim run
  tv 'settings put global window_animation_scale 0'
  tv 'settings put global transition_animation_scale 0'
  tv 'settings put global animator_duration_scale 0.5'
  step anim ok "0 / 0 / 0.5"; mark anim
}

do_disable() {
  if is_fire; then step disable skip "Fire TV: אמזון לא מאפשרת לכבות את השירותים שלה"; return 0; fi
  step disable run
  local list="com.google.android.tvrecommendations com.google.android.leanbacklauncher.recommendations"
  [ "$VOICE" = off ] && list="$list com.google.android.katniss"
  local done_=""
  for p in $list; do
    has "$p" || continue
    tv "pm disable-user --user 0 $p" >/dev/null   # one pm per shell call
    grep -qx "$p" "$BK/kit-disabled.txt" 2>/dev/null || echo "$p" >> "$BK/kit-disabled.txt"
    done_="$done_ $p"
  done
  local missing=""
  for p in $done_; do tv 'pm list packages -d' | grep -qx "package:$p" || missing="$missing $p"; done
  if [ -n "$missing" ]; then step disable fail "לא כובו:$missing"; return 1; fi
  step disable ok "$(echo $done_ | wc -w | tr -d ' ') כובו"; mark disable
  shot 03-disable HOME
}

do_apps() {
  tv 'pm list packages -3' | sed 's/^package://' | tr -d '\r' | sort > "$BK/packages_3rd_now.txt"
  echo "user-installed apps not on the keep list (dock: $DOCK):"
  local n=0
  while read -r p; do
    case " $KEEP " in *" $p "*) continue ;; esac
    case "$p" in il.co.partnertv*) continue ;; esac
    echo "  $p"; n=$((n+1))
  done < "$BK/packages_3rd_now.txt"
  grep -vxF -f <(printf '%s\n' $KEEP) "$BK/packages_3rd_now.txt" | grep -v '^il\.co\.partnertv' \
    | python3 -I -c 'import json,sys; print(json.dumps([{"value":p,"label":p,"checked":True} for p in sys.stdin.read().split()]))' > "$BK/uninstall-options.json"
  echo "options for the page: $BK/uninstall-options.json"
  step uninstall run "$n"
}

do_uninstall() {
  [ $# -gt 0 ] || { echo "usage: fasttv.sh <ip> <room> uninstall <pkg...>" >&2; return 2; }
  step uninstall run "מסיר $# אפליקציות"
  local third; third="$(tv 'pm list packages -3' | tr -d '\r')"
  local ok=0
  for p in "$@"; do
    case " $KEEP " in *" $p "*) echo "skip (keep list): $p"; continue ;; esac
    echo "$third" | grep -qx "package:$p" || { echo "skip (not a user app): $p"; continue; }
    if tv "pm uninstall --user 0 $p" | grep -q Success; then echo "$p" >> "$BK/uninstalled.txt"; ok=$((ok+1)); echo "removed $p"; fi
  done
  step uninstall ok "$ok הוסרו"
}

do_launcher() {
  if is_fire; then step launcher skip "Fire TV: אמזון נועלת את מסך הבית"; return 0; fi
  step launcher run "מתקין מסך בית"
  [ -f "$HOME_APK" ] || do_setup
  (cd "$CYT/launcher" && SKIP_BUILD=1 ./build-and-install.sh)   # ready-made APK: no JDK or Android SDK needed
  local th="$WORK/theme-$IP"; rm -rf "$th"; mkdir -p "$th"
  cp "$KIT/theme-nvision/wallpaper.jpg" "$th/"
  DOCK="$DOCK" START_APP="${START_APP:-}" python3 -I - "$KIT/theme-nvision/config.json" "$th/config.json" <<'EOF'
import json, os, sys
c = json.load(open(sys.argv[1]))
c["dock_apps"] = os.environ["DOCK"].split()
app = os.environ.get("START_APP", "")
if app and app != "home":   # open this app at power-on and on wake (boot_to_live_tv + patched launcher)
    c.update(live_tv_package=app, boot_to_live_tv=True, open_on_start_choice=True, open_on_start_on_wake=True, open_on_start_network_wait=60)
json.dump(c, open(sys.argv[2], "w"), indent=2, ensure_ascii=False)
EOF
  (cd "$CYT" && tools/theme.sh "$th")
  sleep 3
  # the default Home, not what is on screen: a sleeping TV shows no resumed activity
  if tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | tail -n 1 | grep -q com.gathin.tvhome; then
    step launcher ok "מסך הבית החדש פעיל"; mark launcher
  else
    step launcher fail "Home לא עבר ל-com.gathin.tvhome"; return 1
  fi
  shot 06-home HOME
}

do_airplay() {
  step airplay run "מתקין AirPlay"
  [ -f "$AIRPLAY_APK" ] || do_setup
  "$PY" -I "$CYT/tools/b64push.py" "$AIRPLAY_APK" /data/local/tmp/airplay.apk >/dev/null
  local out; out="$(tv 'pm install -r /data/local/tmp/airplay.apk' 2>&1)"
  if echo "$out" | grep -q 'INSTALL_FAILED_UPDATE_INCOMPATIBLE'; then   # an older copy with another signature
    tv 'pm uninstall io.github.jqssun.airplay' >/dev/null; out="$(tv 'pm install -r /data/local/tmp/airplay.apk' 2>&1)"
  fi
  echo "$out" | grep -q Success || { step airplay fail "pm install: $out"; return 1; }
  tv 'rm -f /data/local/tmp/airplay.apk' >/dev/null
  tv 'am start -n io.github.jqssun.airplay/.MainActivity' >/dev/null   # once, so it leaves the stopped state and starts at boot
  sleep 6
  tv "am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key server_name --es value '$ROOM'"
  tv "am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key boot_auto_start --es value true" >/dev/null
  tv 'appops set io.github.jqssun.airplay SYSTEM_ALERT_WINDOW allow' >/dev/null   # the code pops up over what is playing
  tv "am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key airplay_password --es value ''" >/dev/null
  tv "am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key require_pin --es value true" >/dev/null
  shot 07-airplay
  tv 'input keyevent HOME' >/dev/null
  step airplay ok "שם: $ROOM"; mark airplay
}

do_time() {   # a wrong clock breaks HTTPS: Play Store, Google sign-in and some streaming apps fail
  step time run "בודק את השעון"
  tv 'settings put global auto_time 1; settings put global auto_time_zone 1; settings put global ntp_server time.google.com' >/dev/null
  tv 'settings put global auto_time 0; settings put global auto_time 1' >/dev/null   # nudges a new NTP request
  local i tvs now
  for i in 1 2 3 4 5 6; do
    tvs="$(tv 'date +%s' | tr -dc 0-9)"; now="$(date +%s)"
    if [ -n "$tvs" ] && [ $(( tvs > now ? tvs - now : now - tvs )) -lt 120 ]; then step time ok "השעון מדויק"; mark time; return 0; fi
    sleep 5
  done
  local gw; gw="$(tv 'ping -c1 -W2 $(ip route | grep -m1 default | cut -d" " -f3) >/dev/null 2>&1 && echo up || echo down' | tr -d '\r')"
  if [ "$gw" = down ]; then
    step time fail "השעון לא מסונכרן, והממיר לא מגיע לראוטר: לאתחל אותו או לנתק ולחבר את כבל הרשת"
  else
    step time fail "השעון לא מסונכרן (פורט NTP 123 חסום בראוטר?)"
  fi
  return 1
}

do_cec() {
  step cec run
  local s; s="$(tv 'settings list global' | grep -i hdmi_control || true)"
  echo "${s:-no hdmi_control_* settings (defaults apply)}"
  if echo "$s" | grep -q 'hdmi_control_enabled=0'; then step cec fail "HDMI-CEC כבוי בהגדרות"; else step cec ok "$(echo "$s" | tr '\n' ' ' | cut -c1-80)"; fi
}

do_verify() {
  step verify run "מאתחל (עד 4 דקות)"
  tv 'sync' >/dev/null; sleep 15
  tv --reboot >/dev/null 2>&1 || true
  sleep 20
  wait_tv 240 || { step verify fail "הטלוויזיה לא חזרה אחרי אתחול"; return 1; }
  local bad=""
  tv 'dumpsys activity activities' | grep -E 'mFocusedApp|ResumedActivity' | grep -q com.gathin.tvhome || bad="$bad Home"
  local dis; dis="$(tv 'pm list packages -d' | tr -d '\r')"
  while read -r p; do [ -z "$p" ] || echo "$dis" | grep -qx "package:$p" || bad="$bad $p-enabled"; done < "$BK/kit-disabled.txt"
  local end=$(( $(date +%s) + 240 )) ap=no
  while [ "$(date +%s)" -lt "$end" ]; do if port_open 7000; then ap=yes; break; fi; sleep 10; done
  [ "$ap" = yes ] || bad="$bad AirPlay"
  shot 09-after-reboot
  if [ -n "$bad" ]; then step verify fail "בעיה:$bad"; return 1; fi
  step verify ok "Home, AirPlay וחבילות כבויות - הכל תקין"
}

do_status() {   # what is already true on the TV, whoever did it; JSON on stdout, done steps marked on the page
  local o; o="$(tv 'echo anim=$(settings get global window_animation_scale);
    echo home=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n 1);
    echo theme=$(ls /sdcard/Android/data/com.gathin.tvhome/files/config.json 2>/dev/null);
    echo ap=$(dumpsys package io.github.jqssun.airplay | grep -m1 versionName | cut -d= -f2);
    echo apsig=$(dumpsys package io.github.jqssun.airplay | grep -m1 "signatures:" | tr -d " ");
    echo overlay=$(appops get io.github.jqssun.airplay SYSTEM_ALERT_WINDOW | grep -o allow);
    echo backup=$(ls '"$ONTV"'/backup/packages_all.txt 2>/dev/null);
    echo done=$(cat '"$ONTV"'/done.txt 2>/dev/null | tr "\n" ",");
    echo disabled=$(pm list packages -d | cut -d: -f2 | tr "\n" ",");
    echo third=$(pm list packages -3 | cut -d: -f2 | tr "\n" ",")' 2>/dev/null | tr -d '\r')"
  local settings room=""; settings="$(tv 'am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.LIST_SETTINGS' 2>/dev/null)"
  room="$(echo "$settings" | grep -o '"server_name":{"value":"[^"]*"' | sed 's/.*"value":"//;s/"$//')"
  local dock; dock="$(tv 'cat /sdcard/Android/data/com.gathin.tvhome/files/config.json' 2>/dev/null | python3 -I -c 'import json,sys
try: print(" ".join(json.load(sys.stdin).get("dock_apps",[])))
except Exception: print("")')"
  O="$o" ROOM_NOW="$room" DOCK_NOW="$dock" KEEP="$KEEP" APV="$AIRPLAY_VERSION" python3 -I - <<'PY'
import json, os
kv = dict(l.split("=", 1) for l in os.environ["O"].splitlines() if "=" in l)
dis = set(filter(None, kv.get("disabled", "").split(",")))
third = set(filter(None, kv.get("third", "").split(",")))
keep = set(os.environ["KEEP"].split()) | set(os.environ["DOCK_NOW"].split())
extra = sorted(p for p in third if p not in keep and not p.startswith("il.co.partnertv"))
st = {
  "backup": bool(kv.get("backup")),
  "anim": kv.get("anim") in ("0", "0.0"),
  "disable": "com.google.android.tvrecommendations" in dis or "com.google.android.leanbacklauncher.recommendations" in dis,
  "uninstall": not extra,
  "launcher": kv.get("home", "").startswith("com.gathin.tvhome") and bool(kv.get("theme")),
  "airplay": kv.get("ap") == os.environ["APV"] and kv.get("overlay") == "allow",
}
print(json.dumps({"done": st, "airplay_version": kv.get("ap", ""), "voice_off": "com.google.android.katniss" in dis,
                  "room": os.environ["ROOM_NOW"], "dock": os.environ["DOCK_NOW"].split(), "apps_left": extra,
                  "history": kv.get("done", "")}, ensure_ascii=False))
PY
}

do_clean() {   # only after the user confirmed on the finish card that everything works
  step close run "מנקה ומוחק גיבויים"
  tv "rm -rf $ONTV /data/local/tmp/*.apk" >/dev/null 2>&1 || true
  rm -rf "$BK" "$WORK/theme-$IP"
  do_close
}

do_sleep() { tv 'input keyevent KEYCODE_SLEEP' >/dev/null; echo "asleep"; }

do_close() {
  step close run
  tv 'settings put global adb_enabled 0' >/dev/null 2>&1 || true
  sleep 3
  local i
  for i in 1 2 3 4 5; do
    if "$PY" -I "$CYT/tools/adb-closed.py" "$IP"; then step close ok "פורט 5555 סגור"; return 0; fi
    sleep 4
  done
  step close fail "פורט 5555 עדיין פתוח: לכבות USB debugging בטלוויזיה"; return 1
}

case "$STEP" in
  setup) do_setup ;;
  connect|backup|anim|disable|apps|launcher|airplay|cec|time|verify|close|clean|sleep|status) "do_$STEP" ;;
  uninstall) do_uninstall "$@" ;;
  auto) for s in connect backup time anim disable launcher airplay cec verify; do "do_$s"; done ;;
  *) echo "unknown step: $STEP" >&2; exit 2 ;;
esac
