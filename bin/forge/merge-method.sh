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
# A gathered batch is also named by its PR title (`gather: …`) and by the first line of its body
# (`MERGE WITH A MERGE COMMIT`), so a button or a tool that never saw the head branch still knows.
is_gather_pr() {  # <head> <body> [title]
  local head="${1-}" body="${2-}" title="${3-}"
  case "$head" in yggdrasil/gather-*|gather/*) return 0 ;; esac
  case "$title" in gather:*) return 0 ;; esac
  case "$body" in "MERGE WITH A MERGE COMMIT"*|*'gathered by `bin/forge/gather.sh`'*) return 0 ;; esac
  return 1
}

merge_flag_for() {
  local head="${1-}" body="${2-}" title="${3-}"
  is_gather_pr "$head" "$body" "$title" && { printf '%s\n' --merge; return 0; }
  case "$head" in yggdrasil/gather-*|gather/*) printf '%s\n' --merge; return 0 ;; esac
  case "$body" in *'gathered by `bin/forge/gather.sh`'*) printf '%s\n' --merge; return 0 ;; esac
  printf '%s\n' --squash
}

merge_flag_for_pr() {
  local pr="${1:?pr number}" repo="${2-}" head body title json
  if [ -n "$repo" ]; then json="$(gh pr view "$pr" -R "$repo" --json headRefName,body,title 2>/dev/null)" || json=""
  else json="$(gh pr view "$pr" --json headRefName,body,title 2>/dev/null)" || json=""; fi
  [ -n "$json" ] || { printf '%s\n' --squash; return 0; }
  head="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("headRefName",""))' 2>/dev/null)"
  body="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("body","") or "")' 2>/dev/null)"
  title="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("title","") or "")' 2>/dev/null)"
  merge_flag_for "$head" "$body" "$title"
}

# refuse_squash_of_gather <pr> <flag> [repo] — exit 1 (and say why) when a gathered batch is about
# to be squashed. The merge doors call it on the flag they are about to pass, so a changed default
# or a forced flag can never squash a batch (PR #688 was squashed by the button: never again).
refuse_squash_of_gather() {
  local pr="${1:?pr number}" flag="${2-}" repo="${3-}" want
  [ "$flag" = --squash ] || return 0
  want="$(merge_flag_for_pr "$pr" "$repo")"
  [ "$want" = --merge ] || return 0
  printf 'refused: PR #%s is a gathered batch — MERGE WITH A MERGE COMMIT; a squash erases each errand'"'"'s history\n' "$pr" >&2
  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ $# -ge 1 ] || { echo "usage: merge-method.sh <pr> [repo]" >&2; exit 2; }
  merge_flag_for_pr "$@"
fi
