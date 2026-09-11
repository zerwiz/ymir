#!/usr/bin/env bash
# stop-all.sh — stop every model on every backend, return GPU to baseline.
#
# Unloads in order: llama.cpp (model-host) → LM Studio (all) → Ollama (each).
# Confirms the 26 MiB VRAM baseline at the end (skill rule #1).
#
# Usage: stop-all.sh
set -uo pipefail

echo "=== llama.cpp (model-host) ==="
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
"$ROOT/scripts/model-host.sh" stop 2>/dev/null | grep -E "stopped|not running" || echo "  none running"

echo "=== Ollama ==="
for m in $(ollama ps --format json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(' '.join(x.get('Name','') for x in d.get('models', [])))
except Exception:
    print('')" 2>/dev/null); do
  echo "  ollama stop $m"
  ollama stop "$m" 2>/dev/null || true
done

echo "=== LM Studio (any spawned llama-server backends) ==="
pids=$(pgrep -f "lmstudio.*llama-server" 2>/dev/null || true)
if [ -n "$pids" ]; then
  # ask LM Studio to unload via its API if up, else signal the backend processes
  curl -s -X POST http://localhost:1234/api/v0/models/unload -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1 \
    && echo "  asked LM Studio to unload all" || {
      echo "  no LM Studio API — killing $(echo $pids | wc -w) backend process(es)"
      kill $pids 2>/dev/null || true
    }
else
  echo "  none running"
fi

sleep 2
echo ""
echo "=== final VRAM ==="
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
echo "  (expect ~26 MiB used = clean baseline)"