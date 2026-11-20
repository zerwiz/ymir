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

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
CFG="${YMIR_TAILSCALE_SYNC:-$YMIR_SETTINGS_DIR/tailscale-sync.yaml}"
DRY=0; ACTION=""; PEER=""

for a in "$@"; do
  case "$a" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run|-n) DRY=1 ;;
    status|push|pull|check|init|receive) ACTION="$a" ;;
    -*) printf 'error: unknown flag %s\n' "$a" >&2; exit 2 ;;
    *) PEER="$a" ;;
  esac
done
ACTION="${ACTION:-status}"

have() { command -v "$1" >/dev/null 2>&1; }

# Expand a leading ~ locally (rsync/taildrop receive it literally otherwise).
expand_path() { case "$1" in "~/"*) printf '%s' "$HOME/${1#\~/}" ;; *) printf '%s' "$1" ;; esac; }

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
  TPL="$YMIR_SETTINGS_DIR/tailscale-sync.example.yaml"
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
if [ "$ACTION" = check ]; then
  # verify: parity-only walk. --checksum compares content, not just size/time;
  # --dry-run moves nothing; --itemize-changes names what WOULD differ. Exit 0
  # when the far end already mirrors the near end, 1 when anything drifts
  # (added/changed/missing/deleted) — the hoard's collision and loss alarm.
  check_flags=(-a -c --dry-run --itemize-changes --exclude 'sessions/' --exclude '*.log')
  [ "$DRY" = 1 ] && check_flags+=(--dry-run)
  rc=0
  ssh_cmd="${YMIR_SSH:-ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"
  for peer in "${PEERS[@]}"; do
    for path in "${PATHS[@]}"; do
      [ -n "$path" ] || continue
      case "$path" in auth.json|*auth.json) [ "$include_auth" = 1 ] || continue ;; esac
      src="$(expand_path "$path")"; dst="$peer:$path"
      printf 'tailscale-sync[1]{action,peer,path}:
  "check","%s","%s"\n' "$peer" "$path"
      out=$(rsync "${check_flags[@]}" -e "$ssh_cmd" --mkpath "$src" "$dst" 2>&1) || rc=1
      changes=$(printf '%s\n' "$out" | grep -cE '^[<>ch.*]' || true)
      if [ "${changes:-0}" -gt 0 ]; then
        printf 'tailscale-sync[1]{state,path,drift}:
  "DRIFT","%s","%s lines differ"\n' "$path" "$changes"
      else
        printf 'tailscale-sync[1]{state,path,parity}:
  "IN SYNC","%s"\n' "$path"
      fi
    done
  done
  [ "$rc" = 0 ] && printf 'tailscale-sync[1]{verdict}:
  "hoard mirrors the far end"\n' || printf 'tailscale-sync[1]{verdict}:
  "DRIFT — run push to reconcile"\n'
  exit "$rc"
fi

[ "$DRY" = 1 ] && rsync_flags+=(--dry-run)

# Taildrop road: when the tailnet's SSH ACL forbids SSH (but Taildrop works),
# bundle the configured paths into ONE tarball and send that — Taildrop carries
# files, not folders. The peer runs `receive` to fetch and unpack.
if [ "${YMIR_SYNC_VIA:-rsync}" = taildrop ]; then
  [ "$ACTION" = push ] || { printf 'error: taildrop transport supports push (and receive on the peer)\n' >&2; exit 2; }
  rel=()
  for path in "${PATHS[@]}"; do
    [ -n "$path" ] || continue
    case "$path" in auth.json|*auth.json) [ "$include_auth" = 1 ] || continue ;; esac
    case "$path" in "~/"*) rel+=("${path#\~/}") ;; *) rel+=("$path") ;; esac
  done
  tmp="$(mktemp -d)"; bundle="$tmp/ymir-sync-$(hostname -s)-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$bundle" -C "$HOME" "${rel[@]}" 2>/dev/null || { printf 'error: could not bundle paths\n' >&2; exit 1; }
  rc=0
  for peer in "${PEERS[@]}"; do
    printf 'tailscale-sync[1]{via,peer,bundle}:\n  "taildrop","%s","%s"\n' "$peer" "$(basename "$bundle")"
    tailscale file cp "$bundle" "$peer:" || rc=1
  done
  rm -rf "$tmp"
  exit "$rc"
fi

# receive — on the peer: fetch the Taildrop inbox and unpack any ymir-sync bundle
# into $HOME (paths were stored relative to HOME).
if [ "$ACTION" = receive ]; then
  dir="${PEER:-$HOME/Downloads}"; mkdir -p "$dir"
  tailscale file get "$dir" || exit 1
  rc=0
  for b in "$dir"/ymir-sync-*.tar.gz; do
    [ -e "$b" ] || continue
    printf 'tailscale-sync[1]{action,bundle}:\n  "receive","%s"\n' "$(basename "$b")"
    tar -xzf "$b" -C "$HOME" || rc=1
    rm -f "$b"
  done
  exit "$rc"
fi

ssh_cmd="${YMIR_SSH:-ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"
rc=0
for peer in "${PEERS[@]}"; do
  for path in "${PATHS[@]}"; do
    [ -n "$path" ] || continue
    case "$path" in auth.json|*auth.json) [ "$include_auth" = 1 ] || continue ;; esac
    if [ "$ACTION" = push ]; then src="$(expand_path "$path")"; dst="$peer:$path"; else src="$peer:$path"; dst="$(expand_path "$path")"; fi
    printf 'tailscale-sync[1]{dir,peer,path}:\n  "%s","%s","%s"\n' "$ACTION" "$peer" "$path"
    rsync "${rsync_flags[@]}" -e "$ssh_cmd" --mkpath "$src" "$dst" || rc=1
  done
done
exit "$rc"
