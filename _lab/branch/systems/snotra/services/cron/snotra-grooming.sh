#!/usr/bin/env bash
# snotra-grooming.sh — the Monthly Grooming card (DEC-20261022-04).
#
#   snotra-grooming.sh run     <meeting-dir>   create/update the Monthly Grooming card
#   snotra-grooming.sh dry-run <meeting-dir>   what would be created — no writes
#   snotra-grooming.sh status  <meeting-dir>   is the grooming card there?
#
# The Monthly Grooming goes through the Backlog and decides which tasks are
# prioritised for the coming month. It creates a card on the Next Meeting
# Agenda list with overdue, due-soon, and backlog items grouped.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
exec python3 "$ROOT/bin/time/snotra/snotra-grooming.py" "$@"
