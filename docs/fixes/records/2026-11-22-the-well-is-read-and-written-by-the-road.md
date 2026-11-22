# The well is read before work and written after it, by the road

**Date:** 2026-11-22 · **Component:** records (`bin/records/well-brief.sh`, `bin/records/well-write.sh`) · **Plan:** 350 part E

## What was wrong

- **The engine's brief recall called a door that does not exist.** `src/ymir_runtime/seat.py` asked `bin/mimir.sh`.
  The door is `bin/records/mimir.sh`, so no engine-seated brief ever carried a recall.
- **The spawn road recalled the same thing for every errand.** `bin/agents/einherjar-spawn.sh` asked the well
  about the brief's first heading. Since the bearings were prepended, that heading is the bearings' own on every
  brief.
- **The session head carried no recall.** It was in a section read only on demand.
- **The well was written only when an agent remembered.** A judge's verdict, a merge and a fix note wrote nothing.
  A write that failed was dropped with a warning.

## What was built

- `bin/records/well-brief.sh` is the one recall door. The brief's section asks for the work, skips the bearings,
  and is marked so it is never doubled. The engine, the spawn road and `eindri-start.sh` all call it. Its
  `--head` form is the new **THE WELL** section of the short head (54 of 60 lines).
- `bin/records/well-write.sh` is the one write door. It writes now, or appends to a queue that `flush` retries.
  The queue is never rewritten, and `--key` makes a write idempotent.
- The road writes: `eindri-acclaim.sh` (the minimal episode now goes through the queue), the judge's verdict in
  `bin/forge/judge-merge.sh` (once per review and head), and the merge door `bin/agents/pr-seal.sh` (one episode
  per merge, and one procedural episode per fix note the PR adds).
- The cron template carries `well-write.sh flush` every 10 minutes.

## Proof

- `bash bin/records/tests/test_living_well.sh` — 19 passed.
- `bash tests/test_acclaim_well.sh` — 4 ok.
- `bash bin/forge/tests/test_judge_merge.sh` — 68 passed.
- `bash bin/time/saga-session-start.sh --check` — the head fits (54 lines ≤ 60).
- `python3 -m unittest tests.test_engine` — 457 run. The same 9 failures and 5 errors occur on clean `main`, so
  none of them come from this change.
