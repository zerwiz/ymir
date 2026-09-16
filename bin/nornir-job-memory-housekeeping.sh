#!/usr/bin/env bash
# nornir-job-memory-housekeeping.sh - Muninn, the raven of memory.
#
# Nightly engram/memory housekeeping. Muninn (memory) remembers and prunes.
# This job:
#   1. reports the state of the engram/vector store (decay/compress are the
#      engine's job; when no engine is wired it says so, it does not fake it);
#   2. snapshots the memory trees to a compressed backup FIRST;
#   3. only then, and only when explicitly enabled, prunes ephemeral files.
#
# Safety law: never destructive without a backup. If the backup cannot be
# written, no file is removed and the failure is reported plainly.
#
# Environment:
#   BROKK_HOME, BROKK_STATE_OVERRIDE
#   BROKK_BACKUP_DIR     backup target (default $BROKK_HOME/state/backups)
#   BROKK_MEMORY_ROOTS   colon-separated roots (defaults below)
#   BROKK_MIMIR_DB       vector/engram db path to inspect
#   BROKK_MEMORY_PRUNE   set 1 to enable pruning after a successful backup
#   BROKK_MEMORY_PRUNE_DAYS  age threshold for pruning (default 7)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
# shellcheck source=bin/runes-append.sh
. "$SCRIPT_DIR/runes-append.sh"

REALM="${BROKK_REALM:-}"
if [ -z "$REALM" ] && [ -r "$DATA/realm.md" ]; then
  REALM=$(head -n 1 "$DATA/realm.md" 2>/dev/null | tr -d '[:space:]')
fi
REALM="${REALM:-}"
# Never assume the company's slug: resolve the operator's realm neutrally.
if [ -z "$REALM" ]; then . "$SCRIPT_DIR/realm-lib.sh"; ymir_active_realm "$ROOT" REALM; fi

BACKUP_DIR="${BROKK_BACKUP_DIR:-$STATE/backups}"
if [ -n "${BROKK_MEMORY_ROOTS:-}" ]; then
  ROOTS="$BROKK_MEMORY_ROOTS"
else
  ROOTS="$BROKK_HOME/.agents/memory:${YMIR_HOME:-$HOME/Documents/Ymir}/hodd/memory:${YMIR_HOME:-$HOME/Documents/Ymir}/svartalfaheim/$REALM/workspace/memory"
fi
MIMIR_DB="${BROKK_MIMIR_DB:-$BROKK_HOME/.agents/memory/mimirsbrunn.db}"
PRUNE_DAYS="${BROKK_MEMORY_PRUNE_DAYS:-7}"
TODAY=$(date +%Y-%m-%d)
STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

printf 'MUNINN HOUSEKEEPING - %s\n' "$STAMP"

# ---- 1. Engram / vector store state --------------------------------------
if [ -r "$MIMIR_DB" ]; then
  size=$(stat -c '%s' "$MIMIR_DB" 2>/dev/null || printf 0)
  mtime=$(stat -c '%y' "$MIMIR_DB" 2>/dev/null | cut -d'.' -f1)
  printf 'engram: present db=%s size=%sB mtime=%s\n' "$MIMIR_DB" "$size" "$mtime"
  printf 'engram: decay skipped (no vector engine wired); compress handled by engine, not this job\n'
else
  printf 'engram: ABSENT (%s) — decay/compress skipped, nothing to age\n' "$MIMIR_DB"
fi

# ---- 2. Backup (required before any prune) -------------------------------
backup_ok=0
backup_file=""
if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
  printf 'backup: FAILED — cannot create backup target %s; no pruning performed\n' "$BACKUP_DIR"
else
  existing=""
  IFS=':' read -r -a roots_arr <<<"$ROOTS"
  for r in "${roots_arr[@]}"; do
    [ -n "$r" ] || continue
    case "$r" in
      "$BROKK_HOME"/*) rel=${r#"$BROKK_HOME"/}; [ -e "$BROKK_HOME/$rel" ] && existing="$existing $rel" ;;
      *) [ -e "$r" ] && existing="$existing $r" ;;
    esac
  done
  if [ -z "$existing" ]; then
    printf 'backup: no memory roots exist yet (%s) — nothing to snapshot\n' "$ROOTS"
  else
    backup_file="$BACKUP_DIR/memory-$TODAY.tar.gz"
    tmp_backup="$backup_file.tmp.$$"
    # Archive relative paths so a restore is home-relative.
    if tar -czf "$tmp_backup" -C "$BROKK_HOME" $existing 2>/dev/null; then
      mv "$tmp_backup" "$backup_file"
      backup_ok=1
      printf 'backup: wrote %s (%s bytes) from:%s\n' "$backup_file" "$(wc -c <"$backup_file" | tr -d '[:space:]')" "$existing"
    else
      rm -f "$tmp_backup"
      printf 'backup: FAILED to archive memory roots; no pruning performed\n'
    fi
  fi
fi

# ---- 3. Prune (opt-in, backup-gated, never runes/masterplan) -------------
pruned=0
if [ "${BROKK_MEMORY_PRUNE:-0}" = "1" ]; then
  if [ "$backup_ok" != "1" ]; then
    printf 'prune: skipped — backup did not succeed\n'
  else
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rm -f "$f" && { pruned=$((pruned + 1)); printf 'prune: removed %s\n' "$f"; }
    done <<EOF
$(find "$STATE" -maxdepth 1 \( -name '*.tmp' -o -name '*.tmp.*' -o -name '.brief-*.tmp*' \) -mtime +"$PRUNE_DAYS" 2>/dev/null)
EOF
    printf 'prune: removed %s ephemeral file(s) older than %s days\n' "$pruned" "$PRUNE_DAYS"
  fi
else
  printf 'prune: disabled (set BROKK_MEMORY_PRUNE=1 to enable), backup retained\n'
fi

summary="engram=$([ -r "$MIMIR_DB" ] && printf present || printf absent) backup=$([ "$backup_ok" = "1" ] && printf "$backup_file" || printf failed) pruned=$pruned"
printf 'muninn: %s\n' "$summary"
runes_append "muninn" "memory.housekeeping" --realm "$REALM" --message "$summary" >/dev/null 2>&1 || printf 'muninn: rune append failed (non-fatal)\n'
