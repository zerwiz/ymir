#!/usr/bin/env bash
# gleipnir-lock-lib.sh — the session lock (Gleipnir), a THIN SHIM.
#
# Gleipnir is the impossible chain that bound Fenrir: here it binds ONE live
# Brokk primary per MACHINE. The lock's correctness lives in ONE implementation —
# `src/ymir_runtime/state/lock.py`, reached through `bin/ymir-state.sh`. This file
# defines no behaviour of its own: every function maps its shell name and its
# `<result-var>` convention onto the module and returns its answer, so the lock
# has exactly one implementation and two readers (the shell doors and the
# `.pi` / `.opencode` harness extensions, which read the `state/.lock-path`
# pointer the module writes). A body added here would be the second
# implementation this shim exists to remove.
#
# The contract is preserved to the byte:
#
#   · the primary's lock is machine-global (`${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`);
#     an Eindri-home keeps its own `<home>/state/.lock`.
#   · the state dir resolves from the hoard (`$YMIR_HOME/state`), never the tree.
#   · the owner is the live harness pid; `<lock>.starttime` makes pid reuse read
#     as death; a zombie is not a lock; a live other owner is REFUSED.
#   · `GLEIPNIR_LOCK_ACQUIRED` is set exactly as before.
#
# Source-safe: defines functions only; call `<fn> <result-var>`.
set -u

_gleipnir_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_gleipnir_root="${BROKK_ROOT_OVERRIDE:-$(cd "$_gleipnir_lib_dir/.." && pwd)}"

# The engine's state door — resolved beside THIS library, so a packaged install
# (bin/ + src/ shipped together) resolves it, and a caller's BROKK_ROOT_OVERRIDE
# (which may point at a project, not the tree) cannot misdirect it.
_gleipnir_state() {
  local door="$_gleipnir_lib_dir/ymir-state.sh"
  [ -x "$door" ] || {
    printf 'gleipnir: the engine door %s is missing — the lock cannot resolve\n' "$door" >&2
    return 127
  }
  "$door" "$@"
}

gleipnir_root() {  # <result-var>
  local result_var=${1-}
  [ -n "$result_var" ] || return 2
  printf -v "$result_var" '%s' "$_gleipnir_root"
}

# An Eindri-home is a worker home; it keeps a per-home lock so it can run beside
# the primary.
gleipnir_is_eindri_home() {
  _gleipnir_state lock is-eindri-home
}

# Runtime state, resolved through the one resolver (Rule 04/07).
gleipnir_hoard_state_dir() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock hoard-state-dir) || _out=""
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_state_dir() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock state-dir) || return $?
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_proc_stat_rest() {  # <pid> <result-var>
  local result_var=${2-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock proc-stat-rest "$1") || { printf -v "$result_var" '%s' ''; return 1; }
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_proc_starttime() {  # <pid> <result-var>
  local result_var=${2-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock proc-starttime "$1") || { printf -v "$result_var" '%s' ''; return 1; }
  printf -v "$result_var" '%s' "$_out"
}

# A pid is alive only when the process genuinely exists (zombie/recycled = dead).
gleipnir_pid_alive() {  # <pid> [<recorded-starttime>]
  _gleipnir_state lock pid-alive "${1-}" "${2-}"
}

# The pid the lock binds to: the live HARNESS process, not this short-lived
# helper. The shell's own `$$` is the fallback and is passed through.
gleipnir_session_pid() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock session-pid --shell-pid "$$") || _out="$$"
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_machine_state_dir() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock machine-state-dir) || _out=""
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_legacy_lock_path() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock legacy-lock-path) || _out=""
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_lock_path() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock lock-path) || _out=""
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_lock_pointer_path() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock pointer-path) || _out=""
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_lock_owner() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_gleipnir_state lock owner) || _out=""
  printf -v "$result_var" '%s' "$_out"
}

gleipnir_lock_owned() {  # exit 0 when this shell's session owns the lock
  _gleipnir_state lock owned --shell-pid "$$"
}

gleipnir_write_lock_pointer() {  # <resolved-lock-path>
  _gleipnir_state lock write-pointer "$1"
}

gleipnir_lock_drop_legacy() {  # <want-pid>
  _gleipnir_state lock drop-legacy "$1"
}

gleipnir_lock_acquire() {
  GLEIPNIR_LOCK_ACQUIRED=0
  _gleipnir_state lock acquire --shell-pid "$$"
  local _rc=$?
  [ "$_rc" = 0 ] && GLEIPNIR_LOCK_ACQUIRED=1
  return "$_rc"
}

# A lock whose owner is dead is NOT a lock.
gleipnir_lock_reap() {
  _gleipnir_state lock reap
}

gleipnir_lock_release() {
  _gleipnir_state lock release --shell-pid "$$"
  GLEIPNIR_LOCK_ACQUIRED=0
  return 0
}

# shellcheck disable=SC2034 # Public source-library variable used by callers.
GLEIPNIR_LOCK_ACQUIRED=0
