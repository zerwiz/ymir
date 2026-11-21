#!/usr/bin/env bash
# team-run.sh — run the smithy on a chosen machine (here, a named one, or the least loaded) and follow the run.
#   team-run.sh run --task "<text>" [--on HOST|auto] [--team T] [--project P] [--runtime herdr|internal] [--phone|--json]
#   team-run.sh status|tail|stop <id> [--on HOST]    team-run.sh where
# The work is in team-run.py; this is the door every face (Pi tool, MCP tool, a person) calls.
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/team-run.py" "$@"
