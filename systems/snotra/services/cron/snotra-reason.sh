#!/usr/bin/env bash
# snotra-reason.sh — the reasoning pass: use an LLM for logic tasks.
#
#   snotra-reason.sh extract   <transcript-file> [--provider P] [--model M] [--api-key K]
#   snotra-reason.sh steps     <action-text>      [--provider P] [--model M] [--api-key K]
#   snotra-reason.sh classify  <card-text>        [--provider P] [--model M] [--api-key K]
#   snotra-reason.sh dedup     <new-card> --context <existing> [--provider P] [--model M] [--api-key K]
#   snotra-reason.sh identity  <speaker> --context <context> [--provider P] [--model M] [--api-key K]
#   snotra-reason.sh test      [--provider P] [--model M] [--api-key K]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec python3 "$ROOT/systems/snotra/services/cron/reasoning_adapter.py" "$@"
