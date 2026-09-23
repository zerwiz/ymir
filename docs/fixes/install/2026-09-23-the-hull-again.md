# install · 2026-09-23 — the hull, again (the pretest's first catch)

## Why
The four-portals manifest fold (02ca2f5) rewrote package.json and DROPPED the
files[] `tools/` entry #125 had added. The regression would have sailed: a
publish from that tree ships a tool-less tarball. The new npm-pretest gate
(also in this PR) caught it in the sandbox BEFORE any publish — exactly the
decree's job.

## What
- `package.json` files[] re-gains `tools/` (+ the node_modules/__pycache__/pyc
  exclusions).
- `bin/npm-pretest.sh` — the pre-publish gate: pack → the hull inside the
  tarball → sandbox install → smokes (bins 100+, ymir.js answers,
  essence-fetch heals, fleet servers present) on THIS seat and on heimdall
  (the remote leg). PRETEST FAIL, and nothing sails.

## Files
- `package.json` · `bin/npm-pretest.sh`
