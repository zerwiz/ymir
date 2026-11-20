# install · 2026-09-24 — the pretest proves the apps are FULLY BOOTABLE

## Why
The Allfather's law, stamped critical: the apps must WORK and START — the
electrons above all. The pretest used to verify the packaged SHAPE (dirs
resolve, the resolver answers truthfully) but never proved a single app could
BOOT from the installed package: a merged change could publish a tarball whose
windows never open.

## What
`bin/npm-pretest.sh`'s local smoke now walks the launcher's own first-run road:
- The workspace-aware first-run install at the packaged root
  (`cd <package> && npm install` — the exact road `scripts/electron.sh` walks
  on a fresh package, the P3 law), which lands the hoisted electron runtimes.
- For **every surface** (hlidskjalf · smidja · odrerir · sessrumnir):
  the resolver (`electron_bin`) yields an **executable electron that answers
  `--version`** — the identical guard the launcher runs before it would exec a
  window — AND the web surface's built index stands (`dist/index.html`, or
  `out/main/index.js` for sessrumnir). One `app-boot` PASS row per surface.
- FAIL refuses the PR: a tarball that cannot boot never sails.

## Files
- `bin/npm-pretest.sh`
- `bin/pr-pretest.sh` (the gate wrapper now proves bootability too)
- `.agents/skills/galdr-ymirsystem/assets/installation.md`