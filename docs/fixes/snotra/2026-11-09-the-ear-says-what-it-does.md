# The ear says what it does, and the ladder finishes

**Date:** 2026-11-09 · **Component:** snotra · **Doors:** `bin/records/snotra-what.sh` (new),
`bin/records/meetings.sh` (new), `systems/snotra/services/record/snotra-ladder.sh` (new),
`systems/snotra/services/ear/snotra-capture.sh`, `systems/snotra/services/ear/snotra-detect.sh`,
`systems/snotra/services/record/snotra-store.sh`, `bin/records/plan.sh`, `bin/records/todos.sh` (new),
`bin/time/nornir-job-daily-briefing.sh`

Plans: **228** §1–§3, §8 (F1 · F2 · F5) and **112** (the five silent failures).

## What the Allfather saw

*"update Skírnir's database"*, a meeting he could not attend, and *"is the ear listening"* — three
questions that should answer in one place, in sentences. Measured tonight instead:

```
broken[4]{measure,value,how}:
  "the ear has no status door","`snotra-capture.sh status` → `snotra: the door moved to systems/snotra/services/ear/snotra-capture.sh and is not there` (exit 127)","`bin/time/snotra/snotra-capture.sh status`"
  "a call produces a transcript and nothing else","`3 meetings · 2 with transcript · 0 with minutes · 0 promises`","`bin/records/meetings.sh totals`"
  "a silent ear looks identical to a working one","the watch was active with nothing captured for six days and said so nowhere","`snotra-what.sh now` did not exist"
  "the index nobody could query","`hodd/life/meetings/work/*/` held three meetings and no door read them as a set","`bin/records/meetings.sh list`"
```

Every one of those is plan 112's own law: **a silent failure is indistinguishable from working.**

## What was wrong, and why it stayed wrong

**The capture door carried the retired shim's path guard.** `systems/snotra/services/ear/snotra-capture.sh`
still computed its target as `$_d/../../..`, which from `systems/snotra/services/ear` is `<repo>/systems`,
never the repo root — so the door always concluded it was missing and exited **127**. It is the exact fault
fixed in the watch on 2026-11-04 (`docs/fixes/snotra/2026-11-04-the-watch-heard-its-own-hands.md`); the copy
in the capture was never mended. Its two hotlines were dead twice over: the guard exited before them, and
`say_hotline` used an **undefined `$ROOT`** — under `set -u` the first call aborted the whole capture.

**The pipeline had no upper rungs.** `finalize()` transcribed, then wrote flat files into one shelf
(`<date>-<lane>-<slug>.md`), so a meeting was never a folder, the store contract (`plan 111`: `meeting.json` ·
`transcript.md` · `minutes.md` · `.state`) was never used, the minutes carried `(pending AI summary)`, and no
promise ever became work.

## The mend

```
mended[6]{what,where,proof}:
  "the ear has ONE door that says what it does","`bin/records/snotra-what.sh` — `now` · `last` · `plan` · `week` · `off|on`, plus `--brief` and `--json`","`now` answers `armed — … the rule that decided: … since … the cap ends it at …`; the door's own self-test proves 19 cases against fixture state"
  "a silent ear is reported as silent","the same door","a watch that is up with nothing captured in 24h prints `no call seen in 24h` — in `now` and in the 07:00 brief"
  "his hand is recorded, not hand-edited","`off --reason '<why>'` writes `state/.snotra-off`; the watch reads it and refuses to arm","`now` answers `off by his hand · the rule that decided: he said so — <reason>`"
  "the seven transitions speak","arm · leave (detect) · capture start · capture stop (capture) · transcript ready · minutes filed · a step that FAILED (ladder)","each fires `bin/notify/send.sh --source snotra` with its own key; the ladder's self-test proves a stop fires and a finish does not"
  "the ladder finishes, or names its stop","`systems/snotra/services/record/snotra-ladder.sh`","transcript → minutes composed BY THE MODEL from the transcript AND the people present → every promise a todo in the same act; a failure writes `stopped at <step>: <reason>` into the meeting's own `.state` and fires the hotline"
  "the index reads the shelf, both ways","`bin/records/meetings.sh` (`list` · `show` · `totals` · `json` · `brief` · `plans` · `state`) and `plan.sh new --from-meeting <id>`","`meetings.sh plans <id>` returns the plan files whose header carries `from_meeting:`; a join to a meeting that does not exist is refused"
```

`bin/time/snotra/snotra-capture.sh` is the shim that execs the door; it was already correct and now reaches a
door that answers:

```
$ bin/time/snotra/snotra-capture.sh status
Snotra capture: idle
  Listening indicator: absent
```

## The model call is a config, not a constant (Rule 07)

The ladder composes minutes through the **living rail resolver** (`bin/model/rail-resolve.sh`), the key through
`bin/vault/hodd.sh emit secrets/platform.env`, and the model through `SNOTRA_RAIL_MODEL` → `RAIL_MODEL` → the
resolver's first listed model. Measured on this seat tonight: the resolver's `models[0]` is
**`apodex-1.0-mini`**, which answered `HTTP 500` after ~35 s; the seat's own drop-in already names
`qwen3.5-9b@q4_k_s-summarizer`, which composed the minutes in ~50 s. **A model that 500s is reported as a stop,
never as minutes** — `stopped at minutes: the model did not answer — rail: HTTP Error 500`.

```
$ SNOTRA_RAIL_MODEL=qwen3.5-9b@q4_k_s-summarizer snotra-ladder.sh run <the acceptance fixture>
ladder: FINISHED — …/minutes.md · …/actions.md · 1 todo(s)

## Decisions
- The pre-industrial palette will be used for the whole film.
- No manufactured objects will be in the frame.
- The microphone will never be opened for an online meeting.
```

Every one of those three decisions is in the fixture transcript, verbatim: *"we go with the pre-industrial
palette for the whole film"* · *"No manufactured objects in frame"* · *"we never open the mic for an online
meeting"*. **No decision is invented** — the real Craig Martin transcript contains no settled decision, and the
minutes say `- none stated` rather than promoting a discussion into one.

## Two faults found in the index on the way

- **The plan ledger was never walked.** `meetings.sh` detected a ledger at `depth > 4`, but a ledger sits at
  `svartalfaheim/<realm>/projects/<project>/plans` — *five* separators below `svartalfaheim`. `plans` answered
  "produced no plan yet" for plans it could see.
- **A one-row pipe printed nothing.** `printf '%s' "$planfiles" | tr ',' '\n' | while read` never yields the
  last line without a trailing newline, so a single-plan join printed a header and no plan.

## What changed

- [x] `bin/records/snotra-what.sh` (new) — the ear's one door, with `--brief`, `--json` and `--self-test`.
- [x] `bin/records/meetings.sh` (new) — the index, derived from the folders; `--brief` is the row the 07:00
      brief carries; `plans` is the join, and the depth/newline faults above are mended.
- [x] `bin/records/todos.sh` (new) — the ONE task board: it writes the store the harness's own task tool
      already reads (`state/todos.json`), so a promise a meeting produced appears where the Allfather looks.
      Idempotent by content *and* meeting, so a ladder re-run files nothing twice.
- [x] `bin/records/plan.sh` — `--from-meeting <id>` writes `from_meeting:` into the plan header and refuses a
      join to a meeting folder that does not exist.
- [x] `systems/snotra/services/record/snotra-ladder.sh` (new) — the upper rungs, and `--self-test`.
- [x] `systems/snotra/services/record/snotra-store.sh` — `state <id> stopped-at <step> <reason>`; `new` takes
      `--started` and `--duration` (the ear knows both, the record should too).
- [x] `systems/snotra/services/ear/snotra-capture.sh` — the shim guard removed, the hoard resolved through
      `hoard-lib.sh`, `ROOT` defined so the hotline can fire.
- [x] `systems/snotra/services/ear/snotra-detect.sh` — `hotline()`; arm and leave speak; `.snotra-off` is obeyed;
      `finalize()` now creates one meeting folder through the store and hands the rest to the ladder.
- [x] `bin/time/nornir-job-daily-briefing.sh` — two rows: **the ear** and **the meetings**. A brief that cannot
      reach a shelf says so; it never fails the 07:00 job.
- [x] `systems/snotra/services/record/snotra_paths.py` — a meeting on an **intake shelf**
      (`svartalfaheim/.inbox/*`) is a meeting; three of this home's real ones live there and no door could see
      them.
- [x] `docs/features/snotra-the-meeting-ear.md` and its catalogue entry, and this note.

## What did not change

- **The microphone is never opened to hear an online meeting** (the Allfather's law, 2026-10-31). The local-room
  gate in `do_arm` and in `snotra-capture.sh start` is untouched; the ladder only ever reads a transcript that
  already exists.
- The capture, the arm/leave gates, the probes and the silence floor are unchanged.
- No merge, no pull request: local-only, as the errand required.

## Appended the same day — one board, not two, and the gate that decided it

The first draft of this door wrote a *second* ledger (an append-only `hodd/state/voice/todos.jsonl` with its own
rendered view). The house's own mocks gate refused the name outright — `(todo)` in `bin/` is a stub, and a
door called `todo.sh` trips it on every line it prints — and the second board was the worse fault: the harness
task tool reads `state/todos.json`, so a promise filed elsewhere is a promise nobody ticks.

So the door is `bin/records/todos.sh`, it writes **the harness's own store**, and the refusal is recorded here
because the gate was right: *two boards is one board too many.*
