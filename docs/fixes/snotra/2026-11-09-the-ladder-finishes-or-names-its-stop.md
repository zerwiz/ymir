# The ladder finishes, or it names the step it stopped at

**Date:** 2026-11-09 · **Component:** snotra · **Doors:** `bin/records/snotra-ladder.sh` (new),
`bin/records/meetings.sh`, `bin/records/plan.sh`, `bin/records/todos.sh`

Plan 228 §3 (F2) and §5 (F5), both already specified by plan 111's ladder and plan 112 §18.

## The ledger that measured it

```
before[1]{command,answer}:
  "bin/records/meetings.sh totals","3 meetings · 2 transcripts · 0 minutes · 0 promises"
```

Every piece existed; the **join** did not. A transcript was never turned into minutes; a promise
was never turned into work; and a step that failed left no sentence anywhere, so a meeting that
stopped at transcription looked exactly like one that finished.

## What was built

**1 · The ladder** (`bin/records/snotra-ladder.sh`) — four rungs, in this order, each proving
itself:

- **transcript** — a transcript that has words passes; audio with no words is transcribed on the
  seat through the existing engine door; neither is a **failure that names itself**.
- **minutes** — composed **by the model** from the transcript *and the people present*, written
  into that meeting's own folder. The model is the seat's own choice (`SNOTRA_RAIL_MODEL` from
  the watch unit's drop-in, then `RAIL_MODEL`, then the rail's first served model); the URL and
  the key resolve through `bin/model/rail-resolve.sh` and the vault. **No rail, no minutes** — the
  rung fails with the reason instead of writing a template and calling it done.
- **promises** — every promise the minutes carry, as `actions.md` in the same folder.
- **todos** — every promise filed on the board **in the same act**, through
  `bin/records/todos.sh` (the board's one writer), keyed `meeting:<id>:<n>` so a re-run files
  nothing twice.

**2 · A failed step writes the sentence and fires the hotline.** `stopped at <step>: <reason>`
goes into the meeting's own `.state`; the hotline hears it at HIGH; the door exits 1. The
`dispatched` state is written only when the last rung passes.

**3 · The index reads the shelf** (`bin/records/meetings.sh`). Still derived from the folders,
never a second record. It gained `json` (one shape for every reader), `brief` (the one line the
07:00 brief carries), `state <id>` (finished, or the stop sentence) and `plans <id>` (the plans
the meeting produced). Two counting faults were mended on the way: a `- none in the transcript`
bullet is no longer counted as a decision or a promise, and an empty column can no longer ride a
tab-separated record (`IFS=$'\t' read` collapses consecutive tabs, so every later column shifted
one to the left; `-` is now the sentinel, and the `plans` loop keeps an unterminated last line —
the same fault the fleet recorded on 2026-11-05).

**4 · The join, both ways.** `plan.sh new … --from-meeting <id>` writes `from_meeting: <id>` into
the plan's header; `plan.sh from-meeting <id>` and `meetings.sh plans <id>` read it back, and both
**refuse** rather than guess when no header names the meeting.

**5 · The board's write path.** `bin/records/todos.sh` (already in the tree, unwired) gained
`--key` (idempotent), `--meeting`, and `--json` — so the ladder could use the board instead of
inventing a second todo store. `bin/seat/ymir-mcp.py` and `bin/mcp/ymir-mcp.py` read the same
store and never write it: one writer.

## Measured after, on the real shelf

```
after[3]{command,answer}:
  "bin/records/meetings.sh totals","3 meetings · 2 transcripts · 2 with_minutes · 2 promises · 5 decisions"
  "bin/records/snotra-ladder.sh run 20261022-1713-20261022-1236-craig-martin","1m30s · minutes.md (28 lines) · 5 decisions · 2 promises · 2 filed as todos"
  "bash tests/test_snotra_ladder.sh","24 passed, 0 failed"
```

The Craig Martin meeting's minutes name decisions that exist in its transcript (the SOW, the
payment path, the delivery-window choice) and its two promises are two rows on the board, each
carrying the meeting id. The Andre Matejic fragment honestly reports `none in the transcript` —
the model did not invent a decision to fill the page.

## What this does not do

- **No cron row was added.** `snotra-ladder.sh run --pending` is the sweep; wiring it into Nornir
  is a scheduling decision (his), not a side effect of a fix.
- **The two shelves of todos are not merged.** The voice keeps its own list
  (`hodd/state/voice/todos.jsonl`, rendered to `todo-voice.md`); the house board lives at
  `$YMIR_HOME/state/todos.json` — which is on the home's **gitignored runtime shelf**. A promise
  filed there is not yet backed up by the home repo. The board's move into `hodd/` (with its two
  MCP readers) is the follow-up; it is named here so the gap is not discovered by losing one.
- The board's store is a rewritten JSON array, not an append-only ledger. That is the shape the
  MCP readers already expect; changing it is a design change, not this fix.

## CHANGE LOG

- **2026-11-09** — Opened: what was measured before, the faults in the order they hid each other, what changed, and what was deliberately left for another hand.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a person the house meets. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
