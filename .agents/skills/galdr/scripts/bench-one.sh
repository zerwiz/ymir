#!/usr/bin/env bash
# bench-one.sh — benchmark ONE local GGUF model, end to end, portably.
#
# It starts its OWN throwaway single-model llama-server on a scratch port,
# measures it, and kills it. It never touches a running service, and it needs
# nothing from the testing host but a llama-server binary and a .gguf.
#
# Usage:
#   bench-one.sh <model.gguf | model-id> [options]
#
# Options:
#   --ctx N         context to load            (default 32768)
#   --kv TYPE       KV cache type for BOTH k and v (default f16; q8_0 halves it)
#   --ngl N         layers on GPU              (default 999 = as many as fit)
#   --batch N       batch and ubatch           (default 2048)
#   --threads N     CPU threads                (default: all cores)
#   --device NAME   pin a device (CUDA0, Vulkan0, …)
#   --server PATH   llama-server binary        (default $LLAMA_SERVER, else PATH)
#   --port N        scratch port               (default: a free one)
#   --prompt FILE   request JSON               (default: built-in ~2k-token prompt)
#   --max-tokens N  completion length          (default 128)
#   --keep          leave the server running after the run
#   -h, --help      this text
#
# A bare model-id is only a convenience: if `llama-models` is on PATH (a machine
# registry from a Ymir host) its gguf/ctx/kv are read READ-ONLY so the bench
# matches what that host would serve. With no registry, pass a path to a .gguf.
#
# The 8 rules this follows are in ../SKILL.md; the measurements you take belong
# in YOUR host's Hoard (../METHOD.md → "Where the data lives").
set -euo pipefail

CTX=32768; KV=f16; NGL=999; BATCH=2048; THREADS=""; DEVICE=""; SERVER=""
PORT=""; PROMPT_JSON=""; MAX_TOKENS=128; KEEP=0; MODEL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --ctx)        CTX=$2; shift 2 ;;
    --kv)         KV=$2; shift 2 ;;
    --ngl)        NGL=$2; shift 2 ;;
    --batch)      BATCH=$2; shift 2 ;;
    --threads)    THREADS=$2; shift 2 ;;
    --device)     DEVICE=$2; shift 2 ;;
    --server)     SERVER=$2; shift 2 ;;
    --port)       PORT=$2; shift 2 ;;
    --prompt)     PROMPT_JSON=$2; shift 2 ;;
    --max-tokens) MAX_TOKENS=$2; shift 2 ;;
    --keep)       KEEP=1; shift ;;
    -h|--help)    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)           echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    *)            MODEL=$1; shift ;;
  esac
done
[ -n "$MODEL" ] || { echo "usage: bench-one.sh <model.gguf|model-id> [options]  (--help)" >&2; exit 2; }

# ---- resolve the server --------------------------------------------------
if [ -z "$SERVER" ]; then SERVER="${LLAMA_SERVER:-$(command -v llama-server || true)}"; fi
[ -n "$SERVER" ] && [ -x "$SERVER" ] || {
  echo "✗ no llama-server found. Install one, or pass --server PATH (or set \$LLAMA_SERVER)." >&2; exit 1; }

# ---- resolve the model ---------------------------------------------------
GGUF="$MODEL"
if [ ! -f "$GGUF" ]; then
  if command -v llama-models >/dev/null 2>&1; then
    g=$(llama-models get "$MODEL" gguf 2>/dev/null || true)
    md=$(llama-models defaults 2>/dev/null | cut -d'|' -f2)
    [ -n "$g" ] && GGUF="$md/$g"
    # only adopt registry values the user did not set explicitly
    [ "$CTX" = "32768" ] && { v=$(llama-models get "$MODEL" ctx); [ -n "$v" ] && CTX=$v; }
    [ "$KV" = "f16" ]   && { v=$(llama-models get "$MODEL" kv);  [ -n "$v" ] && KV=$v; }
    [ "$NGL" = "999" ]  && { v=$(llama-models get "$MODEL" ngl); [ -n "$v" ] && NGL=$v; }
    [ -z "$THREADS" ]   && { v=$(llama-models get "$MODEL" threads); [ -n "$v" ] && THREADS=$v; }
  fi
fi
[ -f "$GGUF" ] || { echo "✗ not a file and not a known model id: $MODEL" >&2; exit 2; }
[ -n "$THREADS" ] || THREADS=$( (command -v nproc >/dev/null && nproc) || echo 8 )
[ -n "$PORT" ] || PORT=$(( (RANDOM % 800) + 9200 ))

TMP=$(mktemp -d "${TMPDIR:-/tmp}/bench.XXXXXX")
LOG="$TMP/server.log"; SRV_PID=""
cleanup() {
  # Signal ONLY the server this script started — never anyone else's.
  if [ "$KEEP" = "0" ] && [ -n "$SRV_PID" ] && kill -0 "$SRV_PID" 2>/dev/null; then
    kill "$SRV_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$SRV_PID" 2>/dev/null || break; sleep 1; done
    kill -0 "$SRV_PID" 2>/dev/null && echo "  ⚠ bench server pid $SRV_PID ignored SIGTERM" >&2
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
command -v curl >/dev/null || { echo "✗ curl is required" >&2; exit 1; }

gpu_mem() {  # peak VRAM in MiB, if this host exposes it
  command -v nvidia-smi >/dev/null 2>&1 || { echo "?"; return; }
  nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "?"
}

echo "=== [1/7] server ==="
echo "  $SERVER"
DEVS=$("$SERVER" --list-devices 2>&1 | grep -icE "CUDA|Vulkan|ROCm|Metal" || true)
if [ "$DEVS" -eq 0 ]; then
  echo "  ⚠ this build reports NO GPU device — you are about to measure the CPU."
  echo "    That is a valid CPU test; it is not a GPU measurement."
else
  "$SERVER" --list-devices 2>&1 | grep -iE "CUDA|Vulkan|ROCm|Metal" | sed 's/^/  /'
fi
echo "=== [2/7] configuration ==="
echo "  model: $GGUF"
echo "  ctx=$CTX  kv=$KV (both K and V)  ngl=$NGL  batch=$BATCH  threads=$THREADS${DEVICE:+  device=$DEVICE}"
echo "  note: keep K and V identical. A build that lacks the kernel for your KV"
echo "        type can silently move attention to the CPU (see ../METHOD.md)."
echo "  VRAM in use before start: $(gpu_mem) MiB"

echo "=== [3/7] start a throwaway server on :$PORT ==="
ARGS=(-m "$GGUF" -ngl "$NGL" --flash-attn on
      --cache-type-k "$KV" --cache-type-v "$KV"
      -c "$CTX" -b "$BATCH" -ub "$BATCH" -t "$THREADS" --jinja --temp 0 --seed 42
      -np 1 --host 127.0.0.1 --port "$PORT")
[ -n "$DEVICE" ] && ARGS+=(--device "$DEVICE")
"$SERVER" "${ARGS[@]}" > "$LOG" 2>&1 &
SRV_PID=$!
for i in $(seq 1 120); do
  sleep 2
  grep -qE "model loaded|server is listening" "$LOG" 2>/dev/null && { echo "  loaded in $((i*2))s (pid $SRV_PID)"; break; }
  grep -qE "out of memory|failed to allocate|error loading model" "$LOG" 2>/dev/null && {
    echo "✗ failed to load — lower --ctx, use a smaller --kv, or lower --ngl. Last lines:" >&2
    tail -6 "$LOG" >&2; exit 1; }
  kill -0 "$SRV_PID" 2>/dev/null || { echo "✗ server exited during load:" >&2; tail -8 "$LOG" >&2; exit 1; }
done
grep -qE "model loaded|server is listening" "$LOG" || { echo "✗ timed out waiting for load" >&2; tail -8 "$LOG" >&2; exit 1; }
echo "  VRAM after load: $(gpu_mem) MiB"

echo "=== [4/7] verify the loaded context (from the server, not the flags) ==="
curl -s "http://127.0.0.1:$PORT/props" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    g = d.get('default_generation_settings', {})
    print('  n_ctx:', g.get('n_ctx'))
except Exception: print('  (/props unreadable — record the configured ctx instead)')" 2>/dev/null || true

echo "=== [5/7] build the timed request ==="
if [ -n "$PROMPT_JSON" ]; then REQ="$PROMPT_JSON"; echo "  using $PROMPT_JSON"
else
  REQ="$TMP/req.json"
  python3 - "$REQ" "$MAX_TOKENS" <<'PYEOF'
import json, sys
body = "def f(n):\n    return n if n < 2 else f(n-1) + f(n-2)\n"
text = (body * 330)
json.dump({"model": "local",
           "messages": [{"role": "user",
                         "content": "Explain this code in full detail, including time and space complexity.\n\n" + text}],
           "max_tokens": int(sys.argv[2]), "temperature": 0, "seed": 42, "stream": False},
          open(sys.argv[1], "w"))
print("  built a prompt of roughly", len(text)//4, "tokens")
PYEOF
fi

echo "=== [6/7] warm the GPU, then time a cold-context run ==="
python3 -c "
import json; json.dump({'model':'local','messages':[{'role':'user','content':'hi'}],'max_tokens':8,'temperature':0}, open('$TMP/warm.json','w'))"
curl -s "http://127.0.0.1:$PORT/v1/chat/completions" -H 'Content-Type: application/json' -d @"$TMP/warm.json" -o /dev/null
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=clocks.sm,power.draw --format=csv,noheader | sed 's/^/  after warm: /'
fi
( command -v nvidia-smi >/dev/null 2>&1 && for i in $(seq 1 120); do
    nvidia-smi --query-gpu=utilization.gpu,power.draw,memory.used --format=csv,noheader >> "$TMP/gpu.txt"
    sleep 1
  done ) & SAMPLER=$!
T0=$(date +%s.%N)
curl -s -m 1800 "http://127.0.0.1:$PORT/v1/chat/completions" -H 'Content-Type: application/json' -d @"$REQ" -o "$TMP/out.json"
T1=$(date +%s.%N)
kill "$SAMPLER" 2>/dev/null || true; wait "$SAMPLER" 2>/dev/null || true

echo "=== [7/7] results ==="
python3 - "$TMP/out.json" "$T1" "$T0" "$CTX" "$KV" "$TMP/gpu.txt" <<'PYEOF'
import json, os, sys
out, t1, t0, ctx, kv, gpufile = sys.argv[1:7]
try:
    d = json.load(open(out))
except Exception:
    print("  ✗ no parseable response — check the server log"); raise SystemExit(0)
if "error" in d:
    print("  ✗ server error:", str(d["error"])[:300]); raise SystemExit(0)
t = d.get("timings", {}) or {}
wall = float(t1) - float(t0)
pt = (d.get("usage") or {}).get("prompt_tokens")
print(f"  wall           : {wall:.1f}s")
print(f"  prompt_tokens  : {pt}")
print(f"  prefill        : {t.get('prompt_per_second', 0):.1f} t/s")
print(f"  decode         : {t.get('predicted_per_second', 0):.1f} t/s")
print(f"  cache_n        : {t.get('cache_n')}   (0 = true cold prefill)")
if os.path.exists(gpufile):
    rows = [l.strip().split(', ') for l in open(gpufile) if l.strip()]
    if rows:
        util = max(int(r[0].split()[0]) for r in rows)
        vram = max(int(r[2].split()[0]) for r in rows)
        pwr  = max(float(r[1].split()[0]) for r in rows)
        print(f"  peak GPU       : {util}% util, {vram} MiB, {pwr:.0f} W")
        if util < 50:
            print("  ⚠ utilisation stayed under 50% — the GPU never ramped, or the run was CPU-bound.")
print()
print("  RECORD THIS (your host's Hoard — see ../METHOD.md):")
print(f"    model=<name> quant=<quant> ctx={ctx} kv={kv} "
      f"prefill={t.get('prompt_per_second',0):.1f} decode={t.get('predicted_per_second',0):.1f} "
      f"prompt_tokens={pt} wall={wall:.1f}s")
print("  Always record the context the run was measured at.")
PYEOF

if [ "$KEEP" = "1" ]; then echo "=== --keep: server left running on :$PORT (pid $SRV_PID) ==="; exit 0; fi
echo "=== teardown ==="
kill "$SRV_PID" 2>/dev/null || true; wait "$SRV_PID" 2>/dev/null || true; SRV_PID=""
sleep 1
echo "  VRAM after: $(gpu_mem) MiB"
