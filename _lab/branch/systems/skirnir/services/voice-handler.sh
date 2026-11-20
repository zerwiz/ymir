#!/usr/bin/env bash
# voice-handler.sh — the bridge's outbound voice step, shaped for pi-telegram's command templates.
#
#   bin/assistant/voice-handler.sh <out.ogg>   ← the reply text arrives on STDIN
#
# Why a wrapper and not the mouth directly (measured 2026-10-23): the bridge reads
# `outboundHandlers[].template` by the command-template standard — **a string is one command; an array
# is a SEQUENCE of commands**, not one command split into words. The config held
# `["bash", "…/mouth.sh", "{text}", "{ogg}"]`, so the bridge ran four steps: `bash` with the reply on
# stdin, then the mouth with NO arguments, then the reply text as a command name, then the path. No
# ogg was ever written, and `output: "ogg"` still told the sender to upload `{ogg}` — every voice reply
# died as `sendVoice → Unable to open file as blob`.
#
# Text on stdin also removes the quoting hazard: a long sentence with an apostrophe is data, not shell.
set -u
OUT="${1:-}"
[ -n "$OUT" ] || { printf 'voice-handler: usage: voice-handler.sh <out.ogg>  (text on stdin)\n' >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEXT="$(cat)"
exec /bin/bash "$SCRIPT_DIR/mouth.sh" "$TEXT" "$OUT"
