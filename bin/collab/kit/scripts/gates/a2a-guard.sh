#!/usr/bin/env bash
# a2a-guard — a card in the constellation must stay true, and a changed one must still be valid.
#
# Called from pre-push with the range being pushed:
#   bash scripts/gates/a2a-guard.sh <base-sha> <head-sha>
#
# It runs only when the range touches `.well-known/agent-card.json` or `areas/` — a card is generated
# from the shelf, so a moved area is a moved skill. A repository with no card gets a clean skip.
#
# WHAT IT REFUSES: a changed card that does not parse, does not speak `a2a/1.0`, offers no skill, names
# a loopback address, or carries something that looks like a secret or a mailbox. What it does NOT do:
# decide who may call, or serve anything. A card is an invitation to ask, never a grant.
#
# Exit: 0 nothing to refuse · 1 a refusal · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
base="${1:-}"; head="${2:-HEAD}"

if [ "${YMIR_SKIP_A2A_GUARD:-0}" = "1" ]; then
  printf 'a2a-guard: skipped at the operator\x27s word (YMIR_SKIP_A2A_GUARD=1)\n'
  exit 0
fi
[ -e .well-known/agent-card.json ] || { printf 'a2a-guard: no card in this repository — skipped\n'; exit 0; }
[ -n "$base" ] || { printf 'a2a-guard: no base revision to compare — skipped\n'; exit 0; }
[ -x scripts/a2a.sh ] || { printf 'a2a-guard: no scripts/a2a.sh — skipped (kit older than 1.2.0)\n'; exit 0; }

touched="$(git diff --name-only "$base..$head" 2>/dev/null | grep -E '^(\.well-known/agent-card\.json|areas/)' || true)"
[ -n "$touched" ] || { printf 'a2a-guard: the card and the areas shelf are untouched\n'; exit 0; }

if bash scripts/a2a.sh check; then
  printf 'a2a-guard: the card moved with the shelf and still answers truthfully\n'
  exit 0
fi
printf '\na2a-guard refused: a card that changed with the shelf must still be valid.\n' >&2
printf '  regenerate:  bash scripts/a2a.sh card --write\n' >&2
exit 1
