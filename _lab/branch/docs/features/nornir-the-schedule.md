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

## Appended 2026-10-24 — a row that cannot run is not a row

The four Gná mail rows ran on 2026-10-23 and then, without a single failing check, stopped
executing: the script they name was committed `644`, and the runner takes a bare `bin/…` to
`exec`, so every round since answered `rc=126 Permission denied`. `cron-guard` passed the whole
time — it asked whether the script **ships**, which it does.

`cron-guard` now asks both questions: a `bin/…` named by a schedule must exist **and** be
executable, in the operator's cron, the repo's, and the shipped example. The example was itself
naming a `644` script (`bin/time/nornir-job-doctor.sh`), so a fresh install's daily doctor would
never have run either. Both are executable now; a schedule that names a `644` script fails the
ward with the `chmod` in the message.

| What you see | What to do |
|---|---|
| `a cron job names a script it cannot execute (no execute bit)` | `chmod +x <script> && git update-index --chmod=+x <script>` |
| A cron row that fires and does nothing | `grep rc= state/cron.log` — `rc=126` is this fault, `rc=127` is a path that does not exist |
