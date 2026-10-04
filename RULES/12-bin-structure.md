# Rule 12 — `bin/` has a shape: one folder per system, and nothing loose

> Adopted 2026-10-03, after an attempted restructure silently collapsed the capability register
> from 437 door rows to 2.

## The law

1. **Every door lives under a system folder.** `bin/<system>/<verb>.sh` — never `bin/<verb>.sh`
   for anything new.
2. **`bin/` root is an ENGINE, not a drawer.** Only these may sit loose, because they are what
   boots and supervises everything else:
   `ymir-engine.sh · ymir-install.sh · ymir-start.sh · ymir-stop.sh · verify-seat.sh · (and the
   two runtime entry points the engine itself calls)`.
   That list is **short on purpose** — if it grows, the structure is failing.
3. **A door that moves keeps its name and its behaviour.** A move is a relocation, never a
   rewrite. Every caller is repointed in the same commit as the move.
4. **A door may never resolve the repo by counting `..`.** Root is found by walking UP to the
   marker (`.pi/` + `RULES/`), because depth must not be able to blind the index.
5. **The register and the inventory must see every door at every depth**, and their `--check` is
   the proof — not an assertion that the move was tidy.

## Why, in one sentence

**398 doors in one directory is not a library, it is a drawer nobody can open** — and the cost is
not tidiness, it is that no one can tell which file does what without opening all 398.

## The failure this rule exists to prevent

An attempted move (`bin/capabilities.sh` → `bin/doors/capabilities.sh`) rendered a register with
**2 rows instead of 437**. Cause: `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` — one
level up from the script. Nested, it resolved `ROOT` to `bin/`, then searched for `bin/*.sh`
*inside* `bin/bin/`, found nothing, and reported a healthy-looking empty index.

> **A generator that resolves its own location by depth can be blinded by a folder.**
> Fix the resolver *first*; move second. Anything else is a coin toss with a 437-row index.

## Enforcement

- `bin/bin-shape-check.sh` fails when a **new** door appears loose in `bin/`, or when a system
  folder contains no door.
- The capability register's `--check` fails if the door count drops **without** the change being a
  recorded move — a silent collapse can never again look like a clean run.

## Append-only

Corrections are new entries here citing the old one. This rule is not rewritten in place.