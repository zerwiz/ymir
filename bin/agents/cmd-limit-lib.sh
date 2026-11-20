#!/usr/bin/env bash
# cmd-limit-lib.sh — ONE number for how long a worker's single shell call may run.
#
# Sourced, never executed. The Allfather, 2026-11-20, after two errands sat for hours
# on one command (gimle-catch-up, 8h45m on an ssh that never returned; retired-paths,
# 1h50m on a python file run by bash, waiting on input): *"yes not to small tho"*.
# A limit that is too small stops real work, so it is generous and it is DECLARED —
# **30 minutes by default, 2 hours when a build, a gate suite or a release says so**,
# never unlimited. His runbook words are `hodd/docs/runbooks/fleet.md` → "When a worker
# is stuck — the arm watches, Rödd speaks".
#
# Why a library and not three literals: the number is read by three doors, and three
# copies drift (Rule 07 — configuration is never hardcoded). The readers are
#
#   bin/agents/erindi-brief.sh   the rule every worker is handed, in its own brief
#   bin/agents/eindri-stall.sh   the arm's judgement: a command past this is stuck
#   bin/seat/pi-launcher.sh      the seat's own environment, so a worker's scripts
#                                and the arm read the SAME ceiling
#
# What it CANNOT do, said plainly: pi and opencode have no default-timeout key in
# their settings, so a limit cannot be imposed inside those harnesses — the worker is
# handed the rule and the arm judges the wall clock. Claude Code does have one
# (`BASH_DEFAULT_TIMEOUT_MS` / `BASH_MAX_TIMEOUT_MS`), and it is set in the worker
# profile every Claude seat is launched with: `.agents/harnesses/claude-worker.settings.json`.
#
# Environment (Rule 07: env → one documented default):
#   YMIR_CMD_LIMIT_S      seconds a shell call may run without declaring more (1800 = 30 min)
#   YMIR_CMD_LIMIT_MAX_S  the most any call may declare, with a reason (7200 = 2 h)

# _cmd_limit_int <value> <default> — a positive integer, or the default.
_cmd_limit_int() {
  local v=${1-} d=$2
  case "$v" in ''|*[!0-9]*) printf '%s' "$d"; return 0 ;; esac
  [ "$v" -gt 0 ] 2>/dev/null || { printf '%s' "$d"; return 0; }
  printf '%s' "$v"
}

cmd_limit_seconds()      { _cmd_limit_int "${YMIR_CMD_LIMIT_S:-}" 1800; }
cmd_limit_max_seconds()  { _cmd_limit_int "${YMIR_CMD_LIMIT_MAX_S:-}" 7200; }

# Whole minutes, rounded up — the unit the brief and the sweep speak in.
cmd_limit_minutes() {
  local s; s="$(cmd_limit_seconds)"
  printf '%s' $(( (s + 59) / 60 ))
}
cmd_limit_max_minutes() {
  local s; s="$(cmd_limit_max_seconds)"
  printf '%s' $(( (s + 59) / 60 ))
}

# The two rule lines the brief scaffold prints into every worker's Rules section.
# Markdown, escaped for a shell heredoc (` \$ \``), one rule split over two lines so
# the ssh half is not buried inside the time half: they are different faults (a limit
# nobody declared, and a session that never returns because a background process kept
# its stdin). Wording settled 2026-11-20 with the runbook.
cmd_limit_rule_lines() {
  local secs maxs mins hours
  secs="$(cmd_limit_seconds)"; maxs="$(cmd_limit_max_seconds)"
  mins="$(cmd_limit_minutes)"; hours=$(( maxs / 3600 ))
  [ "$hours" -ge 1 ] || hours=1
  printf '%s\n' \
"7. Every shell call you make has a default limit of **${mins} minutes**: pass \`timeout: ${secs}\` to the bash tool, or \`timeout ${secs} <command>\` in a script. A build, a gate suite or a release may declare up to **${hours} hours** — \`timeout: ${maxs}\` or \`timeout ${maxs} <command>\` — and nothing is ever unlimited: a command with no limit is how an errand sits for hours and nobody notices." \
"8. Over \`ssh\`, detach a background process or the session never returns: \`ssh host 'nohup cmd </dev/null >log 2>&1 &'\`. A process that inherits stdin and stdout keeps the ssh session open forever, long after the worker has stopped waiting for it."
}

# Run as a door (`bin/agents/cmd-limit-lib.sh seconds`) so a script, a test and a
# person all ask the same place instead of re-deriving the number.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1-}" in
    seconds)     cmd_limit_seconds;     printf '\n' ;;
    minutes)     cmd_limit_minutes;     printf '\n' ;;
    max-seconds) cmd_limit_max_seconds; printf '\n' ;;
    max-minutes) cmd_limit_max_minutes; printf '\n' ;;
    rule)        cmd_limit_rule_lines ;;
    -h|--help|'') sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) printf 'error: unknown command %s\nhelp: cmd-limit-lib.sh seconds|minutes|max-seconds|max-minutes|rule\n' "$1" >&2; exit 2 ;;
  esac
  exit 0
fi
