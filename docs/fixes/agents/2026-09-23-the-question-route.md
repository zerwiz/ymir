## agents · unversioned · 2026-09-23 — the question route: a worker's question reaches Brokk, and the answer reaches the worker

### Why
- **A worker with a question had no road to the coordinator.** The Eindri→Brokk
  bridge knew one shape: a *report* (`state/eindri-reports/<agent>.md`), meaning
  the smith is done. A smith that is **blocked** — not done, waiting on a
  decision — had nowhere to put the question. So it asked the only desk it could
  reach, and that was the Allfather's terminal: the `galdr` Eindri blocked on a
  four-option questionnaire about the Chrome DevTools MCP (2026-09-23).
- **A question is not a report.** They share the trigger (wake Brokk) but differ
  in the need: a report wants a **review**, a question wants an **answer**. The
  wake said `reported` for both, so the digest could not tell the coordinator
  which errand needed a reply.
- The answer road already existed — `bin/eindri-send.sh` steers a seated agent —
  but nothing connected the question to it.

### Fix
- **`bin/eindri-seen.sh`** — a question is now a reportable signal: the condition
  is true when `state/eindri-questions/<agent>.md` exists, beside the report file
  and the worktree `REPORT.md`.
- **`bin/eindri-acclaim.sh`** — reads the two shelves apart and names the need in
  the wake:
  - a question → `eindri <agent> QUESTION: QUESTION at
    state/eindri-questions/<agent>.md — answer with bin/eindri-send.sh <agent> "…"`,
    with the desktop alarm raised (`ymir-say.sh alarm`) rather than the quiet
    note.
  - a report → unchanged (`reported`, quiet note).
- **`bin/herdr-run.sh`** — the seat brief now names the right shelf: a genuine
  fork goes to `state/eindri-questions/<name>.md` (Brokk is woken, answers with
  `bin/eindri-send.sh`, and the worker carries on), while a finished errand goes
  to `state/eindri-reports/<name>.md`.

The route is now whole:

```
question_route[3]{from,to,how}:
  "Eindri","Brokk","state/eindri-questions/<agent>.md -> eindri-seen -> eindri-acclaim -> state/.wake-queue"
  "Brokk","Eindri","bin/eindri-send.sh <agent> \"<answer>\""
  "Brokk","Allfather","only when it is genuinely the Allfather's call"
```

### Verification
- `bash -n` clean on all three files.
- Functional, end to end, against a scratch state dir: a question file made
  `eindri-seen.sh` exit 0; `eindri-acclaim.sh` reported
  `"kvasir","QUESTION","QUESTION at state/eindri-questions/kvasir.md — answer
  with bin/eindri-send.sh kvasir "…""`; and the wake queue carried
  `eindri kvasir QUESTION: …`.
- A report still reads `reported`, so the existing road is unchanged.

### Files
- `bin/eindri-seen.sh`
- `bin/eindri-acclaim.sh`
- `bin/herdr-run.sh`
