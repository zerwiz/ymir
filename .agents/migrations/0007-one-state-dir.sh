#!/usr/bin/env bash
# 0007-one-state-dir — retire the code-tree state/ decoy: it becomes a symlink.
#
# Runtime state belongs to the operator's home ($YMIR_HOME/state), resolved
# through bin/hoard-lib.sh (Rule 04). The code tree kept a SECOND `state/`; a
# reader that resolved the tree saw a dead session and stood down (2026-09-25: a
# live arm read as dead because state/.lock held a dead pid). Deleting the decoy
# is not enough — a script whose BROKK_HOME is unset still falls back to
# `$ROOT/state`. So the tree keeps the NAME and drops the DIRECTORY: `state`
# becomes a SYMLINK to the home's state, and every fallback resolves to the one
# truth. Nothing is lost: entries are moved into the home's state, duplicates
# into `.recovered-tree-state/`.
#
# Idempotent: safe to run repeatedly.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TREE_STATE="$ROOT/state"

# shellcheck source=bin/hoard-lib.sh
. "$ROOT/bin/hoard-lib.sh" 2>/dev/null || true
hoard_state_dir HOARD_STATE 2>/dev/null || true
HOARD_STATE="${HOARD_STATE:-${YMIR_STATE_DIR:-}}"
if [ -z "${HOARD_STATE:-}" ]; then
  echo "0007-one-state-dir: cannot resolve the operator state dir (bin/hoard-lib.sh) — skipping"
  exit 0
fi

if [ -L "$TREE_STATE" ]; then
  target="$(readlink "$TREE_STATE" 2>/dev/null || true)"
  if [ "$target" = "$HOARD_STATE" ]; then
    echo "0007-one-state-dir: already one state dir (state -> $target)"
    exit 0
  fi
  echo "0007-one-state-dir: retargeting state -> $HOARD_STATE (was $target)"
  rm -f "$TREE_STATE"
fi

if [ -d "$TREE_STATE" ]; then
  mkdir -p "$HOARD_STATE"
  moved=0; recovered=0; kept=0
  shopt -s dotglob nullglob
  for f in "$TREE_STATE"/*; do
    base="$(basename "$f")"
    if [ "$base" = ".gitkeep" ]; then rm -f "$f"; continue; fi
    if [ -e "$HOARD_STATE/$base" ]; then
      mkdir -p "$HOARD_STATE/.recovered-tree-state"
      dest="$HOARD_STATE/.recovered-tree-state/$base"; n=1
      while [ -e "$dest" ]; do dest="$dest.$n"; n=$((n+1)); done
      if cp -a "$f" "$dest" 2>/dev/null; then rm -rf "$f"; recovered=$((recovered+1)); else kept=$((kept+1)); fi
    else
      if cp -a "$f" "$HOARD_STATE/$base" 2>/dev/null; then rm -rf "$f"; moved=$((moved+1)); else kept=$((kept+1)); fi
    fi
  done
  shopt -u dotglob nullglob
  echo "0007-one-state-dir: retired the tree state/ ($moved moved, $recovered recovered as duplicates, $kept kept)"
  if ! rmdir "$TREE_STATE" 2>/dev/null; then
    echo "0007-one-state-dir: entries remain in $TREE_STATE (kept above) — NOT linking; re-run after they are moved" >&2
    exit 1
  fi
fi

[ -e "$TREE_STATE" ] || ln -s "$HOARD_STATE" "$TREE_STATE"
echo "0007-one-state-dir: state -> $(readlink "$TREE_STATE" 2>/dev/null || printf '%s' "$TREE_STATE")"
echo "0007-one-state-dir: done"
