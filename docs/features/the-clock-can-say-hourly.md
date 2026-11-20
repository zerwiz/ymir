# The clock can say hourly — schedules that repeat, not just land

Nornir runs Ymir's scheduled jobs from one readable list, `$YMIR_HOME/config/cron.yaml`. Until 2026-10-28
every line had to name an exact minute of the day (`06:35`), so a job that should run every hour meant
twenty-four lines — and any one of them could be mistyped and never fire, while still looking scheduled.
Now a line may also say **`@hourly`**, **`@hourly:MM`** or **`@daily`**.

## What you need

- Nothing new. The scheduler is the same one the session start raises (`bin/time/nornir-cron-start.sh`).
- A role gate if the job belongs to one machine kind — `@heart`, `@forge`, `@dev`, `@hand`.

## Do it

Edit `$YMIR_HOME/config/cron.yaml` and pick a shape:

```
@hourly       bin/time/well-vault-sync.sh --mode sync
@hourly:20    bin/time/well-vault-sync.sh --mode sync
@daily        bin/time/nornir-job-memory-housekeeping.sh
@heart 07:00  bin/time/nornir-job-daily-briefing.sh
```

Check what the scheduler sees:

```
bin/time/nornir-cron-start.sh --status
```

It answers `cron: running pid=… jobs=31`, and adds `invalid=1` if any line carries a shape it cannot read.
A bad line is also named when the scheduler starts, in plain words — "will NOT fire" — with the line itself,
so it can never sit there looking scheduled.

## Notes & limits

- `@hourly` fires at the top of the hour, `@hourly:MM` at minute `MM` of every hour. Give each machine its
  own minute (`@hourly:20`, `@hourly:35`) so twenty machines do not knock on the same door together.
- A shape fires **once** per hour or per day even though the scheduler checks every 45 seconds; the stamp is
  what stops a double run.
- `HH:MM` still means once a day at that minute, exactly as before. Nothing old changed.
- There is deliberately no general cron grammar: no `*/15`, no ranges. If you need every fifteen minutes,
  that is four `@hourly`-style lines today, and a conversation about the shape tomorrow.

## If it does not work

`cron: WARNING — 1 line(s) carry a schedule shape Nornir does not understand, and will NOT fire:` — the
line is printed under it. Fix the shape: it must be `HH:MM`, `@daily`, `@hourly` or `@hourly:MM` (0–59).

`--status` shows `invalid=2` and you cannot find them — the rows are recorded in
`$YMIR_HOME/state/.cron-invalid`; read that file.

The job fired at the wrong moment — remember `HH:MM` is once a **day**, and `@hourly` is the top of every
hour. A job that seems to run twice an hour is two lines for the same command with different shapes: the
stamp is per command and per shape.
