# desktop · 2026-11-14 — the desktop answers' row had two owners for one hour

## Files

- `.agents/home-contract.yaml` — one `config/desktop.env` row, the earlier one

## Why

The row for `config/desktop.env` was reported missing by `home-contract-check` on this machine's stale base. Two
hands then wrote it in the same hour: upstream, as `kind: seeded` with `bin/engine/home-seed.sh` as its door, and this
branch, as `kind: defaulted` with no door. Rebuilt on `origin/main` and cherry-picked, the branch carried **both** —
and the contract's own rule is *one file, one row*:

```
"the same home file is claimed twice","config/desktop.env","one file, one row"
```

## Fix

- The branch's row is dropped. Upstream's stands: it is `seeded`, so the shape is copied into a fresh home once and
  never overwritten, which is what an operator's own answers deserve. Dropping mine keeps the later behaviour and
  removes the duplicate.
- `home-contract-check`: clean — 60 rows, every template shipped, every door standing, the package carrying them.

## Verified

- `bash bin/gates/checks/home-contract-check.sh` → `60 rows · 0 findings · clean`.
- `grep -c "  - path: config/desktop.env" .agents/home-contract.yaml` → `1`.

## CHANGE LOG

- **2026-11-14** — note rewritten after the branch was rebuilt on `origin/main`: the row this branch added was
  already upstream's by then, so the note records the duplicate and its removal instead of an addition that no
  longer exists.
