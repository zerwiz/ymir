#!/usr/bin/env bash
# sessions.sh — `ymir sessions`: every agent session on this machine, from every tool (plan 368). Complete on one
# computer with no heart; --fleet only adds. Run with --help for the commands.
set -uo pipefail
exec python3 "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/sessions_index.py" "$@"
