#!/usr/bin/env bash
# private-guard.sh — enforce the Hoard boundary (Rule 04). Nothing under a
# private path may be TRACKED except its allowed guard/scaffold/example. Besides
# secret-guard (values) and docs-guard (public docs/), this stops a private
# path being committed — even by `git add -f` or a `git mv` that bypasses
# .gitignore.
#
#   bin/private-guard.sh           # inspect the staged change
#   bin/private-guard.sh --all     # inspect every tracked file
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Private roots — nothing here is public.
FORBID='^(hodd/|state/|data/|workspace/(work|personal|memory|companies)/|assets/reference/state/|\.a2a/|\.env)'
# Allowed tracked exceptions inside those roots.
ALLOW='^(hodd/(README\.md|\.gitignore|AGENTS\.example\.md|[^/]+\.example(\.md)?)$|state/\.gitkeep$|data/[^/]+\.example$|assets/reference/state/[^/]+\.example$|\.env\.example|\.env\.sample)$'

scan_list() {
  local hit=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if printf '%s\n' "$f" | grep -Eq "$FORBID" && ! printf '%s\n' "$f" | grep -Eq "$ALLOW"; then
      printf 'private-guard: tracked private path: %s\n' "$f" >&2
      hit=1
    fi
  done
  return "$hit"
}

if [ "${1:-}" = "--all" ]; then
  scan_list < <(git -C "$ROOT" ls-files)
else
  scan_list < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM)
fi || { printf 'private-guard: blocked — that path is private; keep it in the Hoard and untracked\n' >&2; exit 1; }
exit 0
