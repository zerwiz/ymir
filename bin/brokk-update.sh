#!/usr/bin/env bash
# brokk-update.sh — update the Ymir world-tree from its remote, safely.
#
# Fast-forward only. Refuses a dirty or diverged tree unless `--yes` (then it
# stashes, fast-forwards, and restores). Never force-pushes, never rewrites
# history. Galdr-style TOON, idempotent.
#
# Usage:
#   brokk-update.sh [--check] [--yes] [--remote <name>] [--branch <name>]
#   brokk-update.sh --version
#
# Exit: 0 ok (or --check), 1 error/refused, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTE=""; BRANCH=""; CHECK=0; YES=0

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --yes|-y) YES=1; shift ;;
    --remote) REMOTE=${2-}; shift 2 ;;
    --branch) BRANCH=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/brokk-update.sh [--check|--yes|--remote|--branch]\n' "$1" >&2; exit 2 ;;
  esac
done

git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'error: not a git repo: %s\n' "$ROOT" >&2; exit 1; }

# Resolve remote/branch from the master registry when the resolver is present.
if [ -x "$SCRIPT_DIR/project-git.sh" ] && "$SCRIPT_DIR/project-git.sh" list 2>/dev/null | grep -q 'ymir-platform'; then
  [ -n "$REMOTE" ] || REMOTE="$("$SCRIPT_DIR/project-git.sh" ymir-platform --field remote 2>/dev/null)"
  [ -n "$BRANCH" ] || BRANCH="$("$SCRIPT_DIR/project-git.sh" ymir-platform --field default_branch 2>/dev/null)"
fi
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"

git -C "$ROOT" remote get-url "$REMOTE" >/dev/null 2>&1 || { printf 'error: unknown remote "%s"\nhelp: bin/brokk-update.sh --remote <name>\n' "$REMOTE" >&2; exit 1; }

# Guard: uncommitted changes.
dirty="$(git -C "$ROOT" status --porcelain | wc -l | tr -d ' ')"

git -C "$ROOT" fetch --quiet --prune "$REMOTE" || { printf 'error: git fetch %s failed\n' "$REMOTE" >&2; exit 1; }
up="$REMOTE/$BRANCH"
git -C "$ROOT" rev-parse --verify --quiet "$up" >/dev/null || { printf 'error: %s not found after fetch\n' "$up" >&2; exit 1; }

local="$(git -C "$ROOT" rev-parse HEAD)"
target="$(git -C "$ROOT" rev-parse "$up")"

if [ "$local" = "$target" ]; then
  printf 'update[1]{state,remote,branch,head,dirty}:\n  "up-to-date","%s","%s","%s",%s\n' "$REMOTE" "$BRANCH" "${local:0:8}" "$dirty"
  exit 0
fi

if ! git -C "$ROOT" merge-base --is-ancestor "$local" "$target"; then
  printf 'update[1]{state,remote,branch,head,dirty}:\n  "DIVERGED","%s","%s","%s",%s\n' "$REMOTE" "$BRANCH" "${local:0:8}" "$dirty"
  printf 'help: the tree has local commits not on %s — merge or rebase by hand (never force)\n' "$up" >&2
  exit 1
fi

behind="$(git -C "$ROOT" rev-list --count "$local..$target")"

if [ "$CHECK" = 1 ]; then
  printf 'update[1]{state,remote,branch,behind,head,dirty}:\n  "BEHIND",%s,"%s","%s",%s,%s\n' "$behind" "$REMOTE" "$BRANCH" "${local:0:8}" "$dirty"
  exit 0
fi

if [ "$dirty" != "0" ] && [ "$YES" != "1" ]; then
  printf 'update[1]{state,behind,head,dirty}:\n  "REFUSED",%s,"%s",%s\n' "$behind" "${local:0:8}" "$dirty"
  printf 'help: %s uncommitted change(s). Commit them, or re-run with --yes to stash + restore.\n' "$dirty" >&2
  exit 1
fi

stashed=0
if [ "$dirty" != "0" ]; then
  git -C "$ROOT" stash push -u -q -m "brokk-update $(date -u +%Y%m%dT%H%M%SZ)" && stashed=1
fi

if git -C "$ROOT" merge --ff-only -q "$target"; then
  newhead="$(git -C "$ROOT" rev-parse --short HEAD)"
  restored="n/a"
  if [ "$stashed" = 1 ]; then
    if git -C "$ROOT" stash pop -q; then restored="ok"; else restored="CONFLICT (see git stash list)"; fi
  fi
  printf 'update[1]{state,remote,branch,behind,head,stashed}:\n  "UPDATED",%s,"%s",%s,"%s","%s"\n' "$behind" "$REMOTE" "$BRANCH" "$newhead" "$restored"
  printf 'next: bin/ymir-install.sh --check · bash .agents/skills/galdr/scripts/compliance-check.sh\n'
  [ "$restored" = "ok" ] || [ "$restored" = "n/a" ] || exit 1
  exit 0
fi

printf 'error: fast-forward failed — tree left unchanged\n' >&2
[ "$stashed" = 1 ] && git -C "$ROOT" stash pop -q 2>/dev/null || true
exit 1
