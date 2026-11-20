#!/usr/bin/env bash
# doors.sh — a door register for ANY directory, rendered from the tree (plan 115 P7).
#
# `bin/README.md` indexes bin/ and the backend shelf and stops there; measured 2026-10-23,
# apps/ holds 405 entry points and tools/ 11 of 13 in no register at all — and a subsystem's
# shell doors are indexed only when they happen to live under bin/. A home shelf has doors too.
#
#   doors.sh --root DIR [--out FILE]     write DIR/DOORS.md (one row per entry point)
#   doors.sh --root DIR --check          fail if the register is stale or missing
#   doors.sh --root DIR --out FILE       write the register somewhere else
#
# Tracked files only inside a git work tree, so the register is reproducible from a clean
# checkout — the fault bin/gates/inventory.sh carried until 2026-10-23.
#
# Exit: 0 written/current · 1 stale or missing · 2 usage.
set -uo pipefail
VERSION="1.0.0"
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}
ROOT="$(_root)"
case "${1-}" in
  -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ] && exit 0 || exit 2 ;;
esac
exec python3 "$ROOT/src/ymir_runtime/doors.py" "$@"
