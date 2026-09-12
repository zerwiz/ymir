#!/usr/bin/env bash
# a2a-serve.sh — run the a2a-sdk A2A 1.0 server for a seated Eindri.
#   bin/a2a-serve.sh <pane-or-agent> <name> [port]
# The server is bin/a2a-serve.py (a2a-sdk); the executor injects via herdr.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${3:-7791}"
exec python3 "$SCRIPT_DIR/a2a-serve.py" "$1" "${2:-eindri}" "$PORT"
