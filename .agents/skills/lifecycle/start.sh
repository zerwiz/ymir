#!/usr/bin/env bash
# start.sh — raise the WayOfNorthStar stack (the lifecycle interface).
#
# This is the NSR compliance harness's contract path: `.compliance/gates/
# check_wiring.sh` requires `.agents/skills/lifecycle/{start,stop,status,
# smoke_test}.sh` for a project to count as operable. The NAME is the harness's
# interface (like `.compliance/`), not a Norse figure — the work it does is a
# wrapper, and a wrapper never rewrites the procedure it wraps.
#
# It delegates to the real boot command. Nothing is duplicated here.
#
# Usage: start.sh [--foreground]
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"

if [ ! -x "$ROOT/scripts/start.sh" ]; then
  printf 'error: %s not found or not executable\nhelp: the stack is raised by scripts/start.sh\n' \
    "$ROOT/scripts/start.sh" >&2
  exit 1
fi
exec "$ROOT/scripts/start.sh" "$@"
