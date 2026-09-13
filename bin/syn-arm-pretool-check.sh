#!/usr/bin/env bash
# syn-arm-pretool-check.sh - PreToolUse seatbelt for watcher-arm bash commands.
#
# Sýn guards the arm path: the arm is owned by the harness extension (a
# plugin-owned child process), so the residual risk is the agent shelling
# `bin/syn-watch-arm.sh` wrong through its own bash tool — backgrounding it,
# detaching it with nohup/setsid/disown, or bundling it so continuity escapes
# the extension. Reading it, or merely checking its syntax, is fine.
#
# Exit: 0 = allow, 2 = block (stderr carries the reason).
# Owner: plan 29 (docs/plans/29-brokk-distro-runtime.md).
set -u

command_text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --command) command_text=${2-}; shift 2 ;;
    *) shift ;;
  esac
done

# Nothing to guard unless the command names the arm script.
case "$command_text" in
  *syn-watch-arm.sh*) ;;
  *) exit 0 ;;
esac

# A pure syntax check never runs it.
case "$command_text" in
  *"bash -n"*|*"sh -n"*|*"-n "*syn-watch-arm.sh*) exit 0 ;;
esac

# Detaching verbs background the arm regardless of an explicit `&`.
case "$command_text" in
  *nohup*syn-watch-arm.sh*|*setsid*syn-watch-arm.sh*|*disown*syn-watch-arm.sh*|*coproc*syn-watch-arm.sh*)
    printf 'denied: do not background the Brokk watcher arm; the extension owns continuity\n' >&2
    exit 2
    ;;
esac

# Otherwise, only a REAL background operator matters. `&&`/`||` are logical
# chains, not backgrounding; `>&`, `2>&1`, and `&>` are redirections. Strip
# those, and any remaining unquoted `&` is a background operator.
scan="$command_text"
scan="${scan//&&/ }"
scan="${scan//||/ }"
scan="${scan//2>&1/ }"
scan="${scan//&>/ }"
scan="${scan//>&/ }"
case "$scan" in
  *'&'*)
    printf 'denied: do not background the Brokk watcher arm; the extension owns continuity\n' >&2
    exit 2
    ;;
esac

exit 0
