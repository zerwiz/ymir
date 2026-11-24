#!/usr/bin/env python3
"""nornir-fleet.py — the Nornir board for every machine, with an honest row for one that cannot be reached.

    nornir-fleet.py [--json]

Each machine in the fleet registry (hodd/data/fleet.json) is asked for `nornir-jobs.py --json` (this machine locally, the
rest over ssh, every call under a timeout). A machine is never mixed into the failures when the board cannot read it:

    ok / failing N     it answered
    offline (last seen T)   the registry marks it off (`"state": "dark"` or `"offline": true`), or ssh timed out
    no road            the registry names no user or no address for it, so there is nothing to dial

The registry is read, never written. A flag the operator may add to a host row: `"offline": true`.
Last-seen times are kept in state/nornir-fleet-seen.json under the home.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("YMIR_HOME") or (Path.home() / "Documents" / "ymirhome"))
FLEET = Path(os.environ.get("NORNIR_FLEET_FILE") or HOME / "hodd" / "data" / "fleet.json")
SEEN = Path(os.environ.get("NORNIR_FLEET_SEEN") or HOME / "state" / "nornir-fleet-seen.json")
HERE = Path(__file__).resolve().parent / "nornir-jobs.py"
TIMEOUT = int(os.environ.get("NORNIR_FLEET_TIMEOUT", "12"))


def classify(name: str, host: dict, me: str) -> tuple[str, str]:
    """(kind, why) where kind is local | dial | offline | noroad — decided from the registry alone."""
    if name == me:
        return "local", ""
    if host.get("offline") or host.get("state") == "dark":
        return "offline", host.get("dark_since", "")
    if not host.get("user") or not (host.get("tailnet") or host.get("lan")):
        return "noroad", "the registry names no user or no address"
    return "dial", ""


def read_seen() -> dict:
    try:
        return json.loads(SEEN.read_text())
    except (OSError, ValueError):
        return {}


def row(name: str, host: dict, me: str, seen: dict) -> dict:
    kind, why = classify(name, host, me)
    out = {"machine": name, "status": "", "failing": 0}
    if kind in ("offline", "noroad"):
        last = seen.get(name) or why or "never"
        out["status"] = f"offline (last seen {last})" if kind == "offline" else "no road"
        out["why"] = why if kind == "noroad" else ""
        return out
    cmd = ["python3", str(HERE), "--json"]
    if kind == "dial":
        addr = host.get("tailnet") or host.get("lan")
        cmd = ["ssh", "-o", "BatchMode=yes", "-o", f"ConnectTimeout={TIMEOUT}", f"{host['user']}@{addr}",
               "python3 ~/ymir-runtime/bin/time/nornir-jobs.py --json"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT + 8)
        doc = json.loads(r.stdout)
    except (subprocess.TimeoutExpired, ValueError, OSError):
        last = seen.get(name) or "never"
        out["status"] = f"offline (last seen {last})"
        return out
    seen[name] = time.strftime("%Y-%m-%d %H:%M")
    n = doc.get("counts", {}).get("failing", 0)
    out.update({"status": f"failing {n}" if n else "ok", "failing": n, "clock": doc.get("clock", "")})
    return out


def main() -> int:
    try:
        fleet = json.loads(FLEET.read_text())
    except (OSError, ValueError):
        print("nornir-fleet: no readable fleet registry", file=sys.stderr)
        return 2
    me = os.uname().nodename.split(".")[0]
    seen = read_seen()
    rows = [row(n, h, me, seen) for n, h in (fleet.get("hosts") or {}).items() if n not in ("localhost", "unknown")]
    try:
        SEEN.parent.mkdir(parents=True, exist_ok=True)
        SEEN.write_text(json.dumps(seen))
    except OSError:
        pass
    if "--json" in sys.argv:
        print(json.dumps({"machines": rows, "failing": sum(r["failing"] for r in rows)}))
    else:
        for r in rows:
            print(f"  {r['machine']:14} {r['status']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
