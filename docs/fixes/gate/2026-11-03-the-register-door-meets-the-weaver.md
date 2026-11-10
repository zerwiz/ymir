## gate · 2026-11-03 — the register door meets the weaver

### Why
PR #493 ("one door for every generated register") was cut before the Þættir weave
landed. Merging main brought two collisions of the same class this branch was built
to end: the capability register was stale after the merge, and the branch's own
feature page (`docs/features/one-door-for-the-registers.md`) had its catalogue row in
the old hand-kept `FEATURES.md` — a file the merge driver re-weaves from fragments,
so the row was dropped and the ward named it.

### Mend
- `bin/gates/registers.sh generate` — both registers regenerated through the branch's
  own door (inventory + capabilities), not by hand.
- The branch's catalogue row was recovered from its pre-merge `FEATURES.md` and seated
  as a fragment under `docs/features/_catalogue/entries/` — the collision-free unit —
  then woven (157 entries).
- No register or catalogue was hand-edited: both answers came from their generators.

### Proven
- `registers-guard`: inventory current · capabilities current.
- `features-guard`: every feature page catalogued, and the woven catalogue is current.

### The map gap the push found
`bin/gates/registers.sh` (this branch's own new door) and the woven catalogue
(`FEATURES.md`, `docs/features/*`) mapped to **no component**, so a correct note
could not cover the paths it described — the same defect the 2026-10-12 StartLimit
mend named. Both now map to `gate`: the register door and the features ward live in
the gate suite.

### The second fault the push found: a merge is not a change
The guard judged `git diff <remote>..HEAD`, so a branch that had **merged main** put
every path main brought into the range — two correct notes could not cover it. It now
judges the paths of **our own non-merge commits** (`git log --no-merges --name-only`):
main's history needs no note from a branch that took it in.

### A known disagreement, recorded
The installed pre-push hook and the guard itself disagreed on this push: run with the
same ref pair, `fixes-guard.sh` says *"ok — 3 note(s)"*; the hook says *"no fix note in
this range"*. The push was made with the loud override and this line as its reason.
The hook/guard mismatch is a follow-up (the hook's refs parsing, most likely), not a
missing note.

## CHANGE LOG

- **2026-11-09** — the note was carried into the integration branch whole, its history with it.
