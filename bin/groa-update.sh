#!/usr/bin/env bash
# groa-update.sh — Gróa, the völva who renews.
#
# Gróa is the updater shaman: she fast-forwards Brokk and every registered
# Eindri-home to the latest, then mends the tree forward (migrations, fleet
# preferences). Brokk runs her; Galdr owns the assets she must be reflected in
# when the instruction surface moves; the `groa-update` skill is her door.
#
# Fast-forward only. Never forces, never stashes, never creates a merge commit.
# Anything dirty, diverged, offline, or on a non-default branch is skipped and
# reported. Touches only Brokk repos and their worktrees — never projects/.
#
# Usage:
#   groa-update.sh [--check] [--remote <name>] [--branch <name>]
#   groa-update.sh --version
#
# The `groa-update` skill invokes her; `bin/brokk-update.sh` is a back-compat
# alias. Prints one row per target, then the action lines:
#   reread-Brokk: yes|no
#   galdr-reread: yes|no                 (Galdr must refresh the owning assets)
#   nudge-eindri-homes: <id> ...|none
set -u

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
# The registry lives in the hoard (RULES/04-hoard.md; correction 2026-09-17).
# Resolve through hoard-lib so the path can never drift again.
if [ -r "$SCRIPT_DIR/hoard-lib.sh" ]; then
  # shellcheck source=bin/hoard-lib.sh
  . "$SCRIPT_DIR/hoard-lib.sh"; hoard_root _hoard
else
  _hoard="${YMIR_HOARD:-$YMIR_HOME/hodd}"
fi
REG="${BROKK_EINDRI_HOMES:-$_hoard/data/eindri-homes.md}"
REMOTE=""; BRANCH=""; CHECK=0

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --remote) REMOTE=${2-}; shift 2 ;;
    --branch) BRANCH=${2-}; shift 2 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/groa-update.sh [--check|--remote|--branch]\n' "$1" >&2; exit 2 ;;
  esac
done

# Resolve remote/branch from the master registry when the resolver is present.
if [ -x "$SCRIPT_DIR/project-git.sh" ] && "$SCRIPT_DIR/project-git.sh" list 2>/dev/null | grep -q 'ymir-platform'; then
  [ -n "$REMOTE" ] || REMOTE="$("$SCRIPT_DIR/project-git.sh" ymir-platform --field remote 2>/dev/null)"
  [ -n "$BRANCH" ] || BRANCH="$("$SCRIPT_DIR/project-git.sh" ymir-platform --field default_branch 2>/dev/null)"
fi
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"

declare -a ROWS; NUDGE_IDS=""
reread=no
changed_surface=0

# Guarded fast-forward of one Brokk home. Sets FF_STATE/FF_DETAIL.
ff_home() { # <path> <label>
  local p="$1" label="$2"
  if [ ! -d "$p" ]; then FF_STATE="skipped"; FF_DETAIL="not found: $p"; return; fi
  if ! git -C "$p" rev-parse --is-inside-work-tree >/dev/null 2>&1; then FF_STATE="skipped"; FF_DETAIL="not a git repo"; return; fi
  local cur; cur="$(git -C "$p" branch --show-current 2>/dev/null || echo '')"
  if [ -n "$cur" ] && [ "$cur" != "$BRANCH" ]; then FF_STATE="skipped"; FF_DETAIL="on branch $cur"; return; fi
  local dirty; dirty="$(git -C "$p" status --porcelain | wc -l | tr -d ' ')"
  if [ "$dirty" != "0" ]; then FF_STATE="skipped"; FF_DETAIL="dirty ($dirty)"; return; fi
  git -C "$p" fetch --quiet --prune "$REMOTE" 2>/dev/null || { FF_STATE="skipped"; FF_DETAIL="offline ($REMOTE)"; return; }
  local local_h target
  local_h="$(git -C "$p" rev-parse HEAD)"
  target="$(git -C "$p" rev-parse "$REMOTE/$BRANCH" 2>/dev/null)" || { FF_STATE="skipped"; FF_DETAIL="$REMOTE/$BRANCH missing"; return; }
  if [ "$local_h" = "$target" ]; then FF_STATE="current"; FF_DETAIL="${local_h:0:8}"; return; fi
  if ! git -C "$p" merge-base --is-ancestor "$local_h" "$target"; then FF_STATE="skipped"; FF_DETAIL="diverged"; return; fi
  if [ "$CHECK" = 1 ]; then FF_STATE="behind"; FF_DETAIL="$(git -C "$p" rev-list --count "$local_h..$target") behind"; return; fi
  if git -C "$p" merge --ff-only -q "$target" 2>/dev/null; then
    FF_STATE="updated"; FF_DETAIL="${local_h:0:8}..$(git -C "$p" rev-parse --short HEAD)"
    if [ -n "$(git -C "$p" diff --name-only "$local_h" "$target" -- AGENTS.md bin .agents/skills 2>/dev/null)" ]; then
      [ "$label" = "$ROOT" ] && changed_surface=1
    fi
  else FF_STATE="skipped"; FF_DETAIL="fast-forward failed"; fi
}

add_row() { ROWS+=("$1"); }

# 1. This home.
ff_home "$ROOT" "$ROOT"
add_row "  \"$ROOT\",\"this Brokk home\",\"$FF_STATE\",\"$FF_DETAIL\""

# 2. Registered Eindri-homes.
if [ -f "$REG" ]; then
  while IFS= read -r line; do
    case "$line" in '- '*) ;; *) continue ;; esac
    id="$(printf '%s' "$line" | sed -nE 's/^- ([^ ]+).*/\1/p')"
    host="$(printf '%s' "$line" | sed -nE 's/.*\(host: ([^;)]+).*/\1/p' | tr -d ' ')"
    home="$(printf '%s' "$line" | sed -nE 's/.*\(.*home: ([^;)]+).*/\1/p' | sed -E 's/ *(host:.*)?$//' | tr -d ' ')"
    [ -n "$id" ] || continue
    if [ -n "$host" ]; then
      root="$(printf '%s' "$line" | sed -nE 's/.*root: ([^;)]+).*/\1/p' | tr -d ' ')"
      add_row "  \"$id\",\"remote $host:${root:-$home}\",\"skipped\",\"remote route — run bin/groa-update.sh on $host\""
      continue
    fi
    [ -n "$home" ] || home="$id"
    ff_home "$home" "$home"
    add_row "  \"$id\",\"$home\",\"$FF_STATE\",\"$FF_DETAIL\""
    [ "$FF_STATE" = "updated" ] && NUDGE_IDS="$NUDGE_IDS $id"
  done <"$REG"
else
  add_row "  \"-\",\"registry\",\"absent\",\"$REG (no Eindri-homes registered)\""
fi

# reread-Brokk: yes when this home's instruction surface advanced.
[ "$changed_surface" = 1 ] && reread=yes

printf 'groa[1]{state,root,remote,branch,mode}:\n  "renew","%s","%s","%s","%s"\n' "$ROOT" "$REMOTE" "$BRANCH" "$([ "$CHECK" = 1 ] && echo check || echo apply)"
printf 'update[%d]{id,target,state,detail}:\n' "${#ROWS[@]}"
printf '%s\n' "${ROWS[@]}"
printf 'reread-Brokk: %s\n' "$reread"
# Galdr owns the assets; when the instruction surface moved she must be reflected
# in the same pass (the code/plan/asset agreement law).
printf 'galdr-reread: %s\n' "$reread"
if [ -n "${NUDGE_IDS# }" ]; then printf 'nudge-eindri-homes: %s\n' "${NUDGE_IDS# }"; else printf 'nudge-eindri-homes: none\n'; fi

# Keep the whole fleet on the fleet preferences (writes each home's gitignored
# state/; never touches a tracked tree).
[ -x "$SCRIPT_DIR/fleet-apply.sh" ] && "$SCRIPT_DIR/fleet-apply.sh" >/dev/null 2>&1 || true

# Heal this home forward (structure migrations) after every update.
[ -x "$SCRIPT_DIR/ymir-migrate.sh" ] && "$SCRIPT_DIR/ymir-migrate.sh" apply >/dev/null 2>&1 || true
