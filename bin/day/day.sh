#!/usr/bin/env bash
# day.sh — the day's door: one read of his acts and the house's measured facts.
#
#   bin/day/day.sh                 print the day (his terminal: senders, subjects, counts)
#   bin/day/day.sh --json          the same, for a surface inside the house
#   bin/day/day.sh --carry         counts and acts only — the only mode a notifier may call
#   bin/day/day.sh acts            his half, numbered (what `open N` refers to)
#   bin/day/day.sh clock           the schedule: due · fired · missed · whose role
#   bin/day/day.sh open N [--run]  the door behind act N, in a pane
#   bin/day/day.sh privacy         the private-data contract, and a check of this door against it
#
# What it reads: his file, the mail store, this seat's schedule and state, the plans ledger, the
# calendar door — all under $YMIR_HOME. What it writes: nothing. What it carries: acts, counts and
# dates, never a sender or a subject. Why: plan 207 §14, RULES/04, RULES/15.
#
# Exit: the python door's own — 0 ok · 1 nothing readable · 2 usage.
set -uo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_here/../.." && pwd)"
_door="$_here/day.py"

[ -r "$_door" ] || { printf 'day: the door is missing at %s\n' "$_door" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'day: python3 is not on PATH\n' >&2; exit 1; }

# The home is resolved by the door itself (hoard-lib order: $YMIR_HOME, then ~/.config/ymir/home),
# so this wrapper never guesses a path and never needs one.
exec python3 "$_door" "$@"
