#!/usr/bin/env bash
# host-status.sh — CPU, memory and GPU of this machine, in one read.
#
# The rule in the home (RULES/the-hosted-services-registry.md) says a hosting question starts with a measurement. This
# is that measurement: load, memory, the top ten by memory, disk, and the GPU if the host has a usable one.
#
#   host-status.sh            one screen
#   host-status.sh --json     machine-readable
set -uo pipefail
json=0; [ "${1:-}" = "--json" ] && json=1

read_load() { cut -d' ' -f1-3 /proc/loadavg; }
read_nproc() { nproc 2>/dev/null || echo 1; }
read_mem() {
  awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} /SwapTotal/{st=$2} /SwapFree/{sf=$2}
       END{printf "%d %d %d %d", t/1024, a/1024, st/1024, sf/1024}' /proc/meminfo
}
read_gpu() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    out="$(nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null | grep -E '[0-9]+ (MiB|%)' | head -1)"
    if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  fi
  printf 'none usable (no nvidia-smi answer; the heart has no working GPU driver)\n'; return 0
  printf 'none usable\n'
}
read_disk() { df -h / 2>/dev/null | awk 'NR==2{printf "%s used of %s (%s)", $3, $2, $5}'; }

read -r l1 l2 l3 <<<"$(read_load)"
read -r mtot mavail stot sfree <<<"$(read_mem)"
if [ "$json" -eq 1 ]; then
  printf '{"load":"%s %s %s","cpus":%s,"memory_total_mb":%s,"memory_available_mb":%s,"swap_total_mb":%s,"swap_free_mb":%s,"disk":"%s","gpu":"%s"}\n' \
    "$l1" "$l2" "$l3" "$(read_nproc)" "$mtot" "$mavail" "$stot" "$sfree" "$(read_disk)" "$(read_gpu | tr -d '"')"
  exit 0
fi

printf 'host: %s   %s\n' "$(hostname -s)" "$(date -u +%FT%TZ)"
printf 'cpu : load %s / %s / %s across %s cores\n' "$l1" "$l2" "$l3" "$(read_nproc)"
printf 'mem : %s MB available of %s MB · swap %s of %s MB free\n' "$mavail" "$mtot" "$sfree" "$stot"
printf 'disk: %s\n' "$(read_disk)"
printf 'gpu : %s\n' "$(read_gpu)"
printf '\ntop by memory:\n'
ps -eo rss,comm --sort=-rss 2>/dev/null | head -11 | tail -10 | awk '{printf "  %6.0f MB  %s\n", $1/1024, $2}'
printf '\ncontainers by memory:\n'
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' 2>/dev/null | sort -t' ' -k2 -hr | head -8 | sed 's/^/  /'
