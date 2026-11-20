#!/usr/bin/env bash
# google-auth.sh — one consent for the meeting powers: calendar write and mail.
#
# Scopes: calendar.events (create/invite), gmail.send (send after approval),
# gmail.compose (draft), gmail.readonly (threads). Stores the refresh token in the
# vault as SNOTRA_GOOGLE_REFRESH_TOKEN. Prints the account it belongs to.
#
#   google-auth.sh --url      print the consent URL
#   google-auth.sh --store    run the loopback consent and store the token
set -euo pipefail
MODE="${1:---url}"; shift || true
case "$MODE" in --url|--store) ;; *) sed -n '2,10p' "$0"; exit 2 ;; esac
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"; [ -r "$SEC/platform.env.age" ] || { echo "error: no vault" >&2; exit 1; }
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"
[ -n "$CID" ] && [ -n "$CSEC" ] || { echo "error: GOOGLE_MCP_CLIENT_ID/SECRET missing" >&2; exit 1; }
PORT="${GOOGLE_AUTH_PORT:-8765}"; REDIRECT="http://127.0.0.1:$PORT/callback"
SCOPE="https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/gmail.compose https://www.googleapis.com/auth/gmail.readonly"
VERIFIER="$(python3 -c 'import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b"=").decode())')"
CHALLENGE="$(python3 -c "import hashlib,base64,sys;print(base64.urlsafe_b64encode(hashlib.sha256(sys.argv[1].encode()).digest()).rstrip(b'=').decode())" "$VERIFIER")"
STATE="$(python3 -c 'import secrets;print(secrets.token_urlsafe(24))')"
URL="https://accounts.google.com/o/oauth2/v2/auth?$(python3 - "$CID" "$REDIRECT" "$SCOPE" "$STATE" "$CHALLENGE" <<'PY'
import sys,urllib.parse
cid,red,scope,state,ch=sys.argv[1:]
print(urllib.parse.urlencode({"client_id":cid,"redirect_uri":red,"response_type":"code","scope":scope,"access_type":"offline","prompt":"consent","state":state,"code_challenge":ch,"code_challenge_method":"S256"}))
PY
)"
[ "$MODE" = --url ] && { printf '%s\n' "$URL"; exit 0; }
printf 'Opening Chromium for the meeting consent...\n'
chromium --profile-directory="${CHROMIUM_PROFILE:-Profile 1}" "$URL" >/dev/null 2>&1 &
CODE="$(python3 - "$PORT" "$STATE" <<'PY'
import http.server,sys,urllib.parse
port,state=int(sys.argv[1]),sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        q=urllib.parse.urlparse(self.path); p=urllib.parse.parse_qs(q.query)
        if q.path=='/callback' and p.get('state',[''])[0]==state:
            H.code=p.get('code',[''])[0]; self.send_response(200); self.end_headers(); self.wfile.write(b'ok'); raise SystemExit
        self.send_response(404); self.end_headers()
    def log_message(self,*a): pass
H.code=''
s=http.server.HTTPServer(('127.0.0.1',port),H)
try: s.handle_request()
except SystemExit: pass
print(H.code)
PY
)"
[ -n "$CODE" ] || { echo "error: no code" >&2; exit 1; }
TOK="$(curl -sS -m 30 -X POST https://oauth2.googleapis.com/token -d "code=$CODE" -d "client_id=$CID" -d "client_secret=$CSEC" -d "redirect_uri=$REDIRECT" -d "grant_type=authorization_code" -d "code_verifier=$VERIFIER")"
RT="$(printf '%s' "$TOK" | python3 -c "import json,sys;print(json.load(sys.stdin).get('refresh_token',''))")"
[ -n "$RT" ] || { echo "error: no refresh token — $TOK" >&2; exit 1; }
printf '%s\n' "$RT" | bash /tmp/vault-put.sh SNOTRA_GOOGLE_REFRESH_TOKEN 2>&1 | tail -1
printf '%s\n' "$SCOPE" | bash /tmp/vault-put.sh SNOTRA_GOOGLE_SCOPES >/dev/null 2>&1
printf 'stored\tSNOTRA_GOOGLE_REFRESH_TOKEN\n'
