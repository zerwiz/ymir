# Plan 02 — Memory System (Hot + Vector)

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

The well: hot recall + vector memory, so the fleet drinks before it acts.

## Scope

engram/Mimirsbrunn bridge (:4602); `bin/mimir.sh` recall/observe/timeline; local well store `.agents/memory/well/`.

## Done when

Recall and observe work via the bridge, with a local fallback that never blocks.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
