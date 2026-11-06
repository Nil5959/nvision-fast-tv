#!/usr/bin/env python3
"""Progress page for fast-tv-nil. State lives in work/progress/status.json; the page polls it.

    progress.py init <tv ip> <room>          start a new run, every step pending
    progress.py set <step> <state> [note]    state: run | ok | fail | skip
    progress.py shot <png>                   show this screenshot on the page
    progress.py serve [port]                 serve the page on http://127.0.0.1:<port>/ (default 8765)
"""
import functools, http.server, json, os, shutil, sys, time

KIT = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(KIT, "work", "progress")
STATUS = os.path.join(DIR, "status.json")
STEPS = [
    ("connect", "חיבור לטלוויזיה"), ("backup", "גיבוי"), ("anim", "אנימציות"),
    ("disable", "כיבוי שירותים מיותרים"), ("uninstall", "הסרת אפליקציות"), ("launcher", "מסך בית חדש"),
    ("airplay", "AirPlay"), ("cec", "HDMI-CEC"), ("verify", "אתחול ובדיקה"), ("close", "סגירת ADB"),
]


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


def main(a):
    if not a:
        print(__doc__.strip()); return 2
    cmd = a[0]
    if cmd == "init" and len(a) == 3:
        save({"ip": a[1], "room": a[2], "started": time.time(), "shot": None,
              "steps": [{"id": i, "title": t, "state": "pending", "note": ""} for i, t in STEPS]})
        shutil.copy(os.path.join(KIT, "progress.html"), os.path.join(DIR, "index.html"))
        return 0
    s = load()
    if cmd == "serve":
        os.makedirs(DIR, exist_ok=True)
        shutil.copy(os.path.join(KIT, "progress.html"), os.path.join(DIR, "index.html"))
        port = int(a[1]) if len(a) > 1 else int(os.environ.get("PORT", 8765))
        h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=DIR)
        h.log_message = lambda *x: None
        print(f"http://127.0.0.1:{port}/", flush=True)
        http.server.ThreadingHTTPServer(("127.0.0.1", port), h).serve_forever()
    if s is None:
        print("no run yet: progress.py init <ip> <room>", file=sys.stderr); return 1
    if cmd == "set" and len(a) >= 3:
        for st in s["steps"]:
            if st["id"] == a[1]:
                st["state"] = a[2]
                st["note"] = " ".join(a[3:])
                st["at"] = time.time()
        save(s); return 0
    if cmd == "shot" and len(a) == 2:
        name = f"shot-{int(time.time())}.png"
        shutil.copy(a[1], os.path.join(DIR, name))
        s["shot"] = name
        save(s); return 0
    print(__doc__.strip(), file=sys.stderr); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
