#!/usr/bin/env python3
"""todo_door — the one way the house writes the to-do (plan 261, and the voice's wake 107 on 2026-11-19).

Every house writer of `hodd/life/personal/me/todo.md` and of the voice's record `hodd/state/voice/todos.jsonl`
goes through here: `comms.sh todo add`, `comms.sh todo-apply`, the voice's tick and update, and the dispatch inbox.

What it guarantees:

* **One writer at a time.** `locked(path)` holds a thread lock for this process and an `flock` in the runtime
  directory for every other, over the whole read-modify-write. Four items spoken in one breath once ran as four
  threads and lost three (docs/fixes/voice/2026-11-19-four-todos-in-one-breath-lost-three.md).
* **A write that proves itself.** `atomic_write` writes a unique temp in the same directory, fsyncs it, gives it the
  target's mode, `os.replace`s it in, and reads the file back. A missing parent is created with its parent's owner.
  No temp outlives a failure.
* **His half is his.** The file says so in its first lines: "his half is written by him and never by a machine".
  `write_todo` refuses any write that changes a single byte of his half. That rule is enforced here, not remembered.
* **A failure names itself.** Every failure is a `DoorError` naming the path and the errno, so a caller can say it.
"""
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import tempfile
import threading
from pathlib import Path
from threading import local as _thread_local

HIS_MARK = "# His half"
_THREAD_LOCK = threading.RLock()
_HELD = _thread_local()   # the paths this thread already holds, so a nested `locked` does not wait on itself


class DoorError(Exception):
    """A write that did not land. The message names the path and the errno."""


class HisHalfError(DoorError):
    """A house write tried to change his half of the to-do."""


def _os_error(exc: OSError, path) -> DoorError:
    where = exc.filename or path
    if getattr(exc, "filename2", None):
        where = f"{exc.filename} -> {exc.filename2}"
    return DoorError(f"could not write {where} (Errno {exc.errno}, {exc.strerror})")


class locked:
    """Hold one file for a whole read-modify-write, against threads and other processes."""

    def __init__(self, path: Path):
        self.path = Path(path)
        self._fh = None
        self._nested = False

    def __enter__(self):
        _THREAD_LOCK.acquire()
        held = _HELD.__dict__.setdefault("paths", set())
        key = str(self.path.resolve())
        if key in held:   # this thread already holds it: a second flock in the same process would wait on itself
            self._nested = True
            return self
        try:
            run = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
            digest = hashlib.sha1(key.encode()).hexdigest()[:12]
            # the lock lives in the runtime dir, never in the home, so it never shows in the home's git status
            self._fh = open(os.path.join(run, f"ymir-todo-{digest}.lock"), "a")
            fcntl.flock(self._fh.fileno(), fcntl.LOCK_EX)
        except OSError as exc:
            if self._fh:
                self._fh.close()
            _THREAD_LOCK.release()
            raise DoorError(f"could not lock {self.path} (Errno {exc.errno}, {exc.strerror})") from exc
        held.add(key)
        return self

    def __exit__(self, *exc):
        try:
            if not self._nested:
                _HELD.paths.discard(str(self.path.resolve()))
                if self._fh:
                    self._fh.close()   # closing drops the flock
        finally:
            _THREAD_LOCK.release()
        return False


def _ensure_parent(parent: Path) -> None:
    if parent.is_dir():
        return
    _ensure_parent(parent.parent)
    parent.mkdir()
    try:   # a new directory takes its parent's owner and mode, as the rest of the home does
        st = parent.parent.stat()
        os.chown(parent, st.st_uid, st.st_gid)
        os.chmod(parent, st.st_mode & 0o7777)
    except OSError:
        pass


def atomic_write(path: Path, text: str) -> None:
    """Same-directory temp, fsync, the target's mode, os.replace, then a readback. Call it under `locked`."""
    path = Path(path)
    tmp = None
    try:
        _ensure_parent(path.parent)
        mode = (path.stat().st_mode & 0o7777) if path.exists() else 0o644
        fd, tmp = tempfile.mkstemp(prefix="." + path.name + ".", suffix=".tmp", dir=str(path.parent))
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
        tmp = None
        if path.read_text(encoding="utf-8") != text:
            raise DoorError(f"{path} does not read back as written")
    except OSError as exc:
        raise _os_error(exc, path) from exc
    finally:
        if tmp:
            try:
                os.unlink(tmp)
            except OSError:
                pass


# ── his half ─────────────────────────────────────────────────────────────────────────────────────────────────

def his_half(text: str) -> str:
    """The bytes from `# His half` up to the next top-level heading. Empty when the file has no such half."""
    lines = text.split("\n")
    start = next((i for i, l in enumerate(lines) if l.startswith(HIS_MARK)), None)
    if start is None:
        return ""
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("# ")), len(lines))
    return "\n".join(lines[start:end]).rstrip("\n")


def write_todo(path: Path, new_text: str) -> None:
    """Write todo.md — refused if it would change his half. Call it under `locked(path)`."""
    path = Path(path)
    old = path.read_text(encoding="utf-8") if path.is_file() else ""
    if his_half(old) != his_half(new_text):
        raise HisHalfError(f"refused: the write would change his half of {path} — his half is written by him "
                           "and never by a machine; the house writes only its own half "
                           "(bin/records/comms.sh todo add · todo-apply)")
    atomic_write(path, new_text)


# ── the voice's record and its view ──────────────────────────────────────────────────────────────────────────

def read_record(ledger: Path) -> list[dict]:
    rows = []
    if Path(ledger).is_file():
        for raw in Path(ledger).read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                rows.append(json.loads(raw))
            except Exception:
                continue
    return rows


def append_record(ledger: Path, event: dict) -> None:
    """Append one event to the record (written whole and replaced, never truncated), then prove it is there.
    Call it under `locked(ledger)`."""
    ledger = Path(ledger)
    old = ledger.read_text(encoding="utf-8") if ledger.is_file() else ""
    if old and not old.endswith("\n"):
        old += "\n"
    atomic_write(ledger, old + json.dumps(event, ensure_ascii=False) + "\n")
    if not any(r.get("id") == event.get("id") and r.get("action") == event.get("action")
               and r.get("ts") == event.get("ts") for r in read_record(ledger)):
        raise DoorError(f"the event {event.get('id')} is missing from {ledger} after the write")


def record_state(rows: list[dict]) -> list[dict]:
    tasks, order = {}, []
    for ev in rows:
        tid = str(ev.get("id") or "")
        if not tid:
            continue
        a = ev.get("action")
        if a == "add":
            tasks[tid] = {"id": tid, "item": ev.get("item", ""), "status": "open", "due": ev.get("due") or "",
                          "priority": ev.get("priority") or "medium", "project": ev.get("project") or "",
                          "added": ev.get("ts", "")}
            if tid not in order:
                order.append(tid)
        elif tid in tasks:
            if a == "done":
                tasks[tid]["status"] = "done"
            elif a == "reopen":
                tasks[tid]["status"] = "open"
            elif a == "update":
                for k in ("due", "priority", "project", "item"):
                    if ev.get(k):
                        tasks[tid][k] = ev[k]
    return [tasks[t] for t in order]


_VIEW_ID = re.compile(r"^- \[[ xX]\] (.*?) · `(t[0-9a-z]+)`")


def view_drift(view_text: str, tasks: list[dict]) -> dict:
    """Compare a rendered view with the record: which ids each holds that the other does not."""
    shown = {}
    for line in view_text.splitlines():
        m = _VIEW_ID.match(line)
        if m:
            shown[m.group(2)] = m.group(1)
    held = {t["id"] for t in tasks}
    return {"missing_from_view": [t["id"] for t in tasks if t["id"] not in shown],
            "missing_from_record": {k: v for k, v in shown.items() if k not in held}}


def render_view(ledger: Path, view: Path, stamp: str) -> dict:
    """Re-render the view from the record and SAY what drifted. Ids the old view showed and the record no longer
    holds are kept on the page under their own heading — never quietly dropped. Call under `locked(view)`."""
    tasks = record_state(read_record(ledger))
    old = Path(view).read_text(encoding="utf-8") if Path(view).is_file() else ""
    drift = view_drift(old, tasks)
    # carry forward what an older view already admitted was missing, so the admission is never lost
    for line in old.splitlines():
        m = re.match(r"^- (.*?) · `(t[0-9a-z]+)` — shown by an older view", line)
        if m and m.group(2) not in {t["id"] for t in tasks}:
            drift["missing_from_record"].setdefault(m.group(2), m.group(1))
    opened = [t for t in tasks if t["status"] == "open"]
    done = [t for t in tasks if t["status"] == "done"]
    prio = {"high": 0, "medium": 1, "low": 2}

    def line(t):
        bits = [f"- [{'x' if t['status'] == 'done' else ' '}] {t['item']}", f"`{t['id']}`"]
        if t["due"]:
            bits.append(f"due {t['due']}")
        if t["priority"] != "medium":
            bits.append(t["priority"])
        if t["project"]:
            bits.append(t["project"])
        return " · ".join(bits)

    rows = ["# The voice's to-do record, rendered", "",
            f"_rendered {stamp} · derived from `hodd/state/voice/todos.jsonl` — a view, never the record. "
            "What he says lands in the house-kept half of `todo.md` too._", ""]
    if drift["missing_from_view"] or drift["missing_from_record"]:
        rows += ["> [!WARNING]",
                 f"> The view before this one was stale: it lacked {len(drift['missing_from_view'])} item(s) the "
                 f"record holds, and showed {len(drift['missing_from_record'])} the record does not. "
                 "The record wins; this page was re-rendered from it.", ""]
    rows += [f"## Open ({len(opened)})", ""]
    rows += [line(t) for t in sorted(opened, key=lambda t: (prio.get(t["priority"], 1), t["due"] or "9999",
                                                            t["added"]))] or ["_nothing open_"]
    rows += ["", f"## Done ({len(done)})", ""]
    rows += [line(t) for t in done[-30:]] or ["_nothing done yet_"]
    if drift["missing_from_record"]:
        rows += ["", "## Shown by an older view, absent from the record", "",
                 "These were on this page once and are not in `todos.jsonl` now. The record is append-only, so a "
                 "row that vanished is a fault to find, not a line to forget.", ""]
        rows += [f"- {txt} · `{tid}` — shown by an older view" for tid, txt in drift["missing_from_record"].items()]
    atomic_write(Path(view), "\n".join(rows) + "\n")
    return drift
