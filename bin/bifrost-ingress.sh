#!/usr/bin/env bash
# bifrost-ingress.sh — raise/lower the ingress stack (Bifrost · Heimdall · Gjallarhorn).
#
# Config lives in `midgard/infrastructure/ingress/`. This dispatches to the owning
# engines when present (Caddy for Bifrost, oauth2-proxy for Heimdall, cloudflared
# for Gjallarhorn) and reports honestly when a binary is missing. Galdr TOON.
#
# Usage: bin/bifrost-ingress.sh [start|stop|status|validate]
#        bin/bifrost-ingress.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ING="$ROOT/midgard/infrastructure/ingress"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-status}"

has() { command -v "$1" >/dev/null 2>&1; }
port_up() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

case "$ACTION" in
  validate)
    rc=0
    if has caddy; then
      caddy validate --config "$ING/Caddyfile" >/dev/null 2>&1 && printf '  "Bifrost","valid"\n' || { printf '  "Bifrost","INVALID"\n'; rc=1; }
    else printf '  "Bifrost","caddy not installed"\n'; fi
    printf 'config[3]{asset,path,status}:\n'
    printf '  "Bifrost","%s","%s"\n' "${ING#"$ROOT"/}/Caddyfile" "$([ -f "$ING/Caddyfile" ] && echo present || echo missing)"
    printf '  "Heimdall","%s","%s"\n' "${ING#"$ROOT"/}/oauth2-proxy.cfg" "$([ -f "$ING/oauth2-proxy.cfg" ] && echo present || echo missing)"
    printf '  "Gjallarhorn","%s","%s"\n' "${ING#"$ROOT"/}/cloudflared.yml" "$([ -f "$ING/cloudflared.yml" ] && echo present || echo missing)"
    exit $rc
    ;;

  status)
    printf 'ingress[3]{edge,engine,status}:'
    printf '\n'
    if port_up 80 || port_up 443; then printf '  "Bifrost","caddy","listening"\n'; else printf '  "Bifrost","caddy","%s"\n' "$(has caddy && echo present || echo not-installed)"; fi
    if port_up 4180; then printf '  "Heimdall","oauth2-proxy","listening"\n'; else printf '  "Heimdall","oauth2-proxy","%s"\n' "$(has oauth2-proxy && echo present || echo not-installed)"; fi
    if has cloudflared; then printf '  "Gjallarhorn","cloudflared","present"\n'; else printf '  "Gjallarhorn","cloudflared","not-installed"\n'; fi
    ;;

  start)
    ok=0
    if [ -f "$ING/Caddyfile" ] && has caddy; then
      caddy start --config "$ING/Caddyfile" >/dev/null 2>&1 && { printf 'Bifrost: raised\n'; ok=1; } || printf 'Bifrost: failed to raise\n' >&2
    else printf 'Bifrost: skipped (%s)\n' "$(has caddy && echo config-missing || echo 'caddy not installed')" >&2; fi
    if [ -f "$ING/oauth2-proxy.cfg" ] && has oauth2-proxy; then
      nohup oauth2-proxy --config "$ING/oauth2-proxy.cfg" >/dev/null 2>&1 & printf 'Heimdall: raised\n'; ok=1
    else printf 'Heimdall: skipped (%s)\n' "$(has oauth2-proxy && echo config-missing || echo 'oauth2-proxy not installed')" >&2; fi
    if [ -f "$ING/cloudflared.yml" ] && has cloudflared; then
      nohup cloudflared tunnel --config "$ING/cloudflared.yml" run >/dev/null 2>&1 & printf 'Gjallarhorn: raised\n'; ok=1
    else printf 'Gjallarhorn: skipped (%s)\n' "$(has cloudflared && echo config-missing || echo 'cloudflared not installed')" >&2; fi
    [ "$ok" = 1 ] || { printf 'error: no ingress engine could start\nhelp: install caddy / oauth2-proxy / cloudflared, then re-run\n' >&2; exit 1; }
    ;;

  stop)
    has caddy && caddy stop >/dev/null 2>&1 && echo "Bifrost: lowered"
    pkill -f 'oauth2-proxy --config' >/dev/null 2>&1 && echo "Heimdall: lowered"
    pkill -f 'cloudflared tunnel' >/dev/null 2>&1 && echo "Gjallarhorn: lowered"
    printf 'ingress: down\n'
    ;;

  *) printf 'error: unknown action %s\nhelp: bin/bifrost-ingress.sh [start|stop|status|validate]\n' "$ACTION" >&2; exit 2 ;;
esac
