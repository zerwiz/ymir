#!/usr/bin/env bash
# card.sh — THE door every card passes through (gimle plan 328). The verbs and the why live in card.py beside it;
# `card.sh --help` prints them. Contract: hodd/identity/cards.yaml in the home. Ledger: hodd/state/boards/cards.jsonl.
set -uo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/card.py" "$@"
