#!/usr/bin/env python3
"""snotra_paths — where a meeting may live. One list, read by every door that scans.

WHY: the doors scanned `svartalfaheim/<realm>/meetings/` and nothing else, so a meeting about the house's own
work (`hodd/life/meetings/work/…`) was invisible to `--recent`, to the smoke and to the layout gate. A shelf
that no door scans is a folder, not a meeting.

CONFIG (Rule 07): `SNOTRA_MEETING_SHELVES` — a colon-separated list. The defaults are the shelves this home
actually keeps: every realm's meetings, the operator's own work meetings, and the shared workspace meetings.
"""
from __future__ import annotations

import os
from pathlib import Path


def home() -> Path:
    h = os.environ.get("YMIR_HOME")
    if h:
        return Path(h).expanduser()
    import subprocess
    root = next(_p for _p in Path(__file__).resolve().parents if (_p / "RULES").is_dir() and (_p / ".agents").is_dir())
    try:
        out = subprocess.check_output(
            ["bash", "-c",
             f'. "{root}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"'],
            timeout=20).decode().strip()
    except Exception:  # noqa: BLE001
        out = ""
    if not out:
        raise SystemExit("snotra_paths: the hoard is unresolved — run bin/vault/hoard-lib.sh or set YMIR_HOME")
    return Path(out)


def shelves() -> list[Path]:
    env = os.environ.get("SNOTRA_MEETING_SHELVES")
    if env:
        return [Path(p).expanduser() for p in env.split(":") if p]
    h = home()
    out: list[Path] = []
    out += sorted(h.glob("svartalfaheim/*/meetings"))
    out += sorted(h.glob("svartalfaheim/*/projects/*/meetings"))
    out += sorted(h.glob("svartalfaheim/*/workspace/*/meetings"))
    # An intake shelf (`.inbox/<name>`) is where a meeting LANDS before a lane
    # sort files it. Three of this home's real meetings arrived that way and no
    # door could see them, so a meeting the operator knows he had was reported as
    # "0 minutes" — the same fault as an unscanned shelf, one level up.
    out += sorted(p for p in h.glob("svartalfaheim/*/.inbox/*") if p.is_dir())
    out += sorted(p for p in h.glob("svartalfaheim/.inbox/*") if p.is_dir())
    out += sorted(h.glob("hodd/life/meetings/*"))
    out += sorted(h.glob("hodd/workspaces/meetings/*"))
    return [p for p in out if p.is_dir()]


def folders(since_days: int | None = None) -> list[Path]:
    """Every folder that IS a meeting — it holds a `meeting.json`, the store contract.

    Newest first, ordered by the meeting's own `started_at` (never by file mtime: the record
    is the authority on when a meeting happened). `since_days` filters on that same date, so a
    door counting a week counts a week of meetings, not a week of touches.
    """
    import datetime as _dt
    import json
    import time

    cutoff = (time.time() - since_days * 86400) if since_days else None
    found: list[tuple[float, Path]] = []
    for shelf in shelves():
        for p in shelf.rglob("meeting.json"):
            d = p.parent
            try:
                meta = json.loads(p.read_text(encoding="utf-8", errors="replace"))
            except Exception:  # noqa: BLE001 — a broken record is still a folder
                meta = {}
            stamp = (meta.get("started_at") or meta.get("start") or meta.get("created_at") or "")[:19]
            try:
                when = _dt.datetime.fromisoformat(stamp).timestamp() if stamp else p.stat().st_mtime
            except Exception:  # noqa: BLE001
                when = p.stat().st_mtime
            if cutoff and when < cutoff:
                continue
            found.append((when, d))
    seen: set[Path] = set()
    ordered: list[Path] = []
    for _when, d in sorted(found, key=lambda x: x[0], reverse=True):
        if d in seen:
            continue
        seen.add(d)
        ordered.append(d)
    return ordered


def meetings(since_days: int | None = None) -> list[Path]:
    """Every folder that holds a record.json, newest first — optionally only those changed in N days."""
    import time
    cutoff = time.time() - since_days * 86400 if since_days else None
    found: list[Path] = []
    for shelf in shelves():
        for p in shelf.rglob("record.json"):
            d = p.parent
            if cutoff and p.stat().st_mtime < cutoff:
                continue
            found.append(d)
    return sorted(set(found), key=lambda d: (d / "record.json").stat().st_mtime, reverse=True)


if __name__ == "__main__":
    import sys
    if "--shelves" in sys.argv:
        for s in shelves():
            print(s)
    elif "--folders" in sys.argv:
        days = None
        if "--since-days" in sys.argv:
            i = sys.argv.index("--since-days")
            days = int(sys.argv[i + 1]) if len(sys.argv) > i + 1 else None
        for m in folders(days):
            print(m)
    elif "--recent" in sys.argv:
        days = int(sys.argv[sys.argv.index("--recent") + 1]) if len(sys.argv) > sys.argv.index("--recent") + 1 else 2
        for m in meetings(days):
            print(m)
    else:
        print(__doc__)
