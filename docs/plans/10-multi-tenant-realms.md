# Plan 10 — Multi-Tenant Realms

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

Tenant isolation: realm-scoped dirs and secrets.

## Scope

`svartalfaheim/<realm>/`; `.env.realm`; realm routing; boundaries sacred.

## Done when

No realm reads or writes another without an explicit grant.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
