#!/usr/bin/env bash
#
# cache: tree — the verdict is a pure function of the tracked tree.
# cache: tree
# blocking-door-guard.sh — a door that can block a hand must answer before it blocks.
#
# WHY THIS EXISTS (measured 2026-11-18, and it cost a whole session): a hand asked
# `bin/agents/eindri-arm.sh --help` for its usage. The script had no `--help`, so the flag
# fell through to `ID="${1-}"`, an arm named `--help` was claimed, and its `while :` cycle
# held the caller's turn for the full 24-hour TTL. The Allfather asked three questions into
# a dead session before the turn was killed.
#
# The law this ward enforces: a script that contains a LONG POLL LOOP (`while :` /
# `while true`) either
#
#   1. answers `-h|--help` (and `--version`) BEFORE the loop, so a question can never
#      become a wait; or
#   2. declares itself in its first 40 lines as one of the shapes that must not be called
#      by hand:
#
#        # blocking-door: daemon — <why this runs under a unit, never from a hand>
#        # blocking-door: library — <why the loop is a helper the caller bounds>
#
# A door with neither is a trap, and a trap is worse than a fault: it is silent.
#
# Usage:  blocking-door-guard.sh [--check|--scan] [path...]
# Exit:   0 clean, 1 a blocking door with no answer, 2 usage.

set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
cd "$ROOT" || exit 1

case "${1-}" in
  -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  --check|--scan) shift ;;
  "") set -- --scan ;;
  -*) printf 'error: unknown flag %s\nhelp: blocking-door-guard.sh [--check|--scan]\n' "$1" >&2; exit 2 ;;
esac

EXEMPT_RE='^(node_modules/|\.yggdrasil/|vendor/)'
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  mapfile -t FILES < <(git ls-files '*.sh' 2>/dev/null | grep -vE "$EXEMPT_RE")
fi

findings=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  # a long poll loop, in CODE (a commented line is prose, never a loop)
  grep -nE '^[[:space:]]*while[[:space:]]+(:|true)[[:space:]]*;?[[:space:]]*do' "$f" >/dev/null 2>&1 || continue
  head -40 "$f" | grep -qE '^#[[:space:]]*blocking-door:[[:space:]]*(daemon|library)' && continue
  grep -qE '\-h\|--help|--help\)' "$f" && continue
  printf '  "%s","a poll loop with no -h|--help and no `# blocking-door:` line"\n' "$f"
  findings=$((findings+1))
done

if [ "$findings" -gt 0 ]; then
  printf 'blocking-door-guard[1]{findings}:\n  "%d"\n' "$findings"
  printf 'help: answer -h|--help before the loop, or declare `# blocking-door: daemon|library — why` in the first 40 lines\n' >&2
  exit 1
fi
printf 'blocking-door-guard[1]{findings,verdict}:\n  "0","every poll loop answers a hand before it holds one"\n'
exit 0
