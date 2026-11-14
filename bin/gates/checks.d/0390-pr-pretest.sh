# pr-pretest — a REAL npm install of the publish artifact, when this run is asked to pay for it.
#
# The publish pretest is no longer a per-push gate (the Allfather, 2026-11-04: *"stop testing the
# npm installation on every push"*). It packs the real tarball, installs it in a sandbox and boots
# the apps — minutes of work that proved NOTHING about a change that cannot affect the artifact,
# and its cost made every push slow enough to invite the override that this house has learned to
# distrust. It has its own door now: .github/workflows/npm-pretest.yml, run by hand or when the
# artifact's own inputs change (package.json · the app build · the hull), and
# `bin/forge/npm/pr-pretest.sh` locally before a release. Set YMIR_PRETEST_ON_PUSH=1 to run it here
# as before.
if [ "${YMIR_PRETEST_ON_PUSH:-0}" = 1 ]; then
  gate pr-pretest  "a REAL npm install of the publish artifact" bash "$ROOT/bin/forge/npm/npm-pretest.sh local"
else
  printf '  "%s","SKIP","%s"\n' pr-pretest "the publish artifact is proved by .github/workflows/npm-pretest.yml (set YMIR_PRETEST_ON_PUSH=1 to run it here)"
fi
