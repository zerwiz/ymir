#!/usr/bin/env bash
# housekeeping.sh — what the worktrees cost, what is already safe to forget, and what has
# NOT been pushed. Read-only by default; removal needs an explicit --yes.
#
# THE PROBLEM (measured 2026-10-20 on this box): `.yggdrasil/` held **5.9 GB across 55
# worktrees** and 144 local branches, most of them work that had long since landed on
# `origin/main`. The disk pays for every one of them, and the one thing that must never
# happen — losing an unpushed commit — is exactly the thing an over-eager cleanup does.
#
# So the order is: PROVE, then report, then (only with --yes) reclaim.
#
#   housekeeping.sh                 # the report: every worktree and branch, with a verdict
#   housekeeping.sh report --json   # the same, machine-readable
#   housekeeping.sh clean           # the PLAN (nothing is removed)
#   housekeeping.sh clean --yes     # remove only what the plan proved reclaimable
#   housekeeping.sh clean --yes --merged-only   # only work already IN origin/main (the
#                                              # strictest form: a pushed branch with an open
#                                              # PR is deliberately kept, because you may still
#                                              # be working in it)
#   housekeeping.sh check           # exit 1 when any work is unpushed (for a cron/gate)
#
# Verdicts:
#   reclaimable:merged   every commit is already in origin/main — the worktree/branch is a copy
#   reclaimable:pushed   HEAD is exactly the remote branch — the work lives on the remote
#   keep:dirty           uncommitted changes (tracked or untracked) — never touched
#   keep:in-use          a live process is working inside it (an agent's shell, a herdr pane)
#   keep:unpushed:N      N commits that exist nowhere but this machine — never touched.
#                        (No separate "unmerged" verdict: a commit on no remote IS unpushed,
#                        and the remedy is the same — push it or merge it.)
#
# NEVER touched: the main worktree, main itself, anything dirty, anything with unpushed
# commits. `git worktree remove` runs WITHOUT --force, and `git branch -d` (not -D) is the
# branch remover — the safe form, so a bug here still cannot delete live work.
#
# Exit: 0 ok · 1 `check` found unpushed work · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

CMD="report"; YES=0; JSON=0; MERGED_ONLY=0
for a in "$@"; do
  case "$a" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    report|clean|check) CMD="$a" ;;
    --yes|-y) YES=1 ;;
    --merged-only) MERGED_ONLY=1 ;;
    --json) JSON=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/forge/housekeeping.sh [report|clean|check] [--yes] [--json]\n' "$a" >&2; exit 2 ;;
  esac
done

cd "$ROOT" || exit 1
command -v git >/dev/null 2>&1 || { printf 'housekeeping[1]{state}:\n  "skip","no git"\n'; exit 0; }

BASE="origin/main"
git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1 || BASE="main"
MAIN_WT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname 2>/dev/null || printf '%s' "$ROOT")"

# ── the facts, gathered once ─────────────────────────────────────────────────
# worktrees: path<TAB>branch   (the main worktree is excluded from every verdict)
wt_rows() {
  git worktree list --porcelain 2>/dev/null | awk '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { br = substr($0, 8); sub("^refs/heads/", "", br); print path "\t" br }
    /^detached$/ { print path "\t(detached)" }
  '
}

# branches with no worktree: branch<TAB>upstream
bare_branches() {
  local in_wt; in_wt="$(wt_rows | cut -f2 | sort -u)"
  git for-each-ref --format='%(refname:short)%09%(upstream:short)' refs/heads 2>/dev/null | while IFS=$'\t' read -r br up; do
    printf '%s\n' "$in_wt" | grep -qxF "$br" && continue
    printf '%s\t%s\n' "$br" "$up"
  done
}

size_of() { du -sh "$1" 2>/dev/null | awk '{print $1}'; }

# Is any live process working INSIDE this path? A merged worktree can still be someone's
# shell — the Allfather's own agent may be sitting in it. Measured 2026-10-20: reclaiming a
# tree holds a cwd a live shell depends on (my own session was killed twice by exactly that
# class of shortcut). `$PWD` of a process is `/proc/<pid>/cwd`.
in_use() {  # <abs-path> → exit 0 when a live process stands inside it
  local target="$1" pid cwd
  for pid in /proc/[0-9]*; do
    cwd="$(readlink -f "$pid/cwd" 2>/dev/null)" || continue
    [ -n "$cwd" ] || continue
    case "$cwd" in "$target"|"$target"/*) return 0 ;; esac
  done
  return 1
}

# verdict <path> <branch> → one of the five, with a count where useful
verdict() {
  local path=$1 br=$2
  [ "$path" = "$MAIN_WT" ] && { printf 'main-worktree'; return; }
  [ "$br" = "main" ] && { printf 'keep:main'; return; }
  [ "$br" = "(detached)" ] && { printf 'keep:detached'; return; }

  if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then printf 'keep:dirty'; return; fi
  if in_use "$path"; then printf 'keep:in-use'; return; fi

  local head up_name ahead
  head="$(git -C "$path" rev-parse HEAD 2>/dev/null)" || { printf 'keep:unreadable'; return; }
  if git merge-base --is-ancestor "$head" "$BASE" 2>/dev/null; then printf 'reclaimable:merged'; return; fi

  up_name="$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [ -n "$up_name" ]; then
    ahead="$(git -C "$path" rev-list --count "${up_name}..HEAD" 2>/dev/null || echo 0)"
    [ "${ahead:-0}" = 0 ] && { printf 'reclaimable:pushed'; return; }
    printf 'keep:unpushed:%s' "$ahead"; return
  fi

  # No upstream: is the remote branch identical, and does it exist at all?
  if git rev-parse --verify --quiet "origin/$br" >/dev/null 2>&1; then
    if [ "$(git rev-parse "origin/$br")" = "$head" ]; then printf 'reclaimable:pushed'; return; fi
  fi
  # `-C "$path"`: measured in the fixture — counting from the repo root counted MAIN's
  # commits, not the worktree's, and called real local work "0".
  local solo; solo="$(git -C "$path" rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)"
  printf 'keep:unpushed:%s' "${solo:-0}"
}

# ── gather ───────────────────────────────────────────────────────────────────
TOTAL_WT=0; TOTAL_RECLAIM=0; UNPUSHED=0; DIRTY=0; IN_USE=0
declare -a LINES=()
while IFS=$'\t' read -r path br; do
  [ -n "${path:-}" ] || continue
  TOTAL_WT=$((TOTAL_WT + 1))
  v="$(verdict "$path" "$br")"
  s="$(size_of "$path")"
  case "$v" in
    reclaimable:*) TOTAL_RECLAIM=$((TOTAL_RECLAIM + 1)) ;;
    keep:unpushed*) UNPUSHED=$((UNPUSHED + 1)) ;;
    keep:dirty) DIRTY=$((DIRTY + 1)) ;;
    keep:in-use) IN_USE=$((IN_USE + 1)) ;;
  esac
  idx="${path#$ROOT/.yggdrasil/}"
  LINES+=("$(printf "%s\t%s\t%s\t%s\t%s" "$idx" "$br" "$v" "${s:-?}" "$path")")
done < <(wt_rows)

declare -a BRANCHES=()
while IFS=$'\t' read -r br up; do
  [ -n "${br:-}" ] || continue
  [ "$br" = "main" ] && continue
  if git merge-base --is-ancestor "$br" "$BASE" 2>/dev/null; then
    v="reclaimable:merged"
  elif [ -n "${up:-}" ]; then
    ahead="$(git rev-list --count "$up..$br" 2>/dev/null || echo 0)"
    if [ "${ahead:-0}" = 0 ]; then v="reclaimable:pushed"; else v="keep:unpushed:$ahead"; UNPUSHED=$((UNPUSHED + 1)); fi
  else
    v="keep:unpushed:$(git rev-list --count "$BASE..$br" 2>/dev/null || echo 0)"
  fi
  case "$v" in reclaimable:*) TOTAL_RECLAIM=$((TOTAL_RECLAIM + 1)) ;; esac
  BRANCHES+=("$(printf '%s\t%s' "$br" "$v")")
done < <(bare_branches)

# ── report ───────────────────────────────────────────────────────────────────
if [ "$JSON" = 1 ]; then
  printf '{"worktrees":['
  first=1
  for l in "${LINES[@]}"; do
    IFS=$'\t' read -r p b v s _abs <<<"$l"
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"path":"%s","branch":"%s","verdict":"%s","size":"%s"}' "$p" "$b" "$v" "$s"
  done
  printf '],"branches":['
  first=1
  for l in "${BRANCHES[@]}"; do
    IFS=$'\t' read -r b v <<<"$l"
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"branch":"%s","verdict":"%s"}' "$b" "$v"
  done
  printf ']}\n'
else
  printf 'housekeeping[1]{base,worktrees,branches,reclaimable,unpushed,dirty,in_use}:\n'
  printf '  "%s",%s,%s,%s,%s,%s,%s\n' "$BASE" "$TOTAL_WT" "$(git branch | wc -l | tr -d ' ')" "$TOTAL_RECLAIM" "$UNPUSHED" "$DIRTY" "$IN_USE"
  printf 'worktrees[%s]{path,branch,verdict,size}:\n' "${#LINES[@]}"
  for l in "${LINES[@]}"; do
    IFS=$'\t' read -r p b v s _abs <<<"$l"
    printf '  "%s","%s","%s","%s"\n' "$p" "$b" "$v" "$s"
  done
  if [ "${#BRANCHES[@]}" -gt 0 ]; then
    printf 'branches[%s]{branch,verdict}:\n' "${#BRANCHES[@]}"
    for l in "${BRANCHES[@]}"; do
      IFS=$'\t' read -r b v <<<"$l"
      printf '  "%s","%s"\n' "$b" "$v"
    done
  fi
fi

if [ "$CMD" = "check" ]; then
  if [ "$UNPUSHED" -gt 0 ] || [ "$DIRTY" -gt 0 ]; then
    printf 'housekeeping[1]{state}:\n  "unpushed-work","%s worktree/branch(es) carry work that exists only here — push or merge before anything is reclaimed"\n' "$UNPUSHED"
    exit 1
  fi
  printf 'housekeeping[1]{state}:\n  "clean","nothing unpushed; %s item(s) reclaimable"\n' "$TOTAL_RECLAIM"
  exit 0
fi

if [ "$CMD" = "clean" ]; then
  if [ "$YES" = 0 ]; then
    printf 'plan[%s]{action,target,why}:\n' "$TOTAL_RECLAIM"
    for l in "${LINES[@]}"; do
      IFS=$'\t' read -r p b v s _abs <<<"$l"
      case "$v" in reclaimable:merged) ;; reclaimable:pushed) [ "$MERGED_ONLY" = 1 ] && continue ;; reclaimable:*) ;; *) continue ;; esac
      case "$v" in reclaimable:*) printf '  "worktree-remove","%s (%s, %s)","%s"\n' "$p" "$b" "$s" "$v" ;; esac
    done
    for l in "${BRANCHES[@]}"; do
      IFS=$'\t' read -r b v <<<"$l"
      case "$v" in
        reclaimable:merged) ;;
        reclaimable:pushed) [ "$MERGED_ONLY" = 1 ] && continue ;;
        reclaimable:*) ;;
        *) continue ;;
      esac
      printf '  "branch-delete","%s","%s"\n' "$b" "$v"
    done
    printf 'nothing was removed. re-run with --yes to reclaim.\n'
    exit 0
  fi

  WT_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname)/.yggdrasil"
  [ -d "$WT_ROOT" ] || WT_ROOT="$ROOT/.yggdrasil"
  removed=0; freed_before="$(du -sh "$WT_ROOT" 2>/dev/null | awk '{print $1}')"
  for l in "${LINES[@]}"; do
    IFS=$'\t' read -r p b v s _abs <<<"$l"
    case "$v" in
      reclaimable:merged) ;;
      reclaimable:pushed) [ "$MERGED_ONLY" = 1 ] && continue ;;
      *) continue ;;
    esac
    # `$_abs` is the ABSOLUTE path git reported; the first field is the short display index.
    # Using the display index here is what made one run remove nothing at all.
    full="$_abs"
    [ -d "$full" ] || continue
    # Double guard: re-ask the verdict immediately before touching it.
    now="$(verdict "$full" "$b")"
    case "$now" in reclaimable:*) ;; *) printf '  refused:"%s" changed to %s\n' "$p" "$now"; continue ;; esac
    if git worktree remove "$full" 2>/dev/null; then
      printf '  removed-worktree:"%s" (%s)\n' "$p" "$s"; removed=$((removed + 1))
    else
      printf '  kept:"%s" (git refused to remove it)\n' "$p"
    fi
  done
  git worktree prune 2>/dev/null || true

  for l in "${BRANCHES[@]}"; do
    IFS=$'\t' read -r b v <<<"$l"
    case "$v" in
      reclaimable:merged) ;;
      reclaimable:pushed) [ "$MERGED_ONLY" = 1 ] && continue ;;
      *) continue ;;
    esac
    # `git branch -d` judges "merged" against the CURRENT HEAD, and this checkout may sit on
    # a feature branch (it did: feat/snotra-letter), so a branch fully merged into main was
    # refused. The safety proof is the one the verdict already made — the tip is an ancestor
    # of the base — so -D is used ONLY under that proof, and said out loud.
    if git merge-base --is-ancestor "$b" "$BASE" 2>/dev/null; then
      git branch -D "$b" >/dev/null 2>&1 && { printf '  removed-branch:"%s"\n' "$b"; removed=$((removed + 1)); } \
        || printf '  kept-branch:"%s" (git refused)\n' "$b"
    else
      git branch -d "$b" >/dev/null 2>&1 && { printf '  removed-branch:"%s"\n' "$b"; removed=$((removed + 1)); } \
        || printf '  kept-branch:"%s" (not merged)\n' "$b"
    fi
  done

  printf 'housekeeping[1]{removed,freed_overall}:\n  %s,"%s (whole .yggdrasil now)"\n' "$removed" "$(du -sh "$WT_ROOT" 2>/dev/null | awk '{print $1}')"
  [ -n "${freed_before:-}" ] && printf 'was %s\n' "$freed_before"
  exit 0
fi

exit 0
