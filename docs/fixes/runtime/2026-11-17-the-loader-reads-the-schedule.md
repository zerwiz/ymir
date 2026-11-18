# runtime · 2026-11-17 — the loader reads the schedule the way the scheduler reads it

## Files

- `src/ymir_runtime/config/load.py` — `_parse_cron` rewritten around one token scan
- `tests/test_config_cron.py` — NEW, 8 proofs
- `.agents/config/cron.schema.json` — an optional `day` array, and the full shape list on `time`

## Why

`src/ymir_runtime/config/load.py` reads the operator's `config/cron.yaml` for validation. Its refusal
is the loud one — it names the file and the line — so a disagreement with the real scheduler is a
false alarm about a file that works.

Two were measured while shipping plan 305's weekly row:

1. **The loader refused shapes the clock accepts.** `_CRON_TIME` matched `HH:MM` only, while
   `bin/time/nornir-cron-start.sh` and `cron.schema.json` both accepted `@daily`, `@hourly`,
   `@hourly:MM` and `@every:N`. The same line was legal to the schedule and illegal to the validator.
2. **`@daily cmd` was read as a role gate.** Any leading `@word` was taken for a gate, so an ungated
   `@daily` row consumed the shape and then failed on the command as if it were a time.

The day gate (`Mon 09:15 …`) then had to be understood by both doors, or the row that fires would be
the row the validator refuses.

## Fix

One token scan, mirroring the scheduler's own rule — **gates are found by what they are, never by
position**:

- a **role gate** matches `@(heart|forge|dev|hand)(,…)` — and nothing else, so `@daily` can never be
  mistaken for one;
- a **day gate** matches `Mon` … `Sun` / full names, optionally comma-listed;
- the **shape** is the first token that matches the scheduler's shape list, and the command is the
  rest of the line **as written** (spacing and quoting preserved by slicing the original line, not by
  re-joining tokens);
- a role gate may also follow the shape (`09:15 @heart cmd`), which is the older form.

## Proof

`python3 tests/test_config_cron.py` — 8 proofs:

| Proof | What it pins |
|---|---|
| a weekly row parses with its day and role | `@heart Mon 09:15 cmd` → `day:[Mon] roles:[heart]`, the command intact |
| a day list before an ungated shape | `Mon,Fri 09:15 @dev cmd` → the gate is taken out of the command |
| the older shape-first form | `09:15 @heart cmd` still parses |
| every shape the schedule uses | `@daily` · `@hourly` · `@hourly:20` · `@every:5` · `06:00` |
| `Funday`, a bad minute, no command, no shape | each REFUSED by name |

The scheduler's own proofs live in `.agents/tests/nornir-schedule-shapes.test.sh`, run by the
`nornir-day-gate` CI gate; this file proves the OTHER reader of the same file.
