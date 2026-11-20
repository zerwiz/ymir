#!/usr/bin/env python3
"""home_shelves.py — the home's four shelves for Python, behind the ONE resolver (plan 331.6).

    home_shelves.py life            the operator's own material   (<home>/life)
    home_shelves.py state           runtime state                (<home>/state)
    home_shelves.py config          settings                     (<home>/config)
    home_shelves.py record          the record                   (<home>/hodd)
    home_shelves.py home            the home itself
    home_shelves.py shelf <name>    the same, by name

WHY THIS FILE EXISTS. Plan 331 gave the home four shelves — `hodd/` the record, `life/` the
operator's own material, `state/` runtime state, `config/` settings — and retired three paths:
the record's old "life", "state" and "workspaces/<topic>" sub-shelves. A module that spelled one of
those kept working only through a one-cycle compatibility link, and would break the day the link was
removed. (retired-path-ok: that sentence names the retirement without teaching a path.)

A Python door cannot source `bin/vault/hoard-lib.sh`, so this module asks it — one subprocess, cached
for the process — and hands back the shelf. The rule it enforces is the same one the shell obeys:
code names a SHELF, never a retired path, and never a second copy of the layout.

    from home_shelves import shelf
    todo = shelf("life") / "personal" / "me" / "todo.md"

The shell and Python answers cannot drift: both ask hoard-lib.sh.
"""
from __future__ import annotations

import os
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELVES = ("record", "life", "state", "config")


def _ask(function: str) -> str:
    """Call one resolver function in hoard-lib.sh and return its value (empty on failure)."""
    lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
    try:
        out = subprocess.run(
            ["bash", "-c", f'. "{lib}" >/dev/null 2>&1; r=""; {function} r 2>/dev/null; printf "%s" "$r"'],
            capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        out = ""
    return out


@lru_cache(maxsize=8)
def shelf(name: str) -> Path:
    """The absolute path of a shelf by name. An unknown name is a refusal, never a guess."""
    if name not in SHELVES:
        raise SystemExit(f"home_shelves: no shelf {name!r} — the four are {' · '.join(SHELVES)}")
    fn = {"record": "hoard_root", "life": "hoard_life_dir",
          "state": "hoard_state_dir", "config": "hoard_settings_dir"}[name]
    answer = _ask(fn)
    if answer:
        return Path(answer).expanduser()
    # hoard-lib answered nothing: the home is unresolved. Fall back ONLY to a home the
    # environment names, so a caller in a test home still works; otherwise say so.
    env = os.environ.get("YMIR_HOME")
    if env:
        sub = {"record": "hodd", "life": "life", "state": "state", "config": "config"}[name]
        return Path(env).expanduser() / sub
    raise SystemExit("home_shelves: the home is unresolved — set YMIR_HOME (bin/vault/hoard-lib.sh)")


@lru_cache(maxsize=1)
def home() -> Path:
    """The home itself, through the same resolver."""
    answer = _ask("ymir_home_root")
    if answer:
        return Path(answer).expanduser()
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    raise SystemExit("home_shelves: the home is unresolved — set YMIR_HOME (bin/vault/hoard-lib.sh)")


@lru_cache(maxsize=1)
def record() -> Path:
    """The record shelf — `hodd/`."""
    return shelf("record")


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    name = argv[1] if argv[0] == "shelf" and len(argv) > 1 else argv[0]
    if name == "home":
        print(home())
        return 0
    print(shelf(name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
