#!/usr/bin/env bash
# calendar-auth.sh — re-grant Mánagandr's read-only calendar and store the token.
#
# Why: the Google grant is a Testing-mode app token and expires every seven days.
# When it does, the reader answers `fetch_failed` and auto-join has no calendar.
#
# Usage:
#   calendar-auth.sh --url              print the authorization URL and exit
#   calendar-auth.sh --store            run the loopback flow, then store the token
#
# Env: GOOGLE_MCP_CLIENT_ID / GOOGLE_MCP_CLIENT_SECRET (from the vault),
#      CALENDAR_AUTH_PORT (default 8765), CHROMIUM_PROFILE (default "Profile 1")
#
# Exit: 0 ok · 1 error · 2 usage · 3 refused
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE="${1:---url}"; shift || true
case "$MODE" in --url|--store) ;; *) sed -n '2,16p' "$0" >&2; exit 2 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
YMIR_HOME="${YMIR_HOME:-}"
[ -r "$ROOT/bin/vault/hoard-lib.sh" ] && . "$ROOT/bin/vault/hoard-lib.sh" && ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"
[ -r "$SEC/platform.env.age" ] || { printf 'error: no vault at %s\n' "$SEC" >&2; exit 1; }
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"
[ -n "$CID" ] && [ -n "$CSEC" ] || { printf 'error: GOOGLE_MCP_CLIENT_ID/SECRET missing from the vault\n' >&2; exit 1; }
PORT="${CALENDAR_AUTH_PORT:-8765}"; REDIRECT="http://127.0.0.1:$PORT/callback"
SCOPE="https://www.googleapis.com/auth/calendar.events.readonly"
VERIFIER="$(python3 -c 'import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b"=").decode())')"
CHALLENGE="$(python3 -c "import hashlib,base64,sys;print(base64.urlsafe_b64encode(hashlib.sha256(sys.argv[1].encode()).digest()).rstrip(b'=').decode())" "$VERIFIER")"
STATE="$(python3 -c 'import secrets;print(secrets.token_urlsafe(24))')"
URL="https://accounts.google.com/o/oauth2/v2/auth?$(python3 - "$CID" "$REDIRECT" "$SCOPE" "$STATE" "$CHALLENGE" <<'PY'
import sys,urllib.parse
cid,red,scope,state,ch=sys.argv[1:]
print(urllib.parse.urlencode({"client_id":cid,"redirect_uri":red,"response_type":"code","scope":scope,"access_type":"offline","prompt":"consent","state":state,"code_challenge":ch,"code_challenge_method":"S256"}))
PY
)"
if [ "$MODE" = --url ]; then printf '%s\n' "$URL"; exit 0; fi

printf 'Opening Chromium (%s) for the calendar grant...\n' "${CHROMIUM_PROFILE:-Profile 1}"
chromium --profile-directory="${CHROMIUM_PROFILE:-Profile 1}" "$URL" >/dev/null 2>&1 &
CODE="$(python3 - "$PORT" "$STATE" <<'PY'
import http.server,sys,urllib.parse
port,state=int(sys.argv[1]),sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        q=urllib.parse.urlparse(self.path)
        p=urllib.parse.parse_qs(q.query)
        if q.path=='/callback' and p.get('state',[''])[0]==state:
            H.code=p.get('code',[''])[0]
            self.send_response(200);self.end_headers();self.wfile.write(b'ok')
            raise SystemExit
        self.send_response(404);self.end_headers()
    def log_message(self,*a): pass
H.code=''
s=http.server.HTTPServer(('127.0.0.1',port),H)
try: s.handle_request()
except SystemExit: pass
print(H.code)
PY
)"
[ -n "$CODE" ] || { printf 'error: no authorization code received\n' >&2; exit 1; }
TOK="$(curl -sS -m 30 -X POST https://oauth2.googleapis.com/token \
  -d "code=$CODE" -d "client_id=$CID" -d "client_secret=$CSEC" \
  -d "redirect_uri=$REDIRECT" -d "grant_type=authorization_code" -d "code_verifier=$VERIFIER")"
RT="$(printf '%s' "$TOK" | python3 -c "import json,sys;print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null)"
[ -n "$RT" ] || { printf 'error: no refresh token — %s\n' "$TOK" >&2; exit 1; }
TMP=$(mktemp); chmod 600 "$TMP"; trap 'shred -u "$TMP" 2>/dev/null || rm -f "$TMP"' EXIT
age -d -i "$SEC/age.key" -o "$TMP" "$SEC/platform.env.age"
python3 - "$TMP" "$RT" <<'PY'
import re,sys,shlex
p,val=sys.argv[1],sys.argv[2]
lines=open(p).read().splitlines(); out=[]; done=False
for l in lines:
    if re.match(r'^MANAGANDR_OAUTH_REFRESH_TOKEN=',l): out.append("MANAGANDR_OAUTH_REFRESH_TOKEN="+shlex.quote(val)); done=True
    else: out.append(l)
if not done: out.append("MANAGANDR_OAUTH_REFRESH_TOKEN="+shlex.quote(val))
open(p,'w').write("\n".join(out)+"\n")
PY
cp -p "$SEC/platform.env.age" "$SEC/platform.env.age.bak-$(date -u +%Y%m%dT%H%M%SZ)"
age -e -r "$(age-keygen -y "$SEC/age.key")" -o "$SEC/platform.env.age" "$TMP"
age -d -i "$SEC/age.key" "$SEC/platform.env.age" | grep -q '^MANAGANDR_OAUTH_REFRESH_TOKEN=' \
  && printf 'stored\tMANAGANDR_OAUTH_REFRESH_TOKEN\n' || { printf 'error: verify failed\n' >&2; exit 1; }
