## records · 2026-11-14 — the running inventory is brought up to current main, and the plans route stops guessing the home

### Why

PR #745 (`feat/running-inventory`) was **BEHIND** main, and its push was refused by `defaults-guard`.

### The merge

`git merge origin/main` into the branch — a merge, never a rebase and never a force-push. It merged **cleanly**: no
file conflicted. `bin/records/running-inventory.sh` is a generated inventory and was not touched by hand.

### The ward that refused the push

Two of the branch's own new doors carried a second knowledge of where the home lives:

```
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"     # running-inventory.sh, nornir-job-agnostic-audit.sh
```

Both now resolve the home through `bin/vault/hoard-lib.sh` (`ymir_home_root`), as `bin/records/atlas.sh` does, and a
home that cannot be resolved fails loudly with `exit 2` instead of silently addressing `/hodd/...`.

The guard also named one more file, `apps/hlidskjalf/server/index.ts`, which this branch does not author: its plans
route called `homedir()` and then restated `Documents/ymirhome`, so a seat on another machine would read a ledger
path that does not exist. The file already resolves the home once, in `HOME_DIR` (env → the recorded choice → the
one default); the route now uses it:

```ts
const dir = process.env.YMIR_PLANS_DIR ?? join(HOME_DIR, 'svartalfaheim/whynotproductions/projects/ymir/plans');
```

That line is a fault **in main as well** (measured: `defaults-guard.sh check apps/hlidskjalf/server/index.ts` on main
names line 2604), so this branch carries the mend rather than passing the fault along.

### How it was proved

`bash -n` is clean on both shell files, every `defaults-guard` section now answers `"none"` for this push's changed
path set, and the `Documents/ymirhome` literal survives in `index.ts` only inside the resolver's own one-default
fallback and this explanation. No build was run: this machine has 11 GB and the change is a type-checked call
replacement, not new surface.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #765
