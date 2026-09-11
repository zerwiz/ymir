#!/usr/bin/env bash
# yggdrasil.sh — the worktree manager (Yggdrasil, the world-tree).
#
# Zero-collision parallel work: each task gets its own `.yggdrasil/<id>/` checkout
# on its own branch, created, listed, merged, and cleaned up explicitly. Galdr-style:
# TOON output, structured errors, no prompts, --version fast path.
#
# Usage:
#   yggdrasil.sh create <id> [--repo <path>] [--base <branch>]
#   yggdrasil.sh list   [--repo <path>]
#   yggdrasil.sh status <id> [--repo <path>]
#   yggdrasil.sh merge  <id> [--repo <path>] [--into <branch>] [--no-ff]
#   yggdrasil.sh cleanup <id> [--repo <path>] [--force]
#   yggdrasil.sh pool   <treehouse args…>   # the reusable worktree pool engine
#   yggdrasil.sh --version
#
# Engine: the reusable worktree pool is **treehouse**
# (github.com/kunchenguid/treehouse); this script is the Norse shell. `create`
# keeps an explicit, named branch for merge/cleanup; `pool` delegates to the
# treehouse pool directly.
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${YGGDRASIL_REPO:-$(pwd)}"
WT=".yggdrasil"
PREFIX="yggdrasil"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

# `pool` delegates straight to the treehouse pool engine (no branch bookkeeping).
if [ "$CMD" = "pool" ]; then
  command -v treehouse >/dev/null 2>&1 || { printf 'error: treehouse not installed\nhelp: bin/ymir-install.sh\n' >&2; exit 1; }
  exec treehouse "$@"
fi

ID=""
BASE=""
INTO=""
FORCE=0
NOFF=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO=${2-}; shift 2 ;;
    --base) BASE=${2-}; shift 2 ;;
    --into) INTO=${2-}; shift 2 ;;
    --force) FORCE=1; shift ;;
    --no-ff) NOFF=1; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/yggdrasil.sh %s [--repo <p>]\n' "$1" "$CMD" >&2; exit 2 ;;
    *) ID=$1; shift ;;
  esac
done

[ -d "$REPO" ] || { printf 'error: repo not found: %s\nhelp: pass --repo <path>\n' "$REPO" >&2; exit 1; }
REPO="$(cd "$REPO" && pwd)"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { printf 'error: not a git repository: %s\n' "$REPO" >&2; exit 1; }
BRANCH="$PREFIX/$ID"
WTPATH="$REPO/$WT/$ID"

default_branch() {
  local db
  db="$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  [ -n "$db" ] || db="$(git -C "$REPO" branch --show-current 2>/dev/null)"
  [ -n "$db" ] || db=main
  printf '%s' "$db"
}

case "$CMD" in
  create)
    [ -n "$ID" ] || { printf 'error: create needs an id\nhelp: bin/yggdrasil.sh create <id>\n' >&2; exit 2; }
    case "$ID" in *[!A-Za-z0-9._-]*) printf 'error: unsafe id: %s\n' "$ID" >&2; exit 2 ;; esac
    if [ -e "$WTPATH" ] || git -C "$REPO" show-ref --verify --quiet "refs/heads/$BRANCH"; then
      printf 'error: worktree already exists: %s\nhelp: bin/yggdrasil.sh list\n' "$BRANCH" >&2; exit 1
    fi
    BASE="${BASE:-$(default_branch)}"
    mkdir -p "$REPO/$WT"
    git -C "$REPO" worktree add -b "$BRANCH" "$WTPATH" "$BASE" >/dev/null 2>&1 || { printf 'error: git worktree add failed (base %s)\n' "$BASE" >&2; exit 1; }
    printf 'worktree[1]{id,branch,path,base}:\n  "%s","%s","%s","%s"\n' "$ID" "$BRANCH" "$WT/$ID" "$BASE"
    ;;

  list)
    n=$(git -C "$REPO" worktree list --porcelain 2>/dev/null | awk -v wt="$WT" '/^worktree /{ if ($2 ~ ("/" wt "/")) c++ } END { print c+0 }')
    printf 'worktrees[%s]{id,branch,path,head}:\n' "$n"
    git -C "$REPO" worktree list --porcelain 2>/dev/null | awk -v repo="$REPO" -v wt="$WT" '
      /^worktree /{p=$2}
      /^branch /{b=$2; sub("refs/heads/","",b)}
      /^HEAD /{h=$2}
      /^$/{ if (p ~ ("/" wt "/")) { id=p; sub(".*/","",id); printf "  \"%s\",\"%s\",\"%s\",\"%s\"\n", id, b, p, substr(h,1,8) } }
    '
    ;;

  status)
    [ -n "$ID" ] || { printf 'error: status needs an id\n' >&2; exit 2; }
    [ -e "$WTPATH" ] || { printf 'error: no worktree %s\nhelp: bin/yggdrasil.sh list\n' "$ID" >&2; exit 1; }
    dirty=$(git -C "$WTPATH" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    head=$(git -C "$WTPATH" rev-parse --short HEAD 2>/dev/null)
    ahead=$(git -C "$REPO" rev-list --count "$(default_branch)..$BRANCH" 2>/dev/null || echo 0)
    printf 'status[1]{id,branch,head,dirty,ahead}:\n  "%s","%s","%s",%s,%s\n' "$ID" "$BRANCH" "$head" "$dirty" "$ahead"
    ;;

  merge)
    [ -n "$ID" ] || { printf 'error: merge needs an id\n' >&2; exit 2; }
    [ -e "$WTPATH" ] || { printf 'error: no worktree %s\n' "$ID" >&2; exit 1; }
    dirty=$(git -C "$WTPATH" status --porcelain | wc -l | tr -d ' ')
    if [ "$dirty" != "0" ]; then
      printf 'error: worktree %s has unlanded changes (%s)\nhelp: commit or discard them first — never merge over unlanded work\n' "$ID" "$dirty" >&2
      exit 1
    fi
    INTO="${INTO:-$(default_branch)}"
    cur=$(git -C "$REPO" branch --show-current)
    if [ "$cur" != "$INTO" ]; then
      if git -C "$REPO" show-ref --verify --quiet "refs/heads/$INTO"; then
        git -C "$REPO" checkout "$INTO" >/dev/null 2>&1 || { printf 'error: cannot checkout %s (dirty tree?)\n' "$INTO" >&2; exit 1; }
      else
        printf 'error: target branch %s not found\n' "$INTO" >&2; exit 1
      fi
    fi
    if [ "$NOFF" = 1 ]; then
      git -C "$REPO" merge --no-ff "$BRANCH" >/dev/null 2>&1 || { printf 'error: merge conflict — resolve manually\n' >&2; exit 1; }
    else
      git -C "$REPO" merge --ff-only "$BRANCH" >/dev/null 2>&1 || git -C "$REPO" merge --no-ff "$BRANCH" >/dev/null 2>&1 || { printf 'error: merge failed\n' >&2; exit 1; }
    fi
    printf 'merged[1]{id,into}:\n  "%s","%s"\n' "$ID" "$INTO"
    ;;

  cleanup)
    [ -n "$ID" ] || { printf 'error: cleanup needs an id\n' >&2; exit 2; }
    if [ -e "$WTPATH" ]; then
      dirty=$(git -C "$WTPATH" status --porcelain | wc -l | tr -d ' ')
      if [ "$dirty" != "0" ] && [ "$FORCE" != "1" ]; then
        printf 'error: worktree %s has unlanded changes (%s)\nhelp: bin/yggdrasil.sh cleanup %s --force  (only after the Allfather approves discarding)\n' "$ID" "$dirty" "$ID" >&2
        exit 1
      fi
      git -C "$REPO" worktree remove ${FORCE:+--force} "$WTPATH" >/dev/null 2>&1 || true
    fi
    git -C "$REPO" worktree prune >/dev/null 2>&1 || true
    git -C "$REPO" branch -D "$BRANCH" >/dev/null 2>&1 || true
    printf 'cleaned[1]{id,branch}:\n  "%s","%s"\n' "$ID" "$BRANCH"
    ;;

  *)
    printf 'error: unknown command %s\nhelp: bin/yggdrasil.sh [-v|create|list|status|merge|cleanup]\n' "$CMD" >&2
    exit 2 ;;
esac
