#!/usr/bin/env bash
# runes-append.sh — the append-only Runes ledger, a THIN SHIM.
#
# Runes are what was carved: an append-only JSONL record of every significant
# action in the Ymir runtime, each entry chaining to the one before it by folding
# the previous checksum into its own. The chain law lives in ONE implementation —
# `src/ymir_runtime/state/runes.py`, reached through `bin/ymir-state.sh`. This
# file defines no behaviour of its own: `runes_append` maps its arguments onto the
# module and returns its line; the ledger path, the lock, the head, the escape,
# the fold, and the append are all the module's. A body added here would be the
# second implementation this shim exists to remove.
#
# The ledger format is preserved to the byte, because the ledger already has
# history: one JSON object per line, keys
# `timestamp · actor · order · realm · event · message · prev · checksum`, the
# checksum folding `prev + "\n" + <the entry without its closing brace>`, appended
# under one exclusive lock. An existing entry is NEVER rewritten and the ledger
# is NEVER truncated: a parity mismatch is a refusal, not an overwrite.
#
# Ledger: hodd/memory/runes_audit.md (JSONL lines appended under a .md head)
#
# CLI:
#   runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."
#
# Library:
#   . bin/records/runes-append.sh
#   runes_append <actor> <event> [--order Wxxxx] [--realm R] --message "..."
#
# Environment:
#   BROKK_HOME           home that owns the ledger lock (default: repo root)
#   BROKK_RUNES_FILE     explicit ledger path override
#   BROKK_RUNES_DIR      directory holding runes_audit.md (default $home/hodd/memory)
#   BROKK_RUNES_LOCK     append lock file (default $BROKK_HOME/state/runes.lock)
#
# Exit: 0 appended, 1 usage/IO error (error + help on stdout).
set -u

_runes_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_runes_state() {
  local door="$_runes_lib_dir/ymir-state.sh"
  [ -x "$door" ] || {
    printf 'runes: the engine door %s is missing — the ledger cannot append\n' "$door" >&2
    return 127
  }
  "$door" runes "$@"
}

runes_file_path() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_runes_state path) || return $?
  printf -v "$result_var" '%s' "$_out"
}

runes_lock_path() {  # <result-var>
  local result_var=${1-} _out
  [ -n "$result_var" ] || return 2
  _out=$(_runes_state lock-path) || return $?
  printf -v "$result_var" '%s' "$_out"
}

runes_append() {  # <actor> <event> [--order O] [--realm R] --message M
  local actor="${1-}" event="${2-}"
  [ -n "$actor" ] && [ -n "$event" ] || return 2
  shift 2
  local have_message=0 _arg
  for _arg in "$@"; do
    case "$_arg" in
      --message|--message=*) have_message=1 ;;
    esac
  done
  [ "$have_message" = "1" ] || return 2

  local _out _rc
  _out=$(_runes_state append "$actor" "$event" "$@")
  _rc=$?
  [ "$_rc" = 0 ] || return "$_rc"
  printf '%s\n' "$_out"
  RUNES_LAST_CHECKSUM=${_out##*checksum=}
  return 0
}

runes_usage() {
  cat <<'EOF'
Usage:
  runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."

Appends one chained JSONL entry to hodd/memory/runes_audit.md. Existing entries
are never rewritten. The checksum folds the previous line's checksum.

Library:  . bin/records/runes-append.sh ; runes_append <actor> <event> ...
EOF
}

runes_main() {
  case "${1-}" in
    -h|--help|help) runes_usage; return 0 ;;
    '') runes_usage >&2; return 2 ;;
  esac
  local rc=0
  runes_append "$@" || rc=$?
  if [ "$rc" = "2" ]; then
    printf 'error: actor and event are required, and --message must be supplied\n'
    printf 'help: runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."\n'
  elif [ "$rc" != "0" ]; then
    printf 'error: could not append to the Runes ledger\n'
    printf 'help: check write access to the ledger and state/\n'
  fi
  return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  runes_main "$@"
  exit $?
fi
