#!/usr/bin/env bash
# free-models.sh — the free models a harness can serve on this machine, and the one to use.
#
# Why (the Allfather, 2026-11-12): "add free models for both Pi and OpenCode" — said
# the night Pi's paid tokens ran out with two hours to their refresh. A worker that
# names no paid model must still have a road, and a free model is that road.
#
# The truth is the LIVE catalog, never a table in a document (the catalog rule of
# 2026-10-24): `opencode models` for OpenCode, `bin/model/catalog.sh` (pi's catalog)
# for Pi. A model is free when its name says so: `-free` (OpenCode Zen and Go) or
# `:free` (OpenRouter).
#
# `pick` takes the first of the preference list that the catalog serves, else the
# first free model the catalog lists. The preference is YMIR_FREE_MODELS_<HARNESS>
# (comma-separated tokens) when set, else the shipped default below — free models come
# and go, so a missing preference is skipped, never an error.
#
# Usage:
#   free-models.sh list <pi|opencode>      # every free model the harness serves, one row each
#   free-models.sh pick <pi|opencode>      # the one token to pass as --model
#
# Exit: 0 ok · 1 no free model is served · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION=$1; HARNESS=${2-}

# Shipped preference, strongest first. Plain public model names, nothing private.
DEFAULT_OPENCODE="opencode/deepseek-v4.1-flash-free,opencode/glm-5.3-flash-free,opencode/minimax-m3.1-flash-free,opencode/longcat-2.5-free"
DEFAULT_PI="opencode-go/longcat-2.5-free,openrouter/nvidia/nemotron-3.5-super-vl:free,openrouter/google/gemma-4-31b-it:free,opencode-go/beam-free"

served() {  # every free token the harness serves, one per line
  case "$HARNESS" in
    opencode)
      command -v opencode >/dev/null 2>&1 || return 0
      opencode models 2>/dev/null | grep -E '(-free|:free)$' ;;
    pi)
      "$SCRIPT_DIR/catalog.sh" 2>/dev/null \
        | sed -n 's/^ *"\([^"]*\)","\([^"]*\)".*/\1\/\2/p' | grep -E '(-free|:free)$' ;;
  esac
}

case "$HARNESS" in
  pi) PREF="${YMIR_FREE_MODELS_PI:-$DEFAULT_PI}" ;;
  opencode) PREF="${YMIR_FREE_MODELS_OPENCODE:-$DEFAULT_OPENCODE}" ;;
  *) printf 'error: harness must be pi or opencode (got "%s")\nhelp: free-models.sh pick <pi|opencode>\n' "$HARNESS" >&2; exit 2 ;;
esac

LIST="$(served)"
case "$ACTION" in
  list)
    n=$(printf '%s' "$LIST" | grep -c . || true)
    printf 'free-models[%s]{harness,model}:\n' "$n"
    printf '%s\n' "$LIST" | grep . | while IFS= read -r m; do printf '  "%s","%s"\n' "$HARNESS" "$m"; done
    [ "$n" -gt 0 ] || { printf 'help: no free model is served for %s — check the catalog (bin/model/catalog.sh, opencode models)\n' "$HARNESS" >&2; exit 1; }
    ;;
  pick)
    IFS=',' read -r -a prefs <<<"$PREF"
    for p in "${prefs[@]}"; do
      p="${p// /}"
      [ -n "$p" ] && printf '%s\n' "$LIST" | grep -qxF "$p" && { printf '%s\n' "$p"; exit 0; }
    done
    first="$(printf '%s\n' "$LIST" | grep . | head -1)"
    [ -n "$first" ] && { printf '%s\n' "$first"; exit 0; }
    printf 'error: no free model is served for %s on this machine\nhelp: free-models.sh list %s\n' "$HARNESS" "$HARNESS" >&2
    exit 1 ;;
  *) printf 'error: unknown action %s\nhelp: free-models.sh list|pick <pi|opencode>\n' "$ACTION" >&2; exit 2 ;;
esac
