#!/usr/bin/env bash
# well-vault-sync.sh — Kaia's memory across the Allfather's machines.
#
# One memory, one vault. The well's DURABLE artifact is the append log
# (`hodd/memory/well/episodes.jsonl`) — text, append-only, and unionable. The
# engram (`kaia.engram`) is DERIVED from it and lives per-seat, so it is never
# git-merged: a seat keeps its own index (it knows the whole memory even with the
# heart down) and re-seeds it from the union when the log moves.
#
#   export   engram -> log     (nothing is published that the log lacks)
#   union    the log absorbs origin's lines (append-only; never rewritten)
#   reseed   log -> engram     (the local index learns what the union holds)
#
# Same law as nornir-job-git-sync.sh: never force, never discard, never merge a
# rewrite. The lead machine publishes; every machine subscribes and stays whole.
#
#   well-vault-sync.sh [--mode push|pull|sync] [--dry-run] [--quiet]
# Env: YMIR_HOME (default ~/Documents/ymirhome)
set -uo pipefail

MODE="${BROKK_WELL_SYNC_MODE:-sync}"
DRY=0; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-sync}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) shift ;;
  esac
done

say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGTOOL="$HERE/../records/mimir-log.sh"
# The home is resolved through bin/vault/hoard-lib.sh (Rule 07), never guessed.
_home_root() {
  local lib="$(cd "$HERE/../vault" 2>/dev/null && pwd)/hoard-lib.sh"
  [ -r "$lib" ] && . "$lib"
  local h=""; command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root h
  printf '%s' "$h"
}
HOME_REPO="$(_home_root)"
[ -n "$HOME_REPO" ] || { printf 'well-vault-sync: cannot resolve the operator home (bin/vault/hoard-lib.sh missing)\n' >&2; exit 1; }
WELL="$HOME_REPO/hodd/memory"
LOG_REL="hodd/memory/well/episodes.jsonl"
LOG="$HOME_REPO/$LOG_REL"
BRANCH="${BROKK_WELL_BRANCH:-main}"

[ -d "$HOME_REPO/.git" ] || { say "well-vault-sync: no vault at $HOME_REPO"; exit 1; }
[ -x "$LOGTOOL" ] || { say "well-vault-sync: the log tool is missing at $LOGTOOL"; exit 1; }
cd "$HOME_REPO" || exit 1

# Bring our own index into the log first: never publish, never union, and never
# reseed from a log that is behind this seat's own memory.
export_index() { "$LOGTOOL" export ${QUIET:+--quiet} >/dev/null 2>&1 || true; }

do_push() {
  export_index
  git add -- "$LOG_REL" 2>/dev/null
  if git diff --cached --quiet; then say "well-vault-sync: nothing new in the well"; return 0; fi
  if [ "$DRY" = 1 ]; then git diff --cached --stat | tail -1; return 0; fi
  git -c user.name="Brokk" -c user.email="brokk@ymir.local" \
      commit -m "well: Kaia's memory, checkpointed and riding the vault" >/dev/null 2>&1 \
    || { say "well-vault-sync: commit failed"; return 1; }
  if ! git push origin "$BRANCH" >/dev/null 2>&1; then
    say "well-vault-sync: push failed (non-fast-forward?) — run --mode pull first"
    return 1
  fi
  say "well-vault-sync: exactly one new well commit pushed"
}

do_pull() {
  export_index
  git fetch -q origin "$BRANCH" 2>/dev/null || { say "well-vault-sync: fetch failed"; return 1; }
  local tmp; tmp="$(mktemp)"
  if git show "origin/$BRANCH:$LOG_REL" >"$tmp" 2>/dev/null; then
    # Append-only union: our own lines stay, origin's are appended where we lack
    # them. The log is never sorted or rewritten.
    "$LOGTOOL" union "$tmp" ${QUIET:+--quiet} >/dev/null 2>&1 || true
  fi
  rm -f "$tmp"
  # The index learns the whole memory, so this seat is whole even alone.
  "$LOGTOOL" reseed ${QUIET:+--quiet} >/dev/null 2>&1 || \
    say "well-vault-sync: reseed skipped (engram engine unavailable on this seat)"
  git add -- "$LOG_REL" 2>/dev/null
  if git diff --cached --quiet; then
    say "well-vault-sync: the well is current"
  elif [ "$DRY" = 1 ]; then
    git diff --cached --stat | tail -1
  else
    git -c user.name="Brokk" -c user.email="brokk@ymir.local" \
        commit -m "well: the log unioned with origin, the index re-seeded" >/dev/null 2>&1 \
      || { say "well-vault-sync: union commit failed"; return 1; }
    say "well-vault-sync: the well absorbed origin and the index re-seeded"
  fi
}

case "$MODE" in
  push) do_push ;;
  pull) do_pull ;;
  sync) do_pull && do_push ;;
  *) say "well-vault-sync: unknown mode $MODE (use push|pull|sync)"; exit 2 ;;
esac
