#!/usr/bin/env bash
# eindri-send.sh — the DATA plane: send conversational text to a seated Eindri.
# The agent reads it as a new turn (herdr steers the running agent). This is how
# Brokk talks to an Eindri; the reply is read with `herdr agent read`.
#
#   bin/eindri-send.sh <agent-or-pane> "<text>"
set -u
TARGET="${1:-}"; shift || true; TEXT="${*:-}"
[ -n "$TARGET" ] && [ -n "$TEXT" ] || { printf 'error: usage: bin/eindri-send.sh <agent-or-pane> "<text>"\n' >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { printf 'error: herdr not on PATH\n' >&2; exit 1; }
if herdr agent prompt "$TARGET" "$TEXT" >/dev/null 2>&1; then
  printf 'eindri-send[1]{target,state}:\n  "%s","sent"\n' "$TARGET"
else
  printf 'eindri-send[1]{target,state}:\n  "%s","FAILED"\n' "$TARGET" >&2; exit 1
fi
