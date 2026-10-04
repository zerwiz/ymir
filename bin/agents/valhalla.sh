#!/usr/bin/env bash
# valhalla.sh — the process hall (Valhalla). List, inspect, revive, and read logs
# of the fleet's daemons across PM2, Docker, and systemd. Deterministic: every
# action dispatches to the owning manager, never an ad-hoc shell. Galdr-style TOON.
#
# Usage:
#   valhalla.sh list
#   valhalla.sh status <id>
#   valhalla.sh restart <id> | stop <id> | start <id>
#   valhalla.sh logs <id> [n]
#   valhalla.sh --version
#
# ids: pm2:<name>, docker:<name>, systemd:<unit>
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/ymir-platform.sh
. "$SCRIPT_DIR/ymir-platform.sh"
# Docker or rootless Podman (Fedora). Empty when neither binary exists.
ENGINE="$(ymir_container_engine_name 2>/dev/null || true)"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1-}"; shift || true
case "$CMD" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

id_status() { # id -> "status"
  local id=$1 mgr=${1%%:*} name=${1#*:}
  case "$mgr" in
    pm2) pm2 jlist 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except: d=[]
name=sys.argv[1]
for p in d:
    if p.get("name")==name: print(p.get("pm2_env",{}).get("status","?")); break' "$name" ;;
    docker) "${ENGINE:-docker}" inspect -f '{{.State.Status}}' "$name" 2>/dev/null | head -1 ;;
    systemd) systemctl is-active "$name" 2>/dev/null ;;
  esac
}

case "$CMD" in
  list)
    rows=()
    # PM2
    if command -v pm2 >/dev/null 2>&1; then
      while IFS=$'\t' read -r name status cpu mem restarts uptime; do
        [ -n "$name" ] && rows+=("pm2:$name|pm2|$name|$status|$cpu|$mem|$restarts|$uptime")
      done < <(pm2 jlist 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except: d=[]
for p in d:
    e=p.get('pm2_env',{}); m=p.get('monit',{})
    print('\t'.join([p.get('name',''),e.get('status',''),str(m.get('cpu',0)),str(round(m.get('memory',0)/1e6)),str(e.get('restart_time',0)),str(int((__import__('time').time()*1000-e.get('pm_uptime',__import__('time').time()*1000))/1000))]))")
    fi
    # Containers — Docker or rootless Podman (Fedora); quadlets appear here too.
    if [ -n "$ENGINE" ] && "$ENGINE" info >/dev/null 2>&1; then
      while IFS=$'\t' read -r name status; do
        [ -n "$name" ] && rows+=("docker:$name|$ENGINE|$name|$status|0|0|0|0")
      done < <("$ENGINE" ps --format '{{.Names}}\t{{.State}}' 2>/dev/null)
    fi
    # systemd (user + system), running services only, capped
    if command -v systemctl >/dev/null 2>&1; then
      while IFS=" " read -r unit load state sub desc; do
        case "$unit" in *.service) unit=${unit%.service}; rows+=("systemd:$unit|systemd|$unit|$state|0|0|0|0") ;; esac
      done < <(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | head -20)
      # Quadlet-generated user units (Podman): /etc or ~/.config/containers/systemd
      while IFS=" " read -r unit load state sub desc; do
        case "$unit" in *.service) unit=${unit%.service}; rows+=("systemd:$unit|systemd|$unit|$state|0|0|0|0") ;; esac
      done < <(systemctl --user list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | head -20)
    fi
    printf 'processes[%s]{id,manager,name,status,cpu,mem,restarts,uptime}:\n' "${#rows[@]}"
    for r in "${rows[@]}"; do IFS='|' read -r id mgr name st cpu mem rs up <<<"$r"; printf '  "%s","%s","%s","%s",%s,%s,%s,%s\n' "$id" "$mgr" "$name" "$st" "$cpu" "$mem" "$rs" "$up"; done
    ;;

  status)
    id=${1-}; [ -n "$id" ] || { printf 'error: status needs an id (pm2:<name>|docker:<name>|systemd:<unit>)\n' >&2; exit 2; }
    st=$(id_status "$id"); [ -n "$st" ] || { printf 'error: not found: %s\n' "$id" >&2; exit 1; }
    printf 'process[1]{id,status}:\n  "%s","%s"\n' "$id" "$st"
    ;;

  restart|stop|start)
    id=${1-}; [ -n "$id" ] || { printf 'error: %s needs an id\n' "$CMD" >&2; exit 2; }
    mgr=${id%%:*}; name=${id#*:}
    case "$mgr" in
      pm2) pm2 "$CMD" "$name" >/dev/null 2>&1 && printf 'process[1]{id,action,ok}:\n  "%s","%s","yes"\n' "$id" "$CMD" || { printf 'error: pm2 %s failed\n' "$CMD" >&2; exit 1; } ;;
      docker)
        case "$CMD" in
          stop) "${ENGINE:-docker}" stop "$name" >/dev/null 2>&1 ;;
          start) "${ENGINE:-docker}" start "$name" >/dev/null 2>&1 ;;
          restart) "${ENGINE:-docker}" restart "$name" >/dev/null 2>&1 ;;
        esac && printf 'process[1]{id,action,ok}:\n  "%s","%s","yes"\n' "$id" "$CMD" || { printf 'error: %s %s failed\n' "${ENGINE:-docker}" "$CMD" >&2; exit 1; } ;;
      systemd) systemctl "$CMD" "$name" >/dev/null 2>&1 && printf 'process[1]{id,action,ok}:\n  "%s","%s","yes"\n' "$id" "$CMD" || { printf 'error: systemctl %s failed (needs privilege?)\n' "$CMD" >&2; exit 1; } ;;
      *) printf 'error: unknown manager %s\nhelp: id is pm2:<name>|docker:<name>|systemd:<unit>\n' "$mgr" >&2; exit 2 ;;
    esac
    ;;

  logs)
    id=${1-}; n=${2:-30}; [ -n "$id" ] || { printf 'error: logs needs an id\n' >&2; exit 2; }
    mgr=${id%%:*}; name=${id#*:}
    printf 'logs[1]{id,lines}:\n  "%s",%s\n' "$id" "$n"
    case "$mgr" in
      pm2) pm2 logs "$name" --lines "$n" --nostream 2>/dev/null | tail -n "$n" ;;
      docker) "${ENGINE:-docker}" logs --tail "$n" "$name" 2>&1 | tail -n "$n" ;;
      systemd) journalctl -u "$name" -n "$n" --no-pager 2>/dev/null ;;
      *) printf 'error: unknown manager %s\n' "$mgr" >&2; exit 2 ;;
    esac
    ;;

  *) printf 'error: unknown command %s\nhelp: bin/valhalla.sh [list|status|restart|stop|start|logs|--version]\n' "$CMD" >&2; exit 2 ;;
esac
