#!/usr/bin/env bash
# cron-fail-lib.sh — the ONE sentence a failed scheduled row gets (plan 292).
#
#   . bin/time/cron-fail-lib.sh
#   cron_fail_detail <home-dir> <command> <rc> <tail-line>     # one line, ≤ 200 chars
#
# THE FAULT THIS MENDS (measured 2026-11-15). A row whose first word did not exist exited 127, and the
# notifier said:
#
#   job failed (rc=127): bin/records/gimle-tunnels-check.sh --quiet — no output
#
# "no output" is true and useless. It cannot be told from a job that ran and said nothing — and those
# two faults have entirely different mends: one is a tree that has gone stale, the other is a program
# that is broken. The house had the first, 213 times over 28 days, and every one of them read as the
# second.
#
# 126 and 127 are the SHELL's own verdicts, so they are read first and named as what they are:
#   127  the word was not found            → name the path the row actually looked for, and the tree
#   126  it was found and could not be run → name the path and say so
# Anything else is the row's own failure; the tail of the log is the best evidence there is.
#
# Read-only. No writes, no network, no state. Safe to source from the scheduler's own subshell.
set -u 2>/dev/null || true

cron_fail_detail() {
  local home="${1-}" cmd="${2-}" rc="${3-}" tail="${4-}" word path out

  # A JOB THAT SAID "NOT CLEAN" DID ITS WORK (2026-11-17). The daily brief publishes the file and THEN
  # exits 1 when a draft has aged, so a notice reading "job failed (rc=1)" is true and misleading: the
  # brief exists, and its own warning says why the day is not clean. The sentence leads with that, so a
  # reader does not go looking for a missing document that is sitting where it always sits.
  case "$tail" in
    *"NOT CLEAN"*)
      printf 'the work was done, but not clean — %s' "$(printf '%s' "$tail" | sed 's/.*NOT CLEAN[ —-]*//' | cut -c1-160)"
      return 0 ;;
  esac
  word="${cmd%% *}"
  case "$rc" in
    126|127)
      case "$word" in
        /*) path="$word" ;;
        "") path="(an empty row)" ;;
        *)  path="${home:+${home%/}/}$word" ;;
      esac
      if [ "$rc" = 127 ]; then
        if [ -n "$word" ] && [ ! -e "$path" ]; then
          out="not found: $path — the row ran from ${home:-an unset home}; that tree is stale (bin/engine/pin-refresh.sh brings the pin home)"
        else
          out="not found: $path — the shell could not run it although it exists here (check its #! line)"
        fi
      else
        out="not executable: $path — found, but the row may not run it (chmod +x, or a bad #! line)"
      fi
      ;;
    *)
      [ -n "$tail" ] && out="$tail" || out="no output — the row exited $rc and said nothing"
      ;;
  esac
  printf '%s' "$out" | tr '\n' ' ' | cut -c1-200
}
