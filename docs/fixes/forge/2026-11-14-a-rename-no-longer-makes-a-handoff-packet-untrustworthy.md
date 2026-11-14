# forge · 2026-11-14 — a rename no longer makes a handoff packet untrustworthy

**Component:** forge · **Branch:** `eindri/hall-follow` (found while delivering plan 275's items)
**Files:** `bin/forge/handoff-packet.py`

## Why

`handoff-packet write` derived its `changed` list from `git diff --numstat`, where git writes
a rename as `dir/{old => new}` in the path column — one path, half of it prose. `handoff-packet
check` compared that list with `git diff --name-only`, which names only the NEW path. So a
branch whose diff carried any rename produced a packet that was **both** "understated" and
"overstated" at the same moment, and no packet for that branch could ever be trusted:

```
"changed","understated — the diff carries 1 path(s) the packet omits: …/index-CClcEKMB.js"
"changed","overstated — the packet claims 1 path(s) the diff does not touch: …/{index-BL-0c9PA.js => index-CClcEKMB.js}"
```

Measured on 2026-11-14 on a branch that rebuilt a dist asset (a rename git detected by
similarity). A rename is ordinary — a rebuilt bundle, a moved module, a plan file given its
proper name — so this refused the road for ordinary work, not for a mistake.

## What changed

Both diffs are now taken with `--no-renames`. A move then appears as the delete and the add it
really is, and every path in the packet compares literally with the path in the diff.

## How it was proved

```
python3 -c "import ast; ast.parse(open('bin/forge/handoff-packet.py').read())"   → parses
handoff-packet write hall-follow … (a branch carrying a dist rename)             → written
handoff-packet check hall-follow --fetched <head>                                → see the branch's report
```

## Not done, named

- **The rename is not re-detected for a human reader.** The packet lists a delete and an add
  where a reviewer might expect "renamed". That is the honest shape for a checker, and the diff
  itself still shows `git mv` as a rename.

## CHANGE LOG

- 2026-11-14 — `--no-renames` on both the packet's diff and the checker's, so a rename cannot
  make a packet self-contradictory.
