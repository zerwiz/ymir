#!/usr/bin/env bash
# gjallarhorn-tunnel.sh — raise/lower a Cloudflare tunnel (Gjallarhorn).
# Exposes ONE frontier surface from this machine: the video forge, the hound's
# notifications, a hosted board — the operator's own hostname, read from the
# cloudflared config or YMIR_TUNNEL_HOST.
#
# THE HALLS ARE LOCAL, AND NO TUNNEL POINTS AT ONE (plan 275 item 30, 2026-11-14). His
# word: "this feature of opening online must go away with the logins we have. we are not
# hosting the 3 apps online.. they are local. craig found that were opening ports out." The
# halls already listen on loopback only; what survived the hosted era was a tunnel config
# pointing at the gate (:3889). So `start` REFUSES any ingress that names a hall port:
#
#   3888 Hlidskjalf SPA · 3889 the gate · 4322 Óðrerir · 8437 Smíðja ·
#   8787 Bilskirnir · 4602 Mímir (the well) · 4603 Bifrost
#
# A hosted, shared surface is Gimlé's (plan 284) and reaches the world through its own
# door, never through a hall's. Measured 2026-11-14: this machine's tunnels serve the video
# forge (:8761), the hound's notifications (:2586) and :3891 — none of them a hall.
#
# Usage:
#   gjallarhorn-tunnel.sh [start|stop|status|check] [--config <path>] [--tunnel <name>]
#   gjallarhorn-tunnel.sh --version
set -u

# --- portability shim: bin/fleet/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  for _ymir_c in "$(git rev-parse --show-toplevel 2>/dev/null)/bin/fleet/ymir-platform.sh"                  "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/fleet/ymir-platform.sh"; do
    [ -n "$_ymir_c" ] && [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_c
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
CONFIG="${YMIR_TUNNEL_CONFIG:-$HOME/.cloudflared/config-ymir.yml}"
TUNNEL="${YMIR_TUNNEL_NAME:-ymir}"
PID_FILE="$YMIR_STATE_DIR/gjallarhorn.pid"
LOG_FILE="$YMIR_STATE_DIR/gjallarhorn.log"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
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

# ── the halls, and the guard that keeps a tunnel off them ─────────────────────
HALL_PORTS="3888 3889 4322 8437 8787 4602 4603"

# Every `service:` target in the config, as <line>\t<hostname>\t<service>.
# Only a scheme URL can name a port; `http_status:404` and `unix:` cannot and are skipped.
config_ingress() {
  [ -r "$CONFIG" ] || return 0
  awk '
    /^[[:space:]]*-[[:space:]]*hostname:/ { h=$0; sub(/^[^:]*:[[:space:]]*/,"",h); sub(/[[:space:]]*#.*/,"",h); host=h; next }
    /^[[:space:]]*service:/ {
      s=$0; sub(/^[[:space:]]*service:[[:space:]]*/,"",s); sub(/[[:space:]]*#.*/,"",s)
      printf "%d\t%s\t%s\n", NR, (host==""?"(no hostname)":host), s
    }
  ' "$CONFIG"
}

# The port a service URL dials, or empty when it names none (`http_status:404`, `unix:`).
service_port() {
  local svc="$1" rest
  case "$svc" in
    *://*) ;;
    *) return 0 ;;
  esac
  rest="${svc#*://}"; rest="${rest%%/*}"
  case "$rest" in
    *:*[0-9]*) printf '%s' "${rest##*:}" ;;
  esac
}

# Rows whose ingress dials a hall port. Exit 0 when one is found (like grep), 1 when clean.
hall_ingress() {
  local nr host svc port found=1
  while IFS=$'\t' read -r nr host svc; do
    [ -n "$svc" ] || continue
    port="$(service_port "$svc")"
    [ -n "$port" ] || continue
    case " $HALL_PORTS " in
      *" $port "*) printf '%s\t%s\t%s\n' "$nr" "$host" "$svc"; found=0 ;;
    esac
  done < <(config_ingress)
  return $found
}

refuse_hall_ingress() {
  local rows="$1"
  printf 'error: this tunnel config points at a hall — the halls are local, never tunneled\n' >&2
  printf '%s\n' "$rows" | while IFS=$'\t' read -r nr host svc; do
    printf '  %s:%s -> %s (a hall port)\n' "${CONFIG#"$HOME"/}" "$nr" "$host $svc" >&2
  done
  printf 'hall:  %s\n' "$HALL_PORTS" >&2
  printf 'law:   plan 275 item 30 — no ingress at a hall port; a hosted surface reaches the world through its own door (plan 284)\n' >&2
  printf 'help:  point the tunnel at the surface meant to be public (a forge, a board), or leave the hall local\n' >&2
}

case "$ACTION" in
  check)
    [ -r "$CONFIG" ] || { printf 'error: tunnel config not found: %s\n' "$CONFIG" >&2; exit 1; }
    rows="$(hall_ingress || true)"
    if [ -n "$rows" ]; then
      refuse_hall_ingress "$rows"
      printf 'gjallarhorn_check[1]{config,verdict}:\n  "%s","REFUSED"\n' "${CONFIG#"$HOME"/}"
      exit 1
    fi
    n="$(config_ingress | awk -F'\t' '$3 !~ /^http_status:/ && $3 != ""' | wc -l)"
    printf 'gjallarhorn_check[2]{config,verdict,ingress}:\n  "%s","ok — no hall port",%s\n' "${CONFIG#"$HOME"/}" "$n"
    exit 0 ;;
  status)
    state=down
    if running; then state=up; fi
    printf 'gjallarhorn[1]{state,host,pid,config}:\n  "%s","%s",%s,"%s"\n' "$state" "$HOST" "$(running && tr -d '[:space:]' <"$PID_FILE" || echo 0)" "${CONFIG#"$HOME"/}"
    command -v cloudflared >/dev/null 2>&1 && cloudflared tunnel info "$TUNNEL" 2>/dev/null | rg -m1 "CONNECTOR|does not have" || true
    exit 0 ;;
  stop)
    if running; then pid=$(tr -d '[:space:]' <"$PID_FILE"); kill "$pid" 2>/dev/null || true; rm -f "$PID_FILE"; printf 'gjallarhorn: stopped pid=%s\n' "$pid"; else ymir_kill_matching "config-ymir.yml" 2>/dev/null && printf 'gjallarhorn: stopped (matched process)\n' || printf 'gjallarhorn: already stopped\n'; fi
    exit 0 ;;
  start)
    # The guard runs BEFORE cloudflared is even looked for: a config that would publish a
    # hall is refused whatever else is missing (plan 275 item 30).
    [ -r "$CONFIG" ] || { printf 'error: tunnel config not found: %s\nhelp: cp midgard/infrastructure/ingress/cloudflared-ymir.yml ~/.cloudflared/config-ymir.yml\n' "$CONFIG" >&2; exit 1; }
    rows="$(hall_ingress || true)"
    if [ -n "$rows" ]; then refuse_hall_ingress "$rows"; exit 1; fi
    ;;
  *) printf 'error: unknown action %s\nhelp: gjallarhorn-tunnel.sh [start|stop|status|check]\n' "$ACTION" >&2; exit 2 ;;
esac

command -v cloudflared >/dev/null 2>&1 || { printf 'error: cloudflared not found\nhelp: install cloudflared\n' >&2; exit 1; }
[ -r "$CONFIG" ] || { printf 'error: tunnel config not found: %s\nhelp: cp midgard/infrastructure/ingress/cloudflared-ymir.yml ~/.cloudflared/config-ymir.yml\n' "$CONFIG" >&2; exit 1; }
mkdir -p "$YMIR_STATE_DIR"
if running; then printf 'gjallarhorn[1]{state,host}:\n  "already up","%s"\n' "$HOST"; exit 0; fi

nohup cloudflared tunnel --config "$CONFIG" run "$TUNNEL" >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
sleep 4
if running; then
  printf 'gjallarhorn[1]{state,host,pid}:\n  "up","%s",%s\n' "$HOST" "$(cat "$PID_FILE")"
  # Bust the edge cache for the hostname (no-op without CLOUDFLARE_API_TOKEN).
  [ -x "$SCRIPT_DIR/gjallarhorn-purge.sh" ] && "$SCRIPT_DIR/gjallarhorn-purge.sh" "$HOST" >/dev/null 2>&1 || true
else printf 'error: tunnel failed to start; see %s\n' "${LOG_FILE#"$ROOT"/}" >&2; tail -3 "$LOG_FILE" >&2; exit 1; fi
