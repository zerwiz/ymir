#!/usr/bin/env bash
# nda-guard.sh — company, client and NDA-project names never reach the public repo (RULES/04, 2026-11-12).
#   nda-guard.sh [check] [FILE...]   tracked tree (the ward; paths scope it)
#   nda-guard.sh staged | message FILE | push | range A..B | hook
# It reads $YMIR_HOME, so it is never cached.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  staged|message|push|range|hook|tree) ;;
  check) shift; set -- tree "$@" ;;
  *) set -- tree "$@" ;;
esac
exec python3 "$ROOT/bin/gates/guards/nda-guard.py" "$@"
