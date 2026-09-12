#!/usr/bin/env bash
# tailscale-sync.sh — sync the Allfather's pi data across his OWN machines over
# Tailscale. Peer-allowlisted, dry-runnable, never a central server.
#
#   bin/tailscale-sync.sh status            # tailnet + configured peers
#   bin/tailscale-sync.sh init              # seed the config from its template
#   bin/tailscale-sync.sh push [peer]       # local → peer (all peers if omitted)
#   bin/tailscale-sync.sh pull <peer>       # peer → local
#   bin/tailscale-sync.sh --dry-run push    # show what would move
#   bin/tailscale-sync.sh --version
#
# Config: config/tailscale-sync.yaml (private, from the tracked .example).
# Transport: rsync over ssh, addressed by Tailscale MagicDNS. No relay.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG="${YMIR_TAILSCALE_SYNC:-$ROOT/config/tailscale-sync.yaml}"
DRY=0; ACTION=""; PEER=""

for a in "$@"; do
  case "$a" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run|-n) DRY=1 ;;
    status|push|pull|init) ACTION="$a" ;;
    -*) printf 'error: unknown flag %s\n' "$a" >&2; exit 2 ;;
    *) PEER="$a" ;;
  esac
done
ACTION="${ACTION:-status}"

have() { command -v "$1" >/dev/null 2>&1; }

if [ "$ACTION" = status ]; then
  ts_state="absent"; ts_self=""
  if have tailscale; then
    ts_state="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("BackendState") or "unknown")
except Exception: print("unavailable")' 2>/dev/null)"
    ts_self="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print((d.get("Self") or {}).get("DNSName") or "")
except Exception: pass' 2>/dev/null)"
  else
    ts_state="not installed"
  fi
  online=""
  if have tailscale; then
    online="$(tailscale status 2>/dev/null | awk 'NR>1 && $0 !~ /offline/ {print $2}' | paste -sd, -)"
  fi
  peers="none"
  [ -r "$CFG" ] && peers="$(python3 -c 'import yaml,sys; d=yaml.safe_load(open(sys.argv[1])) or {}; print(",".join(p if isinstance(p,str) else p.get("host","") for p in (d.get("peers") or [])))' "$CFG" 2>/dev/null)"
  printf 'tailscale-sync[1]{backend,self,online,peers,config}:\n'
  printf '  "%s","%s","%s","%s","%s"\n' "$ts_state" "${ts_self:-?}" "${online:-none}" "${peers:-none}" "$( [ -r "$CFG" ] && echo present || echo "absent (bin/tailscale-sync.sh init)" )"
  exit 0
fi

if [ "$ACTION" = init ]; then
  TPL="$ROOT/config/tailscale-sync.example.yaml"
  if [ -r "$CFG" ]; then printf 'tailscale-sync[1]{action,state}:\n  "init","kept — %s exists"\n' "$CFG"; exit 0; fi
  [ -r "$TPL" ] || { printf 'error: template missing: %s\n' "$TPL" >&2; exit 1; }
  cp "$TPL" "$CFG" && printf 'tailscale-sync[1]{action,path}:\n  "init","%s"\n' "$CFG"
  exit 0
fi

[ -r "$CFG" ] || { printf 'error: no config %s\nhelp: bin/tailscale-sync.sh init\n' "$CFG" >&2; exit 1; }
have tailscale || { printf 'error: tailscale is not installed\nhelp: https://tailscale.com/download\n' >&2; exit 1; }
have rsync || { printf 'error: rsync is not installed\n' >&2; exit 1; }
[ "$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys;print((json.load(sys.stdin) or {}).get("BackendState",""))' 2>/dev/null)" = "Running" ] \
  || { printf 'error: tailscale is not up\nhelp: sudo tailscale up\n' >&2; exit 1; }

# The config drives every transfer: peers (allowlist) + paths (what may move).
mapfile -t META < <(python3 - "$CFG" "$PEER" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1])) or {}
only = sys.argv[2]
peers = cfg.get("peers") or []
def host(p): return p if isinstance(p, str) else (p.get("host") or "")
print("include_auth=%s" % ("1" if cfg.get("include_auth") else "0"))
for p in peers:
    h = host(p)
    if h and (not only or h == only):
        print("peer=%s" % h)
for path in (cfg.get("paths") or []):
    print("path=%s" % path)
PY
)
include_auth=0; PEERS=(); PATHS=()
for line in "${META[@]:-}"; do
  case "$line" in
    include_auth=*) include_auth="${line#*=}" ;;
    peer=*) PEERS+=("${line#*=}") ;;
    path=*) PATHS+=("${line#*=}") ;;
  esac
done
[ "${#PEERS[@]}" -gt 0 ] || { printf 'error: no matching peer\nhelp: bin/tailscale-sync.sh status\n' >&2; exit 1; }
[ "${#PATHS[@]}" -gt 0 ] || { printf 'error: config lists no paths\n' >&2; exit 1; }
[ "$include_auth" = 1 ] || PATHS=("${PATHS[@]/~\/.pi\/agent\/auth.json/}")

rsync_flags=(-a --info=NAME --exclude 'sessions/' --exclude '*.log')
[ "$DRY" = 1 ] && rsync_flags+=(--dry-run)
# Tailscale moves the bytes; ssh is the transport. accept-new avoids the
# first-connect host-key prompt. Prefer `tailscale ssh` (no keys) via YMIR_SSH.
ssh_cmd="${YMIR_SSH:-ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"
rc=0
for peer in "${PEERS[@]}"; do
  for path in "${PATHS[@]}"; do
    [ -n "$path" ] || continue
    case "$path" in auth.json|*auth.json) [ "$include_auth" = 1 ] || continue ;; esac
    if [ "$ACTION" = push ]; then src="$path"; dst="$peer:$path"; else src="$peer:$path"; dst="$path"; fi
    printf 'tailscale-sync[1]{dir,peer,path}:\n  "%s","%s","%s"\n' "$ACTION" "$peer" "$path"
    rsync "${rsync_flags[@]}" -e "$ssh_cmd" --mkpath "$src" "$dst" || rc=1
  done
done
exit "$rc"
