#!/usr/bin/env bash
# stop-all.sh — return the GPU to a clean baseline before/after a TEST.
#
# THE LAW: this skill TESTS. It does not run, stop, or manage the machine's
# serving stack. So this script does exactly two things:
#   1. kills the throwaway bench servers THIS SKILL started (their pids live in
#      /tmp/opencode/bench.*/ ), and
#   2. reports what is still holding VRAM, so you know whether your next
#      measurement is clean — without pretending to own the answer.
#
# If something else holds the GPU (the machine's service, LM Studio, Ollama),
# stopping it is that service's business, not a test script's. Its own docs say
# how. This script only refuses to lie about the baseline.
#
# Usage: stop-all.sh
set -uo pipefail

echo "=== bench servers this skill started ==="
found=0
for pidfile in /tmp/opencode/bench.*/server.pid; do
  [ -e "$pidfile" ] || continue
  pid=$(cat "$pidfile" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null && echo "  stopped bench server pid $pid"
    found=1
  fi
done
# bench-one.sh keeps its server pid in memory and cleans up on exit; stray
# single-model servers of ours are matched by their scratch-port range only.
for p in $(pgrep -f "llama-server .*--port 9[0-9][0-9][0-9]" 2>/dev/null || true); do
  kill "$p" 2>/dev/null && { echo "  stopped stray bench server pid $p"; found=1; }
done
[ "$found" = "0" ] && echo "  none running"

sleep 1
echo
echo "=== who holds the GPU now ==="
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>/dev/null | sed 's/^/  /'
echo
echo "=== baseline ==="
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader | sed 's/^/  used/total/util: /'
echo "  (a clean test baseline is the idle floor — a few MiB, depending on the desktop)"
