#!/usr/bin/env bash
# snotra-rules.sh — the rules engine for per-board, per-project, per-company handling.
#
#   snotra-rules.sh load    <company> <board> [--project <project>]   effective rules
#   snotra-rules.sh check   <company>                                  validate rules files
#   snotra-rules.sh defaults                                           house defaults
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec python3 "$ROOT/bin/time/snotra/snotra-rules.py" "$@"
