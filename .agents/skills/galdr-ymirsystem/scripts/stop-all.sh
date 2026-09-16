#!/usr/bin/env bash
# stop-all.sh — clear anything a bench left behind, and report what holds the GPU.
#
# It stops ONLY the throwaway servers this skill started (they live on scratch
# ports in the 9200-9999 range) and then tells you the truth about the device,
# without pretending to manage anyone else's service.
#
# Usage: stop-all.sh
set -uo pipefail

echo "=== throwaway bench servers ==="
found=0
if command -v pgrep >/dev/null 2>&1; then
  for p in $(pgrep -f "llama-server .*--port 9[2-9][0-9][0-9]" 2>/dev/null || true); do
    kill "$p" 2>/dev/null && { echo "  asked pid $p to stop"; found=1; }
  done
fi
[ "$found" = "0" ] && echo "  none running"

sleep 1
echo
echo "=== GPU ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>/dev/null | sed 's/^/  /'
  echo
  nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader | sed 's/^/  used/total/util: /'
  echo "  (a clean test baseline is the device's idle floor — a few MiB, or more on a desktop)"
elif command -v rocm-smi >/dev/null 2>&1; then
  rocm-smi --showmemuse 2>/dev/null | sed 's/^/  /'
else
  echo "  no nvidia-smi or rocm-smi here."
  echo "  Find the holder yourself (lsof / ps) — and note that a model resident in"
  echo "  another service will contaminate your next measurement."
fi
