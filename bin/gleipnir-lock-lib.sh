#!/usr/bin/env bash
# gleipnir-lock-lib.sh - per-home session lock for the Brokk runtime.
#
# Gleipnir is the impossible chain that bound Fenrir: here it binds one live
# Brokk session per home so a second session cannot mutate shared state. The
# `.pi` extensions read `state/.lock` as a bare PID; this library writes and
# releases it. Source-safe.
#
# Ported/trimmed from the upstream session-lock contract for plan 29
# (docs/plans/29-brokk-distro-runtime.md).
set -u

gleipnir_root() {  # <result-var>
  local result_var=${1-}
  local root="${BROKK_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  printf -v "$result_var" '%s' "$root"
}

gleipnir_state_dir() {  # <result-var>
  local result_var=${1-}
  local home="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-}}"
  [ -n "$home" ] || gleipnir_root home
  printf -v "$result_var" '%s' "${BROKK_STATE_OVERRIDE:-$home/state}"
}

gleipnir_pid_alive() {  # <pid>
  case "${1-}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$1" 2>/dev/null
}

gleipnir_lock_path() {  # <result-var>
  local result_var=${1-} state
  gleipnir_state_dir state
  printf -v "$result_var" '%s/.lock' "$state"
}

gleipnir_lock_owner() {  # <result-var>
  local result_var=${1-} lock
  gleipnir_lock_path lock
  if [ -r "$lock" ]; then
    printf -v "$result_var" '%s' "$(tr -d '[:space:]' <"$lock")"
  else
    printf -v "$result_var" ''
  fi
}

gleipnir_lock_owned() {  # exit 0 when this shell's session owns the lock
  local owner
  gleipnir_lock_owner owner
  [ -n "$owner" ] && [ "$owner" = "$$" ] && return 0
  # Walk up the ancestry; the lock is held by a session process, not this
  # short-lived helper.
  local pid=$$ parent i
  for i in 1 2 3 4 5 6 7 8; do
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    [ -n "$parent" ] && [ "$parent" != "1" ] || return 1
    [ "$parent" = "$owner" ] && return 0
    pid=$parent
  done
  return 1
}

gleipnir_lock_acquire() {
  local state lock owner
  GLEIPNIR_LOCK_ACQUIRED=0
  gleipnir_state_dir state
  mkdir -p "$state"
  lock="$state/.lock"
  gleipnir_lock_owner owner
  if [ -n "$owner" ] && [ "$owner" != "${BROKK_SESSION_PID:-$$}" ] && gleipnir_pid_alive "$owner"; then
    return 1
  fi
  printf '%s\n' "${BROKK_SESSION_PID:-$$}" >"$lock"
  GLEIPNIR_LOCK_ACQUIRED=1
  return 0
}

gleipnir_lock_release() {
  local lock owner
  gleipnir_lock_path lock
  gleipnir_lock_owner owner
  if [ "$owner" = "${BROKK_SESSION_PID:-$$}" ]; then
    rm -f "$lock"
    GLEIPNIR_LOCK_ACQUIRED=0
  fi
}

# shellcheck disable=SC2034 # Public source-library variable used by callers.
GLEIPNIR_LOCK_ACQUIRED=0
