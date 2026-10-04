#!/usr/bin/env bash
# vor-crew-state.sh - deterministic read of an Eindri worker's CURRENT state.
#
# Vör ("awareness of what is") reconciles the possibly-stale append-only
# state/<id>.status event log against the authoritative endpoint liveness read
# from state/<id>.meta, and emits one stable, parseable, token-tight line:
#
#   state: <working|parked|done|blocked|paused|failed|unknown> · source: <backend|status-log|none> · <detail>
#
# Why this exists: state/<id>.status is an append-only, best-effort event log,
# so `tail -1` reports the last EVENT, not the current STATE. This helper reads
# the rendered backend endpoint (tmux/herdr) recorded in the task meta and
# reconciles the log against it. It never shells out to a model, never infers
# from a tail alone, and is read-only.
#
# Ported from the upstream distro crew-state reconciliation for plan 29
# (memory/plans/core/29-brokk-distro-runtime.md).
#
# Usage: vor-crew-state.sh <task-id>
# Exits 0 on any successful read regardless of state; exit 2 on a usage error.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$ROOT}}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
PAUSED_VERB="${BROKK_PAUSED_VERB:-paused}"
SEP=' · '

ID=${1:-}
[ -n "$ID" ] || { echo "usage: vor-crew-state.sh <task-id>" >&2; exit 2; }

emit() {  # <state> <source> [detail]
  local line="state: $1${SEP}source: $2"
  [ -n "${3:-}" ] && line="$line${SEP}$3"
  printf '%s\n' "$line"
  exit 0
}

META="$STATE/$ID.meta"
LOG="$STATE/$ID.status"
[ -f "$META" ] || emit unknown none "no metadata for $ID"

meta_value() {  # <key>
  grep "^$1=" "$META" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

WT=$(meta_value worktree)
KIND=$(meta_value kind); KIND=${KIND:-ship}
BACKEND=$(meta_value backend); BACKEND=${BACKEND:-tmux}
TARGET=$(meta_value window)

if [ -z "$WT" ] || [ ! -d "$WT" ]; then
  emit unknown none "worktree gone (torn down?)"
fi

log_last_line() {
  [ -f "$LOG" ] || return 1
  grep -v '^[[:space:]]*$' "$LOG" 2>/dev/null | tail -1
}

LOG_LINE=$(log_last_line || true)
LOG_VERB=""
if [ -n "$LOG_LINE" ]; then
  LOG_VERB=${LOG_LINE%%:*}
  LOG_VERB=$(printf '%s' "$LOG_VERB" | tr -d '[:space:]')
fi

# Map a status-log verb onto a canonical state. `resolved` closes a decision
# and is deliberately not a state.
map_log_state() {  # <verb>
  case "$1" in
    working) echo working ;;
    needs-decision) echo parked ;;
    blocked) echo blocked ;;
    done) echo done ;;
    failed) echo failed ;;
    "$PAUSED_VERB") echo "$PAUSED_VERB" ;;
    *) echo unknown ;;
  esac
}

log_detail() {
  printf '%s' "${LOG_LINE#*:}" | sed 's/^[[:space:]]*//'
}

backend_alive() {  # <backend> <target>
  local backend=$1 target=$2
  [ -n "$target" ] || return 1
  case "$backend" in
    tmux) tmux display-message -p -t "$target" '#{pane_id}' >/dev/null 2>&1 ;;
    herdr) herdr pane get "$target" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

if [ -z "$TARGET" ]; then
  # No endpoint recorded: fall back to the status log only when it maps to a
  # recognized run-state, so a trailing `resolved:` never becomes the state.
  if [ -n "$LOG_VERB" ]; then
    LOG_STATE=$(map_log_state "$LOG_VERB")
    if [ "$LOG_STATE" != unknown ]; then
      emit "$LOG_STATE" status-log "$(log_detail)"
    fi
  fi
  emit unknown none "no backend target recorded"
fi

if backend_alive "$BACKEND" "$TARGET"; then
  LOG_STATE=unknown
  [ -n "$LOG_VERB" ] && LOG_STATE=$(map_log_state "$LOG_VERB")
  case "$LOG_STATE" in
    done|failed) emit "$LOG_STATE" status-log "$(log_detail)" ;;
    working|parked|blocked|"$PAUSED_VERB") emit "$LOG_STATE" status-log "$(log_detail)" ;;
    *) emit working backend "endpoint alive: $TARGET" ;;
  esac
fi

# Endpoint is gone. A terminal log verdict is durable truth; otherwise the
# crew has no current-state source.
case "$(map_log_state "$LOG_VERB")" in
  done|failed) emit "$(map_log_state "$LOG_VERB")" status-log "$(log_detail)" ;;
esac
emit unknown none "backend target gone: $TARGET"
