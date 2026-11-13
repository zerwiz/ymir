#!/usr/bin/env bash
# main-tree.sh — THE TREE THE LAUNCHERS POINT AT, which is never a worktree.
#
# THE LAW (the Allfather, 2026-11-08): *"they all ned to point to main and the updater needs to pull main
# the apps run time must be locked to main. otherwise they might break if the user are swithing threes"*.
#
# And it broke exactly that way: the launcher entries were seated from a worktree
# (`~/ymir/.yggdrasil/areas-of-a-project/apps/rodd/start.sh`), so every desktop button opened a working copy
# that a session would later delete or leave without node_modules.
#
# HOW IT KNOWS: a worktree's `.git` is a FILE pointing at the common dir; the primary checkout's `.git` is a
# DIRECTORY. `git rev-parse --git-common-dir` answers both, and its parent is the canonical tree.
#
#   main-tree.sh            # print the canonical checkout
#   main-tree.sh --check    # 0 when the tree in $PWD is already canonical, 1 when it is a worktree
#
# Exit: 0 resolved · 1 cannot resolve (a caller must refuse rather than guess)
set -uo pipefail
check=0; tree="${PWD}"
for a in "$@"; do case "$a" in --check) check=1 ;; *) tree="$a" ;; esac; done
here="$(cd "$tree" && pwd -P)"   # physical: a pin that is a link to a release is that release, not a worktree
common="$(git -C "$here" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
  printf 'main-tree: %s is not a git checkout\n' "$here" >&2; exit 1; }
canon="$(dirname "$common")"
[ -d "$canon" ] || { printf 'main-tree: the common dir resolves nowhere (%s)\n' "$common" >&2; exit 1; }
if [ "$check" = 1 ]; then
  canon_real="$(cd "$canon" && pwd -P)"
  [ "$canon_real" = "$here" ] && { printf 'main-tree: canonical (%s)\n' "$canon_real"; exit 0; }
  printf 'main-tree: this is a WORKTREE (%s); the canonical tree is %s\n' "$here" "$canon_real"; exit 1
fi
printf '%s\n' "$canon"
