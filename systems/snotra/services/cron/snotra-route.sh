#!/usr/bin/env bash
# snotra-route.sh — the action router: from transcription to action across channels.
#
#   snotra-route.sh run     <meeting-dir>   route all items to configured channels
#   snotra-route.sh dry-run <meeting-dir>   what would be routed — no writes
#   snotra-route.sh status  <meeting-dir>   one row per item type
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec python3 "$ROOT/bin/time/snotra/snotra-route.py" "$@"
