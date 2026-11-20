#!/usr/bin/env bash
# private-guard.sh — private structure and NDA material never cross a surface.
#
#   private-guard.sh check FILE... [--surface trello|email|public|private] [--to ADDRS]
#   private-guard.sh check --stdin [--surface ...]
#   private-guard.sh scan-meeting <meeting-dir> [--surface ...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec python3 "$ROOT/bin/gates/guards/private-guard.py" "$@"
