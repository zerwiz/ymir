# The living well — read before work, written after it

The well (Mimirsbrunn) is read and written by the road itself, not by an agent remembering to.

## What you need

- The well running on this machine, or its door to the heart (`bin/bridge/mimir-bridge.sh --start`).
- The row `@heart,dev @every:10 bin/records/well-write.sh flush` from `config/cron.yaml.example` in your
  home's `config/cron.yaml`.

## When the well is read

| When | What you see | Door |
|---|---|---|
| A session starts | The section **THE WELL** in the short head: the day's topic and up to five episodes for it, this machine and this project | `bin/records/well-brief.sh --head` |
| An errand is briefed | A section *What the well remembers for this errand*, with the top five episodes for the task | `bin/records/well-brief.sh "<task>"` |

The brief asks the well about the **work**: the bearings block, which every brief shares, is skipped. The
section is marked (`<!-- well-recall:v1 -->`), so no brief carries it twice. Recall is data, not orders.

## When the well is written

| When | What is written | Store |
|---|---|---|
| An errand ends | The worker's own episode; if it left none, a minimal one from its line | episodic |
| A judge rules | The verdict and its items, once per review and head | episodic |
| A PR merges (`pr-seal.sh`) | What landed | episodic |
| The merged PR adds a fix note | The note's cause and fix | procedural |

Every write goes through `bin/records/well-write.sh`. A write the well does not take now is appended to
`state/well-write/queue.jsonl` and retried by `well-write.sh flush`. It is never dropped, and the queue is
never rewritten.

## The commands

```bash
bin/records/well-brief.sh --head                        # what the session head shows
bin/records/well-write.sh observe "<lesson>" --store semantic --tags rule
bin/records/well-write.sh pending                       # writes still waiting
bin/records/well-write.sh flush                         # retry them now
```

## Limits

- Consolidating episodes into conclusions is Honcho's work (plan 260), and the deeper well on heimdall's memory
  waits for the operator's answers (plan 350 E, step 2).
- The operator's own rules are written by the arm holder, as before (`--store semantic`).

## If it does not work

- The head says *the well did not answer*: run `bin/records/mimir.sh recall test`, and raise the bridge.
- `well-write.sh pending` keeps growing: the well is down. The writes are safe in the queue; raise the well and
  run `flush`.

## CHANGE LOG

- **2026-11-22** — written with the living well (plan 350 E).
