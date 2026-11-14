#!/usr/bin/env python3
"""snotra_config — the ONE reader of the operator's Snotra settings.

WHY (plan 288 §1, RULES/42): what Snotra does is the repository's; WHICH board, WHICH realm, WHICH
homepage and WHICH meeting hosts are the operator's. Those values used to be written into the code,
which put one house's clients and machines in a public tree. The line is: the shape ships, the values
live in his home.

    the shape   `.agents/config/snotra/snotra.conf.example`   (public, invented values)
    the values  `$YMIR_HOME/config/snotra/snotra.conf`        (private, the operator's own)
    the reader  this file — every Python door asks here, never a second parser

An absent file is a CLEAN FALLBACK, not an error (Rule 25/Rule 42 `defaulted`): `get()` returns the
generic default the caller names, and `source()` says which file answered, so a default never stands in
silently for a home that never received the file.
"""
from __future__ import annotations

import os
import shlex
from pathlib import Path

NAME = "snotra.conf"


def home() -> Path | None:
    """The hoard root, or None when nothing resolves it (a clone with no home is a legal state)."""
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    try:
        import subprocess
        root = next(_p for _p in Path(__file__).resolve().parents if (_p / "RULES").is_dir())
        out = subprocess.check_output(
            ["bash", "-c",
             f'. "{root}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"'],
            timeout=20).decode().strip()
        return Path(out) if out else None
    except Exception:  # noqa: BLE001
        return None


def conf_path() -> Path | None:
    """`SNOTRA_CONF` wins (a test needs a home of its own); else the home's own shelf."""
    env = os.environ.get("SNOTRA_CONF")
    if env:
        return Path(env).expanduser()
    h = home()
    return (h / "config" / "snotra" / NAME) if h else None


def read() -> dict[str, str]:
    """KEY="value" lines, as a shell would source them — one reader, no second spelling."""
    path = conf_path()
    out: dict[str, str] = {}
    if not path or not path.is_file():
        return out
    try:
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip().removeprefix("export ").strip()
            try:
                parts = shlex.split(value, comments=True)
            except ValueError:
                parts = [value]
            out[key] = " ".join(parts).strip()
    except OSError:
        return {}
    return out


def get(key: str, default: str = "") -> str:
    """The operator's value if his file carries one, else `default`."""
    value = read().get(key, "")
    return value or default


def csv(key: str, default: list[str] | None = None) -> list[str]:
    """A comma-separated setting as a list; an absent or empty setting gives the caller's default."""
    value = read().get(key, "")
    if not value:
        return list(default or [])
    return [item.strip() for item in value.split(",") if item.strip()]


def source() -> str:
    """Which file answered — a reader that cannot say this is guessing (RULES/37)."""
    path = conf_path()
    if path and path.is_file():
        return str(path)
    return "the generic default (no home config)"


if __name__ == "__main__":
    import json
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--source":
        print(source())
        raise SystemExit(0)
    print(json.dumps({"source": source(), "values": read()}, ensure_ascii=False, indent=2))
