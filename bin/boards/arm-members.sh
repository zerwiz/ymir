#!/usr/bin/env bash
# arm-members.sh — every arm holder is a member of the board (plan 327). Reads; creates nobody.
#   arm-members.sh plan [--json]
# The logic is bin/boards/arm_members.py (read its head).
set -u
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/arm_members.py" "$@"
