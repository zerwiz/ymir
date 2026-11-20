# install · 2026-09-24 — the PR-time real npm install gate

## Why
The Allfather's law: when PRs are made, we must do REAL npm installations
locally for testing, so the updates work when they are pushed to npm later.
Without it, a merged change can sit unverified in the publish pipeline and the
shelf's next version ships blind.

## What
- `bin/pr-pretest.sh` — the PR-time gate. It packs the exact publish artifact,
  runs a genuine `npm install <tarball>` into a fresh sandbox prefix, and
  smokes the installed essence (bin tools, `ymir.js --version`, the hull
  files, the desktop resolver shape over the packaged tree). Exit 0 = PRETEST
  PASS and out comes the one proof line for the PR body; exit 1 = FAIL, no PR
  until the pack mends.
- `--body` prints the proof block to paste under the PR description.
- `bin/npm-pretest.sh` (the fuller gate) still owns the remote-seat legs before
  an actual publish; `pr-pretest.sh` is the local door every PR walks through.
- Documented in the owning Galdr asset (`installation.md`, Validation).

## Files
- `bin/pr-pretest.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`