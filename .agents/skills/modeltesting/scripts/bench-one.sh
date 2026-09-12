#!/usr/bin/env bash
# bench-one.sh — benchmark ONE llama.cpp model end-to-end on this host.
#
# THE LAW THIS SCRIPT OBEYS: this skill TESTS. It does not run the service.
# So it never calls model-host / llama-router / the swap proxy. It starts its
# OWN throwaway single-model llama-server on a scratch port, measures it, and
# kills it. The machine's serving stack is untouched and unaware.
#
# The registry (machine property, outside every repo) is read READ-ONLY, purely
# to learn a model's gguf/ctx/flags — the same numbers the service would use, so
# the measurement reflects what the service would actually serve.
#
# Follows the modeltesting skill's 8 shared rules:
#   1. nothing else holding VRAM first; confirm the idle baseline at the end
#   2. (best-effort) lock GPU clocks
#   3. warmup request, discarded — AND warm the GPU clocks (see rule 7 note)
#   4. same seed 42 + temp 0
#   5. verify the REAL loaded context via /props (n_ctx)
#   6. capture GPU during the timed run (parallel nvidia-smi → catches CPU spill)
#   7. record observed reality, not asserted
#   8. print the record lines for backends-benchmark.md / TESTING.md / pi
#
# Usage:
#   bench-one.sh <model-id> [prompt-json] [max-tokens]
#     model-id    an id in the machine registry (`llama-models list`)
#     prompt-json optional request file (default: a built-in ~2.3k-token coding prompt)
#     max-tokens  completion length (default 256)
#
# Requires: llama-models (registry reader), a GPU llama-server, curl, python3.
# GPU server: $LLAMA_SERVER_CUDA, else `llama-server-cuda` on PATH, else
# $LLAMA_SERVER. It MUST report a CUDA device — a CPU-only server measures
# nothing (see the runbook), so the script refuses to continue without one.
set -euo pipefail

MODELS_BIN=$(command -v llama-models || echo "$HOME/.local/bin/llama-models")
MODEL=${1:?usage: bench-one.sh <model-id> [prompt-json] [max-tokens]}
PROMPT_JSON=${2:-}
MAX_TOKENS=${3:-256}
SCRATCH_PORT=$(( (RANDOM % 900) + 9100 ))
TMP=$(mktemp -d /tmp/opencode/bench.XXXXXX)
LOG="$TMP/server.log"
SRV_PID=""
cleanup() {
  # Signal ONLY the server this script started — never the machine's service.
  # SIGTERM, then a bounded wait; a server that ignores it is reported, not forced
  # (portable, and it keeps the blast radius at the one pid we own).
  if [ -n "$SRV_PID" ] && kill -0 "$SRV_PID" 2>/dev/null; then
    kill "$SRV_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$SRV_PID" 2>/dev/null || break
      sleep 1
    done
    kill -0 "$SRV_PID" 2>/dev/null && echo "  ⚠ bench server pid $SRV_PID ignored SIGTERM" >&2
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "=== [0/8] preflight — a TEST needs a real GPU server ==="
GPU_SRV="${LLAMA_SERVER_CUDA:-}"
[ -z "$GPU_SRV" ] && command -v llama-server-cuda >/dev/null 2>&1 && GPU_SRV=$(command -v llama-server-cuda)
# Prefer whatever the machine's registry points at — then the bench measures the
# same server the service would use, which is the whole point of the reading.
[ -z "$GPU_SRV" ] && GPU_SRV=$("$MODELS_BIN" defaults 2>/dev/null | cut -d'|' -f1)
[ -n "$GPU_SRV" ] && [ -x "$GPU_SRV" ] || GPU_SRV="${LLAMA_SERVER:-$(command -v llama-server || true)}"
[ -x "$GPU_SRV" ] || { echo "✗ no llama-server found (set LLAMA_SERVER_CUDA)" >&2; exit 1; }
DEVS=$("$GPU_SRV" --list-devices 2>&1 | grep -c CUDA || true)
if [ "$DEVS" -eq 0 ]; then
  echo "✗ this server has NO CUDA device — a CPU-only run is not a measurement:" >&2
  "$GPU_SRV" --list-devices 2>&1 | head -3 >&2
  echo "  use a CUDA build (see HOST-RUNBOOK.md in this skill)." >&2
  exit 1
fi
echo "  server: $GPU_SRV"
"$GPU_SRV" --list-devices 2>&1 | grep CUDA | sed 's/^/  /'

SPEC_GGUF=$("$MODELS_BIN" get "$MODEL" gguf)
[ -n "$SPEC_GGUF" ] || { echo "✗ unknown model '$MODEL' — see: llama-models list" >&2; exit 2; }
MODELS_DIR=$("$MODELS_BIN" defaults | cut -d'|' -f2)
GGUF="$MODELS_DIR/$SPEC_GGUF"
[ -f "$GGUF" ] || { echo "✗ gguf not on disk: $GGUF" >&2; exit 2; }
CTX=$("$MODELS_BIN" get "$MODEL" ctx);              [ -z "$CTX" ] && CTX=32768
NGL=$("$MODELS_BIN" get "$MODEL" ngl);              [ -z "$NGL" ] && NGL=999
KV=$("$MODELS_BIN" get "$MODEL" kv);                [ -z "$KV" ] && KV=q8_0
CPU_MOE=$("$MODELS_BIN" get "$MODEL" cpu_moe)
THREADS=$("$MODELS_BIN" get "$MODEL" threads);      [ -z "$THREADS" ] && THREADS=8
echo "  model: $MODEL  ctx=$CTX  ngl=$NGL  kv=$KV  cpu_moe=$CPU_MOE  threads=$THREADS"

echo "=== [1/8] VRAM pre-check (the machine's service must not be resident) ==="
USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
echo "  VRAM in use: ${USED} MiB of ${TOTAL} MiB"
if [ "$USED" -gt 2000 ]; then
  echo "  ⚠ something already holds ${USED} MiB — your numbers will be contaminated."
  echo "    Stop the machine's service first (see its own docs), not this script."
fi
# Power state: a laptop discharging can cap GPU power, so note it — but do NOT
# assume it explains a slow number. Measured here, the dominant factor is CONTEXT
# LENGTH: the same model gave 21.2 t/s decode at a 19-token prompt and 4.6 t/s at
# 7,940 tokens, while the slow run drew MORE power (113 W vs 53 W).
if grep -qi "discharging" /sys/class/power_supply/*/status 2>/dev/null; then
  echo "  ⚠ ON BATTERY (discharging) — note it in the record, but do not assume it"
  echo "    explains a slow number; context length usually does (see HOST-RUNBOOK 4.1)."
fi

echo "=== [2/8] lock GPU clocks (best effort) ==="
sudo -n nvidia-smi -lgc 1900,1900 >/dev/null 2>&1 && echo "  clocks locked 1900" || echo "  (skip: needs sudo tty)"

echo "=== [3/8] start a THROWAWAY server (scratch :$SCRATCH_PORT, not the service) ==="
EXTRA=()
if [ "$CPU_MOE" = "True" ] || [ "$CPU_MOE" = "true" ]; then EXTRA+=(--n-cpu-moe 999)
elif [ -n "$CPU_MOE" ] && [ "$CPU_MOE" != "False" ] && [ "$CPU_MOE" != "false" ]; then EXTRA+=(--n-cpu-moe "$CPU_MOE"); fi
"$GPU_SRV" -m "$GGUF" -ngl "$NGL" --flash-attn on \
  --cache-type-k "$KV" --cache-type-v "$KV" \
  -c "$CTX" -b 4096 -ub 4096 -t "$THREADS" --jinja --temp 0 --seed 42 \
  -np 1 --host 127.0.0.1 --port "$SCRATCH_PORT" "${EXTRA[@]}" > "$LOG" 2>&1 &
SRV_PID=$!
for i in $(seq 1 90); do
  sleep 2
  grep -q "model loaded" "$LOG" 2>/dev/null && { echo "  loaded in $((i*2))s (pid $SRV_PID)"; break; }
  grep -qE "out of memory|error loading model|failed to allocate" "$LOG" 2>/dev/null && {
    echo "✗ FAILED to load — last lines:" >&2; tail -6 "$LOG" >&2; exit 1; }
  kill -0 "$SRV_PID" 2>/dev/null || { echo "✗ server exited during load" >&2; tail -6 "$LOG" >&2; exit 1; }
done
grep -q "model loaded" "$LOG" || { echo "✗ timed out waiting for load" >&2; tail -6 "$LOG" >&2; exit 1; }
nvidia-smi --query-gpu=memory.used --format=csv,noheader | sed 's/^/  VRAM: /'

echo "=== [4/8] verify the REAL loaded context (/props) ==="
curl -s "http://127.0.0.1:$SCRATCH_PORT/props" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  n_ctx:', d.get('default_generation_settings', {}).get('n_ctx'))
print('  model:', d.get('model_path'))
" 2>/dev/null || echo "  (props unreadable)"

echo "=== [5/8] build the timed request ($MAX_TOKENS max tokens) ==="
if [ -n "$PROMPT_JSON" ]; then
  REQ="$PROMPT_JSON"; echo "  using $PROMPT_JSON"
else
  REQ="$TMP/req.json"
  python3 - "$REQ" "$MAX_TOKENS" <<'PYEOF'
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
fi

echo "=== [6/8] WARM THE GPU (this host idles at ~210 MHz and boosts lazily) ==="
python3 -c "
import json;json.dump({'model':'local','messages':[{'role':'user','content':'hi'}],'max_tokens':8,'temperature':0},open('$TMP/warm.json','w'))"
curl -s "http://127.0.0.1:$SCRATCH_PORT/v1/chat/completions" -H "Content-Type: application/json" \
  -d @"$TMP/warm.json" -o /dev/null
nvidia-smi --query-gpu=clocks.sm,power.draw --format=csv,noheader | sed 's/^/  after warm: /'

echo "=== [7/8] timed run + GPU sampling ==="
( for i in $(seq 1 120); do
    nvidia-smi --query-gpu=utilization.gpu,power.draw,memory.used --format=csv,noheader >> "$TMP/gpu.txt"
    sleep 1
  done ) &
SAMPLER=$!
START=$(date +%s.%N)
curl -s "http://127.0.0.1:$SCRATCH_PORT/v1/chat/completions" -H "Content-Type: application/json" \
  -d @"$REQ" -o "$TMP/out.json"
END=$(date +%s.%N)
kill "$SAMPLER" 2>/dev/null || true; wait "$SAMPLER" 2>/dev/null || true
echo "  peak VRAM / peak util / max power seen:"
python3 - "$TMP/gpu.txt" <<'PYEOF'
import sys
rows = [l.strip().split(", ") for l in open(sys.argv[1]) if l.strip()]
if rows:
    vram = max(int(r[2].split()[0]) for r in rows)
    util = max(int(r[0].split()[0]) for r in rows)
    pwr  = max(float(r[1].split()[0]) for r in rows)
    print(f"    VRAM {vram} MiB | util {util}% | {pwr:.0f} W")
    if util < 50:
        print("    ⚠ util stayed under 50% — clocks never rose, or the run was CPU-bound.")
PYEOF

echo "=== [8/8] results ==="
python3 - "$TMP/out.json" "$START" "$END" "$CTX" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
if "error" in d:
    print("  ERROR:", str(d["error"])[:400]); sys.exit(0)
t = d.get("timings", {})
wall = float(sys.argv[3]) - float(sys.argv[2])
print(f"  wall: {wall:.1f}s   configured ctx: {sys.argv[4]}")
print(f"  prompt_tokens: {d.get('usage',{}).get('prompt_tokens')}")
print(f"  prefill: {t.get('prompt_per_second', 0):.1f} t/s   decode: {t.get('predicted_per_second', 0):.1f} t/s")
print(f"  cache_n: {t.get('cache_n')}  (0 = true cold prefill)")
print("\n  RECORD THESE (backends-benchmark §10.5 + TESTING.md §8 + pi models.json):")
print(f"    prefill={t.get('prompt_per_second',0):.1f} decode={t.get('predicted_per_second',0):.1f} wall={wall:.1f}s ctx={'see /props'}")
print(f"\n  NOTE: decode/prefill above are measured at THIS run's context")
print(f"        ({d.get('usage',{}).get('prompt_tokens')} prompt tokens). A short-context figure is an")
print(f"        UPPER BOUND — only compare runs at equal context (HOST-RUNBOOK 4.1).")
PYEOF

echo "=== teardown ==="
kill "$SRV_PID" 2>/dev/null || true; wait "$SRV_PID" 2>/dev/null || true; SRV_PID=""
sleep 1
echo "  VRAM after: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader) (expect the idle baseline)"
