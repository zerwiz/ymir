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
store="${YMIR_HOME:-$HOME/Documents/ymirhome}/hodd/state/gate-verdicts"
mkdir -p "$store"

# 1 · is MAIN green? Read from the verdict store, not from a fresh 7-minute run: one sha, one verdict. `--live` runs
# the gate now instead, for when the store is empty and someone must be told the truth the slow way.
main_sha=$(git -C "$ROOT" rev-parse origin/main 2>/dev/null | cut -c1-40)
main_verdict=$(grep -h "${main_sha:0:8}" "$store"/*.txt 2>/dev/null | tail -1)
main_green=no
case "$main_verdict" in *PASS*) main_green=yes ;; esac
if [ "${LIVE_GATE:-0}" = "1" ] && [ -f "$ROOT/bin/gates/ci-verify.sh" ]; then
  timeout 900 bash "$ROOT/bin/gates/ci-verify.sh" >/tmp/mv-ci.out 2>&1 && main_green=yes || main_green=no
fi
if [ "$main_green" = yes ]; then
  say "main ${main_sha:0:8}: green (recorded)"
else
  say "main ${main_sha:0:8}: RED or no verdict recorded"
fi

# 2 · head sha and its verdict
head=$(gh pr view "$pr" --json headRefOid,headRefName,isDraft,mergeable --jq '.headRefOid' 2>/dev/null)
[ -z "$head" ] && { say "cannot read PR $pr — NO"; exit 2; }
draft=$(gh pr view "$pr" --json isDraft --jq '.isDraft' 2>/dev/null)
[ "$draft" = "true" ] && { say "PR $pr is a draft — NO"; exit 1; }

# the verdict store: a PASS line naming this sha, written by whoever ran the gate on it
short="${head:0:8}"
if grep -qs "$short" "$store"/*.txt 2>/dev/null; then
  # the LAST line for this sha wins: a correction is appended, never rewritten (the store is a ledger)
  # the VERDICT is the third field, never a word anywhere in the line: a correction that says
  # "my earlier PASS was wrong" contains the word PASS and was read as a pass (found 2026-11-14 on #750).
  vtoken=$(grep -h "$short" "$store"/*.txt 2>/dev/null | sort | tail -1 | awk '{print $3}')
  case "$vtoken" in PASS) say "head $short: PASS (recorded)" ;; *)
    say "head $short: recorded verdict is ${vtoken:-none} — NO"; exit 1 ;;
  esac
else
  say "head $short: NO VERDICT RECORDED"
  say "verdict: NO — run the gate on that sha and record it first (bin/gates/ci-verify.sh · record with gate-verdict.sh)"
  exit 1
fi

# 2b · the stop-the-line exception: while main is red, ONLY the PR that carries main's repair may merge — and only
# with a verdict of its own. Nothing else rides in behind a green main that has not arrived yet.
if [ "$main_green" != yes ]; then
  branch=$(gh pr view "$pr" --json headRefName --jq '.headRefName' 2>/dev/null)
  case "$branch" in
    *main-gate-green*|*main-green*) say "main is red: this PR is the repair, so it goes first — its own verdict decides" ;;
    *) say "verdict: NO — main is red; only the repair of main may merge, and this is $branch"; exit 1 ;;
  esac
fi

# 3 · current with main
merge_state=$(gh pr view "$pr" --json mergeable --jq '.mergeable' 2>/dev/null)
case "$merge_state" in
  MERGEABLE) : ;;
  UNKNOWN)   say "mergeability is still being computed by GitHub — ask again in a moment (NOT a yes)" ; exit 2 ;;
  CONFLICTING) say "branch conflicts with main — NO (rebase it, then re-gate)"; exit 1 ;;
  *)         say "branch is not mergeable (${merge_state:-unreadable}) — NO"; exit 1 ;;
esac

# 4 · no bypass claimed
body=$(gh pr view "$pr" --json body --jq '.body' 2>/dev/null)
if printf '%s' "$body" | grep -qE 'YMIR_SKIP_[A-Z_]+' && ! printf '%s' "$body" | grep -qiE 'because|reason'; then
  say "a YMIR_SKIP_* is named with no reason in the body — NO"; exit 1
fi

say "verdict: YES — main green · head verdict PASS · current · no unexplained bypass"
exit 0
