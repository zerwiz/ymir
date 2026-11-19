#!/usr/bin/env bash
# stop.sh — lower the viewer this release raised (by its port, loopback only).
set -euo pipefail
port="${SMIDJA_VIZ_API_PORT:-8437}"
pids="$(ss -ltnpH "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u)"
[ -n "$pids" ] || { printf 'smidja: nothing listens on :%s\n' "$port"; exit 0; }
kill $pids && printf 'smidja: viewer stopped (%s)\n' "$pids"
