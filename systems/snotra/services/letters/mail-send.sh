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
#       [--attach FILE ...] [--record ID] [--reply-to ID|last:<addr>|q:<search>] [--new-thread] [--dry-run]
#       (--reply-to answers INSIDE that message's thread: In-Reply-To + References + the threadId,
#        and --subject defaults to "Re: <its subject>")
#       (a --subject that OPENS "Re:" is a claim the door must prove: exactly one message in the
#        mailbox carries that subject, or the letter is refused with the candidates named. It joins
#        that message's thread and says which one it answers. --new-thread is the deliberate way to
#        start a conversation; a subject that does not open "Re:" is never looked up.)
#   mail-send.sh raw    <draft-id>     # the exact bytes, for an approval hash
#   mail-send.sh send <draft-id>       # refused unless the approval matches those bytes
#   mail-send.sh discard <draft-id>
#   mail-send.sh status
#   mail-send.sh --self-test           # prove the gate refuses, sends once, and refuses a replay
#
# Endpoint configuration (Rule 07): YMIR_GMAIL_API_BASE · YMIR_OAUTH_TOKEN_URL.
set -euo pipefail
VERSION="1.1.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
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
# ── a reply names its message ────────────────────────────────────────────────────────────────────
# The subject is the only name a person has for the message they are answering. So a subject that
# opens "Re:" is read as a claim — it says this letter answers something — and the door must prove
# it before the letter leaves, or refuse and say why. These two helpers are that reading.

# The subject a reply claims to answer, normalised: every leading "Re:" (any case, however many),
# whitespace collapsed, case folded. `Re: Re:  the PLAN` and `the plan` are the same subject.
norm_subject(){
  printf '%s' "${1-}" | python3 -c 'import re,sys
s=sys.stdin.read().strip()
while True:
    m=re.match(r"(?is)^\s*re\s*:\s*",s)
    if not m: break
    s=s[m.end():]
print(re.sub(r"\s+"," ",s).strip().lower())'
}

# Does this subject say it answers a message?
is_reply_subject(){ printf '%s' "${1-}" | grep -qiE '^[[:space:]]*re[[:space:]]*:'; }

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
  local to="" subject="" body="" html="" dry=0 record="" from_record="" meeting_dir="" plain=0 template="leemunroe-simple" footer="" reply_to="" new_thread=0 undressed=""; local attaches=()
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --subject) subject="${2-}"; shift 2 ;;
    --body) body="${2-}"; shift 2 ;;
    --html) html="${2-}"; shift 2 ;;
    --template) template="${2-}"; shift 2 ;;
    --footer) footer="${2-}"; shift 2 ;;
    --plain) plain=1; shift ;;
    --undressed) undressed="${2-}"; shift 2 ;;
    --meeting-dir) meeting_dir="${2-}"; shift 2 ;;
    --attach) attaches+=("${2-}"); shift 2 ;;
    --record) record="${2-}"; shift 2 ;;
    --from-record) from_record="${2-}"; shift 2 ;;
    --reply-to) reply_to="${2-}"; shift 2 ;;
    --new-thread) new_thread=1; shift ;;
    --dry-run) dry=1; shift ;;
    *) die "unknown option: $1" ;; esac; done
  # A reply joins the thread it answers (2026-11-12): Gmail threads a message by its threadId, and every
  # other client by In-Reply-To/References — a reply that carries neither starts a new conversation.
  local reply_mid="" reply_refs="" reply_thread=""
  # ONE THREAD, NOT A NEW ONE EVERY TIME (2026-11-14, the Allfather: *"we need to update the logic in one
  # thread. we are sending new threads all the time"*). The threading itself was already right — a reply
  # carries In-Reply-To, References and the threadId — but naming a thread meant knowing a Gmail message
  # id, which no person does, so every letter started a new thread. `--reply-to` now also takes:
  #   last:<address>   the newest message to or from that address   (last:<their address>)
  #   q:<search>       the newest message matching a Gmail search   (q:subject:"<topic>")
  # A REPLY NAMES ITS MESSAGE (2026-11-17). Three letters went out in one night with "Re:" subjects that
  # began NEW threads: the subject claimed to answer a message and the headers that would have joined it
  # were simply never set, because naming a message meant knowing a Gmail id that nobody has. A subject is
  # what a person HAS. So a subject that opens "Re:" is a claim, and the door proves it before the letter
  # leaves: exactly ONE message in the mailbox carries that subject (normalised), or the letter is refused
  # with the reason and the candidates named. `--new-thread` is the deliberate way to start a conversation.
  # A subject that does not open "Re:" promised nothing and is never looked up.
  if [ -n "$reply_to" ] && [ "$new_thread" = 1 ]; then
    die "REFUSED — --new-thread says start a conversation and --reply-to says answer one; pick a road"
  fi
  if [ -z "$reply_to" ] && [ "$new_thread" != 1 ] && is_reply_subject "$subject"; then
    local norm normq ids cid meta mcode row r_id r_norm r_subj r_from r_date c
    local -a matched=()
    norm="$(norm_subject "$subject")"
    [ -n "$norm" ] || die "REFUSED — a subject of nothing but \"Re:\" cannot name the message it answers; give the subject, or start afresh with --new-thread"
    normq="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote("subject:\""+sys.argv[1].replace("\""," ")+"\""))' "$norm")"
    ids="$(gmail GET "/users/me/messages?maxResults=20&q=$normq")"
    mcode="${ids##*$'\n'}"; ids="${ids%$'\n'*}"
    case "$mcode" in
      200) ;;
      *) die "REFUSED — this letter's subject opens \"Re:\" and the mailbox could not be searched to prove it answers a message (HTTP $mcode); pass --new-thread to start a new conversation" ;;
    esac
    ids="$(printf '%s' "$ids" | python3 -c 'import json,sys
d=json.loads(sys.stdin.read() or "{}")
print("\n".join(m.get("id","") for m in (d.get("messages") or [])))' 2>/dev/null || true)"
    while IFS= read -r cid; do
      [ -n "$cid" ] || continue
      meta="$(gmail GET "/users/me/messages/$cid?format=metadata&metadataHeaders=Message-ID&metadataHeaders=References&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date")"
      mcode="${meta##*$'\n'}"; meta="${meta%$'\n'*}"
      # a candidate that cannot be read is not a candidate: it cannot be proven either way, and the count
      # below is what decides. Silence is safer than a guess — a letter is refused, never mis-threaded.
      [ "$mcode" = 200 ] || continue
      row="$(printf '%s' "$meta" | python3 -c 'import json,re,sys
d=json.loads(sys.stdin.read())
h={x.get("name","").lower():x.get("value","") for x in (d.get("payload") or {}).get("headers",[])}
s=h.get("subject","").strip()
while True:
    m=re.match(r"(?is)^\s*re\s*:\s*",s)
    if not m: break
    s=s[m.end():]
s=re.sub(r"\s+"," ",s).strip().lower()
print("\x1f".join([s,h.get("subject",""),h.get("from",""),h.get("date","")]))' 2>/dev/null || true)"
      [ -n "$row" ] || continue
      IFS=$'\x1f' read -r r_norm r_subj r_from r_date <<<"$row"
      if [ "$r_norm" = "$norm" ]; then matched+=("$cid"$'\x1f'"${r_subj:-(no subject)}"$'\x1f'"${r_from:-(unknown sender)}"$'\x1f'"${r_date:-(no date)}"); fi
    done < <(printf '%s\n' "$ids")
    case "${#matched[@]}" in
      1)
        IFS=$'\x1f' read -r cid r_subj r_from r_date <<<"${matched[0]}"
        reply_to="$cid"
        printf 'answers\t%s\t%s\t%s\t%s\n' "$cid" "$r_subj" "$r_from" "$r_date" >&2 ;;
      0)
        printf 'mail-send: REFUSED — this letter answers a message, and no message in the mailbox carries that subject\n' >&2
        printf '  the subject it claims to answer: \"%s\"\n' "$norm" >&2
        printf '  a \"Re:\" subject with nothing behind it opens a new thread that pretends to be a reply\n' >&2
        printf '  name the message: --reply-to <id> · or start a new conversation deliberately: --new-thread\n' >&2
        exit 1 ;;
      *)
        printf 'mail-send: REFUSED — this letter answers a message, and %s messages in the mailbox carry that subject\n' "${#matched[@]}" >&2
        printf '  the subject it claims to answer: \"%s\"\n' "$norm" >&2
        printf '  a subject that names more than one message cannot choose between them, so the door does not guess:\n' >&2
        for c in "${matched[@]}"; do
          IFS=$'\x1f' read -r r_id r_subj r_from r_date <<<"$c"
          printf '  %s  %s  —  %s  %s\n' "$r_id" "$r_subj" "$r_from" "$r_date" >&2
        done
        printf '  say which one: --reply-to <id> · or start a new conversation: --new-thread\n' >&2
        exit 1 ;;
    esac
  fi
  if [ -n "$reply_to" ]; then
    case "$reply_to" in
      last:*|q:*)
        local term id code
        case "$reply_to" in
          last:*) term="to:${reply_to#last:} OR from:${reply_to#last:}" ;;
          *)      term="${reply_to#q:}" ;;
        esac
        id="$(gmail GET "/users/me/messages?maxResults=1&q=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$term")" \
              | python3 -c 'import json,sys;d=json.loads(sys.stdin.read().rsplit("\n",1)[0]);m=(d.get("messages") or []);print(m[0]["id"] if m else "")')"
        [ -n "$id" ] || die "--reply-to $reply_to: no message matched — nothing to reply inside"
        printf 'thread\t%s -> %s\n' "$reply_to" "$id" >&2
        reply_to="$id" ;;
    esac
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
  # ── A LETTER IS DRESSED, AND THE DOOR PROVES IT (plan 322, 2026-11-19) ────────────────────────────
  # The default path already dressed a letter. What it could not do was PROVE it: `--plain` was an
  # unguarded escape, and a hand-dressed `--html` from a stale copy looked identical to one from the
  # pinned shelf. So the door writes the evidence into the letter itself, as a header:
  #   X-Ymir-Letter: dressed · <template>      (or)   X-Ymir-Letter: undressed · <why>
  # and `send` refuses a draft whose bytes carry neither. An undressed letter without a reason does not
  # exist; the reason is what the approval record repeats.
  local letter_mark=""
  if [ "$plain" = 1 ]; then
    [ -n "$undressed" ] || die "a plain letter needs a reason: --plain --undressed \"<why>\" (plan 322)"
    letter_mark="undressed · $undressed"
  elif printf '%s' "$html" | grep -q '<!-- letter: '; then
    local tname; tname="$(printf '%s' "$html" | sed -n 's/.*<!-- letter: \([^ ]*\) .*/\1/p' | head -1)"
    letter_mark="dressed · ${tname:-$template}"
  elif [ -n "$undressed" ]; then
    letter_mark="undressed · $undressed"
  else
    die "this letter carries no dressing stamp — it was not rendered by the shelf (plan 322); drop --html and let the door dress it, or say why with --undressed \"<why>\""
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
  python3 - "$to" "$subject" "$body" "$eml" "$html" "$reply_mid" "$reply_refs" "$letter_mark" "${attaches[@]}" <<'PY'
import sys, os, mimetypes
from email.message import EmailMessage
to,subject,body,out,html,reply_mid,reply_refs,letter_mark,*att=sys.argv[1:]
m=EmailMessage(); m["To"]=to; m["Subject"]=subject
if letter_mark: m["X-Ymir-Letter"]=letter_mark
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
  # THE DOOR THAT MOVED (2026-11-16): this called bin/time/snotra/, a retired shim that still works and
  # says so on every send — "has MOVED to systems/snotra" printed beside a letter that went out fine.
  # A retired path kept "because callers still work" is how a move becomes a mystery; pointed at the
  # real door, with the shim left in place for any hand that has not been repointed yet.
  local approve="$ROOT/systems/snotra/services/approve/snotra-approve.sh"
  # THE WORD FIRST. No send is requested until the approval record matches the draft's
  # CURRENT RFC822 bytes; the gate prints the reason (NOT APPROVED · STALE · ALREADY SENT)
  # and carves the refusal into the Runes itself. A door that checked nothing is how a
  # letter reached the partners on 2026-10-23 — so the check lives here, not in a caller.
  bash "$approve" gate mail "$id" >/dev/null || die "send refused for draft $id — the operator's word is missing, stale, or already spent; nothing was sent"
  # THE DRESSING IS PROVED ON THE BYTES THAT LEAVE (plan 322). A draft made before the stamp existed, or
  # by a caller that reached Gmail another way, carries no X-Ymir-Letter line; it is refused here rather
  # than sent bare.
  local mark; mark="$(raw "$id" 2>/dev/null | sed -n 's/^X-Ymir-Letter: //p' | head -1)"
  [ -n "$mark" ] || die "send refused for draft $id — it carries no X-Ymir-Letter line, so nobody can say it was dressed (plan 322); discard it and let the door draft it"
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
