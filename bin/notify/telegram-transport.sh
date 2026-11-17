#!/usr/bin/env bash
# telegram-transport.sh — a stale transport is released AT ONCE, not waited out.
#
# Why (plan 001 §4 F4, measured 2026-11-17): `state.json` still named transport pid 3599906, `ps`
# said that process was gone, and the next poller waited its full timeout (~40 s) before giving up and
# attaching. A dead pid in a lock file is a lock nobody holds: it must be released in the same breath
# as its holder's death, so the session that needs the mouth can take it in the next second.
#
# The record is pi-telegram's own (`~/.pi/agent/tmp/pi-telegram/state.json`), and this door is
# READ-WRITE on exactly one key of it: `profiles.<profile>.transport`. Everything else in the document
# is copied byte for byte, and the write is atomic — a half-written state.json would be a worse fault
# than the one it fixes.
#
# A LIVE HOLDER IS NEVER TOUCHED. If the pid answers, this door refuses and names it; the only thing
# that may release a live transport is its own session.
#
# Usage:
#   telegram-transport.sh status [--profile P]     # who holds the mouth, and is that pid alive
#   telegram-transport.sh release [--profile P] [--quiet]
#   telegram-transport.sh --check                  # exit 0 when nothing stale holds the mouth
#
# Env:
#   YMIR_TELEGRAM_STATE   the state document (default: <pi home>/agent/tmp/pi-telegram/state.json)
#   YMIR_PI_HOME          pi's home (default: ~/.pi)
#   YMIR_TELEGRAM_PROFILE the profile (default: default)
#
# Exit: 0 ok · 1 stale transport still held (check) · 3 a live holder refused · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_HOME="${YMIR_PI_HOME:-$HOME/.pi}"
STATE_DOC="${YMIR_TELEGRAM_STATE:-$PI_HOME/agent/tmp/pi-telegram/state.json}"
PROFILE="${YMIR_TELEGRAM_PROFILE:-default}"
QUIET=0

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

ACTION="${1:-status}"; shift || true
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage 0 ;;
  status|release|--check|check) ;;
  *) usage 2 ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-default}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

STATE_DOC="$STATE_DOC" PROFILE="$PROFILE" ACTION="$ACTION" QUIET="$QUIET" python3 - <<'PY'
import json
import os
import sys
import time
from pathlib import Path

doc_path = Path(os.environ["STATE_DOC"]).expanduser()
profile = os.environ["PROFILE"]
action = os.environ["ACTION"]
quiet = os.environ["QUIET"] == "1"


def load():
    try:
        return json.loads(doc_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except Exception:
        return "unreadable"


def alive(pid) -> bool:
    """A pid answers only if /proc says so (or `kill -0`, where /proc is silent)."""
    if not str(pid).isdigit():
        return False
    proc = Path(f"/proc/{pid}")
    if proc.exists():
        try:
            stat = (proc / "stat").read_text(encoding="utf-8", errors="replace")
            state = stat.rsplit(")", 1)[-1].split()[0]
            return state != "Z"
        except OSError:
            return True
    try:
        os.kill(int(pid), 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except Exception:
        return False


def transport_of(doc):
    profiles = (doc or {}).get("profiles") or {}
    entry = profiles.get(profile) or {}
    return entry.get("transport") or {}


def main() -> int:
    doc = load()
    if doc is None:
        print("telegram-transport[1]{state,transport_pid,verdict}:")
        print(f'  "absent","","nothing holds the mouth — the next session claims it at once"')
        return 0
    if doc == "unreadable":
        print("telegram-transport[1]{state,transport_pid,verdict}:")
        print(f'  "unreadable","{doc_path}","the state document cannot be parsed; this door writes nothing"')
        return 1

    transport = transport_of(doc)
    pid = transport.get("pid")
    live = alive(pid) if pid else False

    if action in ("status", "--check", "check"):
        verdict = ("held by a live session" if live
                   else "STALE — the named pid is gone, so nothing holds the mouth"
                   if pid else "none — the mouth is free")
        print("telegram-transport[1]{profile,transport_pid,alive,verdict}:")
        print(f'  "{profile}","{pid or ""}","{"yes" if live else "no"}","{verdict}"')
        if action in ("--check", "check"):
            return 0 if (not pid or live) else 1
        return 0

    # release
    if not pid:
        if not quiet:
            print("telegram-transport-release[1]{profile,released,elapsed_s,note}:")
            print(f'  "{profile}","no","0.0","no transport was recorded — nothing to release"')
        return 0
    if live:
        print(f'telegram-transport: REFUSED — transport pid {pid} is alive; a live holder is never released by another session', file=sys.stderr)
        print("telegram-transport-release[1]{profile,released,elapsed_s,note}:")
        print(f'  "{profile}","no","0.0","a live holder (pid {pid}) — refused, never stolen"')
        return 3

    started = time.monotonic()
    profiles = doc.setdefault("profiles", {})
    entry = profiles.setdefault(profile, {})
    entry.pop("transport", None)
    # Atomic: a torn state document would be a worse fault than the stale pid it removes.
    temp = doc_path.with_name(f".{doc_path.name}.{os.getpid()}")
    temp.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    temp.replace(doc_path)
    elapsed = f"{time.monotonic() - started:.2f}"
    if not quiet:
        print("telegram-transport-release[1]{profile,released,elapsed_s,note}:")
        print(f'  "{profile}","yes","{elapsed}","the recorded pid {pid} was not alive — released at once, no wait"')
    return 0


sys.exit(main())
PY
