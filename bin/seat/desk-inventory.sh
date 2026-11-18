#!/usr/bin/env bash
# desk-inventory.sh — which panes held a LIVE agent, written down before the desk can lose them.
#
# Why (plan 001 §4 F2, measured 2026-11-17): after the OOM restart the desk reported 27 agents and
# `ps` found ZERO `pi` processes. `herdr agent list` is a CLAIM; a pane is a shell and the agent is
# the desk's child. Because nothing had written down who stood where, nobody could raise them again —
# the panes came back as bare shells and still said *idle*.
#
# So this door answers one question twice, and the same way both times:
#
#   save    snapshot every pane the desk claims, with its session file and cwd, to
#           `<state>/desk-inventory.json` — atomically, because a torn record is a lying one
#   check   for every claimed pane: does a process ACTUALLY stand there? `live` or `shell`
#   lost    the inventory rows that are no longer standing — the list a restart leaves behind
#
# LIVENESS is asked of the machine, never of the desk (the runbook's rule: `herdr agent list` is a
# claim, `ps` is the truth). An agent is LIVE when a process exists whose name is an agent harness
# (the list the engine owns — `src/ymir_runtime/state/lock.py`, never a second copy here) and whose
# working directory or command line matches the pane's agent. Anything else is a shell in an empty
# room.
#
# Usage:
#   desk-inventory.sh save [--claimed]   # write the snapshot; prints the path and the counts.
#                                        #   --claimed records what the DESK says even where no process
#                                        #   stands — the repair road for a desk that already lost its hands
#   desk-inventory.sh check              # one row per claimed pane: live or shell
#   desk-inventory.sh lost               # inventory rows that no longer stand (TSV), exit 1 when any
#   desk-inventory.sh show               # the saved snapshot, as rows
#
# Env:
#   YMIR_DESK_INVENTORY   the snapshot path (default: <state>/desk-inventory.json)
#   YMIR_STATE_DIR        the state root (default: the home's, via hoard-lib.sh)
#   HERDR_BIN             the herdr binary (default: resolved on PATH, else ~/.local/bin/herdr)
#   YMIR_DESK_AGENTS_JSON  read a saved `herdr agent list` document instead of asking herdr (tests)
#
# Exit: 0 ok · 1 nothing stands (check/lost, when the answer is "all shells") · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die()   { printf 'desk-inventory: %s\n' "$*" >&2; exit 1; }

# The two roots are the home's business (Rule 07).
if [ -z "${YMIR_STATE_DIR:-}" ]; then
  if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
    # shellcheck source=../vault/hoard-lib.sh
    . "$ROOT/bin/vault/hoard-lib.sh"
    hoard_state_dir YMIR_STATE_DIR 2>/dev/null || true
  fi
fi
[ -n "${YMIR_STATE_DIR:-}" ] || YMIR_STATE_DIR="$HOME/.local/state/ymir"
INVENTORY="${YMIR_DESK_INVENTORY:-$YMIR_STATE_DIR/desk-inventory.json}"

# herdr is resolved once: a non-interactive shell does not always carry ~/.local/bin on PATH, and a
# reader that fails because of PATH reports "no agents" — the exact false green this plan removes.
if [ -z "${HERDR_BIN:-}" ]; then
  if command -v herdr >/dev/null 2>&1; then HERDR_BIN="$(command -v herdr)"
  elif [ -x "$HOME/.local/bin/herdr" ]; then HERDR_BIN="$HOME/.local/bin/herdr"
  else HERDR_BIN=""; fi
fi

ACTION="${1:-check}"
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage 0 ;;
  save|check|lost|show) ;;
  *) usage 2 ;;
esac
shift || true

INVENTORY="$INVENTORY" HERDR_BIN="${HERDR_BIN:-}" AGENTS_JSON="${YMIR_DESK_AGENTS_JSON:-}" \
PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}" \
python3 - "$ACTION" "$@" <<'PY'
import json
import os
import sys
import time
from pathlib import Path

action = sys.argv[1]
inventory = Path(os.environ["INVENTORY"])

# THE HARNESS LIST IS THE ENGINE'S. Importing it (never copying it) keeps one answer to "what is an
# agent process": the same tuple the lock and the watch module use to recognise a speaking session.
try:
    from ymir_runtime.state.lock import HARNESS_COMMS
except Exception:  # an old tree, or no engine beside this door
    HARNESS_COMMS = ("pi", "opencode", "claude", "cursor", "codex", "grok", "kimi", "muse", "hermes")

LIVE_CLAIMS = {"working", "idle", "blocked", "done"}


def fetch_agents() -> list:
    """The desk's claim: every agent row herdr reports, as JSON."""
    raw_override = os.environ.get("AGENTS_JSON") or ""
    if raw_override:
        try:
            return json.loads(Path(raw_override).read_text(encoding="utf-8")).get("result", {}).get("agents", [])
        except Exception:
            return []
    herdr = os.environ.get("HERDR_BIN") or ""
    if not herdr:
        return []
    import subprocess
    try:
        out = subprocess.run([herdr, "agent", "list"], capture_output=True, text=True, timeout=20)
    except Exception:
        return []
    if out.returncode != 0 or not out.stdout.strip():
        return []
    try:
        return json.loads(out.stdout).get("result", {}).get("agents", [])
    except Exception:
        return []


def session_of(row: dict) -> str:
    sess = row.get("agent_session") or {}
    value = sess.get("value") or ""
    return value if sess.get("kind") == "path" else ""


def cwd_of(row: dict) -> str:
    return row.get("foreground_cwd") or row.get("cwd") or ""


def processes() -> list:
    """(pid, comm, cwd, cmdline) for every process we can read — one pass, then matched per pane."""
    found = []
    for entry in Path("/proc").iterdir() if Path("/proc").is_dir() else []:
        if not entry.name.isdigit():
            continue
        try:
            comm = (entry / "comm").read_text(encoding="utf-8", errors="replace").strip()
        except OSError:
            continue
        if comm not in HARNESS_COMMS:
            continue
        try:
            cwd = os.readlink(entry / "cwd")
        except OSError:
            cwd = ""
        try:
            cmdline = (entry / "cmdline").read_bytes().replace(b"\0", b" ").decode("utf-8", "replace").strip()
        except OSError:
            cmdline = ""
        found.append({"pid": entry.name, "comm": comm, "cwd": cwd, "cmdline": cmdline})
    return found


def stands(row: dict, procs: list) -> dict | None:
    """The process that IS this pane's agent, or None. Session file first (exact), then cwd."""
    sess = session_of(row)
    cwd = cwd_of(row)
    for proc in procs:
        if sess and sess in proc["cmdline"]:
            return proc
    if cwd:
        for proc in procs:
            if proc["cwd"] == cwd:
                return proc
    return None


def rows_with_verdict(agents: list) -> list:
    procs = processes()
    rows = []
    for row in agents:
        pane = row.get("pane_id") or ""
        if not pane:
            continue
        proc = stands(row, procs)
        rows.append({
            "pane": pane,
            "workspace": row.get("workspace_id") or "",
            "agent": row.get("agent") or row.get("name") or "",
            "claim": row.get("agent_status") or "",
            "session": session_of(row),
            "cwd": cwd_of(row),
            "live": bool(proc),
            "pid": proc["pid"] if proc else "",
            "comm": proc["comm"] if proc else "",
        })
    return rows


def load_inventory() -> dict:
    try:
        return json.loads(inventory.read_text(encoding="utf-8"))
    except Exception:
        return {"version": 1, "panes": []}


def save() -> int:
    # --claimed records what the DESK says even where no process stands. That is the repair road for a
    # desk that has ALREADY lost its hands (the 07:21 case, and the heart today): herdr still remembers
    # every pane's session path, so those panes can be named and, one at a time, raised. A plain save
    # records only what is provably standing — the record a healthy desk leaves for the one it becomes.
    claimed_mode = "--claimed" in sys.argv
    rows = rows_with_verdict(fetch_agents())
    if claimed_mode:
        kept = [r for r in rows if r["claim"] in LIVE_CLAIMS or r["live"]]
    else:
        kept = [r for r in rows if r["live"] and r["claim"] in LIVE_CLAIMS]
    document = {
        "version": 1,
        "saved_at": int(time.time()),
        "host": os.uname().nodename,
        "desk": "herdr",
        "source": "claim" if claimed_mode else "process",
        "panes": kept,
        "claimed": len(rows),
    }
    inventory.parent.mkdir(parents=True, exist_ok=True)
    temp = inventory.with_name(f".{inventory.name}.{os.getpid()}")
    temp.write_text(json.dumps(document, indent=1) + "\n", encoding="utf-8")
    temp.replace(inventory)
    print(f"desk-inventory[1]{{path,claimed,recorded,source,saved_at}}:")
    print(f'  "{inventory}","{len(rows)}","{len(kept)}","{document["source"]}","{document["saved_at"]}"')
    return 0


def check() -> int:
    rows = rows_with_verdict(fetch_agents())
    live = sum(1 for r in rows if r["live"])
    print("desk-agents[]{pane,claim,liveness,pid,agent,cwd}:")
    for row in rows:
        print('  "%s","%s","%s","%s","%s","%s"' % (
            row["pane"], row["claim"], "live" if row["live"] else "shell",
            row["pid"], row["agent"], row["cwd"]))
    print('desk-verdict[1]{claimed,live,shells}:')
    print(f'  "{len(rows)}","{live}","{len(rows) - live}"')
    return 0 if live else 1


def lost() -> int:
    saved = load_inventory()
    rows = {r["pane"]: r for r in rows_with_verdict(fetch_agents())}
    gone = []
    for row in saved.get("panes", []):
        now = rows.get(row["pane"])
        if now is None:
            gone.append({**row, "why": "the pane is gone"})
        elif not now["live"]:
            gone.append({**row, "why": "the pane holds a shell, not an agent"})
        elif row.get("session") and now.get("session") and now["session"] != row["session"]:
            gone.append({**row, "why": "a different session now stands here"})
    print("desk-lost[]{pane,session,cwd,why}:")
    for row in gone:
        if os.environ.get("YMIR_DESK_TSV") == "1":
            print("\t".join([row.get("pane", ""), row.get("session", ""), row.get("cwd", ""), row["why"]]))
            continue
        print('  "%s","%s","%s","%s"' % (row.get("pane", ""), row.get("session", ""), row.get("cwd", ""), row["why"]))
    if os.environ.get("YMIR_DESK_TSV") == "1":
        return 1 if gone else 0
    print('desk-lost-count[1]{saved,standing,lost}:')
    print(f'  "{len(saved.get("panes", []))}","{len(saved.get("panes", [])) - len(gone)}","{len(gone)}"')
    return 1 if gone else 0


def show() -> int:
    saved = load_inventory()
    print("desk-inventory-saved[]{pane,agent,session,cwd}:")
    for row in saved.get("panes", []):
        print('  "%s","%s","%s","%s"' % (row.get("pane", ""), row.get("agent", ""), row.get("session", ""), row.get("cwd", "")))
    print('desk-inventory-meta[1]{path,saved_at,panes}:')
    print(f'  "{inventory}","{saved.get("saved_at", "")}","{len(saved.get("panes", []))}"')
    return 0


sys.exit({"save": save, "check": check, "lost": lost, "show": show}[action]())
PY
