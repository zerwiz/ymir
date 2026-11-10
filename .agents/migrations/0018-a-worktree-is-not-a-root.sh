#!/usr/bin/env bash
# 0018-a-worktree-is-not-a-root — heal the two faults that made every Eindri worktree
# lie about the repository it stands in (measured 2026-11-10).
#
# WHY (both found by hand on the heart seat, both reaching every user who installs or
# updates Ymir):
#
#   (a) `.pi/extensions/` in an Eindri worktree. `einherjar-spawn.sh` deleted the
#       worktree's copy and then ran `git update-index --assume-unchanged .pi/extensions`
#       — but assume-unchanged is a PER-FILE bit, and it does nothing for a directory.
#       So `git status` in every worktree reported all 45 extension files as DELETED,
#       and a worker running `git add -A` (or `commit -a`) would have deleted every pi
#       extension from the repository. The fix is git's own per-worktree mechanism,
#       the same one `bin/forge/yggdrasil.sh` already used:
#         git sparse-checkout set --no-cone '/*' '!/.pi/extensions/'
#       Worktrees cut before the fix still carry the broken INDEX, so this migration
#       heals them in place: clear the stale bit, set the exclusion, prove clean.
#
#   (b) `~/.pi/agent/extensions/.ymir-root` recorded a `.yggdrasil/` WORKTREE as a
#       root, because `bin/seat/valknut-load.sh --pi` was once run from inside one. A
#       root is a HOME; a worktree is an ERRAND and dies with it. The transient path
#       was found and removed by hand; everywhere else it is still there.
#
# WHAT IT DOES — two idempotent repairs, nothing else:
#   1. prune every linked-worktree / `.yggdrasil/` path from `.ymir-root`, keeping a
#      dated backup beside it (`<pointer>.pre-0018`) before the first rewrite;
#   2. for every worktree under `.yggdrasil/` that still shows the broken state,
#      switch it to the sparse-checkout exclusion and DELETE NOTHING from the index
#      by hand — git owns the skip-worktree bit.
#
# WHAT IT DELIBERATELY DOES NOT DO:
#   * it never removes a worktree, a branch or a commit (that is
#     `bin/forge/housekeeping.sh`, and only with the Allfather's approval);
#   * it never touches a worktree whose `.pi/extensions` is genuinely absent and whose
#     status is already clean;
#   * it never rewrites a root that is a real home — the record keeps them all, in
#     order, exactly as the resolver expects.
#
# Idempotent: a second run prints "clean" for the roots and "clean" for every worktree.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || { . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && ymir_home_root HOME_DIR; }

say() { printf '0018: %s\n' "$1"; }

# The one test git offers: in a linked worktree `--git-common-dir` names the main
# repo's git directory while `--git-dir` names this worktree's own, so they differ.
# (The same expression lives in bin/seat/valknut-load.sh's is_linked_worktree.)
is_linked_worktree() {  # <path>
  local p=${1:-.} common own
  common="$(git -C "$p" rev-parse --git-common-dir 2>/dev/null)" || return 1
  own="$(git -C "$p" rev-parse --git-dir 2>/dev/null)" || return 1
  [ -n "$common" ] && [ -n "$own" ] || return 1
  [ "$(CDPATH='' cd "$p" && CDPATH='' cd "$common" 2>/dev/null && pwd -P)" \
    = "$(CDPATH='' cd "$p" && CDPATH='' cd "$own" 2>/dev/null && pwd -P)" ] && return 1
  return 0
}

# ── 1. the root record ───────────────────────────────────────────────────────
pointer="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}/.ymir-root"
if [ -r "$pointer" ]; then
  tmp="$(mktemp)" || exit 1
  : >"$tmp"
  pruned=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      */.yggdrasil/*|*/.yggdrasil) pruned=$((pruned + 1)); continue ;;
    esac
    if [ -d "$line" ] && is_linked_worktree "$line"; then pruned=$((pruned + 1)); continue; fi
    printf '%s\n' "$line" >>"$tmp"
  done <"$pointer"
  if [ "$pruned" -gt 0 ]; then
    cp "$pointer" "$pointer.pre-0018" 2>/dev/null || true
    mv "$tmp" "$pointer"
    say "root record: pruned $pruned linked-worktree path(s) from .ymir-root (backup: $(basename "$pointer").pre-0018)"
  else
    rm -f "$tmp"
    say "root record: clean — no worktree is recorded as a root"
  fi
  if [ ! -s "$pointer" ]; then
    say "root record: EMPTY after pruning — re-seat it from the real checkout: bin/seat/valknut-load.sh --pi"
  fi
else
  say "root record: no .ymir-root on this seat (nothing recorded yet)"
fi

# ── 2. the worktrees that still carry the broken index state ─────────────────
if ! command -v git >/dev/null 2>&1; then
  say "worktrees: no git — skipped"
  exit 0
fi
base="${BROKK_ROOT_OVERRIDE:-$ROOT}"
wt_dir="$base/.yggdrasil"
# A cache of worktrees is only a hint: the real list is git's own.
wt_list="$(git -C "$base" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')"
[ -n "$wt_list" ] || wt_list="$(ls -d "$wt_dir"/*/ 2>/dev/null | sed 's:/$::')"
healed=0; clean=0; failed=0
while IFS= read -r wt; do
  [ -n "$wt" ] || continue
  case "$wt" in */.yggdrasil/*) ;; *) continue ;; esac
  [ -d "$wt/.git" ] || [ -f "$wt/.git" ] || continue
  dirty_before="$(git -C "$wt" status --porcelain 2>/dev/null)"
  # The tell: deletions under .pi/extensions. Nothing else in this migration's scope.
  exts_gone="$(printf '%s\n' "$dirty_before" | grep -c '^ \{0,1\}D  *\.pi/extensions/')"
  if [ "$exts_gone" = 0 ] && [ -z "$dirty_before" ]; then
    clean=$((clean + 1)); continue
  fi
  git -C "$wt" update-index --no-assume-unchanged .pi/extensions 2>/dev/null || true
  if git -C "$wt" sparse-checkout set --no-cone '/*' '!/.pi/extensions/' >/dev/null 2>&1 \
     && [ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
    healed=$((healed + 1))
  else
    failed=$((failed + 1))
    say "worktree NOT healed: $wt — run: git -C $wt sparse-checkout set --no-cone '/*' '!/.pi/extensions/'"
  fi
done <<<"$wt_list"
say "worktrees: $healed healed to the sparse-checkout exclusion, $clean already clean, $failed need a hand"
say "done — a worktree excludes the extension tree by git's own rule, and no worktree is a root"
