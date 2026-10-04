#!/usr/bin/env bash
# perm-guard.sh — flag agent profiles whose permissions are self-defeating.
# The headline case: a flat `bash: allow` gives a total shell, so any
# `edit: deny` / `write: deny` on the same agent stops nothing.
#
#   bin/perm-guard.sh            # report (exit 0)
#   bin/perm-guard.sh --strict   # exit 1 if any flat bash allowance exists
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STRICT=0; [ "${1:-}" = "--strict" ] && STRICT=1

hits=0
printf 'perm-guard{agent,issue}:\n'
for f in "$ROOT"/.agents/agents/*.md; do
  [ -e "$f" ] || continue
  name="$(sed -n 's/^name: *//p' "$f" | head -1)"; [ -n "$name" ] || name="$(basename "$f" .md)"
  if grep -Eq '^  bash: *allow *$' "$f"; then
    if grep -Eq '^  (edit|write): *deny' "$f"; then
      printf '  "%s","flat bash:allow defeats edit/write deny"\n' "$name"
    else
      printf '  "%s","flat bash:allow (total shell)"\n' "$name"
    fi
    hits=$((hits+1))
  fi
done
[ "$hits" -gt 0 ] || printf '  "none","all agents use a patterned bash"\n'
[ "$STRICT" = 1 ] && [ "$hits" -gt 0 ] && exit 1
exit 0
