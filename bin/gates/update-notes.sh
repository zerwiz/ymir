#!/usr/bin/env bash
# update-notes.sh — WHAT CHANGED FOR YOU, since your last update.
#
# WHY (2026-10-01): *"All updates we are doing should be in the fixes so users who is updating
# knows that all this is fixes … how come that we can push without the fixes are getting used?"*
#
# Both halves were true and neither was good:
#   1. every change carries a fix note in `docs/fixes/` — and **nothing read them**. A note that
#      no door prints is a note that exists for the author, not for the user.
#   2. a user running `bin/groa-update.sh` saw "updated" and nothing else. They could not tell
#      what they had just received, so they could not tell what to re-check.
#
# So the notes become a CONSUMED artefact: this door prints what landed since a ref (or since the
# last update), and `bin/groa-update.sh` calls it. The record and the reader close.
#
#   bin/update-notes.sh                    # since the last tag/commit recorded in state/
#   bin/update-notes.sh --since v0.1.50    # since a ref
#   bin/update-notes.sh --since 3d          # since N days ago
#   bin/update-notes.sh --all               # the whole record, newest first
set -uo pipefail

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" || exit 2
FIXES="docs/fixes"
[ -d "$FIXES" ] || { echo "no $FIXES — nothing to report"; exit 0; }

mode="${1:---last}"; arg="${2:-}"

range() {
  case "$1" in
    all)     echo "" ;;
    last)    last=$(cat state/.last-update-ref 2>/dev/null || true)
             [ -n "$last" ] && git rev-parse --verify -q "$last" >/dev/null && echo "$last" || echo "" ;;
    since)   case "$2" in
               [0-9]*d) echo "$(date -u -d "-$2 days" +%Y-%m-%dT%H:%M:%SZ)" ;;
               *) git rev-parse --verify -q "$2" >/dev/null && echo "$2" || echo "" ;;
             esac ;;
  esac
}

FROM="$(range "$mode" "$arg")"

if [ "$mode" = "--all" ]; then
  files=$(find "$FIXES" -name '*.md' -newermt '1970-01-01' | sort -r)
elif [ -z "$FROM" ]; then
  files=$(find "$FIXES" -name '*.md' -mtime -14 | sort -r)   # default window when unknown
  echo "no recorded last-update ref — showing the last 14 days"
else
  files=""
  while read -r f; do [ -n "$f" ] && files="$files$f"$'\n'; done < <(git diff --name-only "$FROM"..HEAD -- "$FIXES" 2>/dev/null | grep '\.md$')
fi

N=$(printf '%s' "$files" | grep -c . || true)
printf 'what changed for you[2]{since,notes}:\n  "%s","%s"\n' "${FROM:-14 days}", "$N"
if [ "${N:-0}" -eq 0 ]; then
  printf '  nothing since your last update — or your note history predates it.\n'
  exit 0
fi

printf '%s' "$files" | while read -r f; do
  [ -n "$f" ] || continue
  comp="${f#$FIXES/}"; comp="${comp%%/*}"
  head=$(grep -m1 '^## ' "$f" 2>/dev/null | sed 's/^## //')
  [ -z "$head" ] && head=$(grep -m1 '^# ' "$f" | sed 's/^# //')
  printf '  %-14s %s\n' "$comp" "${head:0:96}"
done
printf 'the full record, newest first: %s/\n' "$FIXES"
printf 'a note with no Files section is a claim; one with files and numbers is a record.\n'