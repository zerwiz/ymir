#!/usr/bin/env bash
# saga-sessionstart-run.sh - session-open entry point for run-tier harnesses.
#
# Sága's runner. A harness whose session-open adapter can RUN a command invokes
# this; it decides from the session-open source whether the open needs the full
# digest, a context re-emit, or a short nudge. Ported from the upstream agent-distro reference for plan 29.
#
# Usage: saga-sessionstart-run.sh [--source <source>] [--pi-prerequisite]
#   --source  startup|new|clear|compact|resume|reload|fork. When omitted it is
#             read from a Claude/Codex-shaped JSON hook payload on stdin.
#   --pi-prerequisite  Pi extension mode: an intentional stand-down exits 3 so
#             provider preflight can distinguish it from an eligible attempt
#             that settled without output.
#
# Every ordinary transport path exits 0: a failed session start must reach the
# agent as digest text it can act on, never as a refusal to open the session.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
COMPLETION_FILE="$STATE/.session-start-complete"

SOURCE=""
PI_PREREQUISITE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE=${2:-}; if [ $# -ge 2 ]; then shift 2; else shift; fi ;;
    --pi-prerequisite) PI_PREREQUISITE=1; shift ;;
    *) shift ;;
  esac
done

if [ -z "$SOURCE" ] && [ ! -t 0 ]; then
  payload=$(cat 2>/dev/null || true)
  case "$payload" in
    *'"source":"startup"'*|*'"source": "startup"'*) SOURCE=startup ;;
    *'"source":"clear"'*|*'"source": "clear"'*) SOURCE=clear ;;
    *'"source":"compact"'*|*'"source": "compact"'*) SOURCE=compact ;;
    *'"source":"resume"'*|*'"source": "resume"'*) SOURCE=resume ;;
    *'"source":"fork"'*|*'"source": "fork"'*) SOURCE=fork ;;
    *'"source":"new"'*|*'"source": "new"'*) SOURCE=new ;;
  esac
fi
SOURCE="${SOURCE:-startup}"

# Pi prerequisite eligibility: this build always considers the primary eligible.
# A deployment that must stand down sets BROKK_SESSIONSTART_INELIGIBLE=1.
if [ "$PI_PREREQUISITE" = "1" ] && [ "${BROKK_SESSIONSTART_INELIGIBLE:-0}" = "1" ]; then
  exit 3
fi

mkdir -p "$STATE"

# The well walks with the session: raise Mimirsbrunn (engram :4602) on EVERY
# open, not only the full digest — a clear/compact re-emit or a resume must
# still find the bridge up when the well extension's session_start probe fires.
# --start is idempotent (no-op when already up); the digest repeats it later
# only as its own status line.
if [ -x "$SCRIPT_DIR/mimir-bridge.sh" ]; then
  if ! "$SCRIPT_DIR/mimir-bridge.sh" --start >/dev/null 2>&1; then
    printf 'well bridge: failed to start (see state/mimir-bridge.log)\n'
  fi
fi

case "$SOURCE" in
  startup|new)
    "$SCRIPT_DIR/saga-session-start.sh"
    : >"$COMPLETION_FILE"
    ;;
  clear|compact)
    if [ -f "$COMPLETION_FILE" ]; then
      printf 'CONTEXT RE-EMIT (source=%s)\n\n' "$SOURCE"
      printf 'Session-start context was already taken this lock. Re-read data/operator.md,\n'
      printf 'data/projects.md, and data/learnings.md only if this turn needs them.\n'
    else
      "$SCRIPT_DIR/saga-session-start.sh"
      : >"$COMPLETION_FILE"
    fi
    ;;
  resume|reload|fork)
    printf 'Run `%s` exactly once now, before executing any other instructions.\n' "bash $SCRIPT_DIR/saga-session-start.sh"
    ;;
  *)
    "$SCRIPT_DIR/saga-session-start.sh"
    : >"$COMPLETION_FILE"
    ;;
esac

exit 0
