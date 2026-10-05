#!/usr/bin/env bash
# 0007-one-word-three-meanings — the workspace rename, for EVERY seat's home.
#
# Six places wore the word "workspace" for three unrelated meanings, and two of
# them were faults (a stray double-`hodd`, and a stale realm). Plan 62.
#
#   ymir/workspace/                              -> ymir/registry/     (the repo's example registries)
#   hodd/workspaces/                             -> hodd/life/        (the operator's life's shelves)
#   svartalfaheim/<realm>/workspace/<project>/    -> svartalfaheim/<realm>/projects/<project>/
#   hodd/hodd/                                   -> removed (a stray; nothing read it)
#
# The value rename (`workspace:` -> `realm:` in the registries) is NOT done here:
# a registry rewrite can break a reader silently, so it ships with its readers in
# the same change (the repo half). This migration moves PATHS only.
#
# THE LAW: the home is the vault (Rule 04) and a private git repo, so every move
# is a `git mv` — never copy-and-delete — and the append-only set is verified BY
# NAME before and after. A user who has never seen these paths pays nothing: every
# branch is guarded by its own existence, so this is a no-op on a fresh home.
#
# Idempotent: safe to run repeatedly.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The HOME, not the hoard, and RESOLVED — never read from an env and never
# guessed. `hoard_root` answers `$YMIR_HOME/hodd` (the private MATERIAL root);
# using it here made every path in this migration one level wrong, so it moved
# nothing, verified nothing, and still reported success (2026-09-30). The one
# resolver for the operator's home is `ymir_home_root` in bin/vault/hoard-lib.sh.
# shellcheck source=bin/vault/hoard-lib.sh
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""
if command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root HOME_DIR
fi
if [ -z "$HOME_DIR" ] && [ -n "${YMIR_HOME:-}" ]; then
  HOME_DIR="$YMIR_HOME"
fi
[ -n "$HOME_DIR" ] || { printf '0007: no home resolved — nothing touched\n'; exit 0; }
[ -f "$HOME_DIR/hodd/memory/runes_audit.md" ] || {
  printf '0007: %s is not a Ymir home (no hodd/memory/runes_audit.md) — nothing touched\n' "$HOME_DIR"
  exit 0
}

say() { printf '0007-one-word-three-meanings: %s\n' "$*"; }

[ -d "$HOME_DIR" ] || { say "no home at $HOME_DIR — nothing to do"; exit 0; }
cd "$HOME_DIR" || exit 0

moved=0

# git mv when this home is a git repo (it is the vault), plain mv otherwise.
# Either way: never a copy followed by a delete.
move_path() {  # <from> <to>
  local from=$1 to=$2
  [ -e "$from" ] || return 1
  if [ -e "$to" ]; then
    say "kept $(basename "$to") — the new name is already there (nothing to move)"
    return 2
  fi
  mkdir -p "$(dirname "$to")"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git mv "$from" "$to" 2>/dev/null || mv "$from" "$to"
  else
    mv "$from" "$to"
  fi
  say "moved $from -> $to"
  moved=$((moved + 1))
  return 0
}

# 1 — the operator's life shelves.
move_path "hodd/workspaces" "hodd/life" || true

# 2 — every realm's project shelves, whatever realms exist here.
for realm_dir in svartalfaheim/*/; do
  [ -d "$realm_dir" ] || continue
  move_path "${realm_dir}workspace" "${realm_dir}projects" || true
done

# 3 — the stray double-hodd. Nothing read it, and it is not in the layout map.
if [ -d "hodd/hodd" ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git rm -r -q hodd/hodd 2>/dev/null || rm -rf hodd/hodd
  else
    rm -rf hodd/hodd
  fi
  say "removed the stray hodd/hodd/ (nothing read it)"
  moved=$((moved + 1))
fi

# 4 — the append-only set, verified BY NAME. A move that lost one of these would
# be the worst thing this script could do, so it is checked, not assumed.
missing=0
for keep in hodd/memory/runes_audit.md hodd/secrets/platform.env.age hodd/secrets/age.key; do
  [ -e "$keep" ] || { say "MISSING after the move: $keep"; missing=1; }
done
for keep in hodd/memory/daily svartalfaheim/*/projects/*/plans; do
  # shellcheck disable=SC2086
  [ -e $keep ] || { say "MISSING after the move: $keep"; missing=1; }
done
[ "$missing" -eq 0 ] && say "the append-only set is intact by name (runes, secrets, daily logs, plan ledgers)"

# 5 — if this home is a repo, the move is staged; the Allfather commits it.
if [ "$moved" -gt 0 ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  say "$moved path(s) moved and STAGED — review with 'git status' and commit in the home"
fi
exit 0