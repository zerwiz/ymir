#!/usr/bin/env bash
# sync_upstream.sh — fetch, rebase, then land through the no-mistakes gate (git-ops).
#
# Pushing straight to origin skips the gate that reviews, tests, lints, documents
# and opens the PR. This script pushes to the `no-mistakes` remote instead, so the
# gate validates first and advances origin itself. When the gate is not installed
# it falls back to a direct push and SAYS SO — a silent fallback here would mean
# silently shipping unreviewed code.
#
# Usage:
#   sync_upstream.sh [--check] [--direct] [--branch <name>]
#     --check    fetch + report what landing would do; change nothing
#     --direct   push straight to origin (bypasses the gate; reported)
#
# Exit: 0 landed, 1 blocked, 2 usage.
set -u

VERSION="1.0.0"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf 'error: not a git repository\n' >&2; exit 1; }
cd "$ROOT" || exit 1

# no args means "land this branch"; only an explicit flag asks for help
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

CHECK=0; DIRECT=0; BRANCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --direct) DIRECT=1; shift ;;
    --branch) BRANCH=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: sync_upstream.sh [--check|--direct|--branch <name>]\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$BRANCH" ] || BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# a dirty tree cannot rebase safely, and rebasing over uncommitted work is how
# changes get lost
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" != 0 ]; then
  printf 'sync[1]{branch,state,detail}:\n  "%s","blocked","%s uncommitted path(s) — commit them first (git-ops/safe_commit.sh)"\n' "$BRANCH" "$DIRTY"
  exit 1
fi

git fetch -q origin 2>/dev/null || { printf 'sync[1]{state,detail}:\n  "blocked","could not fetch origin — check the network and gh auth"\n' >&2; exit 1; }
DEFAULT="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
[ -n "$DEFAULT" ] || DEFAULT=main
BEHIND=$(git rev-list --count "HEAD..origin/$DEFAULT" 2>/dev/null || echo 0)
AHEAD=$(git rev-list --count "origin/$DEFAULT..HEAD" 2>/dev/null || echo 0)

printf 'sync[1]{branch,base,behind,ahead}:\n  "%s","%s",%s,%s\n' "$BRANCH" "$DEFAULT" "$BEHIND" "$AHEAD"

if [ "$CHECK" = 1 ]; then
  printf 'plan[1]{step,detail}:\n'
  [ "$BEHIND" -gt 0 ] && printf '  "rebase","onto origin/%s (%s behind)"\n' "$DEFAULT" "$BEHIND" || printf '  "rebase","already current"\n'
  if git remote | grep -qx "no-mistakes" && [ "$DIRECT" = 0 ]; then
    printf '  "land","push to the no-mistakes gate, then axi sync"
'
  else
    printf '  "land","push directly to origin (gate not installed)"
'
  fi
  exit 0
fi

# ── rebase onto the base ─────────────────────────────────────────────────────
if [ "$BEHIND" -gt 0 ]; then
  if ! git rebase -q "origin/$DEFAULT" 2>/dev/null; then
    printf 'sync[1]{branch,state,detail}:\n  "%s","blocked","rebase conflict — resolve it, then re-run (git rebase --continue)"\n' "$BRANCH"
    exit 1
  fi
  printf 'rebase[1]{onto,new_head}:\n  "origin/%s","%s"\n' "$DEFAULT" "$(git rev-parse --short HEAD)"
fi

# ── land ─────────────────────────────────────────────────────────────────────
if git remote | grep -qx "no-mistakes" && [ "$DIRECT" = 0 ]; then
  printf 'gate[1]{remote,detail}:\n  "no-mistakes","validating before origin — this is the clean-PR gate"\n'
  if ! git push -q no-mistakes "$BRANCH" 2>/dev/null; then
    printf 'sync[1]{branch,state,detail}:\n  "%s","blocked","the gate refused the push — run: no-mistakes axi status"\n' "$BRANCH"
    exit 1
  fi
  if command -v no-mistakes >/dev/null 2>&1; then
    printf 'axi[1]{action,detail}:\n  "sync","moving %s to the verified head"\n' "$BRANCH"
    no-mistakes axi sync 2>&1 | tail -8
  fi
else
  printf 'gate[1]{remote,detail}:\n  "origin","NO GATE — pushing unreviewed (no-mistakes remote absent or --direct)"\n'
  git push -q origin "$BRANCH" 2>/dev/null || {
    printf 'sync[1]{branch,state,detail}:\n  "%s","blocked","push to origin failed"\n' "$BRANCH"; exit 1; }
fi
printf 'landed[1]{branch,head}:\n  "%s","%s"\n' "$BRANCH" "$(git rev-parse --short HEAD)"
exit 0
