# agents · 2026-11-20 — a report counts only with its record, and a question nobody answers is raised

Plan 339, phases 339.2 and 339.3. It builds on the arm watcher in
`2026-11-20-the-arm-wakes-on-the-errands-it-dispatched.md` (dead pane, false done, stalled), which this change
carries in the same branch.

## What went wrong

On 2026-11-20 three errands reported *done* against an empty, an unpushed or a nonexistent branch. One claimed a
commit in another repository that the machine it named does not hold. In the same day, ten errand questions sat in
the home with no answer while the hall showed their workers as idle. Nothing raised either fault. Both were found by
hand.

The reporting contract (the commit, the files, `git status`, where it is) lived in one hand-written brief. No other
brief carried it, and nothing checked it.

## What changed

### 339.2 — the contract is in every brief, written by git, and checked

| Where | What |
|---|---|
| `.agents/assets/agents/eindri-core.md` | A new section, *Your report counts only with its record*. `eindri-bearings.sh` prints this core into every brief. |
| `bin/agents/erindi-brief.sh` | The scaffolded brief carries the same contract in its status section. |
| `bin/agents/eindri-acclaim.sh` | `--terminal done` appends a `## Record` block to the report, measured from git: `commit:` (the `git log --oneline -1` line, or `none — nothing committed`), `branch:`, `repo:`, `machine:`, `where:` (`pushed` · `parked` · `local only`), the files from `git diff --name-only <base>...HEAD`, and `git status --short`. A shelf that already has a record is not given a second. |
| `src/ymir_runtime/watch.py` | `parse_record` reads the block (or a bare pasted one-line log). `verify_record` checks the claim. |

The check, in order. Each failure is a fault phrase; a machine or origin that does not answer gives no verdict.

1. The commit exists in the named repo, on the named machine. Another machine is asked over
   `ssh -o BatchMode=yes <machine> git -C <repo> …`.
2. The named branch exists there and contains the commit.
3. The commit is not already on the base. A pasted `git log -1` of `main` reads as *nothing committed*.
4. `pushed` means `git ls-remote origin refs/heads/<branch>` holds it; `parked` means `refs/parked/<id>` holds it.
5. `local only` on an errand that owes a push (`direct-PR`, `no-mistakes`, `pr`) is short of the contract.

With no record, the older branch check stands. A scout, review or recon errand that committed nothing is honest, and
so is a report that says **nothing committed** when git agrees.

A failed claim appends `false-done: <stamp> — the arm checked the record: reported done with <fault>` to the
errand's status file and raises `check: errand <id> false-done — reported done with <fault>`. The line text changed
from the earlier `check: errand <id> reported done with …`, so the helm reads the verdict by name. `false-done:` is an
ended status: the dead and stall checks leave it alone, and the celebratory `signal: <id> done:` is never raised over
it.

### 339.3 — the fourth eye: the unanswered question

`question_wake` in `src/ymir_runtime/watch.py` reads `state/eindri-questions/*.md`, after the errand checks.

| Age | What happens | Line |
|---|---|---|
| over 15 minutes | the helm is woken, once per question | `check: errand <id> question unanswered for <n> minutes (<path>): <first line>` |
| over 1 hour | one line to the operator through `bin/notify/send.sh` (`--severity HIGH`, `--key question:<id>:<mtime>`, two buttons), and the helm is told it went | `check: errand <id> question unanswered for <n> minutes — sent to the operator` |

A question counts as answered when its file carries an `answer:` line, when it has left the shelf, when the fleet send
log (`state/fleet/messages.jsonl`) shows a line into the worker's pane after it, or when the worker wrote a status line
after it that is not `needs-decision:`, `blocked:` or `paused:`. Each step is keyed in `.arm.errand-woke` by the
question's file time, so a new question from the same errand is news again. Questions past the 24-hour horizon are
left to the ledger.

`bin/agents/eindri-answer.sh <id> "<text>"` is the helm's answer act: it speaks into the pane through
`eindri-send.sh`, appends the `answer:` line, and moves the file to `answered/`. A send that fails leaves the question
open. `--record-only` records an answer given another way, and `--list` shows the open questions.

The windows are `BROKK_WATCH_QUESTION_WAKE_SECONDS` (900) and `BROKK_WATCH_QUESTION_ESCALATE_SECONDS` (3600).

## A fault found on the way: the mid-session sweep had stopped

`sweep_handoff` in `watch.py` asked for `bin/eindri-handoff.sh`. The door moved to `bin/agents/` with the folder
split, so the arm's mid-session sweep had silently not run since. It now asks `bin/agents/eindri-handoff.sh` first and
keeps the flat path as a fallback for an older pin. Expect a first burst of report and question wakes on the first
poll after the pin carries this, for shelves that were never delivered; the shared ledger keeps each to one.

## Proof

- `python3 -m unittest ymir_runtime.tests.test_watch` (from `src/`): **107 tests, OK**. New: `HonestReportTest`
  (11 cases, real git repos with a bare origin, ssh scripted) and `QuestionWakeTest` (11 cases).
- `bash tests/test_acclaim_record.sh`: **6 ok**. The record the act writes is the record the arm accepts; a doctored
  sha is caught.
- `bash tests/test_question_wake.sh`: **7 ok**. A fake errand, the real answer door, a fake hotline and sender.
- The real door, `bin/pi/syn-watch.sh run --emit`, against a scratch state with a fake `herdr`:

```text
== 339.2: done claiming pushed, origin lacks it ==       (first pass: the revived sweep's queue wake)
check: errand probe-done false-done — reported done with a claim of pushed, but origin holds no refs/heads/eindri/probe-done
== 339.3: a question 20 minutes old ==                   (first pass: the sweep's queue wake)
check: errand probe-ask2 question unanswered for 20 minutes (<scratch>/eindri-questions/probe-ask2.md): Which base, main or the batch head?
== next pass ==
[exit 124]                                                (quiet: one wake per question)
```

Not proven here: the arm running from the pin (this branch is not gathered, so the pin does not carry it), a second
machine, and a real Telegram line. `bin/gates/tests/test_sol_stamps.sh` has one failing case (`the acclaim prints one
stamped human line`) on `main` as well; it is not this change.
