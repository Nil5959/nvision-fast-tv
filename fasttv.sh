#!/usr/bin/env bash
# N Vision Fast TV: set up an Android TV box the way Nil's balcony box was done, step by step, with a live progress page.
#
#   fasttv.sh <tv ip> "<airplay room name>" <step> [args]
#
# Steps, in the usual order (each one can be run again on its own):
#   setup      clone cleanyourtv into work/, make its venv, download the AirPlay APK (no TV needed)
#   connect    reach the TV over ADB and print model / Android / ABI
#   backup     save packages, getprop, settings to work/backups/<ip>/ and write restore.sh there
#   anim       animations: window 0, transition 0, animator 0.5
#   disable    pm disable-user: Google TV / leanback recommendations, and katniss when VOICE=off (default)
#   apps       list user-installed apps that are not on the keep list (candidates to uninstall)
#   uninstall  <pkg...> uninstall exactly these user apps (only ones `apps` listed)
#   launcher   install the cleanyourtv launcher as Home (stock launcher disabled only after Home is confirmed)
#              and push the N Vision theme with DOCK="pkg pkg ..." (default: the balcony dock)
#   airplay    install N Vision AirPlay, open it once, set the room name (and PASSWORD if set)
#   cec        print the HDMI-CEC settings
#   verify     sync, reboot, then check Home, AirPlay (port 7000) and that disabled packages stayed disabled
#   close      only if the user chose it: settings put global adb_enabled 0, confirmed with adb-closed.py
#   sleep      put the box (and over CEC the TV) to sleep
#   auto       connect backup anim disable launcher airplay cec verify   (not uninstall, not close)
#
# Env: VOICE=on keeps katniss. DOCK overrides the dock apps. PASSWORD sets an AirPlay password.
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
WORK="$KIT/work"
CYT="$WORK/cleanyourtv"
PY="$CYT/tools/venv/bin/python"
PROG="python3 -I $KIT/progress.py"
AIRPLAY_APK="$WORK/nvision-airplay.apk"
AIRPLAY_URL="https://github.com/Nil5959/nvision-airplay/releases/latest/download/nvision-airplay.apk"
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
step() { $PROG set "$1" "$2" "${3:-}" >/dev/null 2>&1 || true; }
shot() {  # shot <name> [KEY...]: screenshot into the backup folder and onto the progress page
  local f="$BK/shots/$1.png"; shift; mkdir -p "$BK/shots"
  if tv --screenshot "$f" "$@" >/dev/null 2>&1; then $PROG shot "$f" >/dev/null 2>&1 || true; echo "screenshot: $f"; fi
}
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
T="$PY -I $CYT/tools/tv.py"
while read -r p; do [ -n "\$p" ] && \$T "pm enable \$p"; done < kit-disabled.txt
for k in window_animation_scale transition_animation_scale animator_duration_scale; do \$T "settings put global \$k 1"; done
\$T "cmd package set-home-activity --user 0 \$(cat home_before.txt)"
echo "uninstalled (reinstall from Play Store if wanted):"; cat uninstalled.txt
EOF
  chmod +x "$BK/restore.sh"
  step backup ok "$(grep -c . "$BK/packages_all.txt") חבילות · restore.sh מוכן"
  echo "backup: $BK"
}

do_anim() {
  step anim run
  tv 'settings put global window_animation_scale 0'
  tv 'settings put global transition_animation_scale 0'
  tv 'settings put global animator_duration_scale 0.5'
  step anim ok "0 / 0 / 0.5"
}

do_disable() {
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
  step disable ok "$(echo $done_ | wc -w | tr -d ' ') כובו"
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
  step launcher run "מתקין מסך בית"
  local apk="$CYT/launcher/app/build/outputs/apk/release/app-release.apk"
  if [ -f "$apk" ]; then (cd "$CYT/launcher" && SKIP_BUILD=1 ./build-and-install.sh); else (cd "$CYT/launcher" && ./build-and-install.sh); fi
  local th="$WORK/theme-$IP"; rm -rf "$th"; mkdir -p "$th"
  cp "$KIT/theme-nvision/wallpaper.jpg" "$th/"
  DOCK="$DOCK" python3 -I - "$KIT/theme-nvision/config.json" "$th/config.json" <<'EOF'
import json, os, sys
c = json.load(open(sys.argv[1]))
c["dock_apps"] = os.environ["DOCK"].split()
json.dump(c, open(sys.argv[2], "w"), indent=2, ensure_ascii=False)
EOF
  (cd "$CYT" && tools/theme.sh "$th")
  sleep 3
  if tv 'dumpsys activity activities' | grep -E 'mFocusedApp|ResumedActivity' | grep -q com.gathin.tvhome; then
    step launcher ok "מסך הבית החדש פעיל"
  else
    step launcher fail "Home לא עבר ל-com.gathin.tvhome"; return 1
  fi
  shot 06-home HOME
}

do_airplay() {
  step airplay run "מתקין AirPlay"
  [ -f "$AIRPLAY_APK" ] || do_setup
  "$PY" -I "$CYT/tools/b64push.py" "$AIRPLAY_APK" /data/local/tmp/airplay.apk
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
  if [ -n "${PASSWORD:-}" ]; then tv "am broadcast -n io.github.jqssun.airplay/.SettingsReceiver -a io.github.jqssun.airplay.SET_SETTING --es key airplay_password --es value '$PASSWORD'" >/dev/null; fi
  shot 07-airplay
  tv 'input keyevent HOME' >/dev/null
  step airplay ok "שם: $ROOM"
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
  connect|backup|anim|disable|apps|launcher|airplay|cec|verify|close|sleep) "do_$STEP" ;;
  uninstall) do_uninstall "$@" ;;
  auto) for s in connect backup anim disable launcher airplay cec verify; do "do_$s"; done ;;
  *) echo "unknown step: $STEP" >&2; exit 2 ;;
esac
