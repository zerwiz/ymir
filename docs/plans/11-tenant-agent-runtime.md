# Plan 11 — Tenant Agent Runtime

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

Per-user workers boot behind a tenant with context.

## Scope

Hermes profiles, `tenant_context_loader`, worktree + sandbox per worker.

## Done when

A tenant request spawns an isolated, context-loaded worker.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
