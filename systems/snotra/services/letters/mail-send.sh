#!/usr/bin/env bash
# mail-send.sh — the follow-up email with the record attached, as a draft or send.
#
# Uses the Gmail API with the vault grant (gmail.compose, gmail.send). Never sends
# without the operator's word: `send` asks snotra-approve.sh first, and an approval
# that does not match the draft's CURRENT bytes is a refusal (plan 124 §7).
#
# TEMPLATES: systems/snotra/services/letters/templates/ — vendored, pinned, licence-clean
# HTML letter templates (Cerberus · leemunroe · Mailgun). A letter is DRESSED BY DEFAULT: the words
# in --body are rendered into leemunroe-simple by letter-html.py, so nobody has to remember to make a
# letter look deliberate. `--plain` says so on purpose; `--html FILE` takes a letter dressed by hand in
# another template; read that folder's README first.
#
#   mail-send.sh draft --to a@x,b@y --subject S --body FILE \
#       [--html FILE | --template NAME | --plain] [--footer LINE] \
#       (a --body that opens with a `theme:` header is rendered by letter-design.py — the house letter design)
#       [--attach FILE ...] [--record ID] [--reply-to GMAIL-MESSAGE-ID] [--dry-run]
#       (--reply-to answers INSIDE that message's thread: In-Reply-To + References + the threadId,
#        and --subject defaults to "Re: <its subject>")
#   mail-send.sh raw    <draft-id>     # the exact bytes, for an approval hash
#   mail-send.sh send <draft-id>       # refused unless the approval matches those bytes
#   mail-send.sh discard <draft-id>
#   mail-send.sh status
#   mail-send.sh --self-test           # prove the gate refuses, sends once, and refuses a replay
#
# Endpoint configuration (Rule 07): YMIR_GMAIL_API_BASE · YMIR_OAUTH_TOKEN_URL.
set -euo pipefail
VERSION="1.0.3"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-draft}"; shift || true
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
# Rule 07: an endpoint is configuration, never a constant. The two defaults are the
# real Google doors; a test stands a local server here and proves the gate offline.
GMAIL_API="${YMIR_GMAIL_API_BASE:-https://gmail.googleapis.com/gmail/v1}"
OAUTH_URL="${YMIR_OAUTH_TOKEN_URL:-https://oauth2.googleapis.com/token}"
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"; RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
[ -n "$CID" ] && [ -n "$CSEC" ] && [ -n "$RT" ] || die "google credentials missing"
TOKEN="$(curl -sS -m 20 -X POST "$OAUTH_URL" -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" -d "grant_type=refresh_token" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")"
[ -n "$TOKEN" ] || die "token refresh failed"
gmail(){
  local method=$1 path=$2 body=${3-}; local tmp=""
  local a=(-sS -m 60 -X "$method" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -w '\n%{http_code}')
  # A raw message with a PDF can exceed MAX_ARG_STRLEN; never put it in argv.
  if [ -n "$body" ]; then tmp="$(mktemp)"; printf '%s' "$body" > "$tmp"; a+=(--data-binary "@$tmp"); fi
  local out; out="$(curl "${a[@]}" "$GMAIL_API$path")"
  [ -n "$tmp" ] && rm -f "$tmp"
  printf '%s' "$out"
}

# ── the address ward ─────────────────────────────────────────────────────────────────────────────
# A letter to a domain with no mail exchanger is not sent; it is thrown away slowly, and the sender
# learns of it hours later from a delivery notification that names a stranger's domain. Measured
# 2026-11-01: `thegleemachine.com` publishes no MX at all (its A record is 127.0.0.1), so every
# message to <a personal address> was delayed and lost. The register already knows how to ask
# DNS; this is the send path asking it before the letter leaves.
guard_recipients(){
  local to="${1-}" rc=0 addr domain
  [ -n "$to" ] || return 0
  for addr in $(printf '%s' "$to" | tr ',' '\n' | sed -n 's/.*<\([^>]*\)>.*/\1/p; s/^[[:space:]]*\([^<> ]*@[^<> ]*\)[[:space:]]*$/\1/p'); do
    domain="${addr##*@}"
    case "$domain" in ""|*.*) ;; *) continue ;; esac
    local verdict
    verdict="$(python3 "$ROOT/bin/mail/gna_addresses.py" mx --domain "$domain" 2>/dev/null || true)"
    case "$verdict" in
      present*) continue ;;
      *)
        printf 'mail-send: REFUSED — %s cannot receive mail\n' "$addr" >&2
        printf '  %s\n' "${verdict:-$domain: the register could not measure an MX}" >&2
        printf '  a letter to a domain with no mail exchanger is lost, not sent; fix the address or the domain\n' >&2
        rc=1 ;;
    esac
  done
  return "$rc"
}

draft(){
  local to="" subject="" body="" html="" dry=0 record="" from_record="" meeting_dir="" plain=0 template="leemunroe-simple" footer="" reply_to=""; local attaches=()
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --subject) subject="${2-}"; shift 2 ;;
    --body) body="${2-}"; shift 2 ;;
    --html) html="${2-}"; shift 2 ;;
    --template) template="${2-}"; shift 2 ;;
    --footer) footer="${2-}"; shift 2 ;;
    --plain) plain=1; shift ;;
    --meeting-dir) meeting_dir="${2-}"; shift 2 ;;
    --attach) attaches+=("${2-}"); shift 2 ;;
    --record) record="${2-}"; shift 2 ;;
    --from-record) from_record="${2-}"; shift 2 ;;
    --reply-to) reply_to="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) die "unknown option: $1" ;; esac; done
  # A reply joins the thread it answers (2026-11-12): Gmail threads a message by its threadId, and every
  # other client by In-Reply-To/References — a reply that carries neither starts a new conversation.
  local reply_mid="" reply_refs="" reply_thread=""
  if [ -n "$reply_to" ]; then
    local meta mcode; meta="$(gmail GET "/users/me/messages/$reply_to?format=metadata&metadataHeaders=Message-ID&metadataHeaders=References&metadataHeaders=Subject")"
    mcode="${meta##*$'\n'}"; meta="${meta%$'\n'*}"
    case "$mcode" in 200) ;; *) die "--reply-to: message $reply_to could not be read (HTTP $mcode)" ;; esac
    local parsed; parsed="$(python3 - "$meta" "$subject" <<'PY'
import json, sys
d = json.loads(sys.argv[1]); subject = sys.argv[2]
h = {x.get("name", "").lower(): x.get("value", "") for x in (d.get("payload") or {}).get("headers", [])}
mid = h.get("message-id", "")
refs = " ".join(x for x in (h.get("references", ""), mid) if x).strip()
if not subject:
    orig = h.get("subject", "")
    subject = orig if orig.lower().startswith("re:") else ("Re: " + orig if orig else "")
print("\x1f".join([d.get("threadId", ""), mid, refs, subject]))  # a non-blank separator: an empty field must not collapse
PY
)" || die "--reply-to: the message metadata could not be parsed"
    IFS=$'\x1f' read -r reply_thread reply_mid reply_refs subject <<<"$parsed"
    [ -n "$reply_thread" ] || die "--reply-to: message $reply_to carries no thread"
  fi
  [ -n "$subject" ] && [ -n "$body" ] || die "draft needs --subject --body"
  # --body is a FILE (the help says so). Read it; a plain string still works.
  if [ -f "$body" ]; then body="$(cat "$body")"; fi
  [ -n "$html" ] && [ -f "$html" ] && html="$(cat "$html")"
  # A letter leaves dressed. The words stay exactly the words; this only puts them inside a template, so the
  # house does not depend on any one hand remembering to style what it sends. --plain is the deliberate
  # opt-out, and --html is a letter dressed by hand in one of the templates this script cannot re-render.
  # A letter that opens with a `theme:` header is written for the house letter design (plan 250 §7): it is rendered
  # by letter-design.py — the blocks, the themes, the letter types — and its plain twin is the same words without
  # the header. `letter-design.py --types` lists the letter types; `--themes` the themes (company themes live in the home).
  if [ -z "$html" ] && [ "$plain" != 1 ] && printf '%s' "$body" | head -6 | grep -qE '^theme:[[:space:]]*[A-Za-z]'; then
    local design="$ROOT/systems/snotra/services/letters/letter-design.py"
    [ -f "$design" ] || die "the letter design renderer is missing: $design"
    html="$(printf '%s' "$body" | python3 "$design" -)" || die "the letter could not be designed — run letter-design.py on it to see why"
    body="$(printf '%s' "$body" | awk 'NR==1 && /^---$/ {h=1; next} h && /^---$/ {h=0; next} !h')"
  fi
  if [ -z "$html" ] && [ "$plain" != 1 ]; then
    local render="$ROOT/systems/snotra/services/letters/letter-html.py"
    [ -f "$render" ] || die "the letter renderer is missing: $render (pass --html FILE or --plain)"
    local -a dress=(--subject "$subject" --template "$template")
    [ -n "$footer" ] && dress+=(--footer "$footer")
    html="$(printf '%s' "$body" | python3 "$render" "${dress[@]}" -)" || die "the letter could not be dressed in $template — pass --html FILE, or --plain"
    [ -n "$html" ] || die "the letter renderer returned nothing — pass --html FILE, or --plain"
  fi
  if [ -n "$from_record" ]; then
    [ -r "$from_record" ] || die "record not readable: $from_record"
    local extra; extra="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(",".join(p["email"] for p in d.get("participants",[]) if p.get("email")))' "$from_record")"
    [ -n "$extra" ] && to="${to:+$to,}$extra"
  fi
  [ -n "$to" ] || die "draft needs --to or --from-record with participant emails"
  guard_recipients "$to" || die "refused: a recipient domain cannot receive mail (see above)"
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
  python3 - "$to" "$subject" "$body" "$eml" "$html" "$reply_mid" "$reply_refs" "${attaches[@]}" <<'PY'
import sys, os, mimetypes
from email.message import EmailMessage
to,subject,body,out,html,reply_mid,reply_refs,*att=sys.argv[1:]
m=EmailMessage(); m["To"]=to; m["Subject"]=subject
if reply_mid: m["In-Reply-To"]=reply_mid
if reply_refs: m["References"]=reply_refs
m.set_content(body)
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
  local payload; payload="$(printf '%s' "$raw" | python3 -c 'import json,sys;m={"raw":sys.stdin.read()}
if sys.argv[1]: m["threadId"]=sys.argv[1]
print(json.dumps({"message":m}))' "$reply_thread")"
  local out code body2; out="$(gmail POST "/users/me/drafts" "$payload")"; code="${out##*$'\n'}"; body2="${out%$'\n'*}"
  case "$code" in 200|201) ;; *) die "draft failed (HTTP $code): $body2" ;; esac
  python3 - "$body2" "$eml" <<'PY'
import json,sys
d=json.loads(sys.argv[1]); print(f'draft\t{d.get("id")}\t{sys.argv[2]}')
PY
}
send(){
  local id="${1-}"; [ -n "$id" ] || die "send needs a draft id"
  local approve="$ROOT/bin/time/snotra/snotra-approve.sh"
  # THE WORD FIRST. No send is requested until the approval record matches the draft's
  # CURRENT RFC822 bytes; the gate prints the reason (NOT APPROVED · STALE · ALREADY SENT)
  # and carves the refusal into the Runes itself. A door that checked nothing is how a
  # letter reached the partners on 2026-10-23 — so the check lives here, not in a caller.
  bash "$approve" gate mail "$id" >/dev/null || die "send refused for draft $id — the operator's word is missing, stale, or already spent; nothing was sent"
  local out code body sent_id=""; out="$(gmail POST "/users/me/drafts/send" "{\"id\":\"$id\"}")"; code="${out##*$'\n'}"; body="${out%$'\n'*}"
  case "$code" in 200|201) sent_id="$(python3 - "$body" <<'PY'
import json,sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    d = {}
print(d.get("id", ""))
PY
)"; printf 'sent\t%s\n' "$sent_id"
  ;; *) die "send failed (HTTP $code): $body" ;; esac
  # The word is spent: one approval, one send. A second send is refused as ALREADY SENT.
  bash "$approve" consume mail "$id" >/dev/null || printf 'warning: the approval was not marked spent — a replay would be possible\n' >&2
  # RECORD IT, now: the ledger knows the letter from the moment it leaves, not from the next import.
  # The headers are read back from the draft that was actually sent, so the record says what left
  # rather than what we believe we asked for. A ledger that fails must never fail a sent letter.
  local ledger="$ROOT/bin/mail/ledger.sh"
  if [ -x "$ledger" ] && [ -n "$sent_id" ]; then
    local meta hdrs to subject natt
    meta="$(gmail GET "/users/me/drafts/$id?format=metadata" 2>/dev/null || true)"
    hdrs="$(printf '%s' "${meta%$'\n'*}" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
msg = d.get("message", {}) or {}
payload = msg.get("payload", {}) or {}
hs = {h.get("name", "").lower(): h.get("value", "") for h in payload.get("headers", []) or []}
n = sum(1 for p in payload.get("parts", []) or [] if p.get("filename"))
print(hs.get("to", ""))
print(hs.get("subject", ""))
print(n)
' 2>/dev/null || true)"
    to="$(printf '%s' "$hdrs" | sed -n 1p)"; subject="$(printf '%s' "$hdrs" | sed -n 2p)"; natt="$(printf '%s' "$hdrs" | sed -n 3p)"
    if [ -n "$to" ]; then
      bash "$ledger" out --to "$to" --subject "${subject:-draft $id}" --gmail "$sent_id" --attachments "${natt:-0}" >/dev/null 2>&1 \
        || printf 'warning: the letter was sent but the ledger did not record it\n' >&2
    fi
  fi
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
  --self-test|self-test)
    exec python3 "$ROOT/bin/time/snotra/tests/test_outbound_gate.py" MailGate "$@" ;;
  *) printf 'usage: mail-send.sh draft|send|raw|discard|status|--self-test\n' >&2; exit 2 ;;
esac
