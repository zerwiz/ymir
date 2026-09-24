# install · 2026-09-24 — pr-pretest RUNS when invoked bare

## Why
Two small shape bugs surfaced the moment the gate ran for real:
1. `case "${1-}"` matched `""` (no args) to the help branch, so `bin/pr-pretest.sh`
   with no flags printed usage instead of running — the default must RUN.
2. The `bin/npm-pretest.sh` readiness test required `-x`, but the pretest is
   invoked with `bash` and carries no exec bit in the tree — the gate refused
   its own engine.

## What
- The help branch matches only `-h|--help`; bare invocation runs the gate.
- The readiness test reads the pretest (`-r`) instead of demanding the exec bit.

## Verified
- `bin/pr-pretest.sh` ran bare: **PRETEST PASS** — a real `npm install` of the
  packed `zerwiz-ymir-0.1.52.tgz` into a fresh sandbox, the installed essence
  smoked (bin tools, ymir.js --version, hull, desktop resolver shapes).

## Files
- `bin/pr-pretest.sh`