#!/usr/bin/env bash
# push.sh — commit and push NAMED paths in the home (never `git add -A`).
#
#   push.sh <message> <path> [path…]
#   push.sh --dry-run <message> <path> [path…]   # what would be staged; nothing touched
#
# 2026-11-10: now a thin door onto bin/vault/home-sync.sh ship, which pulls BEFORE it
# commits and merges + retries when another seat pushed first (RULES/50). The old body
# pushed without fetching, so a stale seat's push was simply rejected and the commit
# stayed local — the collision this rule answers.
#
# Staging discipline (Rule 04) and the no-delete rule (Rule 11) are enforced by home-sync.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dry=(); [ "${1-}" = "--dry-run" ] && { dry=(--dry-run); shift; }
msg="${1:-}"; shift || true
[ -n "$msg" ] && [ $# -gt 0 ] || { printf 'usage: push.sh "<message>" <path> [path…]\n' >&2; exit 2; }
exec bash "$ROOT/bin/vault/home-sync.sh" ship "${dry[@]}" "$msg" "$@"
