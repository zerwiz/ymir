# Plan 07 — Utgard Sandbox

- **Status:** active · **Realm:** platform · **Owner:** Brokk
- **Source:** `docs/masterplan.md`, `docs/Architecture.md`, this plan index.

## Objective

Seal untrusted execution: no root, no network, capped.

## Scope

`bin/utgard.sh`; `.agents/sandbox/Dockerfile.utgard`; network-none, cpus/mem/timeout, read-only rootfs.

## Done when

A failed run leaves no trace, and network/root are refused.

## Notes

Reference draft. Authoritative decisions live in `docs/masterplan.md` (forge orders)
and `docs/append-only-log.md`; this file routes, it does not decide.
