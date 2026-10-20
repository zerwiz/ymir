#!/usr/bin/env bash
# mail-send.sh — the follow-up email with the record attached, as a draft or send.
#
# Uses the Gmail API with the vault grant (gmail.compose, gmail.send). Never sends
# without either --send (an approved send) or --draft (default).
#
#   mail-send.sh draft --to a@x,b@y --subject S --body FILE \
#       [--attach FILE ...] [--record ID] [--dry-run]
#   mail-send.sh send <draft-id>
#   mail-send.sh status
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-draft}"; shift || true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"; RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
[ -n "$CID" ] && [ -n "$CSEC" ] && [ -n "$RT" ] || die "google credentials missing"
TOKEN="$(curl -sS -m 20 -X POST https://oauth2.googleapis.com/token -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" -d "grant_type=refresh_token" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")"
[ -n "$TOKEN" ] || die "token refresh failed"
gmail(){ local method=$1 path=$2 body=${3-}; local a=(-sS -m 60 -X "$method" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -w '\n%{http_code}'); [ -n "$body" ] && a+=(-d "$body"); curl "${a[@]}" "https://gmail.googleapis.com/gmail/v1$path"; }

draft(){
  local to="" subject="" body="" dry=0 record=""; local attaches=()
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --subject) subject="${2-}"; shift 2 ;;
    --body) body="${2-}"; shift 2 ;;
    --attach) attaches+=("${2-}"); shift 2 ;;
    --record) record="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) die "unknown option: $1" ;; esac; done
  [ -n "$to" ] && [ -n "$subject" ] && [ -n "$body" ] || die "draft needs --to --subject --body"
  local eml; eml="$(mktemp --suffix=.eml)"
  python3 - "$to" "$subject" "$body" "$eml" "${attaches[@]}" <<'PY'
import sys, os
from email.message import EmailMessage
to,subject,body,out,*att=sys.argv[1:]
m=EmailMessage(); m["To"]=to; m["Subject"]=subject; m.set_content(body)
for p in att:
    if not os.path.isfile(p): continue
    data=open(p,"rb").read()
    m.add_attachment(data, maintype="text", subtype="markdown" if p.endswith(".md") else "plain",
                     filename=os.path.basename(p))
open(out,"wb").write(bytes(m))
PY
  if [ "$dry" = 1 ]; then printf 'eml\t%s\n' "$eml"; return 0; fi
  local raw; raw="$(python3 - "$eml" <<'PY'
import base64,sys
print(base64.urlsafe_b64encode(open(sys.argv[1],'rb').read()).decode())
PY
)"
  local payload; payload="$(python3 - "$raw" <<'PY'
import json,sys
print(json.dumps({"message":{"raw":sys.argv[1]}}))
PY
)"
  local out code body2; out="$(gmail POST "/users/me/drafts" "$payload")"; code="${out##*$'\n'}"; body2="${out%$'\n'*}"
  case "$code" in 200|201) ;; *) die "draft failed (HTTP $code): $body2" ;; esac
  python3 - "$body2" "$eml" <<'PY'
import json,sys
d=json.loads(sys.argv[1]); print(f'draft\t{d.get("id")}\t{sys.argv[2]}')
PY
}
send(){
  local id="${1-}"; [ -n "$id" ] || die "send needs a draft id"
  local out code body; out="$(gmail POST "/users/me/drafts/send" "{\"id\":\"$id\"}")"; code="${out##*$'\n'}"; body="${out%$'\n'*}"
  case "$code" in 200|201) python3 - "$body" <<'PY'
import json,sys;d=json.loads(sys.argv[1]);print(f'sent\t{d.get("id")}')
PY
  ;; *) die "send failed (HTTP $code): $body" ;; esac
}
status(){ local out code; out="$(gmail GET "/users/me/profile")"; code="${out##*$'\n'}"; [ "$code" = 200 ] && printf 'gmail\tready\n' || die "gmail not ready (HTTP $code)"; }
case "$ACTION" in
  draft) draft "$@" ;;
  send) send "$@" ;;
  status) status ;;
  *) printf 'usage: mail-send.sh draft|send|status\n' >&2; exit 2 ;;
esac
