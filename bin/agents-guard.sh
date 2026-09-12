#!/usr/bin/env bash
# agents-guard.sh — root AGENTS.md is the PUBLIC user contract. Block a change
# that leaks operator-private content into it: tenant names, personal handles,
# private paths, or secret-shaped values. Those belong in hodd/AGENTS.md
# (Rule 04-hoard.md).
#
#   bin/agents-guard.sh            # inspect the staged change to AGENTS.md
#   bin/agents-guard.sh --all      # inspect the committed file
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILE="AGENTS.md"

# Operator-private markers that must never enter the public contract.
PATTERNS='(josef|lindbom|/home/zerwiz|hodd/tenants/[a-z0-9]|(ghp|gho|ghs|ghr)_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

check() {  # reads content on stdin
  if grep -Eq "$PATTERNS"; then
    grep -En "$PATTERNS" | sed -E 's/(sk-|ghp_|AKIA|xox[a-z]*-)[A-Za-z0-9-]+/\1…/g; s#/home/zerwiz#/home/<user>#g' | head -5
    return 1
  fi
  return 0
}

if [ "${1:-}" = "--all" ]; then
  git -C "$ROOT" show ":$FILE" 2>/dev/null | check || { printf 'agents-guard: %s holds private content — move it to hodd/AGENTS.md (Rule 04)\n' "$FILE" >&2; exit 1; }
else
  git -C "$ROOT" diff --cached -U0 -- "$FILE" 2>/dev/null | grep -E '^\+' | sed 's/^+//' | check \
    || { printf 'agents-guard: blocked — %s is the public contract; put private content in hodd/AGENTS.md (Rule 04)\n' "$FILE" >&2; exit 1; }
fi
exit 0
