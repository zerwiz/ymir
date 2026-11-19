## apps · 2026-11-19 — the split ledger: a script proves an app's move lost nothing

### Why
The Allfather, 2026-11-18: *"make great splitting plans for all this. we can not lose anything."* The September split
(`81159aa47`, undone two days later in `86e86bf87`) moved files and left the seams to chance. This one proves each move.

### What was built
`bin/apps/split-ledger.py` (plan 02), stdlib only, reading Ymir's own git:
- `inventory <app> [--ref]` — the before-set: every file (path · bytes · git blob · sha256), every commit that touched the
  app, its fix notes and feature pages, and every code line outside it that names its folder.
- `verify <app> --repo <app repo> [--app-ref] [--ref] [--moved FILE] [--after-removal]` — six checks: files (blob for
  blob, or declared in `moved.tsv` with a reason), history (author · date · subject of every commit), records (still in
  Ymir), features (listed for the acceptance run), state (its own verb), ties (no code still names `apps/<dir>` once it
  has left, the resolver's own tables excepted). Exit 1 on any loss.
- `state <app> --snapshot FILE` and `state --compare BEFORE AFTER` — files hashed, sqlite tables counted, jsonl lines
  counted; growth is allowed (an append-only file grows), loss is not.
- `bin/apps/app-path.sh --check` now calls a moved app that is not installed here `not-installed`, not missing: an app
  that left is installed by choice.

### Proof
Its first use is Hvergelmir's move (the next note): 380/380 files, 6/6 commits, 1/1 fix note, 0 ties after removal.
