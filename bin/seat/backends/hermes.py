"""Hermes as a backend — the same six verbs, so a session is reached like a pane.

WHY (plan 303 §14, §13.5 9a–9f): a Hermes agent is not a pane. Two sessions of one Desktop
profile share one gateway and one inbox, so the bridge could not tell them apart (§13.2) and
neither could answer the other. A backend can, because a session IS the address.

Read from the runtime's own admissions, never from a guess: a turn that may have run before the
gateway died is `unknown`, and Hermes pauses the session deliberately rather than replay it.
That is `blocked: lost turn, run recover`, and `recover` shows the lost input BEFORE it
discards anything, because a person's turn is not a worker's to throw away.
"""
import os
import shutil
import sqlite3
import subprocess
import time

from base import Backend, BLOCKED, DEAD, READY, WORKING


def hermes_bin():
    return os.environ.get("HERMES_BIN") or shutil.which("hermes") or os.path.expanduser("~/.local/bin/hermes")


def hermes_home():
    return os.environ.get("HERMES_HOME") or os.path.join(os.path.expanduser("~"), ".hermes")


def state_db():
    return os.environ.get("AGENT_READY_HERMES_DB") or os.path.join(hermes_home(), "state.db")


def _run(argv, timeout=60):
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return 1, "", "timed out"
    return p.returncode, (p.stdout or ""), (p.stderr or "")


class Hermes(Backend):
    name = "hermes"

    def resolve(self, name):
        return name[7:] if name.startswith("hermes:") else name

    # ── the directory ───────────────────────────────────────────────────────────
    def sessions(self):
        """`hermes sessions list` parsed: the only list Hermes offers at this version."""
        rc, out, _err = _run([hermes_bin(), "sessions", "list"], timeout=60)
        if rc != 0 or not out:
            return []
        rows, started = [], False
        for line in out.splitlines():
            if not started:
                if line.startswith("Title") or line.startswith("──") or line.startswith("━"):
                    started = True
                continue
            if not line.strip() or line.startswith("─") or line.startswith("━"):
                continue
            parts = line.split()
            if not parts:
                continue
            sid = parts[-1]
            if not sid.startswith("local-") and len(sid) < 16:
                continue
            head = line[: line.rindex(sid)].rstrip()
            cols = [c.strip() for c in head.split("  ") if c.strip()]
            rows.append({"id": sid, "title": cols[0] if cols else "",
                         "workspace": cols[1] if len(cols) > 1 else "",
                         "last": cols[2] if len(cols) > 2 else ""})
        return rows

    def find(self, want):
        want = (want or "").strip()
        if not want:
            return None

        def bare(sid):
            return sid[6:] if sid.startswith("local-") else sid

        rows = self.sessions()
        for row in rows:
            if row["id"] == want or bare(row["id"]) == bare(want) or bare(row["id"]).startswith(bare(want)):
                return row
        hits = [r for r in rows if want.lower() in (r["title"] or "").lower()]
        if len(hits) == 1:
            return hits[0]
        return None

    def catalogue(self):
        """Every session with its state — this is `list`, in the house's own row shape."""
        rows = []
        for row in self.sessions():
            state, reason, detail = self.get(row["id"])
            rows.append({"name": row["title"] or "?", "harness": "hermes",
                         "target": "hermes:%s" % row["id"], "pane": "",
                         "state": state, "reason": reason,
                         "workspace": row["workspace"], "last": row["last"], "detail": detail})
        return rows

    # ── the six verbs ───────────────────────────────────────────────────────────
    def list(self):
        return self.catalogue()

    def admission(self, session_id):
        db = state_db()
        if not os.path.exists(db):
            return None, "no state.db"
        try:
            con = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
            try:
                row = con.execute(
                    "SELECT status, seq FROM session_admissions WHERE target_session_id=?"
                    " ORDER BY seq DESC LIMIT 1", (session_id,)).fetchone()
            finally:
                con.close()
        except sqlite3.Error as exc:
            return None, str(exc)
        return ((row[0] if row else "") or ""), None

    def get(self, target):
        row = self.find(self.resolve(target))
        if row is None:
            return DEAD, "no such session", ""
        status, err = self.admission(row["id"])
        detail = "session=%s status=%s" % (row["id"][:24], status or "-")
        if err:
            return BLOCKED, "hermes store unreadable (%s)" % err[:60], detail
        if status == "unknown":
            return BLOCKED, "lost turn, run recover", detail
        if status in ("queued", "started"):
            return WORKING, "", detail
        return READY, "", detail

    def read(self, target, lines=40):
        row = self.find(self.resolve(target))
        if row is None:
            return ""
        rc, out, _err = _run([hermes_bin(), "sessions", "export", row["id"]], timeout=90)
        if rc != 0:
            return ""
        tail = out.strip().splitlines()[-lines:]
        return "\n".join(tail)

    def prompt(self, target, text):
        """One headless turn in that session. A paused session is REFUSED, never replayed."""
        row = self.find(self.resolve(target))
        if row is None:
            return ""
        state, reason, _d = self.get(row["id"])
        if state == BLOCKED and "lost turn" in (reason or ""):
            return ""   # the session is paused: the door says why, and does not touch it
        rc, out, _err = _run([hermes_bin(), "chat", "--resume", row["id"], "-q", text, "-Q"],
                             timeout=int(os.environ.get("HERMES_TURN_TIMEOUT", "600")))
        if rc == 3:
            return ""   # the runtime's own "this session is paused" answer
        return "hermes chat --resume" if rc == 0 else ""

    def wait(self, target, until=("working",), timeout=60):
        deadline = time.time() + timeout
        while time.time() < deadline:
            state, _r, _d = self.get(target)
            if state in until:
                return True
            time.sleep(3)
        return False

    def explain(self, target):
        row = self.find(self.resolve(target))
        if row is None:
            return "no such session", "", ""
        status, err = self.admission(row["id"])
        if err:
            return "hermes store unreadable (%s)" % err[:60], "", ""
        if status == "unknown":
            return ("lost turn, run recover",
                    "hermes sessions discard %s   (recover shows the lost input first)" % row["id"],
                    "the runtime recorded a turn that may have run before the gateway died")
        if status in ("queued", "started"):
            return "mid-turn", "wait for the turn to finish", ""
        return "", "", ""

    # ── the door only Hermes needs ──────────────────────────────────────────────
    def lost_input(self, target):
        """What the paused session was carrying, shown BEFORE anything is discarded."""
        row = self.find(self.resolve(target))
        if row is None:
            return ""
        text = self.read(row["id"], lines=200)
        keep = []
        for line in text.splitlines():
            try:
                import json
                d = json.loads(line)
            except Exception:  # noqa: BLE001
                continue
            m = d.get("message") or {}
            if m.get("role") == "user":
                c = m.get("content")
                if isinstance(c, list):
                    c = " ".join(str(x.get("text", "")) for x in c if isinstance(x, dict))
                keep.append(str(c).strip())
        return keep[-1] if keep else ""
