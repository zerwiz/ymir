#!/usr/bin/env bash
# mail-send.sh — the follow-up email with the record attached, as a draft or send.
#
# Uses the Gmail API with the vault grant (gmail.compose, gmail.send). Never sends
# without either --send (an approved send) or --draft (default).
#
#   mail-send.sh draft --to a@x,b@y --subject S --body FILE \
#       [--html FILE] [--attach FILE ...] [--record ID] [--dry-run]
#   mail-send.sh raw    <draft-id>     # the exact bytes, for an approval hash
#   mail-send.sh send <draft-id>
#   mail-send.sh discard <draft-id>
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
gmail(){
  local method=$1 path=$2 body=${3-}; local tmp=""
  local a=(-sS -m 60 -X "$method" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -w '\n%{http_code}')
  # A raw message with a PDF can exceed MAX_ARG_STRLEN; never put it in argv.
  if [ -n "$body" ]; then tmp="$(mktemp)"; printf '%s' "$body" > "$tmp"; a+=(--data-binary "@$tmp"); fi
  local out; out="$(curl "${a[@]}" "https://gmail.googleapis.com/gmail/v1$path")"
  [ -n "$tmp" ] && rm -f "$tmp"
  printf '%s' "$out"
}

draft(){
  local to="" subject="" body="" html="" dry=0 record="" from_record="" meeting_dir=""; local attaches=()
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --subject) subject="${2-}"; shift 2 ;;
    --body) body="${2-}"; shift 2 ;;
    --html) html="${2-}"; shift 2 ;;
    --meeting-dir) meeting_dir="${2-}"; shift 2 ;;
    --attach) attaches+=("${2-}"); shift 2 ;;
    --record) record="${2-}"; shift 2 ;;
    --from-record) from_record="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) die "unknown option: $1" ;; esac; done
  [ -n "$subject" ] && [ -n "$body" ] || die "draft needs --subject --body"
  # --body is a FILE (the help says so). Read it; a plain string still works.
  if [ -f "$body" ]; then body="$(cat "$body")"; fi
  [ -n "$html" ] && [ -f "$html" ] && html="$(cat "$html")"
  if [ -n "$from_record" ]; then
    [ -r "$from_record" ] || die "record not readable: $from_record"
    local extra; extra="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(",".join(p["email"] for p in d.get("participants",[]) if p.get("email")))' "$from_record")"
    [ -n "$extra" ] && to="${to:+$to,}$extra"
  fi
  [ -n "$to" ] || die "draft needs --to or --from-record with participant emails"
  # Rule 26 + Rule 27: the sensitive gate first, then the private guard.
  if [ -n "$meeting_dir" ] && [ -x "$ROOT/bin/gates/guards/sensitive-gate.sh" ]; then
    "$ROOT/bin/gates/guards/sensitive-gate.sh" "$meeting_dir" --surface email --to "$to" >/dev/null 2>&1 || die "sensitive gate refused this meeting for email"
  fi
  local guard="$ROOT/bin/gates/guards/private-guard.sh"
  if [ -x "$guard" ]; then
    local gtmp; gtmp="$(mktemp)"; printf '%s\n%s\n' "$body" "$html" > "$gtmp"
    "$guard" check --surface email --to "$to" "$gtmp" >/dev/null 2>&1 || { rm -f "$gtmp"; die "private-guard refused the letter (run the guard to see the finding)"; }
    rm -f "$gtmp"
    for a in "${attaches[@]:-}"; do [ -f "$a" ] && { "$guard" check --surface email --to "$to" "$a" >/dev/null 2>&1 || die "private-guard refused attachment: $(basename "$a")"; }; done
  fi
  local eml; eml="$(mktemp --suffix=.eml)"
  python3 - "$to" "$subject" "$body" "$eml" "$html" "${attaches[@]}" <<'PY'
import sys, os, mimetypes
from email.message import EmailMessage
to,subject,body,out,html,*att=sys.argv[1:]
m=EmailMessage(); m["To"]=to; m["Subject"]=subject; m.set_content(body)
if html: m.add_alternative(html, subtype="html")
for p in att:
    if not os.path.isfile(p): continue
    data=open(p,"rb").read()
    if p.endswith(".md"):
        maintype, subtype = "text", "markdown"
    else:
        maintype, subtype = mimetypes.guess_type(p)[0].split("/", 1) if mimetypes.guess_type(p)[0] else ("application", "octet-stream")
    m.add_attachment(data, maintype=maintype, subtype=subtype, filename=os.path.basename(p))
open(out,"wb").write(bytes(m))
PY
  if [ "$dry" = 1 ]; then printf 'eml\t%s\n' "$eml"; return 0; fi
  local raw; raw="$(python3 - "$eml" <<'PY'
import base64,sys
print(base64.urlsafe_b64encode(open(sys.argv[1],'rb').read()).decode())
PY
)"
  # The raw message can exceed MAX_ARG_STRLEN (a PDF attachment does), so it
  # reaches Python on stdin, never as an argument.
  local payload; payload="$(printf '%s' "$raw" | python3 -c 'import json,sys;print(json.dumps({"message":{"raw":sys.stdin.read()}}))')"
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
discard(){
  local id="${1-}"; [ -n "$id" ] || die "discard needs a draft id"
  local out code body; out="$(gmail DELETE "/users/me/drafts/$id")"; code="${out##*$'
'}"; body="${out%$'
'*}"
  case "$code" in 200|204) printf 'discarded\t%s\n' "$id" ;; 404) printf 'gone\t%s\n' "$id" ;; *) die "discard failed (HTTP $code): $body" ;; esac
}
raw(){
  # the draft's exact RFC822 bytes, base64url-decoded — what snotra-approve.sh hashes. Without this an
  # approval cannot be bound to content, and "approved" would only mean "was looked at once".
  # The body is passed through a FILE, not argv: a draft with attachments is tens of megabytes and
  # "argument list too long" is a failure a mail door must not have.
  local id="${1-}"; [ -n "$id" ] || die "raw needs a draft id"
  local out code body tmp; out="$(gmail GET "/users/me/drafts/$id?format=raw")"; code="${out##*$'\n'}"; body="${out%$'\n'*}"
  [ "$code" = 200 ] || die "raw failed (HTTP $code)"
  tmp="$(mktemp)"; printf '%s' "$body" >"$tmp"
  python3 - "$tmp" <<'PYRAW'
import base64, json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
raw = (d.get("message") or {}).get("raw") or d.get("raw") or ""
sys.stdout.write(base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)).decode("utf-8", "replace"))
PYRAW
  local rc=$?; rm -f "$tmp"; return $rc
}
status(){ local out code; out="$(gmail GET "/users/me/profile")"; code="${out##*$'\n'}"; [ "$code" = 200 ] && printf 'gmail\tready\n' || die "gmail not ready (HTTP $code)"; }
case "$ACTION" in
  draft) draft "$@" ;;
  send) send "$@" ;;
  raw) raw "$@" ;;
  discard) discard "$@" ;;
  status) status ;;
  *) printf 'usage: mail-send.sh draft|send|status\n' >&2; exit 2 ;;
esac
