#!/usr/bin/env bash
# docs-guard.sh — docs/ is the PUBLIC, user-facing tree. Block operator-private
# documents (plans, strategy, roadmaps, the masterplan) before they are staged.
# Those live at $YMIR_HOME/hodd/docs/ (Rule 04-hoard.md).
#
#   bin/docs-guard.sh            # scan the staged change (used as pre-commit)
#   bin/docs-guard.sh --all      # scan every tracked file
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/hoard-lib.sh" ]; then . "$_yh/bin/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Private document shapes that must never be published under docs/.
PATTERNS='(^docs/plans/|^docs/masterplan|^docs/append-only-log|^docs/ratatoskr\.md|^docs/.*-plan\.md$|^docs/.*(plan|strategy|roadmap|backlog|proposal|private)\.md$)'
# Exception: public transformation plans (about separating private data for
# open-source release). These are operational, not operator-private.
PATTERN_ALLOW='(^docs/plans/0003-private-data-separation\.md$)'

scan_list() {
  local hit=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if printf '%s\n' "$f" | grep -Eq "$PATTERN_ALLOW"; then
      continue
    fi
    if printf '%s\n' "$f" | grep -Eq "$PATTERNS"; then
      printf 'docs-guard: private document under docs/: %s\n' "$f" >&2
      hit=1
    fi
  done
  return "$hit"
}

if [ "${1:-}" = "--all" ]; then
  scan_list < <(git -C "$ROOT" ls-files)
else
  scan_list < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM)
fi || { printf 'docs-guard: blocked — docs/ is public; move it to $YMIR_HOME/hodd/docs/ (or $YMIR_HOME/memory/plans/ for plans) (Rule 04)\n' >&2; exit 1; }
exit 0
