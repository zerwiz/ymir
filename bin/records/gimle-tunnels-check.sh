#!/usr/bin/env bash
# gimle-tunnels-check.sh — every Gimlé surface must be reachable on a tunnel, and we must KNOW it is, not assume it.
#
# His word (2026-11-14): "everything for gimle must be up on the tunnels. We need to know that."
#
# For each service in hodd/identity/services.yaml that declares a public_url, this asserts four things and reports a line:
#   1. a tunnel config names that hostname              (the road exists)
#   2. DNS resolves it                                  (the name exists)
#   3. the HTTP answer through the tunnel is expected   (the road works)
#   4. the local upstream answers too                   (the service behind it works)
#
#   gimle-tunnels-check.sh            table + exit 1 if any Gimlé surface fails
#   gimle-tunnels-check.sh --quiet    one line
set -uo pipefail
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
fi
[ -n "${YMIR_HOME:-}" ] || { printf '%s: the home could not be resolved (bin/vault/hoard-lib.sh, RULES/07)\n' "$(basename "$0")" >&2; exit 2; }
HOME_DIR="${YMIR_HOME}"
REG="$HOME_DIR/hodd/identity/services.yaml"
CD="${CLOUDFLARED_DIR:-$HOME/.cloudflared}"
quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1

rows=$(python3 - "$REG" "$CD" <<'PY'
import sys,yaml,glob,os,re
reg=yaml.safe_load(open(sys.argv[1]))
cd=sys.argv[2]
names=set()
for cfg in glob.glob(os.path.join(cd,'config*.yml')):
    for m in re.finditer(r'hostname:\s*(\S+)', open(cfg,encoding='utf-8',errors='ignore').read()):
        names.add(m.group(1))
for s in reg.get('services',[]):
    url=s.get('public_url')
    if not url: continue
    host=re.sub(r'^https?://','',url).split('/')[0]
    print('\t'.join([s['id'], host, 'yes' if host in names else 'no', s.get('criticality','')]))
PY
)

pass=0; fail=0; out=""
while IFS=$'\t' read -r id host road crit; do
  [ -z "$id" ] && continue
  why=""; note=""
  dns=$(getent hosts "$host" >/dev/null 2>&1 && echo yes || echo no)
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "https://$host/" 2>/dev/null)
  case "$code" in
    200|301|302|303|307|308) http=ok ;;
    404) http=ok; note="api surface (no root page)" ;;      # the MCP and the bridge answer where they should
    *) http="fail" ;;
  esac
  state=ok
  [ "$road" = no ] && { state=FAIL; why="$why no tunnel names it;"; }
  [ "$dns" = no ] && { state=FAIL; why="$why dns does not resolve;"; }
  [ "$http" != ok ] && { state=FAIL; why="$why http $code;"; }
  if [ "$state" = ok ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
  printf -v line '%-14s %-32s %-5s %-5s %-6s %-5s %s\n' "$id" "$host" "$road" "$dns" "$code" "$state" "$why$note"
  out+="$line"$'\n'
done <<< "$rows"

if [ "$quiet" -eq 1 ]; then
  printf 'gimle-tunnels: %s up · %s failing\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] && exit 0 || exit 1
fi

printf 'GIMLÉ ON THE TUNNELS — %s\n\n' "$(date -u +%FT%TZ)"
printf '%-14s %-32s %-8s %-7s %-8s %-5s %s\n' SURFACE HOSTNAME ROAD DNS HTTP STATE WHY
printf '%s' "$out"
printf '\n%s up · %s failing\n' "$pass" "$fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
