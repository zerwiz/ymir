#!/usr/bin/env bash
# syn-arm-pretool-check.sh - PreToolUse seatbelt for watcher-arm bash commands.
#
# Sýn guards the arm path. v0 is inert (always allow); the contract exists so
# the Sýn Pi extension can deny a bash invocation that tries to background or
# bundle the watcher arm itself. Owner: plan 29 (docs/plans/29-brokk-distro-runtime.md).
#
# Usage: syn-arm-pretool-check.sh --command <bash command>
# Exit:  0 = allow, 2 = block (stderr carries the reason)
set -u

command_text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --command) command_text=${2-}; shift 2 ;;
    *) shift ;;
  esac
done

case "$command_text" in
  *syn-watch-arm.sh*'&'*|*'&'*syn-watch-arm.sh*)
    printf 'denied: do not background the Brokk watcher arm; the Pi extension owns continuity\n' >&2
    exit 2
    ;;
esac

exit 0
