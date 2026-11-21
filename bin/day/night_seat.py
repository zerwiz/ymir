#!/usr/bin/env python3
"""night_seat.py — one seat's errands for the night report, as JSON (stdlib only).

The errand records (`state/<id>.status`, `state/eindri-reports/<id>.md`) are per seat: the home's
`state/` is not carried by git, so every seat keeps its own. The night report reads this seat by
importing `gather()`, and every other seat by sending THIS FILE over ssh to `python3 -` there. That
is why it imports nothing outside the standard library and reads no other file of the repository:
it must run on a seat whose runtime does not carry the night report yet.

    python3 night_seat.py --since <epoch> [--home <path>] [--machine <name>] [--now <epoch>]

Prints one JSON object: {"machine", "home", "errands": [...]} — never a secret, only what the
status lines already say.
"""
import argparse
import json
import os
import re
import socket
import time
from pathlib import Path

TERMINAL = ("done", "failed", "needs-decision", "blocked", "paused", "false-done")
STATE_WORDS = TERMINAL + ("working", "resolved")
PR_URL = re.compile(r"https://github\.com/[\w.-]+/[\w.-]+/pull/\d+")
STUCK_AFTER = 2 * 3600  # a `working:` errand silent this long is stuck, not running


def resolve_home(explicit=None):
    """The home, in hoard-lib's order: an explicit path, $YMIR_HOME, ~/.config/ymir/home, the default."""
    if explicit:
        return Path(explicit).expanduser()
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    pointer = Path.home() / ".config" / "ymir" / "home"
    try:
        text = pointer.read_text(encoding="utf-8").strip()
        if text:
            return Path(text).expanduser()
    except OSError:
        pass
    return Path.home() / "Documents" / "ymirhome"


def _state_line(line):
    m = re.match(r"^([a-z-]+):\s*(.*)$", line.strip())
    if m and m.group(1) in STATE_WORDS:
        return m.group(1), m.group(2).strip()
    return None, line.strip()


def _clip(text, n=180):
    text = " ".join((text or "").split())
    return text if len(text) <= n else text[: n - 1].rstrip() + "…"


def classify(status_text, mtime, now):
    """(outcome, state, reason) for one status file. outcome: done · not-done · running."""
    last_state, last_text = None, ""
    for line in status_text.splitlines():
        state, text = _state_line(line)
        if state and state != "resolved":
            last_state, last_text = state, text
    if last_state == "done":
        return "done", "done", _clip(last_text)
    if last_state == "false-done":
        return "not-done", "false-done", "claimed done, but git did not bear it out — " + _clip(last_text, 140)
    if last_state in ("failed", "needs-decision", "blocked"):
        return "not-done", last_state, _clip(last_text)
    if last_state in ("working", "paused", None):
        silent = now - mtime
        if last_state == "paused":
            return "not-done", "paused", _clip(last_text)
        if silent >= STUCK_AFTER:
            hours = int(silent // 3600)
            return "not-done", "stuck", f"silent {hours}h — last line: " + _clip(last_text, 140)
        return "running", "working", _clip(last_text)
    return "running", last_state or "unknown", _clip(last_text)


def gather(home, since, now=None, machine=None):
    now = time.time() if now is None else now
    home = Path(home)
    state = home / "state"
    reports = state / "eindri-reports"
    errands = []
    for path in sorted(state.glob("*.status")):
        try:
            mtime = path.stat().st_mtime
        except OSError:
            continue
        if mtime < since:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        eid = path.name[: -len(".status")]
        outcome, word, reason = classify(text, mtime, now)
        report = reports / f"{eid}.md"
        report_text = ""
        if report.is_file():
            try:
                report_text = report.read_text(encoding="utf-8", errors="replace")
            except OSError:
                report_text = ""
        prs = PR_URL.findall(text) + PR_URL.findall(report_text)
        where = ""
        m = re.search(r"^where:\s*(\S+)", report_text, re.M)
        if m:
            where = m.group(1)
        errands.append({
            "id": eid,
            "outcome": outcome,
            "state": word,
            "reason": reason,
            "pr": prs[-1] if prs else "",
            "where": where,
            "at": int(mtime),
            "source": f"state/{path.name}",
            "report": f"state/eindri-reports/{eid}.md" if report_text else "",
        })
    return {"machine": machine or socket.gethostname().split(".")[0], "home": str(home), "errands": errands}


def errand_state(home, eid):
    """The outcome of one named errand on this seat, any time — for ticking his list."""
    path = Path(home) / "state" / f"{eid}.status"
    if not path.is_file():
        return None
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
        mtime = path.stat().st_mtime
    except OSError:
        return None
    outcome, word, reason = classify(text, mtime, time.time())
    prs = PR_URL.findall(text)
    return {"id": eid, "outcome": outcome, "state": word, "reason": reason, "pr": prs[-1] if prs else "",
            "at": int(mtime), "source": f"state/{path.name}"}


def main():
    ap = argparse.ArgumentParser(description="one seat's errands for the night report")
    ap.add_argument("--since", type=float, required=True)
    ap.add_argument("--home")
    ap.add_argument("--machine")
    ap.add_argument("--now", type=float)
    a = ap.parse_args()
    print(json.dumps(gather(resolve_home(a.home), a.since, a.now, a.machine)))


if __name__ == "__main__":
    main()
