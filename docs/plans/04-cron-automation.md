# Plan 04 — Cron Automation

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

Stateless scheduled jobs that spawn, execute, write, and exit.

## Scope

`.agents/config/cron.yaml`; `bin/nornir-cron-start.sh`; daily briefing, observer, housekeeping, git sync.

## Done when

Jobs start at session open and run once per schedule, date-guarded.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
