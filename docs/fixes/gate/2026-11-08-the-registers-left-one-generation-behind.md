# gate · 2026-11-08 — the registers were left one generation behind by three merges

## What

After today's three merges onto `main` — Rödd (578), the private-guard binary-media fix (581) and the
kit/areas branch — a clean checkout of `main` failed its own wards:

```
inventory-guard[1]{finding,detail}:
  "STALE","bin/{forge,gates,seat,vault,voice}/INDEX.md disagree with the tree"
registers-guard: a register is stale — run bin/gates/registers.sh generate
```

Five shelfs drifted — `forge`, `gates`, `seat`, `vault`, `voice` — because each branch regenerated its own
registers and the merge order rewrote them again. Nothing in the code was wrong; the *record* of what exists
was one generation behind, which is the same shape of fault the inventory tree was built to prevent (plan 211:
a change in one folder rewrites one file instead of colliding on every branch).

## Why it matters

A register that is stale is a register nobody can trust, and a ward that fails on `main` trains people to
merge past a red gate. The fix belongs on `main` itself, immediately, not in a follow-up branch that drifts.

## Verified

- `bin/gates/inventory.sh` then `bin/gates/registers.sh generate` on a clean `origin/main` checkout.
- `inventory-guard` and `registers-guard` both **PASS** afterwards; the only diff is five `INDEX.md` files.
- nothing else in the tree changed: no behaviour, no document, no door.

## Not verified / owed

- Why the merge order loses a generation at all: the regeneration happens in the branch, and merging two
  regenerated files resolves by content rather than by re-weaving. The woven tree (plan 211) was meant to
  make this impossible; a merge-time re-weave is the honest next step, and it is not built.

## CHANGE LOG

- **2026-11-08** — written. The five stale registers, regenerated on `main`, with the underlying merge-order
  fault named rather than papered over.
