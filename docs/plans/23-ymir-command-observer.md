# Plan 23 — Ymir ↔ Command/Firstmate Observer

- **Status:** proposed · **Realm:** platform · **Owner:** Brokk
- **Context:** ENTRY-003 research — `command` (WayOf Command ops center, `.compliance/`) and `firstmate` (crew supervisor, worktrees) already exist on this machine. Ymir must **manage what exists**, not rebuild it.

## Objective

A read-only observation bridge from Ymir into `~/command` and `~/firstmate`:
Ymir sees their state, surfaces it in Hlidskjalf, and feeds it into Mimirsbrunn —
but never edits their trees (their own agents own those).

## What Ymir observes

| Source | Signal |
|---|---|
| `command` | FEATURES.md registry, `.compliance/` gates, tenants (josef, craig), factory runs (factory.db), Kaia's engram (`kaia.engram`) |
| `firstmate` | captain/crew sessions, worktree state, supervision handoffs |

## Mechanics

- `ymir_command_observer.ts` reads each system's manifests/DBs on a schedule
  (cron; plan 24) and on webhook/file-change.
- Each observation becomes an **episode** in Mimirsbrunn (`/observe`, tag
  `source: command|firstmate`) and a filtered line in Runes.
- Hlidskjalf gets a "fleet" tab listing both external systems with their live
  process/repo state.
- **Never write into `~/command` or `~/firstmate`** — read-only by contract
  (realm-boundary law).

## ADD / NOT / KEEP

- **ADD:** observer service, scheduled sync, portal tab, memory ingest.
- **NOT:** edits or syncing changes back into command/firstmate.
- **KEEP:** reuse over rebuild — command-factory & firstmate stay the owners of their domains.