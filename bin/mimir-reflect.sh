#!/usr/bin/env bash
# mimir-reflect — smelt the well's episodes into facts, through the LLAMA-ROUTER.
#
# The router is Ymir's one door to local models: its seats are llama.cpp on :8080
# (coding) and Apodex on :1234 (research/planning). NEVER point this at Ollama —
# ollama is the machine's own server, not a Ymir provider, and one local model
# rides the router at a time. Swap seats by re-pointing the router, not by
# reaching past it.
#
#   bin/mimir-reflect.sh              # the well, with the default seat
#   YMIR_ROUTER_URL=http://127.0.0.1:8080/v1 YMIR_REFLECT_MODEL=qwen3.6-35b-a3b bin/mimir-reflect.sh
set -euo pipefail

WELL="${YMIR_WELL:-${YMIR_HOME:-$HOME/Documents/Ymir}/memory/kaia.engram}"
BASE="${YMIR_ROUTER_URL:-http://127.0.0.1:1234/v1}"
MODEL="${YMIR_REFLECT_MODEL:-apodex-1.0-mini}"

[ -f "$WELL" ] || { echo "error: no well at $WELL" >&2; echo "help: set YMIR_WELL or run bin/mimir-bridge.py first" >&2; exit 1; }

echo "mimir-reflect[well,seat]:"
echo "  \"$WELL\""
echo "  \"$BASE\"  model \"$MODEL\""
echo

# A local seat needs no key; an empty one keeps the OpenAI client quiet.
OPENAI_API_KEY="${OPENAI_API_KEY:-local}" \
  exec engram reflect "$WELL" --llm openai --model "$MODEL" --base-url "$BASE"
