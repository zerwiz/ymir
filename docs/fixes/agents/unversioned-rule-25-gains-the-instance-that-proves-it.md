## agents · unversioned · 2026-10-18 — Rule 25 gains the instance that proves it

### Why

Rule 25 (*agnostic by construction*) was written on 2026-10-18 from that day's
wounds. The next day, the rule found its own instance from the other side: the
skill index shipped to heimdall with **192 absolute `/home/<seat>/…` paths**, so on
the second machine the finder resolved nothing, `--check` read it as incomplete
forever, and the home went dirty every session.

The law was already written; what was not written is **why a generated file is the
likeliest place to break it** — code is reviewed, and a derived artifact is read by
nobody and synced to everybody.

### Now

`RULES/25-agnostic-by-construction.md` is **appended** (never rewritten) with the
instance: what broke, on which machine, how it was mended (relative paths anchored
by the reader; the index untracked and gitignored in the home; `stat` probed; a test
that fails the build if a machine path reappears), and the sentence to carry
forward — *any file a machine generates for itself belongs to that machine: keep it
out of the shared tree, or keep it relative.*

### Verified

- `bin/gates/guards/rules-number-guard.sh` → clean — 25 rules, no duplicates, index agrees.
- `toon-check.py RULES/25-agnostic-by-construction.md` → the `agnostic_law` block PASS (8/8, 2 cols).
- `bin/gates/guards.sh` → **10 wards PASS**.
- The append is additive only: the file grows from 43 to 65 lines, nothing rewritten.

### Files

- `RULES/25-agnostic-by-construction.md`
