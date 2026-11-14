# The smithy's built UI left git, and three doors build it instead

**Date:** 2026-11-14 · **Component:** smidja (`apps/smidja-factory/apps/visualizer/dist/`, `.gitignore`)
· **Errand:** `out-of-git` (plan 288 step 7, plan 287 P4)

## What was wrong

Seventy-two files under `apps/smidja-factory/apps/visualizer/dist/` were tracked in the public
repository: a Vite bundle, its CSS, forty font files, an SVG icon and a `models/` folder — 1.5 MB of
**build output** committed as if it were source. They were added on purpose in September 2026, for a
real reason: the npm tarball had shipped without its interface, so the un-ignore lines in
`.gitignore` were the fix of that day.

The bill for that fix: the committed bundle goes stale against its own source, every clone carries
it, and a reader cannot tell which of the 6,124 tracked files are the program and which are the
output of the program. Plan 288 §1 draws the line — **build output does not belong in the
repository** — and `package.json` has since grown an explicit `files` allowlist naming
`apps/smidja-factory/apps/visualizer/dist/**`, which a root `.gitignore` cannot override.

## The fix

- **Three doors build it, and they already did.** `bin/engine/release-build.sh` (`build_asset
  smidja-visualizer … bunx vite build`), `bin/desktop/app-build.sh` (the npm prepack, whose list
  names the nested visualizer), and the install's `step_smidja` (builds when `dist/` is absent).
  Nothing new was invented; git stopped shipping a copy of what they produce.
- **`.gitignore` says what it means.** The two `!…/dist/**` un-ignore lines are gone and
  `apps/smidja-factory/apps/visualizer/dist/` is ignored **by name**, with the history written above
  it: the 2026-09-23 fault (a tarball with no interface) and why the allowlist makes it impossible
  now.
- **The npm tarball still carries the bundle.** `package.json`'s `files` array names the path and its
  glob, and `bin/forge/npm/npm-pretest.sh` builds before it packs and refuses a tarball without
  `apps/smidja-factory/apps/visualizer/dist/index.html` (the hull entry). Proved below by a real
  `npm pack`.

## Recorded move (Rule 11)

No file was deleted. The bytes that left git are preserved in the operator's home, with a manifest
of every file (sha256 · bytes · path) and the command that rebuilds them:

```
$YMIR_HOME/hodd/reference/out-of-git-2026-11-14/smidja-visualizer-dist-4f5f6b13.tar.gz
$YMIR_HOME/hodd/reference/out-of-git-2026-11-14/smidja-visualizer-dist.manifest.txt
```

The guard's own escape logged the removal with its reason in
`$YMIR_HOME/hodd/memory/deleted-on-purpose.log`.

## How it was proved

```
# 1. a checkout with no dist/ builds it (the release does the same thing, from a clean clone)
cd apps/smidja-factory/apps/visualizer && bun install && bun run build
#    → 56 packages installed, "✓ built in 8.59s", dist/index.html present

# 2. the tarball still carries the interface
npm pack --dry-run --json | jq -r '.[0].files[].path' | grep 'visualizer/dist/index.html'

# 3. a fresh RELEASE builds it and Smíðja serves it
bin/engine/release.sh build --ref eindri/out-of-git
bin/engine/release.sh prove <release>
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8437/       # Smíðja's UI, from the release
```

The measured results are in the errand's report
(`$YMIR_HOME/state/eindri-reports/out-of-git.md`) — this note records the fault and the mend, not a
transcript.

## What this does not change

- **Nothing serves from a dev server.** A release builds every surface inside itself; that was
  already true and is untouched.
- **The visualizer's source is untouched.** Only its output left the index.
- **A machine that already has a tracked `dist/` keeps its working copy** — the removal was
  `git rm --cached`, so a local build keeps serving until the next build replaces it.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
