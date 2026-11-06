#!/usr/bin/env python3
"""Find Android TV / Google TV / Partner TV+ devices on the local network (macOS dns-sd) and print them as
JSON options for the progress page's "tv" card: [{"value": ip, "label": name, "sub": "model · ip · ADB"}].
Linux: install avahi-utils and use `avahi-browse -rt _googlecast._tcp` instead; or ask for the IP.
"""
import json, re, socket, subprocess, sys


def run(args, secs):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=secs).stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or b""
        return out.decode(errors="replace") if isinstance(out, bytes) else out


def adb_open(ip):
    s = socket.socket(); s.settimeout(1.5)
    try:
        return s.connect_ex((ip, 5555)) == 0
    finally:
        s.close()


def main():
    names = sorted(set(re.findall(r"_googlecast\._tcp\.\s+(\S.*)$", run(["dns-sd", "-B", "_googlecast._tcp", "local."], 5), re.M)))
    tvs = {}
    for n in names:
        out = run(["dns-sd", "-L", n.strip(), "_googlecast._tcp", "local."], 3)
        host = re.search(r"can be reached at (\S+?)\.?:\d+", out)
        md = re.search(r"\bmd=(.*?) ic=", out)
        fn = re.search(r"\bfn=(.*?) (?:ca|st)=", out)
        if not host:
            continue
        ip = re.search(r"(\d+\.\d+\.\d+\.\d+)", run(["dns-sd", "-G", "v4", host.group(1)], 3))
        if not ip:
            continue
        model = (md.group(1) if md else "").replace("\\ ", " ")
        if any(x in model for x in ("Onkyo", "Nest", "Google Home", "Chromecast Audio")):
            continue   # speakers and receivers, not TVs
        name = (fn.group(1) if fn else n).replace("\\ ", " ").replace("\\", "")
        tvs[ip.group(1)] = (name, model)
    opts = [{"value": ip, "label": name, "sub": f"{model} · {ip} · ADB {'✓' if adb_open(ip) else '✗'}"}
            for ip, (name, model) in sorted(tvs.items())]
    print(json.dumps(opts, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
