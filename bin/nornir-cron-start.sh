#!/usr/bin/env bash
# nornir-cron-start.sh - ensure Brokk's scheduled jobs are running (idempotent).
#
# Nornir are the fates who govern time. Jobs are declared in config/cron.yaml as
# `HH:MM <command>` lines (one per line, `#` comments). This script keeps exactly
# one lightweight scheduler loop alive via state/cron.pid. The loop:
#   * date-guards each job under state/.cron-fired/<job> so it runs once a day,
#     even across a restarted loop;
#   * runs each command with a per-job flock so a slow job never overlaps itself;
#   * exports the BROKK_* home/state/config/root env to every job;
#   * runs jobs from BROKK_HOME and logs to state/cron.log.
#
# Ported concept from plan 24 (cron schedule) and the upstream stateless-spawn
# pattern for plan 29.
#
# Usage: nornir-cron-start.sh [--status|--stop]
#
# Environment (kept from the original interface):
#   BROKK_ROOT_OVERRIDE, BROKK_HOME, BROKK_STATE_OVERRIDE, BROKK_CONFIG_OVERRIDE
#   BROKK_CRON_LOG_MAX_BYTES  rotation threshold for state/cron.log (default 1 MiB)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-$BROKK_HOME/config}"
CRON_CONFIG="$CONFIG/cron.yaml"
PID_FILE="$STATE/cron.pid"
LOG_FILE="$STATE/cron.log"
STAMP_DIR="$STATE/.cron-fired"
LOCK_DIR="$STATE/.cron-locks"
IDENTITY_MARK='cron run:'

mkdir -p "$STATE"

job_count() {
  [ -r "$CRON_CONFIG" ] || { printf '0'; return; }
  grep -vE '^[[:space:]]*(#|$)' "$CRON_CONFIG" 2>/dev/null | wc -l | tr -d '[:space:]'
}

# A live loop is a live pid whose command line still carries the scheduler body.
# The identity check guards against pid reuse after a reboot/crash.
running_pid() {
  [ -r "$PID_FILE" ] || return 1
  local pid
  pid=$(tr -d '[:space:]' <"$PID_FILE")
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -r "/proc/$pid/cmdline" ]; then
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "$IDENTITY_MARK" || return 1
  fi
  printf '%s' "$pid"
}

rotate_log() {
  [ -r "$LOG_FILE" ] || return 0
  local size max
  size=$(wc -c <"$LOG_FILE" 2>/dev/null | tr -d '[:space:]')
  case "$size" in ''|*[!0-9]*) return 0 ;; esac
  max="${BROKK_CRON_LOG_MAX_BYTES:-1048576}"
  if [ "$size" -gt "$max" ]; then
    mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
  fi
}

scheduler='
  config="$1"; log="$2"; state="$3"; home="$4"; confdir="$5"; root="$6"
  export BROKK_HOME="$home"
  export BROKK_STATE_OVERRIDE="$state"
  export BROKK_CONFIG_OVERRIDE="$confdir"
  export BROKK_ROOT_OVERRIDE="$root"
  export BROKK_REALM="${BROKK_REALM:-}"
  stamp_dir="$state/.cron-fired"
  lock_dir="$state/.cron-locks"
  mkdir -p "$stamp_dir" "$lock_dir"
  while :; do
    now=$(date +%H:%M)
    today=$(date +%Y-%m-%d)
    while IFS= read -r line; do
      case "$line" in ""|\#*) continue ;; esac
      at=${line%% *}
      cmd=${line#* }
      [ -n "$cmd" ] || continue
      [ "$at" = "$now" ] || continue
      key=$(printf "%s" "$cmd" | tr -c "A-Za-z0-9._-" "_")
      stamp="$stamp_dir/$key"
      if [ -r "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$today" ]; then continue; fi
      printf "%s\n" "$today" >"$stamp"
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      printf "%s cron run: %s\n" "$ts" "$cmd" >>"$log"
      lock="$lock_dir/$key.lock"
      if command -v flock >/dev/null 2>&1; then
        ( flock -n 8 || { printf "%s cron skip (busy): %s\n" "$ts" "$cmd" >>"$log"; exit 0; }
          cd "$home" 2>/dev/null || true
          bash -lc "$cmd" >>"$log" 2>&1
        ) 8>>"$lock" &
      else
        ( cd "$home" 2>/dev/null || true; bash -lc "$cmd" >>"$log" 2>&1 ) &
      fi
    done <"$config"
    sleep 45
  done
'

case "${1-}" in
  --status)
    if pid=$(running_pid); then
      printf 'cron: running pid=%s jobs=%s\n' "$pid" "$(job_count)"
    else
      printf 'cron: stopped jobs=%s\n' "$(job_count)"
    fi
    exit 0
    ;;
  --stop)
    if pid=$(running_pid); then
      kill "$pid" 2>/dev/null || true
      rm -f "$PID_FILE"
      printf 'cron: stopped pid=%s\n' "$pid"
    else
      rm -f "$PID_FILE" 2>/dev/null || true
      printf 'cron: already stopped\n'
    fi
    exit 0
    ;;
esac

if pid=$(running_pid); then
  printf 'cron: running pid=%s jobs=%s\n' "$pid" "$(job_count)"
  exit 0
fi

jobs=$(job_count)
if [ "$jobs" = "0" ]; then
  printf 'cron: no jobs configured (%s absent or empty)\n' "$CRON_CONFIG"
  exit 0
fi

mkdir -p "$STAMP_DIR" "$LOCK_DIR"
rotate_log

if command -v setsid >/dev/null 2>&1; then
  setsid bash -c "$scheduler" _ "$CRON_CONFIG" "$LOG_FILE" "$STATE" "$BROKK_HOME" "$CONFIG" "$ROOT" >>"$LOG_FILE" 2>&1 &
else
  nohup bash -c "$scheduler" _ "$CRON_CONFIG" "$LOG_FILE" "$STATE" "$BROKK_HOME" "$CONFIG" "$ROOT" >>"$LOG_FILE" 2>&1 &
fi
loop_pid=$!
printf '%s\n' "$loop_pid" >"$PID_FILE"
printf 'cron: started pid=%s jobs=%s\n' "$loop_pid" "$jobs"
