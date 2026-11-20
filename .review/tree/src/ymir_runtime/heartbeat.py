"""The heartbeat — a dead worker must never look like a thinking one.

The judgement is the same one `bin/eindri-heartbeat.sh` makes, so a seat read
through the engine and a seat read through the old door give the SAME answer:

  · the record is `<state>/<id>.meta` (with `launched=<epoch>`) beside
    `<state>/<id>.status` (one `<state>: <line>` per append)
  · a terminal line is `done:` or `failed:`, or a filed report marker
  · freshness is the STATUS FILE's mtime inside the window
  · a worker that has not appended inside the window is SILENT — suspect

The engine appends the same first line the old door appends, so the baseline is
where every reader already looks for it.
"""

from __future__ import annotations

import time
from datetime import datetime, timezone
from pathlib import Path

WINDOW_SECONDS = 1800

TERMINAL_PREFIXES = ("done:", "failed:")
BLOCKED_PREFIXES = ("blocked:", "needs-decision:", "paused:")


def iso(epoch: float | None = None) -> str:
    """The fleet's timestamp shape: UTC, second precision, `Z`."""
    moment = datetime.fromtimestamp(epoch if epoch is not None else time.time(), tz=timezone.utc)
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def meta_path(state: str | Path, seat_id: str) -> Path:
    return Path(state) / f"{seat_id}.meta"


def status_path(state: str | Path, seat_id: str) -> Path:
    return Path(state) / f"{seat_id}.status"


def read_meta(state: str | Path, seat_id: str) -> dict[str, str]:
    """The seat record as a mapping. Last value wins, as the shell readers do."""
    values: dict[str, str] = {}
    try:
        text = meta_path(state, seat_id).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return values
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    return values


def write_meta(state: str | Path, seat_id: str, values: dict[str, str]) -> Path:
    """Write the record atomically — a torn meta is a lying record."""
    path = meta_path(state, seat_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{int(time.time() * 1000)}")
    body = "".join(f"{key}={value}\n" for key, value in values.items())
    temp.write_text(body, encoding="utf-8")
    temp.replace(path)
    return path


def append(state: str | Path, seat_id: str, line: str) -> Path:
    """Append one `<state>: <line>` to the seat's status log."""
    path = status_path(state, seat_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(line.rstrip("\n") + "\n")
    return path


def baseline(state: str | Path, seat_id: str, moment: str | None = None) -> Path:
    """The first line the old door writes — the baseline every reader expects."""
    return append(state, seat_id, f"working: launched {moment or iso()} (heartbeat baseline)")


def last_line(state: str | Path, seat_id: str) -> str:
    try:
        lines = status_path(state, seat_id).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    return lines[-1].strip() if lines else ""


def classify(line: str) -> str:
    """The state a status line declares: done | failed | blocked | working | ''."""
    stripped = (line or "").strip()
    if not stripped:
        return ""
    head = stripped.split(":", 1)[0].lower()
    if head == "done":
        return "done"
    if head == "failed":
        return "failed"
    if head in ("blocked", "needs-decision", "paused"):
        return "blocked"
    if head == "working":
        return "working"
    return ""


def age(state: str | Path, seat_id: str, *, now: float | None = None) -> int | None:
    """Seconds since the status log last moved, or None when it is absent."""
    try:
        mtime = status_path(state, seat_id).stat().st_mtime
    except OSError:
        return None
    moment = now if now is not None else time.time()
    return max(0, int(moment - mtime))


def verdict(
    state: str | Path,
    seat_id: str,
    *,
    window: int = WINDOW_SECONDS,
    now: float | None = None,
) -> str:
    """silent | fresh | terminal | absent — the shell condition's own verdicts."""
    meta = read_meta(state, seat_id)
    launched = meta.get("launched", "")
    if not launched.isdigit():
        return "absent"

    line = last_line(state, seat_id)
    if classify(line) in ("done", "failed"):
        return "terminal"
    state_dir = Path(state)
    for marker in (f"eindri-done/{seat_id}.md", f"eindri-reports/{seat_id}.md"):
        if (state_dir / marker).is_file():
            return "terminal"

    elapsed = age(state, seat_id, now=now)
    moment = now if now is not None else time.time()
    if elapsed is None:
        elapsed = int(moment - int(launched))
    return "fresh" if elapsed <= window else "silent"
