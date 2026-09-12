#!/usr/bin/env bash
# public-guard.sh — every PUBLIC, user-facing file must be free of operator
# private content (tenant names, personal handles, /home paths, secret shapes).
# Supersedes agents-guard (root AGENTS.md is just one public file).
#
#   bin/public-guard.sh          # inspect the staged change (pre-commit)
#   bin/public-guard.sh --all    # inspect every tracked public file
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The public tree scanned for private markers.
PUBLIC='^(README\.md|CHANGELOG\.md|TODO\.md|Structure\.md|CONTRIBUTING\.md|SECURITY\.md|NOTICE|AGENTS\.md|docs/)'
# Operator-private markers that must never appear in a public file.
PATTERNS='(josef|lindbom|/home/zerwiz|hodd/tenants/[a-z0-9]|(ghp|gho|ghs|ghr)_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

leaks() {  # stdin → prints masked hits, returns 1 on any
  grep -En "$PATTERNS" | sed -E 's/(sk-|ghp_|AKIA|xox[a-z]*-)[A-Za-z0-9-]+/\1…/g; s#/home/zerwiz#/home/<user>#g' | head -5
}

hit=0
if [ "${1:-}" = "--all" ]; then
  while IFS= read -r f; do
    printf '%s\n' "$f" | grep -Eq "$PUBLIC" || continue
    if out="$(git -C "$ROOT" show ":$f" 2>/dev/null | leaks)"; then :; else
      printf 'public-guard: %s\n%s\n' "$f" "$out" >&2; hit=1
    fi
  done < <(git -C "$ROOT" ls-files)
else
  while IFS= read -r f; do
    printf '%s\n' "$f" | grep -Eq "$PUBLIC" || continue
    if out="$(git -C "$ROOT" diff --cached -U0 -- "$f" 2>/dev/null | grep -E '^\+' | sed 's/^+//' | leaks)"; then :; else
      printf 'public-guard: %s\n%s\n' "$f" "$out" >&2; hit=1
    fi
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM)
fi

[ "$hit" = 0 ] || { printf 'public-guard: blocked — that is private; move it to hodd/ (Rule 04)\n' >&2; exit 1; }
exit 0
