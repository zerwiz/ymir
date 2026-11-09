#!/usr/bin/env bash
# assistant-brief.sh — Skírnir's DATABASE: the house's current state, compiled into one dated briefing.
#
#   assistant-brief.sh refresh            compile today's briefing, file it, observe it into the well
#   assistant-brief.sh show [date]        print a briefing (the daily brief reads the same file)
#   assistant-brief.sh recall <question>  the well first (the briefing's tag), then the wider store
#   assistant-brief.sh status             what he currently knows, and whether it is STALE
#
# A THIN DOOR, on purpose: the behaviour lives once, in `assistant_brief.py` beside this file. This
# script only picks the interpreter and hands the verb over — a body added here would be the second
# implementation the house keeps having to remove (`RULES/23`, plan 149).
#
# WHAT IT READS, each through the door that already owns it — never a second implementation:
#   plans     `bin/gates/plan-audit.sh --json` (the shelf) + the ledger index + each plan's CHANGE LOG
#   errands   `bin/agents/eindri-liveness.sh list` (the claim vs the pane)
#   prs       `gh pr list` (merged in the window, and open)
#   decisions `bin/records/daily-log.sh list|show` + the plans' change logs
#   record    `bin/records/ymir-state.sh runes path`
#   the well  `bin/records/mimir.sh recall|observe`
#
# WHERE IT IS FILED: `$YMIR_HOME/hodd/memory/assistant/briefing/<date>.md`, appended — a second refresh
# the same day is a new dated section, never a rewrite (Rule 06). The well holds the same text under a
# STABLE tag (`assistant-briefing`) so a recall about this week can cite the briefing's date.
#
# THE BOUND (plan 227 §S1.5.4): a briefing is the house's INTERNAL state. Any tier but `owner` is
# REFUSED, naming the limit — no NDA, no vault, no other tenant, never a collaborator.
#
# Usage also as a library:  . assistant-brief.sh  → no functions of its own (it execs the engine).
#
# Exit: 0 ok · 1 a fault · 2 usage · 3 refused (a tier that may not hear the briefing).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/assistant_brief.py"
if [ ! -f "$ENGINE" ]; then
  printf 'assistant-brief: the engine is missing — %s\n' "$ENGINE" >&2
  exit 127
fi
PY="${YMIR_PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || { printf 'assistant-brief: no python3 on PATH\n' >&2; exit 127; }
exec "$PY" "$ENGINE" "$@"
