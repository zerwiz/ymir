#!/usr/bin/env bash
# snotra-bot.sh — send Snotra into a meeting, through the Vexa API.
#
# The bot engine is Vexa (Apache-2.0); the participant name is Snotra. This door keeps
# the API key out of every caller and refuses a plain-HTTP endpoint.
#
# It speaks Vexa's CURRENT contract (0.12): `POST /bots` with a platform and the code
# from the join link, `GET /bots/status` to see whether a bot is actually RUNNING, and
# `DELETE /bots/{platform}/{id}` to stop one. Until 2026-11-13 it spoke the retired
# `/meetings` shape, which the 0.12 gateway answers 404 — so a join could never land.
#
# A 201 from `join` means the request was ACCEPTED, never that a bot is in the room:
# plan 147 was exactly that confusion (`bot_container_id: null` while the door said
# joined). `status` is the only thing that may be called a join.
#
# Usage:
#   snotra-bot.sh join <meeting-url> [--workspace work|personal] [--name N] [--platform P]
#   snotra-bot.sh status <meeting-url|platform/id>
#   snotra-bot.sh stop <meeting-url|platform/id>
#   snotra-bot.sh health
#
# Env:
#   VEXA_API_URL       base URL, HTTPS (required unless VEXA_API_URLS is set)
#   VEXA_API_URLS      comma-separated endpoints; the first healthy one wins
#                      (e.g. whynot, then a local Vexa, then hosted)
#   VEXA_API_KEY       bearer token (or SNOTRA_VAULT_KEY name; see below)
#   VEXA_JOIN_PATH     default /bots
#   VEXA_STATUS_PATH   default /bots/status
#   VEXA_HEALTH_PATH   default /health
#   VEXA_ALLOW_HTTP    1 allows http (tests only)
#
# Exit: 0 ok · 1 API/IO error · 2 usage · 3 refused · 4 registered but not running
set -euo pipefail
VERSION="2.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true
[ -n "$ACTION" ] || { sed -n '2,30p' "$0" >&2; exit 2; }

die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
# URLs and key are REFERENCES: env first, then the vault. Never inline.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _c in "$_sd/../../../bin/vault/hoard-lib.sh" "$_sd/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _sd _c
fi
KEY="${VEXA_API_KEY:-}"
if [ -z "${VEXA_API_URLS:-}" ] || [ -z "${VEXA_API_URL:-}" ] || [ -z "$KEY" ]; then
  _have=""
  ymir_home_root _have 2>/dev/null || true
  if [ -n "${_have:-}" ] && [ -r "$_have/hodd/secrets/platform.env.age" ]; then
    _v="$(age -d -i "$_have/hodd/secrets/age.key" "$_have/hodd/secrets/platform.env.age" 2>/dev/null || true)"
    [ -n "${VEXA_API_URLS:-}" ] || VEXA_API_URLS="$(printf '%s\n' "$_v" | sed -n 's/^VEXA_API_URLS=//p' | head -1 | sed "s/^['\"]//; s/['\"]$//")"
    [ -n "${VEXA_API_URL:-}" ] || VEXA_API_URL="$(printf '%s\n' "$_v" | sed -n 's/^VEXA_API_URL=//p' | head -1 | sed "s/^['\"]//; s/['\"]$//")"
    [ -n "$KEY" ] || KEY="$(printf '%s\n' "$_v" | sed -n 's/^VEXA_API_KEY=//p' | head -1 | sed "s/^['\"]//; s/['\"]$//")"
  fi
fi
CANDIDATES="${VEXA_API_URLS:-${VEXA_API_URL:-}}"
# ONE documented default (Rule 07): the engine this box itself hosts, on loopback. An
# address is not a secret and the port is Vexa Lite's own; any other engine is named in
# the vault or the environment, never guessed.
if [ -z "$CANDIDATES" ] && command -v docker >/dev/null 2>&1 \
   && docker inspect "${VEXA_LITE_CONTAINER:-vexa-lite}" >/dev/null 2>&1; then
  CANDIDATES="http://127.0.0.1:${VEXA_LITE_PORT:-8056}"
fi
# A SELF-HOSTED engine on this box mints its own key at first boot and keeps it root-only
# inside the container. The door reads THAT, so the Allfather's vault holds no copy of a
# credential that a reinstall would invalidate — and no document ever carries it.
if [ -z "$KEY" ] && [ -z "${VEXA_API_KEY_DONE:-}" ]; then
  _lite="${VEXA_LITE_CONTAINER:-vexa-lite}"
  case "$CANDIDATES" in
    *127.0.0.1*|*localhost*)
      if command -v docker >/dev/null 2>&1 && docker inspect "$_lite" >/dev/null 2>&1; then
        KEY="$(docker exec "$_lite" sh -c 'sed -n "s/^VEXA_API_KEY=//p" /run/vexa/key.env' 2>/dev/null | head -1)"
        [ -n "$KEY" ] && VEXA_ALLOW_HTTP="${VEXA_ALLOW_HTTP:-1}"
      fi ;;
  esac
  unset _lite
fi
[ -n "$CANDIDATES" ] || die "VEXA_API_URL or VEXA_API_URLS is not set (env or vault), and no local Vexa Lite engine answers"
IFS=',' read -r -a _urls <<< "$CANDIDATES"
for u in "${_urls[@]}"; do
  case "$u" in
    https://*) ;;
    http://127.0.0.1*|http://localhost*) ;;  # loopback is inside one host (network law)
    http://*) [ "${VEXA_ALLOW_HTTP:-0}" = 1 ] || die "refusing plain HTTP: $u (set VEXA_ALLOW_HTTP=1 only for tests)" ;;
    *) die "endpoint must be absolute: $u" ;;
  esac
done
[ -n "$KEY" ] || die "VEXA_API_KEY is not set (env, vault, or the local Vexa Lite engine's own key)"

# Health-failover: whynot may be down; a local Vexa or a hosted one may not be.
pick_url(){
  local u code
  for u in "${_urls[@]}"; do
    # The health route does not authenticate, so this probes REACHABILITY only; the
    # join below is what proves the key. (A 200 here is not proof of a usable grant.)
    code="$(curl -sS -o /dev/null -w '%{http_code}' -m 3 -H "X-API-Key: $KEY" "${u%/}${VEXA_HEALTH_PATH:-/health}" 2>/dev/null || echo 000)"
    [ "$code" = 200 ] && { printf '%s' "${u%/}"; return 0; }
  done
  return 1
}
VEXA_API_URL="$(pick_url)" || die "no healthy Vexa endpoint among: $CANDIDATES"
export VEXA_API_URL

api(){ # method path json
  local method=$1 path=$2 body=${3-}
  # Vexa authenticates with X-API-Key. `Authorization: Bearer` is answered
  # 401 "Missing API key" — and the health route answers 200 to ANY header, so a
  # Bearer probe looked healthy while every join died (measured 2026-10-22).
  local args=(-sS -m 30 -X "$method" -H "X-API-Key: $KEY" -H 'Content-Type: application/json' -w '\n%{http_code}')
  [ -n "$body" ] && args+=(-d "$body")
  curl "${args[@]}" "${VEXA_API_URL%/}$path"
}

# A join link → the platform and the code the API wants. Vexa keys a meeting on
# (platform, native_meeting_id), never on the whole URL.
parse_link(){ # url → platform<TAB>id
  local url="${1-}" platform="${2-}"
  python3 - "$url" "$platform" <<'PY'
import re,sys
from urllib.parse import urlparse
url,forced=sys.argv[1],sys.argv[2]
p=urlparse(url); host=(p.netloc or "").lower(); path=p.path.strip("/")
platform=forced
if not platform:
    if "meet.google." in host: platform="google_meet"
    elif host.endswith("zoom.us"): platform="zoom"
    elif "teams.microsoft." in host or "teams.live." in host: platform="teams"
    elif "jitsi" in host: platform="jitsi"
    elif "ping." in host: platform="ping"
    else: platform="other"
mid=""
if platform=="google_meet":
    m=re.match(r"^(?:meet/)?([A-Za-z0-9\-]+)$", path) or re.search(r"/([A-Za-z0-9\-]+)$", path)
    mid=m.group(1) if m else ""
elif platform=="zoom":
    m=re.search(r"j/(\d+)", path); mid=m.group(1) if m else ""
elif platform=="teams":
    mid=url
else:
    mid=path.split("/")[-1] if path else url
print(f"{platform}\t{mid}")
PY
}

# Every door below accepts either a join URL or the already-parsed `platform/id`.
resolve_target(){ # arg → platform<TAB>id
  local arg="${1-}"
  case "$arg" in
    *://*) parse_link "$arg" "" ;;
    */*)   printf '%s\t%s\n' "${arg%%/*}" "${arg#*/}" ;;
    *)     die "give a meeting URL, or platform/id (e.g. google_meet/abc-defg-hij)" ;;
  esac
}

cmd_join(){
  local url="" ws="work" name="Snotra" platform=""
  url="${1-}"; shift 2>/dev/null || true
  while [ $# -gt 0 ]; do case "$1" in
    --workspace) ws="${2-}"; shift 2 ;;
    --name) name="${2-}"; shift 2 ;;
    --platform) platform="${2-}"; shift 2 ;;
    *) die "unknown option: $1" ;; esac; done
  [ -n "$url" ] || { sed -n '2,30p' "$0" >&2; exit 2; }
  case "$ws" in work|personal) ;; *) die "workspace must be work or personal" ;; esac
  local target plat mid payload
  target="$(parse_link "$url" "$platform")"
  plat="${target%%$'\t'*}"; mid="${target#*$'\t'}"
  [ -n "$mid" ] || die "cannot read a meeting code from: $url"
  payload="$(python3 - "$plat" "$mid" "$name" <<'PY'
import json,sys
platform,mid,name=sys.argv[1:]
print(json.dumps({"platform":platform,"native_meeting_id":mid,"bot_name":name,"transcribe_enabled":True}))
PY
)"
  local out code body
  out="$(api POST "${VEXA_JOIN_PATH:-/bots}" "$payload")" || die "join request failed"
  code="${out##*$'\n'}"; body="${out%$'\n'*}"
  case "$code" in
    200|201|202) ;;
    503) die "join refused (HTTP 503 — the engine has no transcription backend wired; a capture-only bot is a meeting nobody can read). body: $body" ;;
    *) die "join refused (HTTP $code): $body" ;;
  esac
  python3 - "$body" "$plat" "$mid" <<'PY'
import json,sys
raw,plat,mid=sys.argv[1:]
d=json.loads(raw) if raw.strip() else {}
print("dispatched\t%s/%s\tstatus=%s\tid=%s" % (
    d.get("platform") or plat, d.get("native_meeting_id") or mid,
    d.get("status") or "requested", d.get("id")))
print("note\taccepted is not joined — `snotra-bot.sh status %s/%s` is the only proof" % (plat, mid))
PY
}

cmd_status(){
  local arg="${1-}"; [ -n "$arg" ] || { sed -n '2,30p' "$0" >&2; exit 2; }
  local target plat mid out code
  target="$(resolve_target "$arg")"
  plat="${target%%$'\t'*}"; mid="${target#*$'\t'}"
  # The RUNNING list, not a registered row: a meeting row with no bot behind it is
  # precisely the false green of plan 147.
  out="$(api GET "${VEXA_STATUS_PATH:-/bots/status}?platform=$plat")" || die "status request failed"
  code="${out##*$'\n'}"; [ "$code" = 200 ] || die "status failed (HTTP $code): ${out%$'\n'*}"
  python3 - "${out%$'\n'*}" "$plat" "$mid" <<'PY'
import json,sys
raw,plat,mid=sys.argv[1:]
d=json.loads(raw)
bots=d.get("running") or d.get("running_bots") or []
hit=[b for b in bots if str(b.get("native_meeting_id") or "")==mid
     or str(b.get("meeting_url") or "").rstrip("/").endswith(mid)]
if hit:
    b=hit[0]
    print("bot\t%s/%s\tstatus=%s\tid=%s\trunning=yes" % (plat,mid,b.get("status") or "?",b.get("id")))
    sys.exit(0)
print("bot\t%s/%s\tnot-running\t(the API holds no running bot for this meeting — a registered request is not a join)" % (plat,mid))
sys.exit(4)
PY
}

cmd_stop(){
  local arg="${1-}"; [ -n "$arg" ] || { sed -n '2,30p' "$0" >&2; exit 2; }
  local target plat mid out code
  target="$(resolve_target "$arg")"
  plat="${target%%$'\t'*}"; mid="${target#*$'\t'}"
  out="$(api DELETE "/bots/$plat/$mid")" || die "stop request failed"
  code="${out##*$'\n'}"; case "$code" in 200|202|204) printf 'stopped\t%s/%s\n' "$plat" "$mid" ;;
    *) die "stop failed (HTTP $code): ${out%$'\n'*}" ;; esac
}

cmd_health(){
  local out code
  out="$(api GET "${VEXA_HEALTH_PATH:-/health}")" || die "health request failed"
  code="${out##*$'\n'}"; [ "$code" = 200 ] || die "engine is not healthy (HTTP $code)"
  printf 'engine\t%s\tup\n' "$VEXA_API_URL"
}

case "$ACTION" in
  join) cmd_join "$@" ;;
  status) cmd_status "$@" ;;
  stop) cmd_stop "$@" ;;
  health) cmd_health ;;
  *) sed -n '2,30p' "$0" >&2; exit 2 ;;
esac
