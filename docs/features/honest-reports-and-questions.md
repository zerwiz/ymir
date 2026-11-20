# Honest reports and unanswered questions — a worker's "done" is checked, and a waiting worker is heard

## What it is

Two things the arm now watches for you, so a fault is raised before you have to ask.

**A done report must carry its record.** When a worker says *done*, its report carries the commit,
the files it changed, `git status`, and where the commit is (`pushed`, `parked` or `local only`).
The worker's terminal act writes this record from git itself. The arm then checks the record on
the machine the report names. If the commit is missing, not on the branch, or not on origin when
the report says *pushed*, the errand's status turns to `false-done` and the helm is woken.

**A question nobody answered is raised.** When a worker files a question and nobody answers:

- after **15 minutes** the helm is woken, once;
- after **one hour** you get one line on your phone, with buttons to answer it or read it.

An answer clears both steps before they fire.

## What you need

- The arm running (`bin/pi/syn-watch.sh status`), from a pin that carries this change.
- For the one-hour line: the hotline (`bin/notify/send.sh`) able to reach Telegram.

## Do it

See the open questions, oldest first:

```bash
bin/agents/eindri-answer.sh --list
```

Answer one. This speaks the answer into the worker's pane, records it in the question file, and
moves the file to `eindri-questions/answered/`:

```bash
bin/agents/eindri-answer.sh <errand-id> "branch from main"
```

If you already answered another way (on a call, in the pane by hand), record it so the arm stops
asking:

```bash
bin/agents/eindri-answer.sh <errand-id> --record-only "answered on the call"
```

Read what a worker's report claims, and what the arm made of it:

```bash
cat "$YMIR_HOME/state/eindri-reports/<errand-id>.md"     # the ## Record block
tail -2 "$YMIR_HOME/state/<errand-id>.status"           # false-done: … when the claim failed
```

## What the arm counts as an answer

Any one of these:

- the question file carries a line that starts with `answer:` (the door writes it);
- the file has left the question shelf (moved to `answered/`);
- someone spoke into the worker's pane after the question, through `bin/agents/eindri-send.sh`;
- the worker wrote a new status line that is not `needs-decision:`, `blocked:` or `paused:`.

## Limits

- A machine that does not answer over ssh proves nothing: no `false-done` is raised on silence.
- A report with no commit is honest when it says **nothing committed** and the branch agrees, or
  when the errand was a scout, review or recon.
- Questions and done lines older than 24 hours are left to the ledger
  (`BROKK_WATCH_ERRAND_HORIZON_SECONDS`).
- The windows are `BROKK_WATCH_QUESTION_WAKE_SECONDS` (900) and
  `BROKK_WATCH_QUESTION_ESCALATE_SECONDS` (3600). They are counsel until the operator sets them.

## If it does not work

| Symptom | Look at |
|---|---|
| no wake at all | `bin/pi/syn-watch.sh status` — is the arm up, and from which pin? |
| the phone line never came | the arm's line says `the hotline did not take it`; run `bin/notify/send.sh --dry-run …` |
| a true report was called false-done | the `## Record` block: the repo, branch and machine it names must be where the commit is |

## CHANGE LOG

- **2026-11-20** — written: the reporting contract enters every brief, the arm verifies a done claim, and the unanswered question wakes the helm and then the operator (plan 339.2 and 339.3).
