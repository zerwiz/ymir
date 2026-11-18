#!/usr/bin/env python3
"""test_dispatch.py — the dispatcher's three laws, each proved by running the door.

The laws (bin/dispatch/dispatch.py):

  1. IDEMPOTENT BY KEY — a second pass over unchanged input is a NO-OP, and the same item never
     becomes two proposals, even when the ledger is deleted (the to-do is the second guard).
  2. THE ATTEMPT CAP — three failed attempts for one key, and the FOURTH is refused and recorded as
     terminal-failed; every run after that is a no-op naming the terminal state.
  3. AN UNREADABLE INPUT IS AN ERROR — a store that cannot be read exits 3 and writes no proposal,
     never a confident `0`.

Also proved: his half is byte-identical, only the two sanctioned paths are written, --dry-run writes
nothing at all, --check fails on a broken ledger, only asks (never notices) come out of the wake
queue, and the timer row is registered in config/units.yaml (the one writer, never a hand unit).

Usage: test_dispatch.py        Exit: 0 all pass · 1 a failure.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent            # bin/dispatch/tests → the tree
DOOR = ROOT / "bin" / "dispatch" / "dispatch.sh"
JOB = ROOT / "bin" / "time" / "nornir-job-dispatch.sh"

sys.path.insert(0, str(DOOR.parent))
import dispatch as door  # noqa: E402  — the door's own formula, never a second copy

decision_identity = lambda line: door.decision_identity(line)[0]  # noqa: E731

PASS = 0
FAIL = 0


def ok(what: str) -> None:
    global PASS
    PASS += 1
    print(f"  ok   {what}")


def bad(what: str, detail: str = "") -> None:
    global FAIL
    FAIL += 1
    print(f"  FAIL {what}")
    if detail:
        for line in str(detail).strip().splitlines()[:14]:
            print(f"       {line}")


def check(condition, what: str, detail: str = "") -> None:
    ok(what) if condition else bad(what, detail)


HIS_HALF = """# The Allfather's day — his acts, and what the house knows

# His half — what only he can do

- [ ] **Answer a correspondent** — his own line, never touched by a machine.

# The house-kept half — what his messages moved

- [x] 2026-11-12 · done: «Send the board email» (item ee0a39ad)
"""

ACCOUNTS = """accounts:
  - id: operator@example.org
    owner: the Allfather
    status: scoped
"""


def message(mid: str, subject: str, *, action="reply_needed", confidence=0.9, direction="in",
            received="2026-11-16T09:00:00+00:00", sender="a correspondent", email="correspondent@example.org") -> dict:
    return {
        "id": mid, "account": "operator@example.org", "direction": direction,
        "from": {"name": sender, "email": email}, "to": ["operator@example.org"],
        "subject": subject, "received_at": received, "body_text": f"{subject} body",
        "classification": "client", "confidence": confidence,
        "proposed_action": action, "thread_key": mid, "evidence": "fixture",
    }


class Fixture:
    def __init__(self) -> None:
        self.dir = Path(tempfile.mkdtemp(prefix="dispatch-test-"))
        self.home = self.dir / "home"
        (self.home / "hodd" / "memory" / "mail").mkdir(parents=True)
        (self.home / "hodd" / "life" / "personal" / "me").mkdir(parents=True)
        (self.home / "hodd" / "state").mkdir(parents=True)
        (self.home / "state").mkdir(parents=True)
        self.todo = self.home / "hodd" / "life" / "personal" / "me" / "todo.md"
        self.todo.write_text(HIS_HALF, encoding="utf-8")
        self.accounts = self.home / "hodd" / "memory" / "mail" / "accounts.yaml"
        self.accounts.write_text(ACCOUNTS, encoding="utf-8")
        self.spine = self.home / "hodd" / "memory" / "mail" / "messages.jsonl"
        self.wake = self.home / "state" / ".wake-queue"
        self.ledger = self.home / "hodd" / "state" / "dispatch" / "runs.jsonl"
        self.spine.write_text(json.dumps(message("m-one", "Spec v2.5 and the prototype copy")) + "\n"
                             + json.dumps(message("m-two", "The staging accounts")) + "\n",
                             encoding="utf-8")
        self.wake.write_text(
            "2026-11-16 09:00 EET — eindri whiteboard-build reported: report filed (handoff failsafe)\n"
            "2026-11-16T16:08:04Z notify engine HIGH • new PR #789 by zerwiz: a body\n"
            "2026-11-16T16:08:04Z lock-ask ask-20261116T160804Z-641b from=review-watch "
            "at=2026-11-16T16:08:04Z q=PR #789 (zerwiz/ymir) is open at head 7884597ebdf4: mergeable=CONFLICTING\n"
            "2026-11-16 16:20 EET — eindri queue-warden reported: needs-decision: rebuild PR #789 or cut it "
            "again onto a new branch\n"
            "2026-11-16 16:50 EET — eindri queue-warden reported: needs-decision: rebuild PR #789 or cut it "
            "again onto a new branch\n"
            "2026-11-10 08:00 EET — eindri old-work reported: needs-decision: ten days old, not incoming\n",
            encoding="utf-8")
        self.env = dict(os.environ)
        self.env.update({
            "YMIR_HOME": str(self.home),
            "GNA_DESK_URL": "",                      # read the store: no daemon, no network in a test
            "DISPATCH_NOW": "2026-11-16T17:00:00Z",
            "DISPATCH_STATE_DIR": str(self.home / "hodd" / "state" / "dispatch"),
            "DISPATCH_TODO": str(self.todo),
            "DISPATCH_WAKE_QUEUE": str(self.wake),
            "TZ": "UTC",
        })

    def run(self, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(DOOR), *args], capture_output=True, text=True,
                              env=env or self.env, timeout=120)

    def runs(self) -> list[dict]:
        if not self.ledger.exists():
            return []
        return [json.loads(line) for line in self.ledger.read_text(encoding="utf-8").splitlines() if line.strip()]

    def last_run(self) -> dict:
        runs = [r for r in self.runs() if r.get("kind") == "run"]
        return runs[-1] if runs else {}

    def cleanup(self) -> None:
        shutil.rmtree(self.dir, ignore_errors=True)


def key8(source: str, ident: str) -> str:
    import hashlib
    return hashlib.sha256(f"{source}|{ident}".encode()).hexdigest()[:8]


def main() -> int:
    print("test_dispatch")
    if not DOOR.exists():
        print(f"  FAIL the door is missing: {DOOR}")
        return 1

    # ══ 1 · a first run proposes, and a second pass over unchanged input is a no-op ══════════════
    fx = Fixture()
    try:
        first = fx.run("--json")
        check(first.returncode == 0, "a readable home runs clean", first.stderr or first.stdout)
        doc = json.loads(first.stdout) if first.stdout.strip().startswith("{") else {}
        check(doc.get("verdict") == "work", "the first run records work",
              first.stdout or first.stderr)
        check(doc.get("counts", {}).get("proposed") == 3,
              "two mail rows and one ask become three proposals (under DISPATCH_MAX=5)",
              first.stdout)
        text = fx.todo.read_text(encoding="utf-8")
        check(text.startswith(HIS_HALF.split("# The house-kept half")[0]),
              "his half is byte-identical after a run")
        check("<!-- dispatch:inbox" in text and "<!-- /dispatch:inbox -->" in text,
              "the proposals live between the dispatch markers")
        check(fx.todo.read_text(encoding="utf-8").count("dispatch-") >= 3,
              "each proposal carries its key")
        check(key8("mail:operator@example.org", "m-one") in text,
              "the mail key is sha256(source|id) — source `mail:<account>`, id the message id")
        check(key8("wake", decision_identity(
                  "2026-11-16 16:20 EET — eindri queue-warden reported: needs-decision: rebuild PR #789 "
                  "or cut it again onto a new branch")) in text,
              "a decision's key is its words with the clock folded, so a repeat is ONE item")
        check("eindri whiteboard-build reported" not in text,
              "a notice in the wake queue is NOT proposed")
        check("PR #789 (zerwiz/ymir) is open" not in text,
              "a lock-ask is left to the arm — it is never a line on his list")
        check(text.count("rebuild PR #789") == 1,
              "the same decision asked twice (two clocks) is one proposal")
        check(len([r for r in fx.runs() if r.get("kind") == "event"]) == 3,
              "the ledger keeps one row per event (three proposals, three rows)",
              json.dumps(fx.runs(), indent=1)[:900])

        before = fx.todo.read_text(encoding="utf-8")
        second = fx.run("--json")
        after = fx.todo.read_text(encoding="utf-8")
        doc2 = json.loads(second.stdout) if second.stdout.strip().startswith("{") else {}
        check(second.returncode == 0, "the second run exits clean")
        check(doc2.get("verdict") == "no-op", "the second pass over unchanged input is a no-op",
              second.stdout)
        check(after == before, "unchanged input writes not one byte to his to-do")
        runs = fx.runs()
        events = [r for r in runs if r.get("kind") == "event"]
        check(len(runs) - len(events) == 2, "one ledger run row per run, no phantom events",
              json.dumps(runs[-3:], indent=1))
        check(all("already-proposed" in (r.get("reason") or "") for r in doc2.get("items", [])
                  if r["verdict"] == "already-proposed"),
              "the no-op names its reason (already proposed)")
        check(after.count("dispatch-" + key8("mail:operator@example.org", "m-one")) == 1,
              "the same item never becomes two proposals")

        # the to-do alone is the guard: delete the ledger, run again, still one line
        fx.ledger.unlink()
        fx.run()
        again = fx.todo.read_text(encoding="utf-8")
        check(again.count("dispatch-" + key8("mail:operator@example.org", "m-one")) == 1,
              "with the ledger gone the to-do still refuses a second proposal for the same item")
    finally:
        fx.cleanup()

    # ══ 2 · the attempt cap: three failures, the fourth attempt is refused ═══════════════════════
    fx = Fixture()
    try:
        source, ident = "mail:operator@example.org", "m-one"
        key = None
        import hashlib
        key = hashlib.sha256(f"{source}|{ident}".encode()).hexdigest()
        fx.ledger.parent.mkdir(parents=True, exist_ok=True)
        rows = []
        for n in range(3):
            rows.append({"at": f"2026-11-16T1{n}:00:00Z", "run": f"r{n}", "kind": "event",
                         "source": source, "item": ident, "key": key, "key8": key[:8],
                         "verdict": "failed", "reason": "the to-do could not be written",
                         "shape": "errand", "dry_run": False})
        fx.ledger.write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")
        out = fx.run("--json")
        doc = json.loads(out.stdout) if out.stdout.strip().startswith("{") else {}
        check(key[:8] not in fx.todo.read_text(encoding="utf-8"),
              "a key that spent its three attempts is never proposed")
        refusals = [r for r in fx.runs() if r.get("verdict") == "refused"]
        check(len(refusals) == 1, "the fourth attempt is refused, and recorded once",
              json.dumps(fx.runs(), indent=1)[:900])
        check(refusals and "attempt-cap" in refusals[0].get("reason", ""),
              "the refusal names the cap", json.dumps(refusals[:1], indent=1))
        check(doc.get("counts", {}).get("refused") == 1, "the run counts the refusal", out.stdout)

        fx.run("--json")
        refusals2 = [r for r in fx.runs() if r.get("verdict") == "refused"]
        check(len(refusals2) == 1, "a later run does not refuse the same key twice",
              json.dumps(fx.runs()[-3:], indent=1))
        check(key[:8] not in fx.todo.read_text(encoding="utf-8"),
              "the terminal key stays off his list")
    finally:
        fx.cleanup()

    # ══ 3 · an unreadable input exits non-zero and writes no proposal ════════════════════════════
    fx = Fixture()
    try:
        os.chmod(fx.spine, 0o000)
        out = fx.run("--json")
        doc = json.loads(out.stdout) if out.stdout.strip().startswith("{") else {}
        check(out.returncode == 3, "an unreadable mail store exits 3, never 0",
              f"rc={out.returncode}\n{out.stdout}\n{out.stderr}")
        check(doc.get("verdict") == "failed", "the run records `failed`, not `no-op`", out.stdout)
        check("<!-- dispatch:inbox" not in fx.todo.read_text(encoding="utf-8"),
              "an unreadable input writes no proposal")
        last = fx.last_run()
        check(last.get("verdict") == "failed" and "read" in (last.get("why") or ""),
              "the ledger names the unreadable file", json.dumps(last, indent=1))
        os.chmod(fx.spine, 0o600)

        fx.accounts.write_text("accounts: {}\n", encoding="utf-8")
        out = fx.run()
        check(out.returncode == 3, "an accounts file that parses to nothing is an error, not `0`",
              f"rc={out.returncode}\n{out.stdout}")

        fx.accounts.write_text("accounts:\n  - id: [unclosed\n", encoding="utf-8")
        out = fx.run()
        check(out.returncode == 3, "a malformed accounts file is an error", f"rc={out.returncode}")

        fx.accounts.write_text(ACCOUNTS, encoding="utf-8")
        os.chmod(fx.wake, 0o000)
        out = fx.run()
        check(out.returncode == 3, "an unreadable wake queue is an error", f"rc={out.returncode}")
        os.chmod(fx.wake, 0o600)
    finally:
        fx.cleanup()

    # ══ 4 · mail is a NAMED SKIP where the seat has no mailbox, and the asks still come through ══
    fx = Fixture()
    try:
        fx.accounts.unlink()
        out = fx.run("--json")
        doc = json.loads(out.stdout) if out.stdout.strip().startswith("{") else {}
        check(out.returncode == 0, "no accounts.yaml is a clean skip, not a failure",
              out.stderr or out.stdout)
        check(doc.get("mail", {}).get("state") == "not configured",
              "the run names the skip: mail is not configured on this seat", out.stdout)
        check(doc.get("counts", {}).get("proposed") == 1,
              "the wake queue still yields its ask", out.stdout)
    finally:
        fx.cleanup()

    # ══ 5 · --dry-run writes nothing at all ═════════════════════════════════════════════════════
    fx = Fixture()
    try:
        before = fx.todo.read_text(encoding="utf-8")
        out = fx.run("--dry-run", "--json")
        doc = json.loads(out.stdout) if out.stdout.strip().startswith("{") else {}
        check(out.returncode == 0, "--dry-run exits clean", out.stderr or out.stdout)
        check(doc.get("dry_run") is True, "--dry-run says it was a dry run", out.stdout)
        check(fx.todo.read_text(encoding="utf-8") == before,
              "--dry-run writes not one byte to the to-do")
        check(not fx.ledger.exists(), "--dry-run writes no ledger row")
        check(doc.get("counts", {}).get("proposed") == 3,
              "--dry-run still reports what it WOULD do", out.stdout)
    finally:
        fx.cleanup()

    # ══ 6 · --check judges the record, and a broken ledger is a failure ═════════════════════════
    fx = Fixture()
    try:
        out = fx.run("--check", "--json")
        doc = json.loads(out.stdout) if out.stdout.strip().startswith("{") else {}
        check(out.returncode == 0, "--check passes on a healthy home", out.stderr or out.stdout)
        check(doc.get("ok") is True, "--check says ok", out.stdout)
        surfaces = {f["surface"]: f["level"] for f in doc.get("findings", [])}
        check(surfaces.get("his-list") == "ok" and surfaces.get("ledger") == "ok"
              and surfaces.get("mail") == "ok" and surfaces.get("wake") == "ok",
              "--check answers for every surface by name", out.stdout)

        fx.ledger.parent.mkdir(parents=True, exist_ok=True)
        fx.ledger.write_text("{not json}\n", encoding="utf-8")
        out = fx.run("--check")
        check(out.returncode == 4, "a ledger line that is not a record fails --check", out.stdout)
        fx.ledger.unlink()

        fx.todo.write_text(HIS_HALF + "\n- [ ] a stray line\n<!-- /dispatch:inbox -->\n",
                           encoding="utf-8")
        out = fx.run("--check")
        check(out.returncode == 4, "half of the markers is refused, never guessed", out.stdout)
    finally:
        fx.cleanup()

    # ══ 7 · the tree wiring: the row is in the ONE register, and the job is a real door ═════════
    units = (ROOT / "config" / "units.yaml").read_text(encoding="utf-8")
    check("\n  - name: dispatch\n" in units, "config/units.yaml registers the dispatch unit")
    block = units.split("\n  - name: dispatch\n", 1)[1].split("\n  - name: ", 1)[0] if "\n  - name: dispatch\n" in units else ""
    check("kind: timer" in block, "the dispatch unit is a timer", block)
    check("bin/time/nornir-job-dispatch.sh" in block,
          "the timer runs the Nornir job (never a hand-written unit)", block)
    check("mode: render" in block, "the ONE writer owns the unit (mode: render)", block)
    check(JOB.exists() and os.access(JOB, os.X_OK), "bin/time/nornir-job-dispatch.sh exists and runs")
    check(os.access(DOOR, os.X_OK), "bin/dispatch/dispatch.sh is executable")

    print()
    print(f"  {PASS} passed, {FAIL} failed")
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
