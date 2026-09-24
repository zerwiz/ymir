# hlidskjalf · 2026-09-24 — the cron board tells the truth: local and server schedules

## Why
The Nornir gate painted a lie: **Scheduler STOPPED · Jobs 0 · "No jobs. Sign in
live (gate API)"** while the home's `config/cron.yaml` carries 12 real,
role-gated jobs and the local loop was stopped only because it had retired for
want of a live session lock (the plan 29 law). Two read-path faults:

1. `/api/cron` read `<ROOT>/.agents/config/cron.yaml` — the repo's config dir,
   which ships ONLY the example template — so the board always saw an empty
   file and reported zero jobs while the loop ran the home's schedule.
2. The parser's line grammar `/^\d{2}:\d{2}\s+/` missed every role-gated line:
   the home writes `@heart 06:00 bin/…` (role BEFORE the time), so even the
   example's plain lines aside, the heart's record jobs were invisible to the
   board — and, it turned out, to the loop itself (see the runtime note).

## What
- **`/api/cron` is now the loop's own reader**: `cronConfigPath()` resolves
  `$YMIR_HOME/config/cron.yaml` → repo `cron.yaml` → the example (flagged as
  such). The answer carries `source`, each job's `role` and whether it `applies`
  to this seat's roles (`bin/topology.sh --json`), the fired markers from
  `state/.cron-fired`, and — when stopped — a `why` parsed from `state/cron.log`
  (so "DOWN" says *why*: `no live session lock`, `never started this session`,
  …).
- **`/api/cron/seats` (new)**: one read-only ssh round-trip per server seat —
  whynot (host `whynot`) and zerwizserver (host `server`), from `~/.ssh/config`,
  BatchMode + `ConnectTimeout=3` — returning reachable/running/pid/roles and how
  many of the schedule's jobs that seat's roles run. `YMIR_CRON_SERVER_SEATS`
  overrides the list. Read on demand, machine-local (plan 51 rule 1).
- **`src/gates/Cron.tsx`**: two faces — LOCAL (scheduler state + why, the job
  table with role chips, "runs here", last-fired from the date-guard stamps) and
  SERVERS (per seat: reachable · scheduler · role · runs). The bare "No jobs.
  Sign in live…" empty state is gone; a genuinely absent schedule names the
  missing path, a stopped loop its reason, an unreachable seat the failure.
- `src/services/api.ts` + `src/state/store.ts` carry the extended shapes.

## Verified
- `bun x tsc --noEmit` clean; `npm run build` green.
- Live on a test gate: `/api/cron` → `source: home`, 10 jobs, `roles: [dev]`,
  `runs-here: 4`, `why: never started this session` (fresh worktree, no loop).
- `/api/cron/seats` → whynot `reachable: true, running: true, pid 34965,
  roles [heart, forge], applies 10/10`; zerwizserver `running: false,
  roles [dev], applies 4/10`.

## Files
- `apps/hlidskjalf/server/index.ts` · `apps/hlidskjalf/src/gates/Cron.tsx`
- `apps/hlidskjalf/src/services/api.ts` · `apps/hlidskjalf/src/state/store.ts`
- `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`