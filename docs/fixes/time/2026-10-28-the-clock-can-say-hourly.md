## time · 2026-10-28 — the clock can say hourly

### Why

The Allfather asked for the memory sync *"on a cron job every hour"* (plan 139). Nornir could not say
"every hour", and nothing said so. Measured in `bin/time/nornir-cron-start.sh` on this seat:

- the schedule line was `HH:MM [@role] <command>` and the matcher was an **exact string compare** against
  `date +%H:%M` — a 45 s loop that could only fire a row once a day;
- the double-fire guard was a **per-day** stamp (`stamp_dir/$key` holds `$today`), so a row that fired at
  06:35 could not fire again that day — and could not fire at 07:35 either;
- a token the parser could not read was **skipped silently**: it still counted as a declared job in
  `--status`, so a typo looked like a schedule. That is the 2026-09-24 fault (role-first lines dead while
  counted) one layer down.

So "hourly" meant 24 hand-written lines, none of them proof against an edit — and the plan-139 proof
(count the heart's log by `origin=<machine>`, hourly) had no clock to hang on.

### Fix

`bin/time/nornir-cron-start.sh` now parses **shapes**, and the shape decides both the match and the stamp:

```
shape            fires                     stamp key      note
HH:MM            once a day, that minute   <date>         unchanged — every existing row keeps its behaviour
@daily           00:00                     <date>         readable alias; no minute to guess
@hourly          top of every hour         <date>T<HH>    the new shape
@hourly:MM       minute MM of every hour   <date>T<HH>    so twenty machines do not knock at once
```

- **One parser, one validity rule** — `parse_line` / `is_role` / `at_valid`, exported so the parent's
  start-time warning and the loop use the same code. The role gate still parses in **both** orders, and now
  before or after a *shape* too (`@heart @hourly:00 …`, `@hourly:00 @heart …`).
- **An unreadable shape is named, loudly, at start** — "will NOT fire", one line per bad row — and it is
  recorded in `state/.cron-invalid`, which `--status` reports as `invalid=<n>`. A row cannot look declared
  and be dead.
- **Fields are taken by expansion, never by `read`**: this seat put a whole line in the first field under
  `IFS=<tab> read`, and a schedule parser that can eat a row without saying so is a schedule nobody trusts.
- **Test hooks:** `BROKK_CRON_TICK` (loop sleep, default 45) and `BROKK_CRON_ONCE=1` (one pass, exit), so the
  schedule can be proven without waiting an hour.

### Evidence

`.agents/tests/nornir-schedule-shapes.test.sh` — **16 assertions, all passing**: a fake `date` sets the
clock and each pass is driven by `BROKK_CRON_ONCE`. Proven: `@hourly` fires at :00 and not at :07,
`@hourly:07` fires only at :07, a per-day row fires once and not twice in the same minute, `@hourly` fires
again in the next hour, `@daily` fires at midnight and not at 03:00, a role-gated shape still gates, an
unreadable shape never fires, `--status` counts it as `invalid=1`, and the start names it.

The live 31-row schedule in the home parses clean (`cron: stopped jobs=31`, no warning, no invalid rows), so
no existing job changed behaviour.

The asset `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` and `config/cron.schema.json` carry the same
shapes; the schema rejects a token the scheduler would skip.
