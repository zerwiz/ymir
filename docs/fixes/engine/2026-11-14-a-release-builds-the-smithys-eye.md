# A release builds the smithy's eye, and its proof says whether it did

**Date:** 2026-11-14 · **Component:** engine (`bin/engine/release.sh`) · **Errand:** `out-of-git`
(plan 288 step 7, plan 287 P4)

## What was wrong

The Smíðja visualizer is a **nested** app: `apps/smidja-factory/apps/visualizer`, with its own
`bun.lock`, blurb that no root `npm ci` ever installs. `bin/engine/release.sh build` built Hlidskjalf,
Óðrerir, Sessrúmnir and Bilskirnir inside the release and never touched it — so a release served
`:8437` with no interface at all ("No ./dist build found"), and nothing said so: `prove()` judged five
apps and the visualizer was not one of them.

The fault was invisible because the tree carried a **committed** `dist/`. A checkout served a
bundle; a release could not, and no gate compared the two. Removing the bundle from git
(`docs/fixes/smidja/2026-11-14-the-visualizer-bundle-leaves-git.md`) is what made the hole show.

## The fix

- **The release builds it.** After Bilskirnir's web surface, `build` runs
  `bun install --frozen-lockfile && bunx vite build` in the nested folder. A build failure stops the
  release (exit 19) — a release whose interface silently vanished is the 2026-09-23 fault again.
  Where `bun` is absent the build says so in one line and the proof row reports a **skip**, never a
  green.
- **The proof judges it.** `prove()` gained a sixth row for the visualizer with three honest states:
  `ok` (built inside the release), `FAIL` (no bundle **and** bun present — the build was skipped, not
  impossible), `skip` (no bundle and no bun, with the reason). The row count in the TOON header is
  computed, not hardcoded.

## How the fault was found, and how it is proved

```
# the release built before this change proves the hole
bin/engine/release.sh prove ~/.local/share/ymir/releases/2baf10ff28c5
#   "visualizer","FAIL","not built (no dist/index.html) — bun is present, …"    rc=1
#   and `ls <release>/apps/smidja-factory/apps/visualizer/` → no dist/

# after: a fresh release from the branch that carries this fix
bin/engine/release.sh build --ref eindri/out-of-git
#   "visualizer","ok","UI built in the release (served on :8437)"
```

The release's own server is then raised and the page is read through DevTools — the measurement,
with the port and the body, is in the errand's report
(`$YMIR_HOME/state/eindri-reports/out-of-git.md`).

## What this does not change

- **The install still builds it too** (`step_smidja`), and the npm prepack still builds it
  (`bin/desktop/app-build.sh`). Three doors, one build command each, and none of them ships a
  committed copy.
- **No new dependency.** `bun` was already a prerequisite of the smithy's UI and of
  `bin/engine/release-build.sh`, which has built this app since it was added.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #755
