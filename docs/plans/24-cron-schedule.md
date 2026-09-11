# Plan 24 — Cron Schedule & Briefings

- **Status:** proposed · **Realm:** platform · **Owner:** Brokk

## Objective

Stateless, shiftless automation: scheduled jobs spawn fresh processes, inject
directives, execute, write output, and exit. Every run is observed into the well
and logged to Runes.

## Schedule

| Job | When | Writes to |
|---|---|---|
| Daily briefing | 07:00 | `svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md` |
| Git backup / sync | configurable (e.g. hourly) | push to remotes; `runes_audit.md` |
| Command/firstmate observation | plan 23 | Mimirsbrunn episodes + Runes |
| Social poster | configurable | marketing workspace |
| Memory housekeeping | nightly | engram `decay()`/`compress()`/backup (when wired) |

## Mechanics (stateless spawn)

1. Cron fires → `.agents/cron/` spawns a headless process.
2. Inject: `AGENTS.md` + realm context + task prompt (`<untrusted_context>` contained).
3. Execute (optionally inside Utgard; worktree via Yggdrasil for writes).
4. Observe outcome into Mimirsbrunn; carve Runes line.
5. Exit. No resident state between runs.

## ADD / NOT / KEEP

- **ADD:** `.agents/cron/jobs/*` runners, schedule config, briefing template, status page in Hlidskjalf.
- **NOT:** long-lived background agents; cron jobs owning mutable source trees directly.
- **KEEP:** the 07:00 briefing + stateless pattern already mandated by AGENTS.md.