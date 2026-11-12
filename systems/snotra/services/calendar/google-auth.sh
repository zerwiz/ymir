#!/usr/bin/env bash
# google-auth.sh — one consent for a Google Workspace account used by Ymir.
#
# Scopes (default): calendar.events (create/invite), gmail.send (send after
# approval), gmail.compose (draft), gmail.readonly (threads). One OAuth client
# serves every Workspace surface; add scopes later with --scope and Google
# grants them incrementally (include_granted_scopes=true).
#
#   google-auth.sh --url [--account ADDRESS] [--scope URL ...]
#   google-auth.sh --store [--account ADDRESS] [--grant-key KEY] [--scope URL ...]
#
# The client id/secret come from the vault (GOOGLE_MCP_CLIENT_ID /
# GOOGLE_MCP_CLIENT_SECRET) and the refresh token is written there by
# bin/vault/hodd-set.sh, never to the tree. One grant per person: pass a
# distinct --grant-key for each account (default SNOTRA_GOOGLE_REFRESH_TOKEN).
set -euo pipefail

MODE="${1:---url}"; shift || true
case "$MODE" in --url|--store) ;; *) sed -n '2,19p' "$0"; exit 2 ;; esac

ACCOUNT="${GOOGLE_AUTH_ACCOUNT:-}"
GRANT_KEY="${GOOGLE_AUTH_GRANT_KEY:-SNOTRA_GOOGLE_REFRESH_TOKEN}"
SCOPES=(
  "https://www.googleapis.com/auth/calendar.events"
  "https://www.googleapis.com/auth/gmail.send"
  "https://www.googleapis.com/auth/gmail.compose"
  "https://www.googleapis.com/auth/gmail.readonly"
)
while [ $# -gt 0 ]; do
  case "$1" in
    --account) ACCOUNT="${2:?--account needs an address}"; shift 2 ;;
    --grant-key) GRANT_KEY="${2:?--grant-key needs a key}"; shift 2 ;;
    --scope) SCOPES+=("${2:?--scope needs a URL}"); shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "google-auth: unknown option $1" >&2; exit 2 ;;
  esac
done
SCOPE="${SCOPES[*]}"

ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
[ -n "$YMIR_HOME" ] || { echo "error: the home is unresolved" >&2; exit 1; }

# The vault by reference: one door for plain and age-encrypted homes.
VAL="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null || true)"
get() { printf '%s\n' "$VAL" | sed -n "s/^export $1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"
[ -n "$CID" ] && [ -n "$CSEC" ] || {
  echo "error: GOOGLE_MCP_CLIENT_ID/SECRET missing from $YMIR_HOME/hodd/secrets/platform.env" >&2
  echo "       set them with: bin/vault/hodd-set.sh GOOGLE_MCP_CLIENT_ID '<id>'" >&2
  exit 1
}

# One sign-in port for every Google door (plan 276): YMIR_OAUTH_LOOPBACK_PORT, then the old GOOGLE_AUTH_PORT;
# :8765 is Kokoro, the house's voice, and is never a sign-in's default.
PORT="${YMIR_OAUTH_LOOPBACK_PORT:-${GOOGLE_AUTH_PORT:-8767}}"; REDIRECT="http://127.0.0.1:$PORT/callback"

# A busy port is said, never worked around (plan 276): name the holder and stop; stop no service.
if [ "$MODE" = --store ] && (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
  holder="$(ss -ltnpH "sport = :$PORT" 2>/dev/null | sed -n 's/.*users:(("\([^"]*\)",pid=\([0-9]*\).*/\1 (pid \2)/p' | head -1)"
  printf 'error: port %s is held by %s — nothing was signed in\n' "$PORT" "${holder:-another process}" >&2
  printf 'help: free it, or set YMIR_OAUTH_LOOPBACK_PORT to a port registered on the OAuth client (:8765 is Kokoro, the voice)\n' >&2
  exit 1
fi
VERIFIER="$(python3 -c 'import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b"=").decode())')"
CHALLENGE="$(python3 -c "import hashlib,base64,sys;print(base64.urlsafe_b64encode(hashlib.sha256(sys.argv[1].encode()).digest()).rstrip(b'=').decode())" "$VERIFIER")"
STATE="$(python3 -c 'import secrets;print(secrets.token_urlsafe(24))')"

URL="https://accounts.google.com/o/oauth2/v2/auth?$(python3 - "$CID" "$REDIRECT" "$SCOPE" "$STATE" "$CHALLENGE" "$ACCOUNT" <<'PY'
import sys, urllib.parse
cid, red, scope, state, ch, account = sys.argv[1:]
params = {
    "client_id": cid, "redirect_uri": red, "response_type": "code",
    "scope": scope, "access_type": "offline", "prompt": "consent",
    "include_granted_scopes": "true", "state": state,
    "code_challenge": ch, "code_challenge_method": "S256",
}
if account:
    params["login_hint"] = account
print(urllib.parse.urlencode(params))
PY
)"

[ "$MODE" = --url ] && { printf '%s\n' "$URL"; exit 0; }

# Wait on the loopback before opening a browser: a fast redirect must not race
# the listener, and a machine without Chromium can still paste the URL by hand.
python3 - "$PORT" "$STATE" > /tmp/google-auth-code.$$ 2>/dev/null <<'PY' &
import http.server, sys, urllib.parse
port, state = int(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        q = urllib.parse.urlparse(self.path); p = urllib.parse.parse_qs(q.query)
        if q.path == '/callback' and p.get('state', [''])[0] == state:
            H.code = p.get('code', [''])[0]
            self.send_response(200); self.end_headers(); self.wfile.write(b'ok'); raise SystemExit
        self.send_response(404); self.end_headers()
    def log_message(self, *a): pass
H.code = ''
s = http.server.HTTPServer(('127.0.0.1', port), H)
try: s.handle_request()
except SystemExit: pass
print(H.code)
PY
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -f /tmp/google-auth-code.$$' EXIT
sleep 0.5

printf 'Open this URL and consent as %s:\n%s\n' "${ACCOUNT:-the Google account}" "$URL"
if command -v chromium >/dev/null 2>&1; then
  chromium --profile-directory="${CHROMIUM_PROFILE:-Profile 1}" "$URL" >/dev/null 2>&1 &
elif command -v google-chrome >/dev/null 2>&1; then
  google-chrome "$URL" >/dev/null 2>&1 &
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" >/dev/null 2>&1 &
fi

for _ in $(seq 1 300); do
  [ -s /tmp/google-auth-code.$$ ] && break
  sleep 1
done
CODE="$(cat /tmp/google-auth-code.$$ 2>/dev/null || true)"
[ -n "$CODE" ] || { echo "error: no code received on $REDIRECT" >&2; exit 1; }

TOK="$(curl -sS -m 30 -X POST https://oauth2.googleapis.com/token \
  -d "code=$CODE" -d "client_id=$CID" -d "client_secret=$CSEC" \
  -d "redirect_uri=$REDIRECT" -d "grant_type=authorization_code" -d "code_verifier=$VERIFIER")"
RT="$(printf '%s' "$TOK" | python3 -c "import json,sys;print(json.load(sys.stdin).get('refresh_token',''))")"
[ -n "$RT" ] || { echo "error: no refresh token — $TOK" >&2; exit 1; }

bash "$ROOT/bin/vault/hodd-set.sh" "$GRANT_KEY" "$RT" >/dev/null
bash "$ROOT/bin/vault/hodd-set.sh" SNOTRA_GOOGLE_SCOPES "$SCOPE" >/dev/null
printf 'stored\t%s\n' "$GRANT_KEY"
printf 'account\t%s\n' "${ACCOUNT:-unknown}"
printf 'scopes\t%s\n' "$SCOPE"
