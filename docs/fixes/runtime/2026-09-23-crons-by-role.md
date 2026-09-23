## runtime · unversioned · 2026-09-23 — crons by role: a dev body runs no record jobs (plan 51 P4)

### Why
- **Problem:** every session started a full Nornir schedule, so **record jobs ran
  on dev boxes** and ended seats left **8 orphan schedulers** behind. The fleet is
  2 servers + 2 dev machines; jobs belong to the role that owns them, not to
  whichever machine happens to have a session.
- **Fix:** a **role gate** on each job.
  - `config/cron.yaml` lines may carry a prefix: `HH:MM @<role>[,<role>] <command>`.
  - `bin/nornir-cron-start.sh` reads **this machine's roles** from
    `bin/topology.sh` (plan 51 P0), defaulting to `dev`, and runs only jobs whose
    gate includes one of them. **No gate means any role.**
  - Roles: `@heart` owns the record jobs (git-sync, memory housekeeping,
    briefing), `@forge` the model jobs, `@dev` a full body — and a `dev` body runs
    **neither** record nor forge jobs. The template (`config/cron.yaml.example`)
    and the Nornir asset document the syntax.

### Verified
- `.agents/tests/cron-role-gate.test.sh` — **ALL PASS**: a `@dev` job runs on a
  dev box; an ungated job runs on any role; a `@heart` and a `@forge` job **do
  not** run on a dev box.
- `bash -n` clean.

### Files
- `bin/nornir-cron-start.sh`
- `.agents/config/cron.yaml.example`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
- `.agents/tests/cron-role-gate.test.sh`
