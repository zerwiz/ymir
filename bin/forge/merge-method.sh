#!/usr/bin/env bash
# merge-method.sh — which `gh pr merge` flag a pull request takes (RULES/08, batch road).
#
# A gathered batch (head branch `yggdrasil/gather-*`, or a body that says it was gathered by
# `bin/forge/gather.sh`) merges with a MERGE COMMIT, so each errand's history survives and git
# knows the branches are merged. Every other PR keeps --squash.
#
#   source bin/forge/merge-method.sh
#   merge_flag_for <head-ref> <body>      # pure: prints --merge or --squash
#   merge_flag_for_pr <pr> [repo]         # asks gh for the head and body; a failed ask is --squash
#
# Run directly:  merge-method.sh <pr> [repo]   prints the flag.
merge_flag_for() {
  local head="${1-}" body="${2-}"
  case "$head" in yggdrasil/gather-*|gather/*) printf '%s\n' --merge; return 0 ;; esac
  case "$body" in *'gathered by `bin/forge/gather.sh`'*) printf '%s\n' --merge; return 0 ;; esac
  printf '%s\n' --squash
}

merge_flag_for_pr() {
  local pr="${1:?pr number}" repo="${2-}" head body json
  if [ -n "$repo" ]; then json="$(gh pr view "$pr" -R "$repo" --json headRefName,body 2>/dev/null)" || json=""
  else json="$(gh pr view "$pr" --json headRefName,body 2>/dev/null)" || json=""; fi
  [ -n "$json" ] || { printf '%s\n' --squash; return 0; }
  head="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("headRefName",""))' 2>/dev/null)"
  body="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("body","") or "")' 2>/dev/null)"
  merge_flag_for "$head" "$body"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ $# -ge 1 ] || { echo "usage: merge-method.sh <pr> [repo]" >&2; exit 2; }
  merge_flag_for_pr "$@"
fi
