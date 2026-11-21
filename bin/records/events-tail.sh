#!/usr/bin/env bash
# events-tail.sh — door to the events store (tail). One implementation: bin/records/events.py.
# See events.py's header for the schema and flags.
#   bin/records/events-tail.sh [-n 20] [--source S] [--kind K] [--min-severity HIGH]
set -u
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# The home is resolved by the one owner (bin/vault/hoard-lib.sh), never guessed.
if [ -z "${YMIR_EVENTS_DIR:-}" ] && [ -z "${YMIR_STATE_DIR:-}" ] && [ -r "$here/../vault/hoard-lib.sh" ]; then
  # shellcheck disable=SC1091
  . "$here/../vault/hoard-lib.sh" >/dev/null 2>&1
  _s=""; hoard_state_dir _s 2>/dev/null && [ -n "$_s" ] && export YMIR_EVENTS_DIR="$_s/events"
fi
exec "${PYTHON:-python3}" "$here/events.py" tail "$@"
