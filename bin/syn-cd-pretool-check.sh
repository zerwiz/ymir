#!/usr/bin/env bash
# syn-cd-pretool-check.sh - PreToolUse seatbelt for directory-changing commands.
#
# Sýn guards the working directory. v0 is inert (always allow); the contract
# exists so the Sýn Pi extension can deny a bash invocation that would strand
# the primary outside its checkout. Owner: plan 29
# (docs/plans/29-brokk-distro-runtime.md).
#
# Usage: syn-cd-pretool-check.sh --command <bash command>
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
  *'cd '*'/../'*)
    printf 'denied: refusing a cd that escapes the Brokk home\n' >&2
    exit 2
    ;;
esac

exit 0
