#!/usr/bin/env bash
# ask.sh — the door to Skírnir, the Allfather's assistant.
#
#   bin/assistant/ask.sh --tier owner|collaborator|known|stranger --text "…" [--channel console]
#
# The engine (skirnir.py) holds the four walls; this door only exists so a human and a cron row
# call the same thing. It has NO tool access, sends nothing, and answers from the approved digest
# or says it does not know.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/skirnir.py" "$@"
