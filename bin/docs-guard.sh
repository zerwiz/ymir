#!/usr/bin/env bash
# docs-guard.sh — docs/ is the PUBLIC, user-facing tree. Block operator-private
# documents (plans, strategy, roadmaps, the masterplan) before they are staged.
# Those live in hodd/docs/ (Rule 04-hoard.md).
#
#   bin/docs-guard.sh            # scan the staged change (used as pre-commit)
#   bin/docs-guard.sh --all      # scan every tracked file
set -u

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
fi || { printf 'docs-guard: blocked — docs/ is public; move it to hodd/docs/ (Rule 04)\n' >&2; exit 1; }
exit 0
