#!/usr/bin/env bash
# create_branch.sh — create a working branch, correctly named (git-ops).
#
# The house rule is that all git work goes through these three scripts, so a
# branch is always named the same way, always based on the default branch, and
# never created on top of uncommitted work (which is how a change ends up in two
# branches at once).
#
# Usage:
#   create_branch.sh <type>/<name> [--from <base>] [--allow-dirty]
#     type   feat | fix | chore | docs | refactor | test   (what the change is)
#     name   kebab-case slug, e.g. "electron-igpu-gpu-crash"
#     --from <base>   branch from <base> (default: the repository default)
#     --allow-dirty   create anyway with a dirty tree (reported, not hidden)
#
# Exit: 0 created, 1 refused, 2 usage.
set -u

VERSION="1.0.0"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf 'error: not a git repository\n' >&2; exit 1; }
cd "$ROOT" || exit 1

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

BRANCH="${1-}"; shift || true
FROM=""; ALLOW_DIRTY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM=${2-}; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    *) printf 'error: unknown flag %s\nhelp: create_branch.sh <type>/<name> [--from <base>]\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$BRANCH" ] || { printf 'error: no branch name\nhelp: create_branch.sh <type>/<name> [--from <base>]\n' >&2; exit 2; }

# ── the name ─────────────────────────────────────────────────────────────────
case "$BRANCH" in
  */*) TYPE=${BRANCH%%/*}; SLUG=${BRANCH#*/} ;;
  *) printf 'error: branch must be <type>/<name>, got %s\nhelp: types are feat|fix|chore|docs|refactor|test\n' "$BRANCH" >&2; exit 2 ;;
esac
case "$TYPE" in
  feat|fix|chore|docs|refactor|test) : ;;
  *) printf 'error: unknown type %s\nhelp: feat|fix|chore|docs|refactor|test\n' "$TYPE" >&2; exit 2 ;;
esac
printf '%s' "$SLUG" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || {
  printf 'error: name must be kebab-case (a-z, 0-9, single dashes): %s\n' "$SLUG" >&2; exit 2; }

# ── the base ─────────────────────────────────────────────────────────────────
if [ -z "$FROM" ]; then
  FROM="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
  [ -n "$FROM" ] || FROM=main
fi
git rev-parse --verify --quiet "$FROM" >/dev/null || {
  printf 'error: base branch not found: %s\nhelp: fetch first (git-ops/sync_upstream.sh --check) or pass --from\n' "$FROM" >&2; exit 1; }

# ── the tree ─────────────────────────────────────────────────────────────────
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" != 0 ] && [ "$ALLOW_DIRTY" = 0 ]; then
  printf 'branch[1]{branch,state,detail}:\n  "%s","refused","%s uncommitted path(s) would follow you onto the new branch"\n' \
    "$BRANCH" "$DIRTY"
  printf 'help[1]{do}\n  "commit them (git-ops/safe_commit.sh), stash them, or pass --allow-dirty"\n' >&2
  exit 1
fi

git rev-parse --verify --quiet "$BRANCH" >/dev/null && {
  printf 'error: branch already exists: %s\nhelp: pick another name, or switch to it with git switch\n' "$BRANCH" >&2; exit 1; }

# ── create ───────────────────────────────────────────────────────────────────
if ! git checkout -q -b "$BRANCH" "$FROM" 2>/dev/null; then
  printf 'error: could not create %s from %s\n' "$BRANCH" "$FROM" >&2; exit 1
fi

printf 'branch[1]{branch,from,base_sha,dirty}:\n  "%s","%s","%s",%s\n' \
  "$BRANCH" "$FROM" "$(git rev-parse --short HEAD)" "$DIRTY"
printf 'next[2]{step,command}:\n  "work","edit, then git-ops/safe_commit.sh -m ..."\n  "land","git-ops/sync_upstream.sh (pushes through the no-mistakes gate)"\n'
exit 0
