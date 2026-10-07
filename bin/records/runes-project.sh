#!/usr/bin/env bash
# runes-project.sh — the DAG projector, regenerates runes_audit.md from events.
#
# P2: The projector. bin/records/runes-project.sh regenerates runes_audit.md from
# the event set, deterministically: topological (causal) order, ties broken by
# median timestamp, ties broken by hash. Identical input must give a byte-identical
# file on every seat.
#
# Equivocation quarantine (P3): if one seat emits two events sharing a self_parent,
# all of its equivocating siblings are excluded from the projection — deterministically,
# identically on every seat, with no vote and no election. Nothing is deleted (Rule 06):
# exclusion is a derivation.
#
# Usage:
#   runes-project.sh [--seat SEAT] [--output FILE]
#
# Environment:
#   BROKK_RUNES_DIR   directory holding runes_audit.md and events/ (default: $BROKK_HOME/hodd/memory/runes)
#
# Exit: 0 success, 1 error.
set -u

_runes_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_run_python() {
  local door="${_runes_lib_dir}/../src/ymir_runtime/state/runes.py"
  [ -f "$door" ] || {
    printf 'runes-project: the Python module %s is missing\n' "$door" >&2
    return 1
  }
  python3 "$door" "$@"
}

runes_project() {
  local seat="${1-}" output="${2-}"
  [ -n "$seat" ] || seat="heimdall"
  
  local _out _rc
  _out=$(_run_python project "$seat" "$output")
  _rc=$?
  [ "$_rc" = "0" ] || return "$_rc"
  printf '%s' "$_out"
  return 0
}

runes_project_usage() {
  cat <<'EOF'
Usage:
  runes-project.sh [--seat SEAT] [--output FILE]

Regenerates runes_audit.md from the event set under events/<seat>/, deterministically:
  - Topological (causal) order: self_parent -> timestamp -> hash
  - Equivocation quarantine: events sharing self_parent are excluded from projection
  - Identical input gives byte-identical output on every seat

Environment:
  BROKK_RUNES_DIR  directory holding runes_audit.md and events/ (default: $BROKK_HOME/hodd/memory/runes)

Exit: 0 success, 1 error.
EOF
}

runes_project_main() {
  local rc=0
  local have_seat=0 have_output=0 _arg
  while [ $# -gt 0 ]; do
    case "$1" in
      --seat=*) have_seat=1 ;;
      --output=*) have_output=1 ;;
    esac
    shift
  done
  
  if [ "$have_seat" = "0" ] && [ "$have_output" = "0" ]; then
    printf 'error: --seat or --output is required\n' >&2
    printf 'help: runes-project.sh --seat SEAT --output FILE\n' >&2
    return 2
  fi
  
  local _out _rc
  _out=$(_run_python project "$seat" "$output")
  _rc=$?
  [ "$_rc" = "0" ] || return "$_rc"
  printf '%s' "$_out"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  runes_project_main "$@"
  exit $?
fi
