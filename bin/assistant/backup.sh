#!/usr/bin/env bash
# backup.sh — his ledger must survive this disk.
#
#   bin/assistant/backup.sh [--keep N] [--commit]
#
# `hodd/state/` is gitignored, so `assistant.db` — every question anyone asked him, every refusal,
# every answer — is the ONE artifact in this house that dies with the hardware (measured 2026-10-22:
# 372 turns in a day, no copy anywhere). This snapshots the ledger and its policy files into
# `hodd/saves/assistant/<date>/`, which IS tracked, and prunes old snapshots.
#
# `--commit` stages and commits the newest snapshot in the home repo (never pushes). That is the
# Allfather's call, which is why it is a flag and not the default.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'backup: the hoard is unresolved\n' >&2; exit 2; }
KEEP=7; COMMIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP="${2:-7}"; shift 2 ;;
    --commit) COMMIT=1; shift ;;
    *) shift ;;
  esac
done
STATE="$HOME_R/hodd/state/assistant"
DEST="$HOME_R/hodd/saves/assistant/$(date +%Y-%m-%d)"
mkdir -p "$DEST" || exit 3
copied=0
for f in assistant.db asks.json digest.jsonl pending-ask.json; do
  [ -f "$STATE/$f" ] || continue
  if command -v sqlite3 >/dev/null 2>&1 && [ "$f" = "assistant.db" ]; then
    sqlite3 "$STATE/$f" ".backup '$DEST/$f'" 2>/dev/null && copied=$((copied+1)) || cp -f "$STATE/$f" "$DEST/$f"
  else
    cp -f "$STATE/$f" "$DEST/$f" && copied=$((copied+1))
  fi
done
[ -d "$HOME_R/hodd/identity/assistant" ] && cp -a "$HOME_R/hodd/identity/assistant/." "$DEST/identity/" 2>/dev/null
# rotate
ls -1d "$HOME_R/hodd/saves/assistant/"*/ 2>/dev/null | sort | head -n -"$KEEP" | while read -r old; do
  rm -rf "$old"
done
printf 'backup[1]{files,dir,kept}:\n  "%s","%s","%s"\n' "$copied" "$DEST" "$KEEP"
if [ "$COMMIT" -eq 1 ] && [ -d "$HOME_R/.git" ]; then
  ( cd "$HOME_R" && git add "hodd/saves/assistant" >/dev/null 2>&1 \
    && git commit -q -m "hoard: skírnir's ledger snapshot $(date +%Y-%m-%d)" >/dev/null 2>&1 \
    && printf 'backup: committed to the home repo\n' ) || printf 'backup: nothing to commit\n'
fi
