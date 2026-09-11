#!/usr/bin/env bash
# bench-one.sh — benchmark ONE llama.cpp model end-to-end on zerwiz.
#
# Follows the modeltesting skill's 8 shared rules:
#   1. unload everything first, confirm 26 MiB baseline
#   2. (best-effort) lock GPU clocks
#   3. warmup request, discard it
#   4. same seed 42 + temp 0
#   5. verify loaded context via /props (n_ctx)
#   6. capture GPU during the timed run (parallel nvidia-smi → catches CPU spill)
#   7. record observed reality, not asserted
#   8. print the record lines for backends-benchmark.md / TESTING.md / pi
#
# Usage:
#   bench-one.sh <model-id> [prompt-json] [max-tokens]
#     model-id    a model in the llama-models registry (model-host list)
#     prompt-json optional request file (default: a built-in 3800-token coding prompt)
#     max-tokens  completion length (default 256)
#
# Requires: model-host (in PATH or ~/Ymir/scripts), llama-models, curl, jq-ish python3.
set -euo pipefail

MH=/home/zerwiz/Ymir/scripts/model-host.sh
MODELS_BIN=/home/zerwiz/.local/bin/llama-models
MODEL=${1:?usage: bench-one.sh <model-id> [prompt-json] [max-tokens]}
PROMPT_JSON=${2:-}
MAX_TOKENS=${3:-256}
TMP=$(mktemp -d /tmp/opencode/bench.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo "=== [1/7] unload everything, confirm baseline ==="
"$MH" stop >/dev/null 2>&1 || true
sleep 1
BASE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
echo "  VRAM baseline: ${BASE} MiB (expect ~26)"

echo "=== [2/7] lock GPU clocks (best effort) ==="
sudo -n nvidia-smi -lgc 1900,1900 >/dev/null 2>&1 && echo "  clocks locked 1900" || echo "  (skip: needs sudo tty)"

echo "=== [3/7] start model ==="
"$MH" start "$MODEL" 2>&1 | grep -E "starting|loaded|VRAM|✗|exited" || true

PORT=$("$MODELS_BIN" get "$MODEL" port 2>/dev/null)
[ -z "$PORT" ] && PORT=8125
sleep 2

echo "=== [4/7] verify loaded context (/props) ==="
curl -s "http://localhost:$PORT/props" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  n_ctx:', d.get('default_generation_settings', {}).get('n_ctx'))
print('  model:', d.get('model_path'))
" || echo "  (props not readable — server may be slow to init)"

echo "=== [5/7] warmup (discard) ==="
if [ -n "$PROMPT_JSON" ]; then
  curl -s "http://localhost:$PORT/v1/chat/completions" -H "Content-Type: application/json" -d @"$PROMPT_JSON" -o /dev/null
else
  # built-in ~3800-token coding prompt
  python3 - "$TMP/req.json" "$MAX_TOKENS" <<'PYEOF'
import json, sys
lines = ["```python", "def fibonacci(n):", "    if n <= 1: return n",
         "    a, b = 0, 1", "    for _ in range(n - 1):", "        a, b = b, a + b",
         "    return a", "```", ""]
text = "\n".join(lines); chunk = text
while len(text) < 9000: text = text + "\n" + chunk
prompt = ("You are a senior Python engineer. Analyze the following code thoroughly and "
          "explain the time complexity, edge cases, and how you would refactor it for "
          "production. Be detailed and specific.\n\n" + text[:9000] +
          "\n\nWrite a complete, production-quality answer explaining the algorithm.")
json.dump({"model": "local", "messages": [{"role": "user", "content": prompt}],
           "max_tokens": int(sys.argv[2]), "temperature": 0, "seed": 42, "stream": False},
          open(sys.argv[1], "w"))
print("  built prompt ~", len(prompt)//4, "tokens")
PYEOF
  curl -s "http://localhost:$PORT/v1/chat/completions" -H "Content-Type: application/json" -d @"$TMP/req.json" -o /dev/null
fi
echo "  warmup done"

echo "=== [6/7] restart to clear cache, then COLD timed run + GPU sampling ==="
"$MH" stop "$MODEL" >/dev/null 2>&1 || true
sleep 1
"$MH" start "$MODEL" >/dev/null 2>&1 || true
sleep 2
( for i in $(seq 1 10); do nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader >> "$TMP/gpu.txt"; sleep 2; done ) &
SAMPLER=$!
START=$(date +%s.%N)
curl -s "http://localhost:$PORT/v1/chat/completions" -H "Content-Type: application/json" -d @"$TMP/req.json" -o "$TMP/out.json"
END=$(date +%s.%N)
wait "$SAMPLER" || true
echo "  GPU samples during run (util≈95-100% during prefill = good):"
sed 's/^/    /' "$TMP/gpu.txt"

echo "=== [7/7] results ==="
python3 - "$TMP/out.json" "$START" "$END" "$PORT" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
t = d.get("timings", {})
wall = float(sys.argv[3]) - float(sys.argv[2])
print(f"  wall: {wall:.1f}s  port: {sys.argv[4]}")
print(f"  prompt_tokens: {d.get('usage',{}).get('prompt_tokens')}")
print(f"  prefill: {t.get('prompt_per_second', 0):.1f} t/s  decode: {t.get('predicted_per_second', 0):.1f} t/s")
print(f"  cache_n: {t.get('cache_n')}  (0 = true cold prefill)")
print("\n  RECORD THESE (backends-benchmark §10.5 + TESTING.md §8 + pi models.json):")
print(f"    model={d.get('model')} prefill={t.get('prompt_per_second',0):.1f} decode={t.get('predicted_per_second',0):.1f} wall={wall:.1f}s")
PYEOF

echo "=== unload + confirm baseline ==="
"$MH" stop "$MODEL" >/dev/null 2>&1 || true
sleep 1
AFTER=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
echo "  VRAM after: ${AFTER} MiB (expect back to ~26)"