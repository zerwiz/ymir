# time · 2026-11-17 — the clock can say Monday

## Files

- `bin/time/nornir-cron-start.sh` — `is_dow` / `dow_matches` helpers, `parse_line` finds a DAY gate
  wherever it sits, the loop honours it, and the start-time warning judges it
- `.agents/tests/nornir-schedule-shapes.test.sh` — the day-gate matrix on a fake clock (24 assertions
  in the file now; the fake `date` learned `+%a`)
- `.agents/config/cron.schema.json` — an optional `day` array and the full shape list on `time`
- `src/ymir_runtime/config/load.py` — and see `docs/fixes/runtime/2026-11-17-the-loader-reads-the-schedule.md`
- `config/cron.yaml.example` — the weekly draft sweep row, with the reason it is on the heart
- `.agents/migrations/0025-the-weekly-draft-sweep.sh` — seats that row in an existing home

## Why

Plan 305's decision (2026-11-17) names the row exactly: `@heart Mon 09:15 bin/mail/draft-age.sh
--weekly`. Nornir's shapes were `HH:MM`, `@daily`, `@hourly`, `@hourly:MM` and `@every:N` — there was
no way to say *Mondays at nine fifteen*.

The failure mode is the one this house has already paid for once (2026-09-24, eight orphan seat
schedulers): a shape the scheduler cannot read is **not** an error at the point of the row. It is
recorded in `state/.cron-invalid`, counted as `invalid=<n>` by `--status`, and never fires — so the
row looks declared, the sweep looks scheduled, and no draft is ever swept. Writing the row without
teaching the clock would have shipped a dead schedule and a document saying otherwise.

## Fix

A **day gate**: the weekday name(s) `Mon` · `Tue,Fri` · `Monday`, written before the time, with or
without a role gate, and on either side of it where the role gate allows (`@heart Mon 09:15 …`,
`Mon 09:15 @dev …`, `09:15 @heart …`).

- **One parser serves both readers** — the firing loop and the start-time warning share
  `parse_line`, so a shape cannot be legal to one and dead to the other.
- **The stamp is the day**, so a 45-second loop fires a weekly row once on its day, never twice.
- **A day the calendar does not have** (`Funday`) is refused by name: it lands in `.cron-invalid`
  exactly like an unreadable shape, and `--status` counts it.
- **Shapes are found by what they are, never by position.** `@daily` is a shape and never a role
  gate; that distinction is now written into the parser rather than assumed by a token's position.

## Proof

`bash .agents/tests/nornir-schedule-shapes.test.sh` — PASS, 24 assertions, on a fake clock so the
verdict does not depend on what day it is run. The day-gate half:

| Assertion | What it pins |
|---|---|
| fires on its own day | `Mon 09:15` runs on a Monday |
| waits on every other day | it does not run on Tuesday |
| fires once on that day | a second pass stamps and stays quiet |
| waits for its minute | 09:16 does not fire a 09:15 row |
| a day list fires on each listed day | `Tue,Fri` runs on both, and only once each |
| a day it cannot read never fires, and is named | `Funday` → `.cron-invalid`, `--status` counts it |

The pre-existing shapes are re-proved in the same run, because a parser change that breaks `@hourly`
would be a worse fault than the one it mends.

## Not changed

`@daily` / `@hourly` rows keep their per-day and per-hour stamps; the role gate still gates; the
`.cron-invalid` file is still the only record of a shape that will not fire. The day gate is
additive: a schedule with no weekday name in it behaves exactly as it did.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #817
