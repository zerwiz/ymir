#!/usr/bin/env bash
# nda-guard.sh — company, client and NDA-project names never reach the public repo (RULES/04, 2026-11-12).
#   nda-guard.sh [check] [FILE...]   tracked tree (the ward; paths scope it)
#   nda-guard.sh staged | message FILE | push | range A..B | hook
# It reads $YMIR_HOME, so it is never cached.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# THE LINES A CHANGE ADDS, NOT THE FILE IT TOUCHED (plan 339.1, 2026-11-20). guards.sh hands this ward
# the changed FILES and, in YMIR_GUARD_BASE, the fork point of the push. A whole-file read refused any
# push that touched a file already carrying a protected word on main (measured: one ward file carries
# four, and every push that edited it was refused — a scoped ward is never `inherited`). With a base,
# the ward judges what the push ADDS since the fork (committed and uncommitted tracked changes), and
# reads an untracked file whole, because every line of it is new. Without a base — CI's --full, or a
# person typing the ward by hand — every line of every file is judged, as before: that is the binding gate.
if [ "${1-}" = check ] && [ "$#" -gt 1 ] && [ -n "${YMIR_GUARD_BASE:-}" ] \
   && git -C "$ROOT" rev-parse -q --verify "${YMIR_GUARD_BASE}^{commit}" >/dev/null 2>&1; then
  shift
  untracked=()
  for f in "$@"; do
    git -C "$ROOT" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || { [ -f "$ROOT/$f" ] && untracked+=("$f"); }
  done
  rc=0
  ( cd "$ROOT" && python3 bin/gates/guards/nda-guard.py range "$YMIR_GUARD_BASE" ) || rc=1
  if [ "${#untracked[@]}" -gt 0 ]; then
    ( cd "$ROOT" && python3 bin/gates/guards/nda-guard.py tree "${untracked[@]}" ) || rc=1
  fi
  exit "$rc"
fi

case "${1-}" in
  staged|message|push|range|hook|tree) ;;
  check) shift; set -- tree "$@" ;;
  *) set -- tree "$@" ;;
esac
exec python3 "$ROOT/bin/gates/guards/nda-guard.py" "$@"
