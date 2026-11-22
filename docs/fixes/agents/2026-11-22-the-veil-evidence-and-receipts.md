# The Veil: a done needs evidence, and every report gets a RECEIVED

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/eindri-acclaim.sh`, `bin/agents/veil.sh`) · **Plan:** 350 part B (1, 4 and the arm contract)

## What was wrong

- **A worker could say "done" with nothing to show.** The acclaim door checked that a done line named a PR,
  and wrote the git record. It never asked for proof that the claims in the line were true. On the night
  of 2026-11-21, workers reported "fixed" for items still red in CI.
- **Reports piled up unread.** The wake queue and the pane injection carried a report to the arm holder.
  Nothing asked the holder to answer, so neither the sender nor the operator could tell whether it landed.
- **Níðhöggr ran nowhere.** `bin/gates/nidhogg.sh` was built to break looping agents and was wired to no
  clock. The gate register said "a human or a cron row must run it".

## What was built

- **Evidence or no done.** `eindri-acclaim.sh` takes `--evidence "<command>"`, once per claim. It runs each
  one in the errand's repo and files the command, its exit code and its output under `## Evidence`. With no
  evidence, a failing command, or a PR whose checks are red, the terminal state is `unproven` (exit 5).
  The review is not seated and the wake says UNPROVEN. A later act with green evidence becomes `done`.
  `VEIL_EVIDENCE=off` is the loud override. The briefs and the fixed core now teach `--evidence`.
- **The arm contract.** `bin/agents/veil.sh` gives every report an id and keeps an append-only ledger
  (`state/veil/ledger.jsonl`). The holder answers `received`, then `accepted` or `rework`. The answer goes
  back to the sender's own road. The acclaim records its id with `--queued`, so the queue is not written
  twice. `veil.sh sweep` types an unanswered report into the holder's pane after 2 minutes. The trouble
  panel's new `receipts` row is red past 10 minutes, with the count.
- **Hermes on the same road.** `veil.sh steer --to hermes:<session>` steers a Hermes session, with an id it
  answers. When the Hermes gateway is not listening, the Hermes command line (`hermes --resume <id> -z`)
  carries the line. The skill `veil-arm`, on the shipped shelf that the Hermes seat loads, teaches a Hermes
  agent to report and to answer.
- **Níðhöggr on the clock.** `bin/time/nornir-job-nidhogg.sh` scans the seated agents, breaks a loop at
  rung 1, reads the errand branches, and tells each loop once through the Veil. It stamps
  `state/nidhogg/last-run.json`. The trouble panel's `loops` row is red when the stamp is older than an hour.
  The cron template carries both rows.

## Proof

- `bash bin/agents/tests/test_veil.sh` — 23 passed.
- `bash bin/agents/tests/test_acclaim_evidence.sh` — 14 passed.
- `bash bin/ward/tests/test_trouble_veil.sh` — 10 passed.
- `bash bin/ward/tests/test_trouble.sh`, `bash bin/seat/tests/test_everything_up.sh` and
  `bash .agents/tests/eindri-review-spine.test.sh` still pass, with `--evidence` added to their done acts.
- The gate row `veil` (`bin/gates/checks.d/0546-veil.sh`) runs the three new tests.

## CHANGE LOG

- 2026-11-21 — review-mend: added missing heading for #883
