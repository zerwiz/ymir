#!/usr/bin/env bash
# nornir-job-git-sync.sh - Yggdrasil, the world-tree kept in order.
#
# Configurable git sync/backup for Ymir and its realm workspaces. Two modes:
#   fetch  (default, safe)  fetch --prune, then fast-forward ONLY (--ff-only).
#   push   (opt-in)         commit local work, then push. Never force.
#
# Laws this job obeys:
#   * never force anything (no --force, no reset, no checkout, no clean);
#   * never discard unlanded work — a dirty tree is committed, not stashed;
#   * a target that is not a git repo, has no remote, or has diverged is
#     reported plainly and left untouched.
#
# Config (all optional):
#   BROKK_GIT_SYNC_MODE      fetch | push            (default fetch)
#   BROKK_GIT_SYNC_REMOTE    remote name             (default origin)
#   BROKK_GIT_SYNC_TARGETS   colon-separated repo paths (default: auto-discover)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
# shellcheck source=bin/runes-append.sh
. "$SCRIPT_DIR/runes-append.sh"

MODE="${BROKK_GIT_SYNC_MODE:-fetch}"
REMOTE="${BROKK_GIT_SYNC_REMOTE:-origin}"
REALM="${BROKK_REALM:-}"
if [ -z "$REALM" ] && [ -r "$DATA/realm.md" ]; then
  REALM=$(head -n 1 "$DATA/realm.md" 2>/dev/null | tr -d '[:space:]')
fi
REALM="${REALM:-wayof}"
STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

command -v git >/dev/null 2>&1 || { printf 'error: git not installed\nhelp: install git and re-run\n'; exit 1; }

if [ "$MODE" != "fetch" ] && [ "$MODE" != "push" ]; then
  printf 'error: unknown BROKK_GIT_SYNC_MODE=%s\nhelp: use fetch (safe) or push (opt-in)\n' "$MODE"
  exit 2
fi

discover_targets() {
  if [ -n "${BROKK_GIT_SYNC_TARGETS:-}" ]; then
    printf '%s\n' "$BROKK_GIT_SYNC_TARGETS" | tr ':' '\n'
    return 0
  fi
  [ -d "$BROKK_HOME/.git" ] && printf '%s\n' "$BROKK_HOME"
  [ -d "$BROKK_HOME/workspace/.git" ] && printf '%s\n' "$BROKK_HOME/workspace"
  [ -d "$BROKK_HOME/midgard/.git" ] && printf '%s\n' "$BROKK_HOME/midgard"
  for d in "$BROKK_HOME"/svartalfaheim/*; do
    [ -d "$d" ] || continue
    [ -d "$d/.git" ] && printf '%s\n' "$d"
    [ -d "$d/workspace/.git" ] && printf '%s\n' "$d/workspace"
    for p in "$d"/projects/*; do
      [ -d "$p/.git" ] && printf '%s\n' "$p"
    done
  done
  return 0
}

total=0
ok=0
skipped=0
failed=0

printf 'GIT SYNC - %s mode=%s remote=%s realm=%s\n' "$STAMP" "$MODE" "$REMOTE" "$REALM"

while IFS= read -r target; do
  [ -n "$target" ] || continue
  total=$((total + 1))
  if ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'target: skip (not a git repo) %s\n' "$target"
    runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "skip non-repo $target" >/dev/null 2>&1 || true
    skipped=$((skipped + 1))
    continue
  fi
  if ! git -C "$target" remote get-url "$REMOTE" >/dev/null 2>&1; then
    printf 'target: skip (no remote %s) %s\n' "$REMOTE" "$target"
    runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "skip no-remote($REMOTE) $target" >/dev/null 2>&1 || true
    skipped=$((skipped + 1))
    continue
  fi

  branch=$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '?')

  if [ "$MODE" = "fetch" ]; then
    if ! git -C "$target" fetch --prune "$REMOTE" >>/dev/null 2>&1; then
      printf 'target: fetch FAILED %s (%s)\n' "$target" "$branch"
      runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "fetch failed $target ($branch)" >/dev/null 2>&1 || true
      failed=$((failed + 1))
      continue
    fi
    upstream=$(git -C "$target" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    if [ -z "$upstream" ]; then
      printf 'target: fetched (no upstream tracked) %s (%s)\n' "$target" "$branch"
      runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "fetched no-upstream $target ($branch)" >/dev/null 2>&1 || true
      ok=$((ok + 1))
      continue
    fi
    if git -C "$target" merge --ff-only "$upstream" >>/dev/null 2>&1; then
      printf 'target: fast-forward OK %s (%s -> %s)\n' "$target" "$branch" "$upstream"
      runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "ff-only ok $target ($branch <- $upstream)" >/dev/null 2>&1 || true
      ok=$((ok + 1))
    else
      printf 'target: DIVERGED - ff-only refused, left untouched %s (%s)\n' "$target" "$branch"
      runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "diverged ff-only refused $target ($branch)" >/dev/null 2>&1 || true
      failed=$((failed + 1))
    fi
  else
    dirty=$(git -C "$target" status --porcelain 2>/dev/null || true)
    if [ -n "$dirty" ]; then
      git -C "$target" add -A >/dev/null 2>&1 || true
      if git -C "$target" commit -m "nornir git-sync $STAMP" >>/dev/null 2>&1; then
        printf 'target: committed local work %s (%s)\n' "$target" "$branch"
      else
        printf 'target: commit skipped (nothing staged) %s\n' "$target"
      fi
    fi
    upstream=$(git -C "$target" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    if [ -n "$upstream" ]; then
      if git -C "$target" push "$REMOTE" HEAD >>/dev/null 2>&1; then
        printf 'target: pushed %s (%s)\n' "$target" "$branch"
        ok=$((ok + 1))
      else
        printf 'target: push REJECTED (no force used) %s (%s)\n' "$target" "$branch"
        failed=$((failed + 1))
      fi
    else
      if git -C "$target" push -u "$REMOTE" HEAD >>/dev/null 2>&1; then
        printf 'target: pushed and set upstream %s (%s)\n' "$target" "$branch"
        ok=$((ok + 1))
      else
        printf 'target: push REJECTED (no force used) %s (%s)\n' "$target" "$branch"
        failed=$((failed + 1))
      fi
    fi
  fi
done <<EOF
$(discover_targets)
EOF

if [ "$total" = "0" ]; then
  summary="no git targets found under $BROKK_HOME (mode=$MODE)"
  printf 'git-sync: %s\n' "$summary"
else
  summary="targets=$total ok=$ok skipped=$skipped failed=$failed mode=$MODE"
  printf 'git-sync: %s\n' "$summary"
fi
runes_append "yggdrasil" "git.sync" --realm "$REALM" --message "$summary" >/dev/null 2>&1 || printf 'git-sync: rune append failed (non-fatal)\n'
