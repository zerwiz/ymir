## runtime · unversioned · 2026-09-23 — the digest can see its own records

### Why
Every session opened with a lie:

```
Operator: ABSENT — no data/operator.md
Projects: ABSENT — no data/projects.md
Learnings: ABSENT — no data/learnings.md
```

The files were **not** absent. They lived in `$YMIR_HOME/hodd/data/`, the shelf
`bin/hoard-lib.sh` serves. The digest read `$BROKK_HOME/data` — **the code tree**,
where no operator record has ever been. So the Allfather was told his own profile
was missing at every session start, and a fresh hand had no bearings.

`CONFIG` had the same shape (`$BROKK_HOME/config`), and `STATE` defaulted to
`$BROKK_HOME/state` rather than the hoard.

### Fix
- **`bin/saga-session-start.sh`** resolves `STATE`, `DATA` and `CONFIG` through
  `bin/hoard-lib.sh` — the same order of authority every other tool uses — with
  the `BROKK_*_OVERRIDE` env vars still winning, and a fallback to the old
  tree path only when the lib is absent.

### A mistake of mine, recorded
Earlier in the same session I created `operator.md`, `projects.md` and
`learnings.md` under **`$YMIR_HOME/data/`** — a third shelf, neither the tree nor
the hoard. They were duplicates of files that already existed in
`hodd/data/`, and my `operator.md` carried an **error** (`machine: omarchy` — this
box is heimdall, a fact I got wrong once already). The duplicates were removed and
parked under `$YMIR_HOME/state/stale-misplaced-data-*/`; the canonical files are
untouched. The well lessons my copy summarised need no second home — the well
(`hodd/memory/kaia.engram`) is theirs.

### Verification
- `bash -n` clean.
- The resolved paths now exist:
  `DATA=/home/heimdall/Documents/ymirhome/hodd/data` with `operator.md` (2810 B),
  `projects.md` (699 B) and `learnings.md` (4235 B) present.
- `HOOD.md` is genuinely absent for the `work` realm — reported honestly, not a
  path bug.

### Files
- `bin/saga-session-start.sh`
