#!/usr/bin/env bash
# work-loop.sh — the work loop (Skuld owns what is owed): top this machine's coders up to the runbook limit,
# taking the next rework, the next judge, or the next Todo card. Read bin/skuld/work_loop.py's header, or run
# `work-loop.sh --help`, for the order and the brakes.
#
#   work-loop.sh                 one cycle: call the review loop, fill the free slots
#   work-loop.sh --dry-run       say what would go out; spawn and write nothing
#   work-loop.sh status          the limit, the coders standing here, the load
#   work-loop.sh --no-review     do not call the review loop this cycle
#   work-loop.sh --json
set -uo pipefail
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname -- "$(dirname -- "$SCRIPT_DIR")")"
if [ -z "${YMIR_HOME:-}" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  ymir_home_root YMIR_HOME 2>/dev/null || true
  export YMIR_HOME
fi
exec timeout "${YMIR_WORK_LOOP_TIMEOUT:-1500}" python3 "$SCRIPT_DIR/work_loop.py" "$@"
