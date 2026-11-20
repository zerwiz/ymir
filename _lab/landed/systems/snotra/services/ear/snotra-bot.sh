#!/usr/bin/env bash
# snotra-bot.sh — send Snotra into a meeting, through the Vexa API.
#
# The bot engine is Vexa (Apache-2.0); the participant name is Snotra. This door keeps
# the API key out of every caller and refuses a plain-HTTP endpoint.
#
# Usage:
#   snotra-bot.sh join <meeting-url> [--workspace work|personal] [--name N] [--platform P]
#   snotra-bot.sh status <id>
#   snotra-bot.sh stop <id>
#
# Env:
#   VEXA_API_URL       base URL, HTTPS (required unless VEXA_API_URLS is set)
#   VEXA_API_URLS      comma-separated endpoints; the first healthy one wins
#                      (e.g. whynot, then a local Vexa, then hosted)
#   VEXA_API_KEY       bearer token (or SNOTRA_VAULT_KEY name; see below)
#   VEXA_JOIN_PATH     default /meetings
#   VEXA_STATUS_PATH   default /meetings/{id}
#   VEXA_ALLOW_HTTP    1 allows http (tests only)
#
# Exit: 0 ok · 1 API/IO error · 2 usage · 3 refused
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true
[ -n "$ACTION" ] || { sed -n '2,18p' "$0" >&2; exit 2; }

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
[ -n "$CANDIDATES" ] || die "VEXA_API_URL or VEXA_API_URLS is not set"
IFS=',' read -r -a _urls <<< "$CANDIDATES"
for u in "${_urls[@]}"; do
  case "$u" in
    https://*) ;;
    http://127.0.0.1*|http://localhost*) ;;  # loopback is inside one host (network law)
    http://*) [ "${VEXA_ALLOW_HTTP:-0}" = 1 ] || die "refusing plain HTTP: $u (set VEXA_ALLOW_HTTP=1 only for tests)" ;;
    *) die "endpoint must be absolute: $u" ;;
  esac
done
[ -n "$KEY" ] || die "VEXA_API_KEY is not set (env or vault)"

# Health-failover: whynot may be down; a local Vexa or a hosted one may not be.
pick_url(){
  local u code
  for u in "${_urls[@]}"; do
    # /health does not authenticate, so this probes REACHABILITY only; the join
    # below is what proves the key. (A 200 here is not proof of a usable grant.)
    code="$(curl -sS -o /dev/null -w '%{http_code}' -m 3 -H "X-API-Key: $KEY" "${u%/}/health" 2>/dev/null || echo 000)"
    [ "$code" = 200 ] && { printf '%s' "${u%/}"; return 0; }
  done
  return 1
}
VEXA_API_URL="$(pick_url)" || die "no healthy Vexa endpoint among: $CANDIDATES"
export VEXA_API_URL

api(){ # method path json
  local method=$1 path=$2 body=${3-}
  # Vexa authenticates with X-API-Key. `Authorization: Bearer` is answered
  # 401 "Missing API key" — and /health answers 200 to ANY header, so a Bearer
  # probe looked healthy while every join died (measured 2026-10-22).
  local args=(-sS -m 30 -X "$method" -H "X-API-Key: $KEY" -H 'Content-Type: application/json' -w '\n%{http_code}')
  [ -n "$body" ] && args+=(-d "$body")
  curl "${args[@]}" "${VEXA_API_URL%/}$path"
}

cmd_join(){
  local url="" ws="work" name="Snotra" platform=""
  url="${1-}"; shift 2>/dev/null || true
  while [ $# -gt 0 ]; do case "$1" in
    --workspace) ws="${2-}"; shift 2 ;;
    --name) name="${2-}"; shift 2 ;;
    --platform) platform="${2-}"; shift 2 ;;
    *) die "unknown option: $1" ;; esac; done
  [ -n "$url" ] || { sed -n '2,18p' "$0" >&2; exit 2; }
  case "$ws" in work|personal) ;; *) die "workspace must be work or personal" ;; esac
  [ -n "$platform" ] || case "$url" in
    *meet.google.*) platform=google_meet ;;
    *zoom.us*) platform=zoom ;;
    *teams.microsoft.*) platform=teams ;;
    *jitsi*) platform=jitsi ;;
    *ping.zerwiz.org*) platform=ping ;;
    *) platform=other ;; esac
  local payload
  payload="$(python3 - "$url" "$platform" "$name" "$ws" <<'PY'
import json,sys
url,platform,name,ws=sys.argv[1:]
print(json.dumps({"meeting_url":url,"platform":platform,"bot_name":name,"workspace":ws}))
PY
)"
  local out code body
  out="$(api POST "${VEXA_JOIN_PATH:-/meetings}" "$payload")" || die "join request failed"
  code="${out##*$'\n'}"; body="${out%$'\n'*}"
  case "$code" in 200|201|202) ;; *) die "join refused (HTTP $code): $body" ;; esac
  python3 - "$body" <<'PY' || printf '%s\n' "$body"
import json,sys
d=json.loads(sys.argv[1])
print("joined\t%s\t%s" % (d.get("id") or d.get("meeting_id") or "?", d.get("status") or "queued"))
PY
}

cmd_status(){
  local id="${1-}"; [ -n "$id" ] || { sed -n '2,18p' "$0" >&2; exit 2; }
  local path="${VEXA_STATUS_PATH:-/meetings/{id}}"; path="${path//\{id\}/$id}"
  local out code; out="$(api GET "$path")" || die "status request failed"
  code="${out##*$'\n'}"; [ "$code" = 200 ] || die "status failed (HTTP $code)"
  python3 - "${out%$'\n'*}" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
print("bot\t%s\t%s\t%s" % (d.get("id",""),d.get("status",""),d.get("failure_reason") or ""))
PY
}

cmd_stop(){
  local id="${1-}"; [ -n "$id" ] || { sed -n '2,18p' "$0" >&2; exit 2; }
  local path="${VEXA_STATUS_PATH:-/meetings/{id}}"; path="${path//\{id\}/$id}/stop"
  local out code; out="$(api POST "$path" '{}')" || die "stop request failed"
  code="${out##*$'\n'}"; case "$code" in 200|202|204) printf 'stopped\t%s\n' "$id" ;; *) die "stop failed (HTTP $code)" ;; esac
}

case "$ACTION" in
  join) cmd_join "$@" ;;
  status) cmd_status "$@" ;;
  stop) cmd_stop "$@" ;;
  *) sed -n '2,18p' "$0" >&2; exit 2 ;;
esac
