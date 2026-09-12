#!/usr/bin/env bash
# stop.sh — lower the WayOfNorthStar stack (the lifecycle interface).
#
# Delegates to the real stop command; see start.sh for why the name is the
# compliance harness's and why the body is a wrapper.
#
# Usage: stop.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"

if [ ! -x "$ROOT/scripts/stop.sh" ]; then
  printf 'error: %s not found or not executable\nhelp: the stack is lowered by scripts/stop.sh\n' \
    "$ROOT/scripts/stop.sh" >&2
  exit 1
fi
exec "$ROOT/scripts/stop.sh" "$@"
