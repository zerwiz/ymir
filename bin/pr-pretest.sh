#!/usr/bin/env bash
# pr-pretest.sh — the PR-time gate: a REAL npm installation, locally, before
# the pull request ever opens. (2026-09-24, the Allfather's law: "when PRs are
# made we need to do real npm installations locally for testing so our updates
# will work when we're pushing to npm later on.")
#
# `bin/npm-pretest.sh` packs the exact publish artifact and sandbox-installs it
# with a REAL `npm install <tarball>` into a fresh prefix, then smokes the
# installed essence (bin tools, ymir.js --version, the hull files, and the
# desktop resolver shape over the packaged tree). This wrapper is the PR gate
# that REQUIRES that local leg — no remote seats, no network promises — and
# prints the one line to paste into the PR body as the proof.
#
# Usage:
#   bin/pr-pretest.sh           # run the real local npm install test
#   bin/pr-pretest.sh --body    # print the PR-body proof block (after a pass)
#   bin/pr-pretest.sh --version
#
# Exit: 0 = PRETEST PASS (a real install of the tarball this tree packs,
#       installed and smokes); 1 = FAIL — do not open the PR, mend the pack.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LOG="$(mktemp /tmp/pr-pretest-XXXXXX.log)"
trap 'rm -f "$LOG"' EXIT

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --body)
    # The proof block for the PR body — a PASS line already exists meaning the
    # real installation happened on THIS tree, with the tarball's own name set.
    printf '%s\n' \
      '## The real npm install gate (pr-pretest)' \
      'A real local npm installation of the tarball this tree packs was run and smoked:' \
      "  \`NPM_PRETEST_SKIP_REMOTE=1 bin/pr-pretest.sh\` → \`PRETEST PASS\`"
    exit 0
    ;;
esac

[ -x "$ROOT/bin/npm-pretest.sh" ] || { printf 'pr-pretest[1]{gate,state}:\n  "fail","no bin/npm-pretest.sh in this tree"\n' >&2; exit 1; }

# The real local npm installation: pack the exact artifact, sandbox-install with
# a genuine `npm install <tarball>`, and smoke the installed essence. Remote
# seats are the pretest's own separate leg; the PR gate is the LOCAL truth.
if NPM_PRETEST_SKIP_REMOTE=1 bash "$ROOT/bin/npm-pretest.sh" local >"$LOG" 2>&1; then
  printf 'pr-pretest[1]{gate,state,tarball}:\n  "pass","real npm install + smoke","%s"\n' \
    "$(grep -oE 'zerwiz-ymir-[0-9.]+\.tgz' "$LOG" | head -1)"
  printf 'PRETEST PASS — a real local npm installation of this tree''s tarball installed and smokes.\n'
  printf 'proof: paste `NPM_PRETEST_SKIP_REMOTE=1 bin/pr-pretest.sh` → PRETEST PASS into the PR body.\n'
  exit 0
fi

printf 'pr-pretest[1]{gate,state}:\n  "fail","the real npm install did not pass — see:%s"\n' "$LOG" >&2
printf '%s\n' 'PRETEST FAIL — do not open the pull request; mend the pack (bin/npm-pretest.sh names the wound).' >&2
tail -8 "$LOG" >&2
exit 1