#!/usr/bin/env bash
# gpu-sample.sh — sample GPU utilization + VRAM every N seconds while a test runs.
#
# Purpose (skill rule #6): catches CPU-spill / partial-GPU behavior that a single
# post-run number hides. During prefill you want to see 95-100% GPU util; if you
# see it drop to ~30% while decode continues, experts/KV are offloading to CPU.
#
# Usage:
#   gpu-sample.sh [interval] [count]            # just samples
#   gpu-sample.sh 2 10 -- curl -s <url> ...     # samples WHILE a command runs
#
# Examples:
#   gpu-sample.sh 2 8
#   gpu-sample.sh 1 15 -- curl -s http://localhost:8125/v1/chat/completions -d @req.json -o out.json
set -uo pipefail

INTERVAL=${1:-2}; shift 2>/dev/null || true
COUNT=${1:-10}; shift 2>/dev/null || true

# remaining args (after optional interval/count) are a command to run while sampling
if [ "${1:-}" = "--" ]; then
  shift
  RUNCMD=("$@")
  echo "sampling GPU every ${INTERVAL}s × ${COUNT} while running: $*"
  ( for i in $(seq 1 "$COUNT"); do
      nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader | sed "s/^/t+${INTERVAL}s  /"
      sleep "$INTERVAL"
    done ) &
  SAMPLER=$!
  "${RUNCMD[@]}"
  RC=$?
  wait "$SAMPLER" || true
  exit $RC
fi

# plain sampling (no command)
echo "sampling GPU every ${INTERVAL}s × ${COUNT}"
for i in $(seq 1 "$COUNT"); do
  nvidia-smi --query-gpu=utilization.gpu,memory.used,clocks.sm --format=csv,noheader | sed "s/^/t+${INTERVAL}s  /"
  sleep "$INTERVAL"
done
echo "done"
echo "NOTE: util≈95-100% during prefill = good; util ~30% while decoding = CPU spill."