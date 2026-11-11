#!/usr/bin/env bash
# test_attribution_guard.sh — RULES/53: the guard refuses AI attribution and lets a person's co-author through.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
bash "$ROOT/bin/gates/guards/attribution-guard.sh" --self-test
