#!/usr/bin/env bash
# gjallarhorn-tunnel.sh — raise/lower the `ymir` Cloudflare tunnel (Gjallarhorn).
# Exposes Hlidskjalf from this machine at the operator's own hostname
# (YMIR_TUNNEL_HOST, or read from the cloudflared config).
#
# Usage:
#   gjallarhorn-tunnel.sh [start|stop|status] [--config <path>] [--tunnel <name>]
#   gjallarhorn-tunnel.sh --version
set -u

# --- portability shim: bin/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  for _ymir_c in "$(git rev-parse --show-toplevel 2>/dev/null)/bin/ymir-platform.sh"                  "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/ymir-platform.sh"; do
    [ -n "$_ymir_c" ] && [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_c
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${YMIR_TUNNEL_CONFIG:-$HOME/.cloudflared/config-ymir.yml}"
TUNNEL="${YMIR_TUNNEL_NAME:-ymir}"
PID_FILE="$ROOT/state/gjallarhorn.pid"
LOG_FILE="$ROOT/state/gjallarhorn.log"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-status}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --config) CONFIG=${2-}; shift 2 ;; --tunnel) TUNNEL=${2-}; shift 2 ;; *) shift ;; esac; done

running() { [ -r "$PID_FILE" ] && kill -0 "$(tr -d '[:space:]' <"$PID_FILE")" 2>/dev/null; }

# The public hostname is a fact about THIS machine, not about Ymir: take it from
# the environment, or read it out of the tunnel's own config. Never a fixed
# domain — the previous default handed every other operator this one's host.
tunnel_host() {
  if [ -n "${YMIR_TUNNEL_HOST:-}" ]; then printf '%s' "$YMIR_TUNNEL_HOST"; return; fi
  if [ -r "$CONFIG" ]; then
    grep -oE '^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*[^[:space:]]+' "$CONFIG" 2>/dev/null \
      | head -1 | awk '{print $NF}'
  fi
}
HOST="$(tunnel_host)"
[ -n "$HOST" ] || HOST='<unset: set YMIR_TUNNEL_HOST>'

case "$ACTION" in
  status)
    state=down
    if running; then state=up; fi
    printf 'gjallarhorn[1]{state,host,pid,config}:\n  "%s","%s",%s,"%s"\n' "$state" "$HOST" "$(running && tr -d '[:space:]' <"$PID_FILE" || echo 0)" "${CONFIG#"$HOME"/}"
    command -v cloudflared >/dev/null 2>&1 && cloudflared tunnel info "$TUNNEL" 2>/dev/null | rg -m1 "CONNECTOR|does not have" || true
    exit 0 ;;
  stop)
    if running; then pid=$(tr -d '[:space:]' <"$PID_FILE"); kill "$pid" 2>/dev/null || true; rm -f "$PID_FILE"; printf 'gjallarhorn: stopped pid=%s\n' "$pid"; else ymir_kill_matching "config-ymir.yml" 2>/dev/null && printf 'gjallarhorn: stopped (matched process)\n' || printf 'gjallarhorn: already stopped\n'; fi
    exit 0 ;;
  start) ;;
  *) printf 'error: unknown action %s\nhelp: gjallarhorn-tunnel.sh [start|stop|status]\n' "$ACTION" >&2; exit 2 ;;
esac

command -v cloudflared >/dev/null 2>&1 || { printf 'error: cloudflared not found\nhelp: install cloudflared\n' >&2; exit 1; }
[ -r "$CONFIG" ] || { printf 'error: tunnel config not found: %s\nhelp: cp midgard/infrastructure/ingress/cloudflared-ymir.yml ~/.cloudflared/config-ymir.yml\n' "$CONFIG" >&2; exit 1; }
mkdir -p "$ROOT/state"
if running; then printf 'gjallarhorn[1]{state,host}:\n  "already up","%s"\n' "$HOST"; exit 0; fi

nohup cloudflared tunnel --config "$CONFIG" run "$TUNNEL" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 4
if running; then
  printf 'gjallarhorn[1]{state,host,pid}:\n  "up","%s",%s\n' "$HOST" "$(cat "$PID_FILE")"
  # Bust the edge cache for the hostname (no-op without CLOUDFLARE_API_TOKEN).
  [ -x "$SCRIPT_DIR/gjallarhorn-purge.sh" ] && "$SCRIPT_DIR/gjallarhorn-purge.sh" "$HOST" >/dev/null 2>&1 || true
else printf 'error: tunnel failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2; tail -3 "$LOG_FILE" >&2; exit 1; fi
