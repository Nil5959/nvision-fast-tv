#!/usr/bin/env python3
"""N Vision Fast TV progress screen: shows each step, tells the user what to press on the TV, and
collects their clicks and choices so the assistant never has to ask in the chat.

    progress.py serve [port]                 serve the page on http://127.0.0.1:<port>/ (default 8765)
    progress.py init [he|en]                 start a new run, every step pending (default he)
    progress.py set <step> <state> [note]    state: run | ok | fail | skip | pending
    progress.py tv <ip> [room] [model]       show which TV this run is on
    progress.py shot <png>                   show this screenshot on the page
    progress.py ask <id> [json]              put a card on the page (asks.<lang>.json[id], merged with json;
                                             {"options": {"<field>": [{"value","label","sub","checked"}]}} fills a list)
    progress.py wait <id> [seconds]          block until the user answers card <id>; print the answer as JSON
                                             (exit 3 on timeout: call it again)
    progress.py clear                        remove the card (e.g. the TV already accepted)
    progress.py answer <id>                  print a stored answer (exit 1 if none)
State: work/progress/status.json. The page POSTs answers to /answer.
"""
import functools, http.server, json, os, shutil, sys, time

KIT = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(KIT, "work", "progress")
STATUS = os.path.join(DIR, "status.json")
STEPS = {
    "he": [("wifi", "אותה רשת"), ("adb", "הפעלת ADB בטלוויזיה"), ("connect", "חיבור"), ("choices", "בחירות"),
           ("backup", "גיבוי"), ("time", "שעון מדויק"), ("anim", "אנימציות מהירות"), ("disable", "כיבוי שירותים מיותרים"),
           ("uninstall", "הסרת אפליקציות"), ("launcher", "מסך בית N Vision"), ("airplay", "N Vision AirPlay"),
           ("cec", "שלט אחד (HDMI-CEC)"), ("verify", "הפעלה מחדש ובדיקה"), ("close", "סיום")],
    "en": [("wifi", "Same network"), ("adb", "Turn on ADB on the TV"), ("connect", "Connect"), ("choices", "Choices"),
           ("backup", "Backup"), ("time", "Correct clock"), ("anim", "Faster animations"), ("disable", "Turn off extras"),
           ("uninstall", "Remove apps"), ("launcher", "N Vision home screen"), ("airplay", "N Vision AirPlay"),
           ("cec", "One remote (HDMI-CEC)"), ("verify", "Reboot and check"), ("close", "Finish")],
}


def load():
    try:
        with open(STATUS, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def save(s):
    os.makedirs(DIR, exist_ok=True)
    s["updated"] = time.time()
    tmp = STATUS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=1)
    os.replace(tmp, STATUS)


def page():
    os.makedirs(DIR, exist_ok=True)
    for f in ("progress.html", "logo-mark.svg"):
        shutil.copy(os.path.join(KIT, f), os.path.join(DIR, "index.html" if f == "progress.html" else f))


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        if self.path != "/answer":
            self.send_error(404); return
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0) or b"{}")
            s = load()
            ask = s.get("ask") if s else None
            if not ask or body.get("id") != ask.get("id"):
                self.send_error(409, "no such card"); return
            s.setdefault("answers", {})[ask["id"]] = body.get("value")
            s["ask"] = None
            save(s)
            self.send_response(204); self.end_headers()
        except Exception as e:  # a bad request must not stop the server
            self.send_error(400, str(e))


def main(a):
    if not a:
        print(__doc__.strip()); return 2
    cmd, s = a[0], load()
    if cmd == "serve":
        page()
        port = int(a[1]) if len(a) > 1 else int(os.environ.get("PORT", 8765))
        print(f"http://127.0.0.1:{port}/", flush=True)
        http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=DIR)).serve_forever()
    if cmd == "init":
        lang = a[1] if len(a) > 1 and a[1] in STEPS else "he"
        page()
        save({"lang": lang, "started": time.time(), "tv": {}, "shot": None, "ask": None, "answers": {},
              "steps": [{"id": i, "title": t, "state": "pending", "note": ""} for i, t in STEPS[lang]]})
        return 0
    if s is None:
        print("no run yet: progress.py init", file=sys.stderr); return 1
    if cmd == "set" and len(a) >= 3:
        for st in s["steps"]:
            if st["id"] == a[1]:
                st.update(state=a[2], note=" ".join(a[3:]), at=time.time())
        save(s); return 0
    if cmd == "tv" and len(a) >= 2:
        s["tv"] = {"ip": a[1], "room": a[2] if len(a) > 2 else "", "model": a[3] if len(a) > 3 else ""}
        save(s); return 0
    if cmd == "shot" and len(a) == 2:
        name = f"shot-{int(time.time() * 1000)}.png"
        shutil.copy(a[1], os.path.join(DIR, name))
        s["shot"] = name
        save(s); return 0
    if cmd == "ask" and len(a) >= 2:
        with open(os.path.join(KIT, f"asks.{s.get('lang', 'he')}.json"), encoding="utf-8") as f:
            card = dict(json.load(f).get(a[1], {}))
        if len(a) > 2:   # extra json; {"options": {"<field key>": [...]}} fills a field's options
            extra = json.loads(a[2])
            opts = extra.pop("options", {})
            card.update(extra)
            card["fields"] = [dict(f, options=opts.get(f["key"], f.get("options"))) for f in card.get("fields", [])]
        card["id"] = a[1]
        s["ask"] = card
        s.setdefault("answers", {}).pop(a[1], None)
        save(s); return 0
    if cmd == "clear":
        s["ask"] = None
        save(s); return 0
    if cmd == "answer" and len(a) == 2:
        if a[1] in s.get("answers", {}):
            print(json.dumps(s["answers"][a[1]], ensure_ascii=False)); return 0
        return 1
    if cmd == "wait" and len(a) >= 2:
        end = time.time() + (float(a[2]) if len(a) > 2 else 540)
        while time.time() < end:
            s = load() or {}
            if a[1] in s.get("answers", {}):
                print(json.dumps(s["answers"][a[1]], ensure_ascii=False)); return 0
            time.sleep(1)
        print("timeout: still waiting, call wait again", file=sys.stderr); return 3
    print(__doc__.strip(), file=sys.stderr); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
