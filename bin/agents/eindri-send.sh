#!/usr/bin/env bash
# eindri-send.sh — the DATA plane: send conversational text to a seated Eindri.
# The agent reads it as a new turn (herdr steers the running agent). This is how
# Brokk talks to an Eindri; the reply is read with `herdr agent read`.
#
#   bin/agents/eindri-send.sh [--from "<who>"] <agent-or-pane> "<text>"
#
# Every line is stamped with where it came from — "[from Rödd (voice) · heimdall] …", "[from herdr pane w39:pT
# (claude) · heimdall] …" — by bin/agents/msg-origin.sh (2026-11-14, at the Allfather's word). --from, or
# YMIR_MSG_FROM, names the sender; without it the pane, terminal or script is found. YMIR_MSG_STAMP=0 sends bare.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/msg-origin.sh"
[ "${1:-}" = --from ] && { export YMIR_MSG_FROM="${2:-}"; shift 2 || true; }
TARGET="${1:-}"; shift || true; TEXT="${*:-}"
[ "${YMIR_MSG_STAMP:-1}" = 0 ] || [ -z "$TEXT" ] || TEXT="$(msg_stamp "$TEXT")"
[ -n "$TARGET" ] && [ -n "$TEXT" ] || { printf 'error: usage: bin/agents/eindri-send.sh <agent-or-pane> "<text>"\n' >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { printf 'error: herdr not on PATH\n' >&2; exit 1; }
if herdr agent prompt "$TARGET" "$TEXT" >/dev/null 2>&1; then
  printf 'eindri-send[1]{target,state}:\n  "%s","sent"\n' "$TARGET"
else
  printf 'eindri-send[1]{target,state}:\n  "%s","FAILED"\n' "$TARGET" >&2; exit 1
fi
