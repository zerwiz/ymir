#!/usr/bin/env bash
# runes-append.sh - append-only Runes audit ledger.
#
# Runes are what was carved: an append-only JSONL record of every significant
# action in the Ymir runtime. Each entry chains to the one before it by folding
# the previous checksum into its own, so a line cannot be altered or removed
# without breaking every later line. This file is both a source-safe shell
# library and the CLI used by the Nornir jobs. It NEVER rewrites existing
# entries and NEVER truncates the ledger.
#
# Ledger: workspace/memory/runes_audit.md  (JSONL lines appended under a .md head)
#
# CLI:
#   runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."
#
# Library:
#   . bin/runes-append.sh
#   runes_append <actor> <event> [--order Wxxxx] [--realm R] --message "..."
#
# Environment:
#   BROKK_HOME           home that owns the ledger (default: repo root)
#   BROKK_RUNES_FILE     explicit ledger path override
#   BROKK_RUNES_DIR      directory holding runes_audit.md (default $BROKK_HOME/workspace/memory)
#   BROKK_RUNES_LOCK     append lock file (default $BROKK_HOME/state/runes.lock)
#
# Exit: 0 appended, 1 usage/IO error (error + help on stdout).
set -u

RUNES_MARK_NEW=$'\n'

runes_root() {  # <result-var>
  local result_var=${1-}
  printf -v "$result_var" '%s' "${BROKK_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}

runes_home() {  # <result-var>
  local result_var=${1-} root
  if [ -n "${BROKK_HOME:-}" ]; then
    printf -v "$result_var" '%s' "$BROKK_HOME"
    return 0
  fi
  runes_root root
  printf -v "$result_var" '%s' "$root"
}

runes_ymir_home() {  # <result-var> — the operator's home, resolved (Rule 07)
  # env -> the recorded choice -> the ONE documented default, all owned by
  # bin/hoard-lib.sh. Never a literal path in this file.
  local result_var=${1-}
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_HOME:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_HOME"; return 0
  fi
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    local _yr _yc
    _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
      [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
    unset _yr _yc
  fi
  if command -v ymir_home_root >/dev/null 2>&1; then
    ymir_home_root "$result_var"
  else
    printf 'error: cannot resolve YMIR_HOME — bin/hoard-lib.sh was not found near %s\n' "$0" >&2
    printf -v "$result_var" '%s' ""
    return 1
  fi
}

runes_file_path() {  # <result-var>
  local result_var=${1-} home
  if [ -n "${BROKK_RUNES_FILE:-}" ]; then
    printf -v "$result_var" '%s' "$BROKK_RUNES_FILE"
    return 0
  fi
  # The ledger lives with the hoard (the operator's private root), never beside
  # the scripts: an installed runtime may sit in a read-only package directory.
  runes_ymir_home home || return 1
  printf -v "$result_var" '%s' "${BROKK_RUNES_DIR:-${home}/hodd/memory}/runes_audit.md"
}

runes_lock_path() {  # <result-var>
  local result_var=${1-} home
  if [ -n "${BROKK_RUNES_LOCK:-}" ]; then
    printf -v "$result_var" '%s' "$BROKK_RUNES_LOCK"
    return 0
  fi
  runes_home home
  printf -v "$result_var" '%s' "$home/state/runes.lock"
}

runes_hash() {  # <data> <result-var>
  local data=${1-} result_var=${2-} out
  if command -v sha256sum >/dev/null 2>&1; then
    out=$(printf '%s' "$data" | sha256sum | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    out=$(printf '%s' "$data" | shasum -a 256 | cut -d' ' -f1)
  else
    out=$(printf '%s' "$data" | cksum | tr -d '[:space:]')
  fi
  printf -v "$result_var" '%s' "$out"
}

runes_json_escape() {  # <text> <result-var>
  local text=${1-} result_var=${2-} out
  out=$text
  out=${out//\\/\\\\}
  out=${out//\"/\\\"}
  out=${out//$'\n'/\\n}
  out=${out//$'\r'/\\r}
  out=${out//$'\t'/\\t}
  printf -v "$result_var" '%s' "$out"
}

runes_last_checksum() {  # <ledger> <result-var>; prints "" when unset
  local ledger=${1-} result_var=${2-} value=""
  [ -r "$ledger" ] || { printf -v "$result_var" '%s' ''; return 0; }
  value=$(grep '"checksum":"' "$ledger" 2>/dev/null | tail -n 1 | sed -n 's/.*"checksum":"\([^"]*\)".*/\1/p')
  printf -v "$result_var" '%s' "$value"
}

runes_ensure_head() {  # <ledger>
  local ledger=${1-} dir
  dir=$(dirname "$ledger")
  mkdir -p "$dir" || return 1
  [ -e "$ledger" ] && return 0
  printf '# RUNES Audit Trail\n> Append-only log of all significant system actions across Ymir\n\n---\n\n' >"$ledger" || return 1
}

runes_append() {  # <actor> <event> [--order O] [--realm R] --message M
  local actor="${1-}" event="${2-}"
  [ -n "$actor" ] && [ -n "$event" ] || return 2
  shift 2

  local order="" realm="" message="" have_message=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --order) order=${2-}; [ $# -ge 2 ] && shift 2 || shift ;;
      --order=*) order=${1#--order=}; shift ;;
      --realm) realm=${2-}; [ $# -ge 2 ] && shift 2 || shift ;;
      --realm=*) realm=${1#--realm=}; shift ;;
      --message) message=${2-}; have_message=1; [ $# -ge 2 ] && shift 2 || shift ;;
      --message=*) message=${1#--message=}; have_message=1; shift ;;
      *) return 2 ;;
    esac
  done
  [ "$have_message" = "1" ] || return 2

  local ledger lock timestamp checksum
  local esc_actor esc_order esc_realm esc_event esc_message

  runes_file_path ledger
  runes_lock_path lock
  runes_ensure_head "$ledger" || return 1
  runes_json_escape "$actor" esc_actor
  runes_json_escape "$order" esc_order
  runes_json_escape "$realm" esc_realm
  runes_json_escape "$event" esc_event
  runes_json_escape "$message" esc_message
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Read the previous checksum, fold it, and append under ONE exclusive lock so
  # concurrent writers can never fork the chain.
  if command -v flock >/dev/null 2>&1 && [ -n "$lock" ]; then
    mkdir -p "$(dirname "$lock")" 2>/dev/null || true
    checksum=$(
      (
        flock 9 || exit 1
        local prev base calc
        runes_last_checksum "$ledger" prev
        base="{\"timestamp\":\"${timestamp}\",\"actor\":\"${esc_actor}\",\"order\":\"${esc_order}\",\"realm\":\"${esc_realm}\",\"event\":\"${esc_event}\",\"message\":\"${esc_message}\",\"prev\":\"${prev}\""
        runes_hash "${prev}${RUNES_MARK_NEW}${base}" calc
        printf '%s\n' "${base},\"checksum\":\"${calc}\"}" >>"$ledger" || exit 1
        printf '%s' "$calc"
      ) 9>>"$lock"
    ) || return 1
  else
    local prev base calc
    runes_last_checksum "$ledger" prev
    base="{\"timestamp\":\"${timestamp}\",\"actor\":\"${esc_actor}\",\"order\":\"${esc_order}\",\"realm\":\"${esc_realm}\",\"event\":\"${esc_event}\",\"message\":\"${esc_message}\",\"prev\":\"${prev}\""
    runes_hash "${prev}${RUNES_MARK_NEW}${base}" calc
    printf '%s\n' "${base},\"checksum\":\"${calc}\"}" >>"$ledger" || return 1
    checksum=$calc
  fi

  RUNES_LAST_CHECKSUM=$checksum
  printf 'runes: appended actor=%s event=%s order=%s checksum=%s\n' \
    "${actor}" "${event}" "${order:-none}" "$checksum"
}

runes_usage() {
  cat <<'EOF'
Usage:
  runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."

Appends one chained JSONL entry to workspace/memory/runes_audit.md. Existing
entries are never rewritten. The checksum folds the previous line's checksum.

Library:  . bin/runes-append.sh ; runes_append <actor> <event> ...
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
    printf 'help: check write access to workspace/memory/ and state/\n'
  fi
  return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  runes_main "$@"
  exit $?
fi
