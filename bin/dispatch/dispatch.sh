#!/usr/bin/env bash
# dispatch.sh — the dispatcher's door: incoming work becomes a bounded errand or a line on his list.
#
#   dispatch.sh                        the scheduled act: read, propose, record
#   dispatch.sh --dry-run              read and report, write NOTHING (no to-do line, no ledger row)
#   dispatch.sh --check                health only (inputs readable, record intact); a gate may call it
#   dispatch.sh --json                 machine-readable answer instead of TOON
#   dispatch.sh --max N | --hours H    one run's cap on new proposals / the mail window
#
# WHAT IT READS   Gná's desk needs-you queue (the desk over loopback, else the store it reads) and the
#                 durable wake queue — only the lines that ask the Allfather.
# WHAT IT WRITES  a proposal block between two markers inside the house-kept half of his to-do, and
#                 state/dispatch/runs.jsonl (append-only: one row per event, one row per run).
# WHAT IT NEVER   sends mail · writes his half · spawns an errand · takes the arm · rewrites the ledger.
#
# Exit: 0 ran · 2 usage · 3 an input is unreadable · 4 the record cannot be read or written.
#
# The body is bin/dispatch/dispatch.py; this file is the door, and its usage is the only thing it adds.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/dispatch.py" "$@"
