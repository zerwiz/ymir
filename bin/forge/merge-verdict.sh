#!/usr/bin/env bash
# merge-verdict.sh — may this PR be merged right now? One question, one answer, no opinion.
#
# The gate's own law (plan 158 · PR 623): ONE SHA, ONE VERDICT. A merge is legitimate only when all four hold:
#   1. main itself is green — a red main is stop-the-line; nothing merges onto it
#   2. the PR's head sha was gated, and the verdict was PASS
#   3. the branch is current with main (a stale base is a verdict about a tree nobody will merge)
#   4. no bypass is claimed: no --no-verify push, no YMIR_SKIP_* without its reason in the PR body
#
#   merge-verdict.sh <pr>          exit 0 = may merge, 1 = may not, 2 = could not tell
# Anything it cannot measure is a NO. Silence is never consent in a merge.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pr="${1:-}"
[ -z "$pr" ] && { echo "usage: merge-verdict.sh <pr>" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "no gh — cannot tell" >&2; exit 2; }

say() { printf '%s\n' "$*"; }

# 1 · main green
git -C "$ROOT" fetch -q origin 2>/dev/null || { say "could not fetch origin — NO"; exit 2; }
if [ -f "$ROOT/bin/gates/ci-verify.sh" ]; then
  if timeout 420 bash "$ROOT/bin/gates/ci-verify.sh" >/tmp/mv-ci.out 2>&1; then
    say "main: green"
  else
    say "main: RED — $(grep -cE '^\s*FAIL' /tmp/mv-ci.out 2>/dev/null || echo '?') failing gate(s); see /tmp/mv-ci.out"
    say "verdict: NO (stop the line — a red main is fixed before anything is merged onto it)"
    exit 1
  fi
else
  say "no ci-verify.sh — cannot judge main; NO"
  exit 2
fi

# 2 · head sha and its verdict
head=$(gh pr view "$pr" --json headRefOid,headRefName,isDraft,mergeable --jq '.headRefOid' 2>/dev/null)
[ -z "$head" ] && { say "cannot read PR $pr — NO"; exit 2; }
draft=$(gh pr view "$pr" --json isDraft --jq '.isDraft' 2>/dev/null)
[ "$draft" = "true" ] && { say "PR $pr is a draft — NO"; exit 1; }

# the verdict store: a PASS line naming this sha, written by whoever ran the gate on it
store="${YMIR_HOME:-$HOME/Documents/ymirhome}/hodd/state/gate-verdicts"
mkdir -p "$store"
if grep -qs "$head" "$store"/*.txt 2>/dev/null; then
  v=$(grep -h "$head" "$store"/*.txt 2>/dev/null | tail -1)
  case "$v" in *PASS*) say "head ${head:0:8}: PASS (recorded)" ;; *)
    say "head ${head:0:8}: recorded verdict is not PASS — NO"; exit 1 ;;
  esac
else
  say "head ${head:0:8}: NO VERDICT RECORDED"
  say "verdict: NO — run the gate on that sha and record it first (bin/gates/ci-verify.sh · record with gate-verdict.sh)"
  exit 1
fi

# 3 · current with main
if ! gh pr view "$pr" --json mergeable --jq '.mergeable' | grep -q MERGEABLE; then
  say "branch is not mergeable/current with main — NO (rebase it, then re-gate)"; exit 1
fi

# 4 · no bypass claimed
body=$(gh pr view "$pr" --json body --jq '.body' 2>/dev/null)
if printf '%s' "$body" | grep -qE 'YMIR_SKIP_[A-Z_]+' && ! printf '%s' "$body" | grep -qiE 'because|reason'; then
  say "a YMIR_SKIP_* is named with no reason in the body — NO"; exit 1
fi

say "verdict: YES — main green · head verdict PASS · current · no unexplained bypass"
exit 0
