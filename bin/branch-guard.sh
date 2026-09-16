#!/usr/bin/env bash
# branch-guard.sh — Rule 08: no push may land on a protected branch.
#
# Extracted from the ad-hoc .git/hooks/pre-push so the delivery gate is
# versioned and reproducible (installed by bin/changelog-guard.sh --install,
# or run by hand). A local merge on a verbal word is a decision, not a
# delivery — the gate is only fed by a PR (RULES/08-delivery-gate.md).
#
#   bin/branch-guard.sh            # pre-push: refs on stdin (hook mode)
#   bin/branch-guard.sh --branch X # check one branch name
#
# Exit codes: 0 = clear, 1 = blocked, 2 = usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROTECTED="main master release production"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

block() {  # <branch>
  cat >&2 <<EOF
⛔ Rule 08 violation: direct push to '$1' is forbidden.
   Work leaves by PR: branch → commit → push → gh pr create → Glitnir review.
   See RULES/08-delivery-gate.md
EOF
  printf 'error: branch-guard blocked a push to protected branch "%s"\n' "$1" >&2
  printf 'help: push a feature branch and open a PR instead (gh pr create)\n' >&2
  exit 1
}

is_protected() {  # <branch> — exit 0 when protected
  local b=${1-} p
  [ -n "$b" ] || return 1
  for p in $PROTECTED; do [ "$b" = "$p" ] && return 0; done
  return 1
}

case "${1:-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help) usage ;;
  --branch)
    b="${2:-}"; [ -n "$b" ] || usage
    is_protected "$b" && block "$b"
    printf 'branch-guard[1]{gate,result}:\n  "branch","ok"\n'; exit 0 ;;
  "") : ;;
  *) usage ;;
esac

current="$(git -C "$ROOT" symbolic-ref --short HEAD 2>/dev/null || echo '')"
is_protected "$current" && block "$current"

while read -r _local_ref _local_sha remote_ref _remote_sha; do
  [ -n "${remote_ref:-}" ] || continue
  rb="${remote_ref#refs/heads/}"
  is_protected "$rb" && block "$rb"
done

printf 'branch-guard[1]{gate,result}:\n  "branch","ok"\n'
exit 0
