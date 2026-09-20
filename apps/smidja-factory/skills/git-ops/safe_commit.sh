#!/usr/bin/env bash
# safe_commit.sh — run the house gates, then commit (git-ops).
#
# A commit that has not passed the gates is a commit that will fail later, in CI
# or in review, where it costs more. The gates are the repo's own, so local and
# CI cannot diverge. Pushing is NOT done here — that is the gate's job
# (sync_upstream.sh routes through no-mistakes).
#
# Usage:
#   safe_commit.sh -m "<type>(<scope>): <subject>" [--all] [--no-gates]
#
# Exit: 0 committed, 1 refused by a gate or by git, 2 usage.
set -u

VERSION="1.0.0"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf 'error: not a git repository\n' >&2; exit 1; }
cd "$ROOT" || exit 1

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

MSG=""; ALL=0; GATES=1
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--message) MSG=${2-}; shift 2 ;;
    --all) ALL=1; shift ;;
    --no-gates) GATES=0; shift ;;
    *) printf 'error: unknown flag %s\nhelp: safe_commit.sh -m "<message>" [--all] [--no-gates]\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$MSG" ] || { printf 'error: a commit message is required\nhelp: safe_commit.sh -m "<type>(<scope>): <subject>"\n' >&2; exit 2; }

# conventional shape, because the log is read by agents and by humans
printf '%s' "$MSG" | head -1 | grep -qE '^(feat|fix|chore|docs|refactor|test|perf|build|ci)(\([a-z0-9._/-]+\))?: .+' || {
  printf 'error: message must be conventional: type(scope): subject\nhelp: types are feat|fix|chore|docs|refactor|test|perf|build|ci\n' >&2; exit 2; }

# ── stage ────────────────────────────────────────────────────────────────────
if [ "$ALL" = 1 ]; then git add -A; else git add -u; fi
STAGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
[ "$STAGED" != 0 ] || { printf 'commit[1]{state,detail}:\n  "nothing","no staged changes (use --all to include new files)"\n'; exit 1; }

# ── gates ────────────────────────────────────────────────────────────────────
declare -a G S
if [ "$GATES" = 1 ] && [ -d "$ROOT/.compliance/gates" ]; then
  for g in "$ROOT"/.compliance/gates/*.sh; do
    [ -x "$g" ] || continue
    n=$(basename "$g" .sh)
    if bash "$g" >/dev/null 2>&1; then G+=("$n"); S+=("pass"); else G+=("$n"); S+=("FAIL"); fi
  done
fi
if [ "$GATES" = 1 ] && [ -x "$ROOT/.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh" ]; then
  if bash "$ROOT/.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh" >/dev/null 2>&1; then G+=("compliance"); S+=("pass"); else G+=("compliance"); S+=("FAIL"); fi
fi
if [ "$GATES" = 1 ] && [ -x "$ROOT/bin/brokk-lint.sh" ]; then
  if bash "$ROOT/bin/brokk-lint.sh" >/dev/null 2>&1; then G+=("lint"); S+=("pass"); else G+=("lint"); S+=("FAIL"); fi
fi

bad=0
for s in "${S[@]:-}"; do [ "$s" = FAIL ] && bad=1; done
if [ "$bad" = 1 ]; then
  printf 'commit[1]{state,detail}:\n  "refused","a gate failed — nothing was committed"\n'
  ng=${#G[@]}
  printf 'gates[%s]{gate,status}:\n' "$ng"
  if [ "$ng" -gt 0 ]; then
    for i in $(seq 0 $((ng - 1))); do printf '  "%s","%s"\n' "${G[$i]}" "${S[$i]}"; done
  fi
  printf 'help[1]{do}\n  "fix the failing gate, or pass --no-gates to commit anyway (say why in the message)"\n' >&2
  exit 1
fi

# ── commit ───────────────────────────────────────────────────────────────────
if ! git commit -q -m "$MSG"; then
  printf 'commit[1]{state,detail}:\n  "failed","git refused the commit — see the output above"\n' >&2; exit 1
fi
printf 'commit[1]{sha,paths,message}:\n  "%s",%s,"%s"\n' \
  "$(git rev-parse --short HEAD)" "$STAGED" "$(printf '%s' "$MSG" | head -1 | cut -c1-60)"
ng=${#G[@]}
printf 'gates[%s]{gate,status}:\n' "$ng"
if [ "$ng" -gt 0 ]; then
  for i in $(seq 0 $((ng - 1))); do printf '  "%s","%s"\n' "${G[$i]}" "${S[$i]}"; done
fi
printf 'next[1]{step,command}:\n  "land","git-ops/sync_upstream.sh — pushes through the no-mistakes gate"\n'
exit 0
