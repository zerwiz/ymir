#!/usr/bin/env bash
# gjallarhorn-purge.sh — purge the Cloudflare edge cache for a hostname.
# Needs CLOUDFLARE_API_TOKEN (Zone → Cache Purge) in .env.local; the zone id is
# found automatically (or set CLOUDFLARE_ZONE_ID). Galdr-style TOON.
#
# Usage:
#   gjallarhorn-purge.sh [hostname] [--everything]
#   gjallarhorn-purge.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${BROKK_ENV_FILE:-$ROOT/.env.local}"
DOMAIN="${YMIR_DOMAIN:-${YMIR_TUNNEL_HOST:-}}"
[ -n "$DOMAIN" ] || { printf 'gjallarhorn-purge: set YMIR_DOMAIN (or YMIR_TUNNEL_HOST)\n' >&2; exit 2; }
ZONE_NAME="${CLOUDFLARE_ZONE_NAME:-}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
HOST="${1:-$DOMAIN}"; [ "$HOST" = "--everything" ] && HOST=""
EVERYTHING=0; [ "${1-}" = "--everything" ] && EVERYTHING=1

# Load CLOUDFLARE_API_TOKEN from .env.local (never printed).
if [ -r "$ENV_FILE" ]; then set -a; . "$ENV_FILE"; set +a; fi
TOKEN="${CLOUDFLARE_API_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  printf 'gjallarhorn[1]{purge,status}:\n  "cache","NO TOKEN"\n'
  printf 'help: add CLOUDFLARE_API_TOKEN (Zone.Cache Purge) to %s\n' "${ENV_FILE#"$ROOT"/}" >&2
  printf 'note: the cloudflared cert.pem (Argo token) cannot purge; wrangler OAuth lacks the scope\n' >&2
  exit 1
fi

api() { curl -fsS -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' "$@"; }

ZONE="${CLOUDFLARE_ZONE_ID:-}"
if [ -z "$ZONE" ]; then
  ZONE="$(api "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("result") or []; print(r[0]["id"] if r else "")' 2>/dev/null)"
fi
[ -n "$ZONE" ] || { printf 'gjallarhorn[1]{purge,status}:\n  "zone","NOT FOUND (%s)"\n' "$ZONE_NAME" >&2; exit 1; }

if [ "$EVERYTHING" = 1 ]; then
  payload='{"purge_everything":true}'
  what="everything"
else
  payload="{\"hosts\":[\"$HOST\"]}"
  what="$HOST"
fi

resp="$(api -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/purge_cache" -d "$payload" || true)"
ok="$(printf '%s' "$resp" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("success",False))' 2>/dev/null || echo False)"
printf 'gjallarhorn[1]{purge,status,zone}:\n  "%s","%s","%s"\n' "$what" "$([ "$ok" = True ] && echo purged || echo failed)" "${ZONE:0:8}…"
[ "$ok" = True ] || printf '%s\n' "$resp" >&2
