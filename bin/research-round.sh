#!/usr/bin/env bash
# research-round.sh — one reusable research errand: seat a skald or a sage, give
# them the brief, arm the handoff.
#
# The round that Bragi (marketing) and Huginn (research) run is always the same
# shape: a topic, sources to cite, a real artifact on the marketing/research
# shelf, and a report back to Brokk. Doing that by hand means re-typing the seat
# law, the state paths, and the model every time — and getting one of them wrong.
# This is the script (law 7: a recurring task becomes a tool).
#
#   bin/research-round.sh "<topic>" [--figure bragi] [--out DIR] [--model M] [--no-arm]
#
# Figure defaults to bragi (the skald, marketing). Huginn is the researcher.
# The model comes from the private map (bin/agents-config.sh), never a literal.
#
# What it does, in order:
#   1. resolve the figure's harness + model from config/agents.yaml
#   2. seat it in a pane with its OWN state dir (lock + pointer isolated)
#   3. load its role file so it is the figure, not Brokk
#   4. inject the seat law and the research brief
#   5. arm the handoff, so the report wakes Brokk instead of evaporating
#
# Exit: 0 seated, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
hoard_state_dir STATE 2>/dev/null || STATE="${BROKK_STATE_OVERRIDE:-$ROOT/state}"
hoard_root HOME_DIR 2>/dev/null || HOME_DIR="$ROOT"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

TOPIC="${1:-}"; shift || true
FIGURE="bragi"; OUT=""; MODEL=""; ARM=1
while [ $# -gt 0 ]; do
  case "$1" in
    --figure) FIGURE="${2:-bragi}"; shift 2 ;;
    --figure=*) FIGURE="${1#--figure=}"; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --out=*) OUT="${1#--out=}"; shift ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --model=*) MODEL="${1#--model=}"; shift ;;
    --no-arm) ARM=0; shift ;;
    *) shift ;;
  esac
done

[ -n "$TOPIC" ] || { printf 'error: usage: bin/research-round.sh "<topic>" [--figure bragi] [--out DIR] [--model M]\n' >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { printf 'error: herdr not on PATH\n' >&2; exit 1; }

# 1. the figure's harness + model, from the private map (Rule 07: no literal).
if [ -z "$MODEL" ] && [ -x "$SCRIPT_DIR/agents-config.sh" ]; then
  MODEL="$("$SCRIPT_DIR/agents-config.sh" get "$FIGURE" model 2>/dev/null)"
fi
[ -n "$MODEL" ] || MODEL="llama-swap/qwen3.6-35b-a3b@q2_k_xl"
HARNESS="pi"
[ -x "$SCRIPT_DIR/agents-config.sh" ] && HARNESS="$("$SCRIPT_DIR/agents-config.sh" get "$FIGURE" harness 2>/dev/null || printf 'pi')"

# the role file: the chooser speaks short roles, the roster carries the craft
ROLE_FILE=""
for f in "$ROOT/.agents/agents/$FIGURE.md" "$ROOT/.agents/agents/$FIGURE"*.md; do
  [ -r "$f" ] && { ROLE_FILE="$f"; break; }
done

# 2. the seat's own state dir — lock AND pointer, so the primary's helm is safe

# 2a. the LOCAL-MODEL GUARD. One local inference at a time per machine; a seat
# whose model is local must not start when the host is already at capacity. This
# is the law `bin/local-model-lock.sh` exists for and that no seat road called.
case "$MODEL" in
  llama-swap/*|llamacpp-whynot/*|llama.cpp/*|llama-cpp/*|lmstudio/*)
    if [ -x "$SCRIPT_DIR/local-model-lock.sh" ]; then
      if ! "$SCRIPT_DIR/local-model-lock.sh" check >/dev/null 2>&1; then
        "$SCRIPT_DIR/local-model-lock.sh" check >&2
        printf 'help: a local seat already runs on this machine. Wait for it, or seat on a remote/online model.\n' >&2
        exit 3
      fi
    fi
    ;;
esac

SEAT_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ymir/seats/$FIGURE-round-$(date -u +%H%M%S)"
mkdir -p "$SEAT_DIR" 2>/dev/null || true

PANE="$(herdr tab create --cwd "$ROOT" --label "$FIGURE — research round" \
  --env "BROKK_MACHINE_STATE_DIR=$SEAT_DIR" --env "BROKK_STATE_OVERRIDE=$SEAT_DIR" 2>/dev/null \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])' 2>/dev/null)"
[ -n "$PANE" ] || { printf 'error: could not create a pane (is herdr running?)\n' >&2; exit 1; }

# 3. start it with its own file loaded, so it answers as itself
ARGS=(-- --model "$MODEL")
[ -n "$ROLE_FILE" ] && ARGS+=(--append-system-prompt "$ROLE_FILE")
herdr agent start "$FIGURE" --kind "$HARNESS" --pane "$PANE" "${ARGS[@]}" >/dev/null 2>&1 \
  || { printf 'error: could not start %s in %s\nhelp: the pane must sit at an interactive shell prompt\n' "$FIGURE" "$PANE" >&2; exit 1; }
sleep 6

# 4. the seat law + the brief
[ -n "$OUT" ] || OUT="$HOME_DIR/workspaces/marketing/scraped"
mkdir -p "$OUT" 2>/dev/null || true

BRIEF="Seat law, read first. You are a worker figure, not the primary. There is NO human at this terminal: do NOT use ask_user_question. Decide everything inside your craft yourself. If a genuine fork needs the coordinator, write the QUESTION to $STATE/eindri-questions/$FIGURE.md and stop — Brokk answers with bin/eindri-send.sh. When the errand is DONE, write the report to $STATE/eindri-reports/$FIGURE.md. If the same action fails twice, do not run it a third time.

TASK — a research round. TOPIC: $TOPIC

1. Research with SOURCES. Use your pi web tools (web_search, fetch_content) — they need no key. A self-hosted Firecrawl may answer on http://localhost:3002; use it if it does, but never wait on it.
2. Every claim carries its URL. Never invent a statistic, a quote, or a competitor. Where you could not verify something, say so plainly.
3. Land a REAL artifact (not a plan) at: $OUT/
   Name it for the topic and the date.
4. Then write $STATE/eindri-reports/$FIGURE.md with a short summary and the artifact path, and end your turn."

herdr agent prompt "$FIGURE" "$BRIEF" >/dev/null 2>&1 || true

# 5. arm the handoff, so the report wakes Brokk
ARMED="no"
if [ "$ARM" = "1" ] && [ -x "$SCRIPT_DIR/eindri-watch.sh" ]; then
  if "$SCRIPT_DIR/eindri-watch.sh" arm "$FIGURE" "$ROOT" >/dev/null 2>&1; then ARMED="watch-$FIGURE"; fi
fi

printf 'research-round[1]{figure,harness,model,pane,out,report,armed}:\n'
printf '  "%s","%s","%s","%s","%s","%s","%s"\n' \
  "$FIGURE" "$HARNESS" "$MODEL" "$PANE" "$OUT" "$STATE/eindri-reports/$FIGURE.md" "$ARMED"
