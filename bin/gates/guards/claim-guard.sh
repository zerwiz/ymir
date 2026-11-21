#!/usr/bin/env bash
# claim-guard.sh — the push ward that reads the claims ledger (plan 343.14).
#
# A push to a branch another seat holds as CODER is refused, with the holder named. This is the
# #876 situation: two seats pushed rework commits to one branch and its own author could not
# fast-forward. The ledger (bin/agents/claim.sh, tracked in the home) says who holds what; this ward
# only asks it.
#
#   pre-push hook:  claim-guard.sh <remote-name> <remote-url>   (refs on stdin, as git sends them)
#
# Only the claim HOLDER's seat may push a claimed branch. An unclaimed branch, a deletion, and a
# branch held by THIS seat all pass; a STALE claim (no heartbeat for 2 h) is offered, so it passes.
# A ward that cannot read the ledger FAILS OPEN, loudly: the claim is a courtesy between seats, and an
# unreachable home must not stop an honest push (CI and branch-guard still judge it).
#
# Env: YMIR_SKIP_CLAIM_GUARD=1 (the loud override) · CLAIM_NO_SYNC=1 (read the local copy, no pull)
# Exit: 0 clear · 1 refused
set -u
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAIM="$SCRIPT_DIR/../../agents/claim.sh"
case "${1:-}" in -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; -v|-V|--version) echo 1.0.0; exit 0 ;; esac

if [ "${YMIR_SKIP_CLAIM_GUARD:-0}" = 1 ]; then
  echo "claim-guard: YMIR_SKIP_CLAIM_GUARD=1 — the claims ledger is NOT consulted for this push" >&2
  cat >/dev/null; exit 0
fi
[ -x "$CLAIM" ] || { cat >/dev/null; exit 0; }

remote="${1:-origin}"; url="${2:-}"
[ -n "$url" ] || url="$(git remote get-url "$remote" 2>/dev/null || true)"
slug="$(printf '%s' "$url" | sed -nE 's#^(https://|git@|ssh://git@)?github\.com[:/]([^/]+/[^/.]+)(\.git)?/?$#\2#p')"
if [ -z "$slug" ]; then cat >/dev/null; exit 0; fi   # not a GitHub remote: no key to ask about

ZERO=0000000000000000000000000000000000000000
refused=0
while read -r _lref lsha rref _rsha; do
  [ -n "${rref:-}" ] || continue
  [ "${lsha:-$ZERO}" = "$ZERO" ] && continue             # deleting a branch is not a push of work
  case "$rref" in refs/heads/*) ;; *) continue ;; esac
  branch="${rref#refs/heads/}"
  out="$("$CLAIM" check "branch:$slug:$branch" --role coder --sync 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" = 1 ]; then
    printf '⛔ claim-guard: %s is claimed by another seat — a push from this seat would collide.\n' "$branch" >&2
    printf '   %s\n' "$out" >&2
    printf 'help: ask the holder, or wait until its claim is released or goes stale (claim.sh show branch:%s:%s)\n' "$slug" "$branch" >&2
    printf 'help: YMIR_SKIP_CLAIM_GUARD=1 git push   is the loud override\n' >&2
    refused=1
  elif [ "$rc" -ge 2 ]; then
    printf 'claim-guard: could not read the claims ledger for %s (claim.sh exit %s) — failing open\n' "$branch" "$rc" >&2
  fi
done
[ "$refused" = 0 ] || exit 1
exit 0
