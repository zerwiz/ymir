#!/usr/bin/env bash
# hermes-seat.sh — a one-line launcher: the Hermes seat is src/ymir_runtime/hermes/seat.py (plan 317 slices 2–3).
#   bin/seat/hermes-seat.sh [--check | --dry-run]   seat · compare values (exit 1 naming each drift) · show the diff
exec env PYTHONPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src${PYTHONPATH:+:$PYTHONPATH}" python3 -m ymir_runtime.hermes seat "$@"
