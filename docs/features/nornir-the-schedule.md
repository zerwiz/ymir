# Nornir — the schedule

## What it is

**Nornir** are the fates who govern time: Ymir's cron. Jobs are declared in
`config/cron.yaml` as `HH:MM [@role] <command>` lines, one lightweight scheduler loop keeps
exactly one alive per seat, and each job runs **once a day** (date‑guarded) with a
per‑job lock so a slow job never overlaps itself.

## What you need

- Ymir installed. The scheduler starts at session start and rides boot.

## Do it

```bash
bin/time/nornir-cron-start.sh            # ensure the jobs are running (idempotent)
bin/time/nornir-cron-start.sh --status   # is a scheduler live, how many jobs?
```

The default day (in `config/cron.yaml`):

| time | job |
|---|---|
| `06:00` | observer (Huginn) |
| `07:00` | daily briefing |
| `00:15` | memory housekeeping (Muninn) |
| `00:00` | git‑sync (the world‑tree) |

Plus role‑gated jobs (heart/forge/dev). **A command must resolve to a script that ships
in the repo** — a `cron-guard` ward refuses one that does not (Rule 16's door law).

## Notes and limits

- **Role‑correct.** A seat runs only the jobs its roles owe; a body that ran the heart's
  record jobs would fork the chain.
- **Commands ship.** Jobs run from the repo root, so `bin/…` always means the repo
  (`cron-guard` enforces it).
- **State is the home's.** `state/.cron-fired/<job>` date‑guards; `state/cron.log` is the
  log; `state/cron.pid` is the one loop.
- **Started by a session, never before one** — a seat that ends does not leave an orphan
  loop behind.

## If it does not work

| What you see | What to do |
|---|---|
| `--status` says no scheduler | `bin/time/nornir-cron-start.sh`. |
| A job never fires | Check its time/role in `config/cron.yaml`; confirm the seat holds that role. |
| `cron-guard` refuses a push | A job names a script that does not ship — move it into the repo. |
