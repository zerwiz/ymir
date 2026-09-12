#!/usr/bin/env bash
# pi-seat.sh — seat a Pi agent in a VISIBLE herdr pane, optionally on a local
# model. Reusable for Ymir features and users when the stack is running.
#
#   bin/pi-seat.sh                                   # pi + default local model, no task
#   bin/pi-seat.sh --task "design a hero"            # seat, then prompt
#   bin/pi-seat.sh -n sindri -m qwen3.6-35b-q4_k_s --task "..."
#   bin/pi-seat.sh --tab --task "..."               # seat in a new tab
#
# Requires HERDR_ENV=1 (run inside a herdr pane). Splits a pane beside you,
# starts pi with --model <provider>/<id>, and prints the pane + agent name.
set -u

VERSION="1.0.0"
PROVIDER="${PI_LOCAL_PROVIDER:-llama-cpp}"
MODEL="${PI_LOCAL_MODEL:-frontend-design-expert-8b@q4_k_m}"
NAME="pi-local"; TASK=""; WHERE="--current"; DIR="$PWD"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--name) NAME=${2-}; shift 2 ;;
    -m|--model) MODEL=${2-}; shift 2 ;;
    -p|--provider) PROVIDER=${2-}; shift 2 ;;
    --task) TASK=${2-}; shift 2 ;;
    --dir) DIR=${2-}; shift 2 ;;
    --tab) WHERE="--tab"; shift ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
[ "${HERDR_ENV:-}" = "1" ] || { printf 'error: not inside herdr (HERDR_ENV unset)\nhelp: run this from a herdr pane\n' >&2; exit 1; }
have herdr || { printf 'error: herdr not on PATH\n' >&2; exit 1; }

# 1. a place to sit — a new tab, or a split beside the caller.
if [ "$WHERE" = "--tab" ]; then
  PANE="$(herdr tab create --cwd "$DIR" --label "pi:$NAME" 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')"
else
  PANE="$(herdr pane split --current --direction right --cwd "$DIR" 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')"
fi
[ -n "$PANE" ] || { printf 'error: could not create a pane\n' >&2; exit 1; }

# 2. start pi on the chosen model in that pane.
if ! herdr agent start "$NAME" --kind pi --pane "$PANE" -- --model "$PROVIDER/$MODEL" >/dev/null 2>&1; then
  printf 'error: could not start pi in %s\nhelp: the pane must sit at an interactive shell prompt\n' "$PANE" >&2; exit 1
fi

# 3. optional first task.
[ -n "$TASK" ] && herdr agent prompt "$NAME" "$TASK" >/dev/null 2>&1 || true

printf 'pi-seat[1]{agent,pane,provider,model}:\n  "%s","%s","%s","%s"\n' "$NAME" "$PANE" "$PROVIDER" "$MODEL"
