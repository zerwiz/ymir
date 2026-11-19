## sessrumnir · 2026-11-19 — the coding tool leaves for its own repo, its fork contract restored

### Why
The Allfather: *"time to separate the mono repo"*, *"i dont wanna them come into the apps folder anymore if installed
they need their own places"*, *"we can not lose anything"*, *"do both then pr"* (plan 05).

### What moved
`apps/sessrumnir/` (412 files) → `zerwiz/sessrumnir`, cut with `git filter-repo --subdirectory-filter`: every one of the
80 commits that touched it here, authors and dates kept. It locks its own dependencies now (`package-lock.json`, 767
entries). In Ymir it was a workspace member, and its 514 packages leave Ymir's root lock (852 → 338 entries), listed in
`config/split/sessrumnir.lock-left.txt`. The pi-desktop attribution stays in `NOTICE` and `THIRD-PARTY-LICENSES`, each
with an appended note; the app repo carries the upstream licence at its root.

### Lost in September, found and restored
The fork's contract — `fork/owned.json`, `fork/PIN`, `fork/mods.patch` — was lost in the first app split (`81159aa47`,
2026-09-17) and did not come back with the fold-in two days later. From then on the upstream sync could only fail with
"owned.json missing". It is restored, unchanged, from `81159aa47^`; all 12 files it names still exist. Running the sync's
dry run against pi-desktop's head then exposed three more faults, each unseen while the contract was missing:
- `--check` declared a `local` outside any function, so bash refused it;
- it grepped rsync's itemised lines without asking for them (`--itemize-changes`), so it always listed nothing;
- `owned.json` still named September's files, so **a real sync would have deleted every Ymir addition since** (the app
  contract, `themes/`, `public/`, the width probe, the bottom-anchored scroll) **and overwritten `install.sh`**, which
  upstream also ships. 15 paths are owned now. The dry run lists 0 deletions.

The app syncs its own checkout with `scripts/sync-upstream.sh`; Ymir keeps `bin/desktop/sessrumnir-sync.sh` (fixed the same way).

### The contract
`install.sh` now builds in place for Ymir's `apps.sh` (deps, Electron, `node-pty` built for it, the build). Its `--check`
refuses a window that does not name itself Sessrúmnir — fault 5 of 2026-09-18, when the fork renamed itself "Pi
Desktop". Piped from curl it hands over to `scripts/quick-install.sh` (the old `install.sh`), which now downloads from the
app's own releases. Also `start.sh`, `stop.sh` (which closes by the release's own Electron binary: the first version
missed its own process), `activate.sh` (the launcher), `uninstall.sh` (never `~/.config/sessrumnir`) and `app.yaml`.

### Ymir's side
**`step_apps` would have cloned every moved app back into `apps/` the moment Sessrúmnir left** (its in-tree shortcut
required `apps/sessrumnir`); it now never clones an app with its own repo, in the shortcut and in the clone loop over the
home's registry. The seat wire's web raiser and `valknut-load`'s permissions file are found through the resolver; the
release builds it only while it is in the tree; the icon tool and the desktop-class and window tests read it wherever it
is. Ymir's launcher (`sessrumnir-launch.sh`) and installer (`sessrumnir-ensure.sh`) already found it through `app_dir`,
so they follow it into its home unchanged. Kept lines are in `config/split/sessrumnir.kept.tsv`. The registry:
`contract: 1`, `moved: zerwiz/sessrumnir@<sha>`, `install_default: dev`.

### Proof
- `split-ledger.py verify sessrumnir`: 412/412 files, 80/80 commits, 37/37 fix notes, 0 ties owed — **nothing lost**.
- The live store (`~/.config/sessrumnir`, 3,775 entries) snapshotted before and after: **the same**.
- From the cut repo into a fenced apps home: install (npm ci from its own lock, Electron v43.8.9, `node-pty` built), `--check`
  green, flipped, launcher seated (`ymir-app sessrumnir`).
- The installed window opened (with a fenced config folder) and mapped as class `ymir-sessrumnir`, title *Sessrúmnir*;
  DevTools answered with the page *Sessrúmnir*; `stop.sh` closed all of its processes.
- The cut is reproducible: the finalize step gives the same head twice (`133a42991a0c`).

### Found and left
`bin/desktop/tests/test_sessrumnir_stays.sh` fails on main too ("no launcher line"); untouched here, owed as its own fix.
The machine's npm refuses remote tarball fetches (`EALLOWREMOTE`), and one optional Tailwind package needs one; the lock
was generated with `--allow-remote=all` for that run.
