# Plan 23 — Ymir Runtime Observer (self-observation)

- **Status:** proposed · **Realm:** platform · **Owner:** Brokk
- **Context:** Ymir observes its **own** runtime. The former read-only bridge
  into `~/command` is retired — Ymir carries no connection to the external
  `command` tree. The observer reads only Ymir's own files (plus the external
  worktree root, strictly read-only).

## Objective

A read-only observer that turns Ymir's own runtime state into a Rune stream:
forge orders, the agent roster, the well, the ledger, and Smíðja runs. It never
writes the runtime — the only outputs are `state/observer.log` and Runes.

## What Ymir observes

| Source | Signal |
|---|---|
| `docs/masterplan.md` | open / working forge orders |
| `.agents/agents/*.md` | the agent roster |
| `.agents/memory/well/` | the well (episodes) |
| `workspace/memory/runes_audit.md` | the ledger |
| `smidja/smidja_data/smidja.db` | Smíðja runs (read-only SQLite URI) |
| `~/.treehouse` | external worktree dirs (read-only) |

## Mechanics

- `bin/nornir-job-observer.sh` (Huginn) runs on the Nornir schedule (06:00, plan 24).
- Every observation is carved as a Rune line (`huginn / observer.<source>`); an
  absent source carves an explicit `ABSENT` line.
- Hlidskjalf surfaces the stream (Runes gate, Processes, Cron).
- **Never write outside `state/` and the Runes ledger.**
- Full service (episodes into the well, A2A port) = W0086.

## ADD / NOT / KEEP

- **ADD:** self-observation sources, Runes lines, Hlidskjalf surfacing.
- **NOT:** any dependency on, or write into, `~/command`.
- **KEEP:** Ymir owns its own runtime; the external worktree root stays read-only.
