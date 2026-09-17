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

# The well is ONE memory and it lives in the hoard — always (Rule 04/07).
# An explicit YMIR_WELL/ENGRAM_DB is the operator's escape hatch.
if [ -n "${YMIR_WELL:-}" ] || [ -n "${ENGRAM_DB:-}" ]; then
  WELL="${YMIR_WELL:-${ENGRAM_DB:-}}"
else
  . "$SCRIPT_DIR/hoard-lib.sh" 2>/dev/null || true
  hoard_memory_store WELL
fi
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
