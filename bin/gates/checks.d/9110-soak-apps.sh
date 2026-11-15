#!/usr/bin/env bash
# The publish pretest is no longer a per-push gate (the Allfather, 2026-11-04: *"stop testing the npm
# installation on every push"*). It packs the real tarball, installs it in a sandbox and boots the apps —
# minutes of work that proved NOTHING about a change that cannot affect the artifact, and its cost made
# every push slow enough to invite the override that this house has learned to distrust.
# It has its own door now: .github/workflows/npm-pretest.yml, run by hand or when the artifact's own inputs
# change (package.json · the app build · the hull), and `bin/forge/npm/pr-pretest.sh` locally before a
# release. Set YMIR_PRETEST_ON_PUSH=1 to run it here as before.
gate soak-apps  "an app this change touches stays inside the leak budgets (plan 286 P5)" \
     bash "$ROOT/bin/gates/soak-pr.sh"
