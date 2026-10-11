#!/usr/bin/env bash
# well-vault-sync.sh — Kaia's memory across the Allfather's machines.
#
# One memory, one vault. The well (kaia.engram + sidecars + episodes + runes)
# rides the private ymirhome repo; this job checkpoints the engram, stages ONLY
# the named well files (never `git add -A` — unapproved work must not ride),
# commits, and pushes (mode=push) — or fast-forwards from origin (mode=pull).
# Same law as nornir-job-git-sync.sh: never force, never discard, never merge.
#
#   well-vault-sync.sh [--mode push|pull] [--dry-run] [--quiet]
# Env: YMIR_HOME (default ~/Documents/ymirhome)
set -uo pipefail

MODE="${BROKK_WELL_SYNC_MODE:-push}"
DRY=0; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-push}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) shift ;;
  esac
done

say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
# The home is resolved through bin/vault/hoard-lib.sh (Rule 07), never guessed.
_home_root() {
  local lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/../vault" 2>/dev/null && pwd)/hoard-lib.sh"
  [ -r "$lib" ] && . "$lib"
  local h=""; command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root h
  printf '%s' "$h"
}
HOME_REPO="$(_home_root)"
[ -n "$HOME_REPO" ] || { printf 'well-vault-sync: cannot resolve the operator home (bin/vault/hoard-lib.sh missing)\n' >&2; exit 1; }
WELL="$HOME_REPO/hodd/memory"
NAMED=(
  "$WELL/kaia.engram"
  "$WELL/well/episodes.jsonl"
  "$WELL/runes_audit.md"
  "$WELL/runes_audit.wayof-branch.md"
)

[ -d "$HOME_REPO/.git" ] || { say "well-vault-sync: no vault at $HOME_REPO"; exit 1; }
cd "$HOME_REPO" || exit 1

case "$MODE" in
  push)
    # Checkpoint the WAL into the main engram so one binary carries the memory.
    if command -v sqlite3 >/dev/null 2>&1 && [ -f "$WELL/kaia.engram" ]; then
      sqlite3 "$WELL/kaia.engram" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
    fi
    git add -- "${NAMED[@]}" 2>/dev/null
    if git diff --cached --quiet; then
      say "well-vault-sync: nothing new in the well"
      exit 0
    fi
    if [ "$DRY" = 1 ]; then git diff --cached --stat | tail -1; exit 0; fi
    git -c user.name="Brokk" -c user.email="brokk@ymir.local" commit -m "well: Kaia's memory, checkpointed and riding the vault" >/dev/null 2>&1 \
      || { say "well-vault-sync: commit failed"; exit 1; }
    if ! git push origin main >/dev/null 2>&1; then
      say "well-vault-sync: push failed (non-fast-forward?) — pull first or push by hand"
      exit 1
    fi
    say "well-vault-sync: exactly one new well commit pushed"
    ;;
  pull)
    if [ "$DRY" = 1 ]; then say "well-vault-sync: (dry) would pull --ff-only origin main"; exit 0; fi
    if ! git pull --no-rebase --ff-only origin main >/dev/null 2>&1; then
      say "well-vault-sync: pull failed (dirty tree or divergence) — resolve by hand"
      exit 1
    fi
    say "well-vault-sync: pulled — the well is current"
    ;;
  *) say "well-vault-sync: unknown mode $MODE (use push|pull)"; exit 2 ;;
esac