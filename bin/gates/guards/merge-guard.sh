#!/usr/bin/env bash
# merge-guard.sh — the arm holder alone merges; a worker never merges its own PR (RULES/08, plan 354).
set -u
LEASE="${RODD_ARM_LEASE:-$HOME/Documents/ymirhome/state/.arm.lease}"
ARM_HELD=0
if [ -r "$LEASE" ]; then
  pid=$(sed -n 's/.*pid=\([^ ]*\).*/\1/p' "$LEASE" | head -1)
  st=$(sed -n 's/.*starttime=\([^ ]*\).*/\1/p' "$LEASE" | head -1)
  if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    live_st=$(sed -n 's/.*starttime[[:space:]]*:[[:space:]]*//p' "/proc/$pid/stat" 2>/dev/null | head -1)
    [ "$live_st" = "$st" ] && ARM_HELD=1
  fi
fi
if [ "${YMIR_MERGE_REQUEST:-0}" = "1" ] && [ "$ARM_HELD" != 1 ]; then
  printf 'merge-guard: REFUSED — a merge is the arm holder'"'"'s act, and this seat does not hold the arm (plan 354).\n' >&2
  printf 'help: the arm holder merges (bin/voice/rodd-arm.sh who); a worker asks it through the room\n' >&2
  exit 1
fi
exit 0
