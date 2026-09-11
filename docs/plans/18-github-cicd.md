# Plan 18 — GitHub CI/CD & Deployments

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

CI gates and zero-trust deployments.

## Scope

`ymir-*` workflows; `gh secret` sync; deploy workflows; drift guard.

## Done when

CI runs on push/PR; deploys never leak secrets.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
