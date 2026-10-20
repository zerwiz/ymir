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
#   VEXA_API_URL       base URL, HTTPS (required)
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
[ -n "${VEXA_API_URL:-}" ] || die "VEXA_API_URL is not set"
case "$VEXA_API_URL" in
  https://*) ;;
  http://*) [ "${VEXA_ALLOW_HTTP:-0}" = 1 ] || die "refusing plain HTTP: $VEXA_API_URL (set VEXA_ALLOW_HTTP=1 only for tests)" ;;
  *) die "VEXA_API_URL must be an absolute URL" ;;
esac
KEY="${VEXA_API_KEY:-}"
if [ -z "$KEY" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root _h 2>/dev/null || true
  if [ -n "${_h:-}" ] && [ -r "$_h/hodd/secrets/platform.env" ]; then
    KEY="$(sed -n 's/^VEXA_API_KEY=//p' "$_h/hodd/secrets/platform.env" | head -1)"
  fi
fi
[ -n "$KEY" ] || die "VEXA_API_KEY is not set (env or platform.env)"

api(){ # method path json
  local method=$1 path=$2 body=${3-}
  local args=(-sS -m 30 -X "$method" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' -w '\n%{http_code}')
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
