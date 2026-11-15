#!/usr/bin/env bash
# saga-sessionstart-run.sh - session-open entry point for run-tier harnesses.
#
# Sága's runner. A harness whose session-open adapter can RUN a command invokes
# this; it decides from the session-open source whether the open needs the FULL
# session start (the stages, then the short head) or the head alone.
#
# Plan 275 item 28 measured the old shape: every compaction re-ran the whole
# 696-line digest, three times (one per home). Now a session start is ONE head
# (≤ 60 lines) and a compaction re-injects THAT head and nothing else — no lock
# sweep, no bridges, no cron. The detail every session used to pre-load is one
# command away (`--section <name>`), which the head prints.
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
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The completion mark is a RECORD, so it lives on the house's shelf — never in the
# tree (a packaged install replaces its tree, and the mark would be lost with it).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
hoard_state_dir _HS 2>/dev/null
STATE="${SAGA_STATE_DIR:-${_HS:-${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}}}"
unset _HS
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
if [ -x "$SCRIPT_DIR/../bridge/mimir-bridge.sh" ]; then
  if ! "$SCRIPT_DIR/../bridge/mimir-bridge.sh" --start >/dev/null 2>&1; then
    printf 'well bridge: failed to start (see state/mimir-bridge.log)\n'
  fi
fi

case "$SOURCE" in
  startup|new)
    "$SCRIPT_DIR/saga-session-start.sh"
    : >"$COMPLETION_FILE"
    ;;
  clear|compact)
    # ONLY THE HEAD, and only once: the stages (lock, bridges, sweep, cron) belong to
    # the session start that already ran. A compaction is the same session asking to be
    # reminded, not a new hand taking the helm.
    if [ -f "$COMPLETION_FILE" ]; then
      printf 'CONTEXT RE-EMIT (source=%s) — the session start already ran; here is the head again, and nothing else.\n' "$SOURCE"
      "$SCRIPT_DIR/saga-session-start.sh" --head
    else
      "$SCRIPT_DIR/saga-session-start.sh"
      : >"$COMPLETION_FILE"
    fi
    ;;
  resume|reload|fork)
    # A resumed or forked session is a live session: it needs its bearings, not a
    # stage re-run (the mark says the stages already ran).
    if [ -f "$COMPLETION_FILE" ]; then
      printf 'SESSION %s — the head, and nothing else (the stages are already seated).\n' "$(printf '%s' "$SOURCE" | tr '[:lower:]' '[:upper:]')"
      "$SCRIPT_DIR/saga-session-start.sh" --head
    else
      "$SCRIPT_DIR/saga-session-start.sh"
      : >"$COMPLETION_FILE"
    fi
    ;;
  *)
    "$SCRIPT_DIR/saga-session-start.sh"
    : >"$COMPLETION_FILE"
    ;;
esac

exit 0
