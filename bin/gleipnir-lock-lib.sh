#!/usr/bin/env bash
# gleipnir-lock-lib.sh - session lock for the Brokk runtime.
#
# Gleipnir is the impossible chain that bound Fenrir: here it binds ONE live
# Brokk primary per MACHINE. The primary's lock lives at a machine-global path
# (`${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`), not inside the
# checkout, so a stray second checkout of the same machine cannot masquerade as
# its own home and run a competing session. Eindri-homes are worker homes and
# are EXEMPT: each keeps its own `<home>/state/.lock` so workers still run in
# parallel with the primary (and with each other).
#
# Non-bash readers (the `.pi` / `.opencode` harness extensions) read the
# resolved path from `state/.lock-path`, which `gleipnir_lock_acquire` writes,
# and fall back to the legacy `state/.lock` for a session that started before
# this contract. Source-safe.
set -u

gleipnir_root() {  # <result-var>
  local result_var=${1-}
  local root="${BROKK_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  printf -v "$result_var" '%s' "$root"
}

# An Eindri-home is a worker home; it keeps a per-home lock so it can run beside
# the primary. Identified by an explicit marker the seed writes, or by the
# launcher's `BROKK_HOME_KIND=eindri` environment marker.
gleipnir_is_eindri_home() {
  [ "${BROKK_HOME_KIND:-}" = "eindri" ] && return 0
  local home="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-}}"
  [ -n "$home" ] || gleipnir_root home
  [ -f "$home/data/eindri-home" ] && return 0
  return 1
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

# The session pid to record. The lock must bind to the LIVE HARNESS process, not
# the short-lived helper that happens to run the digest — a helper's pid is dead
# a second later, which leaves an orphan lock that blocks supervision. When the
# harness passes BROKK_SESSION_PID we use it; otherwise we walk the ancestry to
# find the harness itself (pi / opencode / claude / cursor / codex / ...). Only a
# run with no harness ancestor (a real cron/headless job) falls back to $$.
gleipnir_session_pid() {  # <result-var>
  local result_var=${1-}
  if [ -n "${BROKK_SESSION_PID:-}" ]; then
    printf -v "$result_var" '%s' "$BROKK_SESSION_PID"
    return 0
  fi
  local pid=$$ comm parent i
  for i in 1 2 3 4 5 6 7 8; do
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    [ -n "$parent" ] && [ "$parent" != "1" ] || break
    comm=$(ps -o comm= -p "$parent" 2>/dev/null | tr -d '[:space:]')
    case "$comm" in
      pi|opencode|claude|cursor|codex|grok|kimi|muse|hermes)
        if gleipnir_pid_alive "$parent"; then
          printf -v "$result_var" '%s' "$parent"
          return 0
        fi
        ;;
    esac
    pid=$parent
  done
  printf -v "$result_var" '%s' "$$"
}

# The machine-global state dir for the primary lock. Overridable for tests and
# for a host that keeps machine state elsewhere.
gleipnir_machine_state_dir() {  # <result-var>
  local result_var=${1-}
  printf -v "$result_var" '%s' "${BROKK_MACHINE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
}

# The pre-machine-lock per-home path. Kept so a session that started before this
# contract still resolves its own lock, and so the pointer can be migrated.
gleipnir_legacy_lock_path() {  # <result-var>
  local result_var=${1-} state
  gleipnir_state_dir state
  printf -v "$result_var" '%s/.lock' "$state"
}

# The resolved lock path: machine-global for the primary, per-home for an
# Eindri-home.
gleipnir_lock_path() {  # <result-var>
  local result_var=${1-} dir
  if gleipnir_is_eindri_home; then
    gleipnir_legacy_lock_path "$result_var"
    return 0
  fi
  gleipnir_machine_state_dir dir
  printf -v "$result_var" '%s/brokk.lock' "$dir"
}

# Pointer file the non-bash harness readers consult so they never re-derive the
# machine/Eindri branch; it records whatever `gleipnir_lock_path` resolved.
gleipnir_lock_pointer_path() {  # <result-var>
  local result_var=${1-} state
  gleipnir_state_dir state
  printf -v "$result_var" '%s/.lock-path' "$state"
}

gleipnir_lock_owner() {  # <result-var>
  local result_var=${1-} lock legacy val
  gleipnir_lock_path lock
  val=""
  if [ -r "$lock" ]; then
    val=$(tr -d '[:space:]' <"$lock")
  fi
  if [ -z "$val" ]; then
    # Migration read: a session that started before the machine lock lived at
    # the legacy home path; honor it until that session restarts.
    gleipnir_legacy_lock_path legacy
    if [ "$legacy" != "$lock" ] && [ -r "$legacy" ]; then
      val=$(tr -d '[:space:]' <"$legacy")
    fi
  fi
  printf -v "$result_var" '%s' "$val"
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

gleipnir_write_lock_pointer() {  # <resolved-lock-path>
  local ptr
  gleipnir_lock_pointer_path ptr
  mkdir -p "$(dirname "$ptr")" 2>/dev/null || true
  printf '%s\n' "$1" >"$ptr" 2>/dev/null || true
}

# Drop the legacy home lock once the resolved lock holds the same session, so a
# stale per-home file cannot make the old path look live during hand-off.
gleipnir_lock_drop_legacy() {  # <want-pid>
  local legacy lock owner
  gleipnir_legacy_lock_path legacy
  gleipnir_lock_path lock
  [ "$legacy" = "$lock" ] && return 0
  [ -r "$legacy" ] || return 0
  owner=$(tr -d '[:space:]' <"$legacy")
  [ "$owner" = "$1" ] && rm -f "$legacy"
  return 0
}

gleipnir_lock_acquire() {
  local state lock owner want dir
  GLEIPNIR_LOCK_ACQUIRED=0
  gleipnir_state_dir state
  mkdir -p "$state"
  gleipnir_lock_path lock
  gleipnir_lock_reap   # a dead owner's lock is not a lock — clear it first
  gleipnir_session_pid want
  gleipnir_lock_owner owner
  if [ -n "$owner" ] && [ "$owner" != "$want" ] && gleipnir_pid_alive "$owner"; then
    return 1
  fi
  dir=$(dirname "$lock")
  mkdir -p "$dir" || return 1
  printf '%s\n' "$want" >"$lock" || return 1
  gleipnir_write_lock_pointer "$lock"
  gleipnir_lock_drop_legacy "$want"
  GLEIPNIR_LOCK_ACQUIRED=1
  return 0
}

# A lock whose owner is dead is NOT a lock. Remove it so an abnormal session
# close (crash, kill, closing the terminal) can never leave a stale lock —
# resolved or legacy — holding supervision and lighting the blind turn-end guard.
gleipnir_lock_reap() {
  local lock legacy owner p
  gleipnir_lock_path lock
  gleipnir_legacy_lock_path legacy
  for p in "$lock" "$legacy"; do
    [ -n "$p" ] && [ -e "$p" ] || continue
    owner=$(tr -d '[:space:]' <"$p" 2>/dev/null || true)
    if [ -n "$owner" ] && ! gleipnir_pid_alive "$owner"; then
      rm -f "$p"
      printf 'gleipnir: reaped stale lock (dead pid %s)\n' "$owner" >&2
    fi
  done
  return 0
}

gleipnir_lock_release() {
  local lock legacy ptr owner want
  gleipnir_lock_path lock
  gleipnir_legacy_lock_path legacy
  gleipnir_session_pid want
  gleipnir_lock_owner owner
  if [ "$owner" = "$want" ]; then
    rm -f "$lock"
    [ "$legacy" != "$lock" ] && rm -f "$legacy"
    gleipnir_lock_pointer_path ptr
    rm -f "$ptr"
    GLEIPNIR_LOCK_ACQUIRED=0
  fi
}

# shellcheck disable=SC2034 # Public source-library variable used by callers.
GLEIPNIR_LOCK_ACQUIRED=0
