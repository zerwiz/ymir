# Plan 06 — Yggdrasil Worktrees

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

Zero-collision parallel work: one worktree per task.

## Scope

`bin/yggdrasil.sh` create/list/status/merge/cleanup; `.yggdrasil/<id>/`.

## Done when

create is collision-free; merge is explicit; cleanup is safe.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
