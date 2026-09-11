# Plan 08 — Sub-Agent Fleet (Eindri)

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

Spawn, brief, and supervise isolated workers.

## Scope

`bin/einherjar-spawn.sh`, `bin/erindi-brief.sh`, `bin/vor-crew-state.sh`; Utgard + Yggdrasil.

## Done when

An Eindri runs isolated and reports state; nothing leaks to main.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
