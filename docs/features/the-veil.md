# The Veil — evidence or no done, and the arm says RECEIVED

The Veil is the gate between what an agent says and what the house accepts. It has three working
parts today:

- A worker's `done` needs evidence, or it ends `unproven`.
- Every report reaches the arm holder with an id, and the holder answers it.
- Níðhöggr, the loop-breaker, runs on the clock, and the panel turns red if his clock stops.

## What you need

- A seat with a held arm (`bin/voice/rodd-arm.sh who`).
- The two cron rows from `config/cron.yaml.example` in your home's `config/cron.yaml`: the Veil sweep
  every 2 minutes, and Níðhöggr every 15.

## Evidence or no done

A worker ends its errand with one `--evidence` per claim:

```bash
bin/agents/eindri-acclaim.sh <id> --terminal done --evidence "bash bin/x/tests/test_y.sh" --line "opened PR <url>"
```

The act runs each command in the errand's repo. It files the command, its exit code and its output
under `## Evidence` in the report. The result is **`unproven`** (exit 5) in any of these cases:

| Case | What the report says |
|---|---|
| No `--evidence` given | `no evidence given` |
| An evidence command fails | `evidence <n> exited <code> (<command>)` |
| The PR's checks are red at its head | `PR checks are red at the head` |

An unproven errand is not reviewed, and the arm holder is told. Run the act again with green
evidence and it becomes `done`. Checks still running are named as pending, not as a failure.

`VEIL_EVIDENCE=off` skips the gate, and says so loudly.

## The arm contract

Every report and every Veil finding carries an id. The arm holder answers it:

```bash
bin/agents/veil.sh pending                    # what is waiting
bin/agents/veil.sh received <id>              # I have it (within 2 minutes)
bin/agents/veil.sh accepted <id>              # the build is right
bin/agents/veil.sh rework <id> "<why>"        # the build goes back
```

| When | What happens |
|---|---|
| A report is sent | It goes to the arm (`rodd-arm.sh tell`), or to the holder's pane when no arm is held |
| No RECEIVED in 2 minutes | The sweep types it into the holder's herdr pane, once |
| No RECEIVED in 10 minutes | The trouble panel's `receipts` row is red, with the count |
| The holder answers | The answer goes back to the sender's own road (`--reply-to`) |

Any agent sends a report the same way:

```bash
bin/agents/veil.sh send --from "<who>" --reply-to "<pane, errand or hermes:<session>>" "<what, and its proof>"
```

The holder steers an agent with an id the agent answers:

```bash
bin/agents/veil.sh steer --to hermes:<session> "<the line>"
```

## Hermes

The skill `veil-arm` is on the shipped shelf, which the Hermes seat loads in every directory. A
Hermes agent sends its report with `veil.sh send --reply-to hermes:<session>`, and hears RECEIVED in
that same session. When the Hermes gateway is not listening, the Veil uses the Hermes command line
(`hermes --resume <session> -z`) instead.

## Níðhöggr on the clock

`bin/time/nornir-job-nidhogg.sh` makes one pass each time it runs:

1. It scans the seated agents. A looping or stalled agent is broken at rung 1: it is interrupted
   and steered. `NIDHOGG_BREAK=off` turns this off.
2. It reads the errand branches for a commit repeated more than twice in an hour.
3. It tells each loop to the arm holder once, through the Veil.
4. It stamps `state/nidhogg/last-run.json`. A stamp older than an hour is red in the trouble panel.

## Limits

- The Veil checks the evidence it was given. It does not yet read a report and re-check every claim
  in it (plan 350 B2).
- A steer is not counted against the holder's receipts. A steered agent that never answers shows in
  `veil.sh status <id>`, not in the panel.

## If it does not work

- `veil.sh send` printed `"none","no"`: no arm is held and the holder's pane could not be found.
  Run `bin/agents/eindri-notify.sh --status`.
- The `receipts` row is red: run `bin/agents/veil.sh pending` and answer each id.
- The `loops` row says Níðhöggr has not run: the cron row is missing or the scheduler is stopped.
  Run `bin/time/nornir-job-nidhogg.sh` once by hand and read its output.
