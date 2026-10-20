#!/usr/bin/env bash
# snotra-signoff.sh — the assembly signs the record, not the decision.
#
#   snotra-signoff.sh init   <meeting-dir>
#   snotra-signoff.sh record <meeting-dir> <name> confirmed|objected|abstained [--note TEXT]
#   snotra-signoff.sh ask    <meeting-dir> [--dry-run]     # one request per participant
#   snotra-signoff.sh sync   <meeting-dir> [--dry-run]     # read Gmail replies
#   snotra-signoff.sh render <meeting-dir>
#   snotra-signoff.sh status <meeting-dir>
#
# Status lives in <meeting-dir>/signoffs.json. A record is approved when every required
# person has confirmed; Grade A needs everyone, Grade B the approver and affected owners,
# Grade C accepts silence after two business days. The Chair signs last.
set -euo pipefail
ACTION="${1:-status}"; DIR="${2-}"; shift 2 2>/dev/null || true
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: snotra-signoff.sh init|record|ask|render|status <meeting-dir>" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MAIL="$ROOT/bin/time/snotra/mail-send.sh"
STATE="$DIR/signoffs.json"
REC="$DIR/record.json"; [ -r "$REC" ] || REC="$DIR/meeting.json"
[ -r "$REC" ] || { echo "error: no record in $DIR" >&2; exit 1; }

init(){
  python3 - "$REC" "$STATE" <<'PY'
import json,sys,datetime
rec=json.load(open(sys.argv[1])); m=rec.get('meeting',rec)
d={'meeting':m.get('title'),'meeting_id':m.get('id') or m.get('started_at','')[:10],
   'state':'draft','created_at':datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
   'signed_at':None,'signed_by':None,
   'people':[{'name':p.get('name'),'email':p.get('email'),'status':'pending','at':None,'note':None} for p in rec.get('participants',[])],
   'decisions':[{'decision_id':x.get('decision_id'),'grade':x.get('grade') or 'C','approver':x.get('decided_by')} for x in rec.get('decisions',[])]}
json.dump(d,open(sys.argv[2],'w'),indent=2,ensure_ascii=False)
print(f"init\t{len(d['people'])} people\t{len(d['decisions'])} decisions")
PY
}
record(){
  local who="${1-}" status="${2-}" note=""; shift 2 2>/dev/null || true
  [ -n "$who" ] && [ -n "$status" ] || { echo "usage: record <dir> <name> confirmed|objected|abstained --note ..." >&2; exit 2; }
  while [ $# -gt 0 ]; do case "$1" in --note) note="${2-}"; shift 2;; *) shift;; esac; done
  python3 - "$STATE" "$who" "$status" "$note" <<'PY'
import json,sys,datetime
p,who,status,note=sys.argv[1:]
d=json.load(open(p)); hit=False
for x in d['people']:
    if x['name']==who:
        x['status']=status; x['at']=datetime.datetime.now().astimezone().isoformat(timespec='seconds'); x['note']=note or None; hit=True
if not hit:
    d['people'].append({'name':who,'email':None,'status':status,'at':datetime.datetime.now().astimezone().isoformat(timespec='seconds'),'note':note or None})
# approved when every person has confirmed, or all non-confirmations are objections resolved by the chair
required=d['people']
if required and all(x['status'] in ('confirmed','abstained') for x in required) and not any(x['status']=='pending' for x in required):
    d['state']='approved'
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False)
print(f"recorded\t{who}\t{status}")
PY
}
render(){
  python3 - "$STATE" "$DIR/signoff.md" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); out=[f"# Sign-off — {d.get('meeting')}",""]
out.append(f"**State:** {d.get('state')}  ")
out.append(f"**Created:** {d.get('created_at')}  ")
out.append(f"**Signed by:** {d.get('signed_by') or '—'}  ")
out.append(f"**Signed at:** {d.get('signed_at') or '—'}  ")
out.append("")
out.append("A record is approved when it is accurate, not when everyone agrees with the decision. "
           "`confirm` signs the truth of the record; `objection:` names the correction.")
out.append("")
out.append("| Person | Status | At | Note |")
out.append("|---|---|---|---|")
for p in d.get('people',[]):
    out.append(f"| {p.get('name')} | {p.get('status')} | {p.get('at') or '—'} | {p.get('note') or ''} |")
out.append("")
out.append("| Decision | Grade | Approver |")
out.append("|---|---|---|")
for x in d.get('decisions',[]):
    out.append(f"| {x.get('decision_id')} | {x.get('grade')} | {x.get('approver')} |")
out.append("")
open(sys.argv[2],'w',encoding='utf-8').write("\n".join(out)+"\n")
print(f"rendered\t{sys.argv[2]}")
PY
}
ask(){
  local dry=0; [ "${1-}" = "--dry-run" ] && dry=1
  [ -r "$STATE" ] || init >/dev/null
  local title; title="$(python3 -c "import json;print(json.load(open('$STATE')).get('meeting','the meeting'))")"
  python3 - "$STATE" <<'PY' > /tmp/signoff-ask.tsv
import json,sys
d=json.load(open(sys.argv[1]))
for p in d.get('people',[]):
    if p.get('status')=='pending' and p.get('email'):
        print(p['name']+"\t"+p['email'])
PY
  while IFS=$'\t' read -r name email; do
    [ -n "$email" ] || continue
    body="$(mktemp --suffix=.md)"
    cat > "$body" <<TXT
$name,

The record of "$title" is ready. Please read it and reply with one of:

  confirm
  objection: <what is wrong or missing>

Replying "confirm" means the record is accurate. It does not mean you agree with every
decision. An objection names the correction; it is not a re-vote.

The record becomes official when the Chair signs it.

— Snotra, for the Secretary
TXT
    if [ "$dry" = 1 ]; then printf 'would draft\t%s\t%s\n' "$name" "$email"; else
      bash "$MAIL" draft --to "$email" --subject "Sign-off: $title" --body "$body" --attach "$DIR/record.pdf" --attach "$DIR/signoff.md" 2>&1 | tail -1
    fi
    rm -f "$body"
  done < /tmp/signoff-ask.tsv
}
sync(){
  local dry=0; [ "${1-}" = "--dry-run" ] && dry=1
  local sec="${YMIR_HOME:-}/hodd/secrets"
  if [ ! -r "$sec/age.key" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; ymir_home_root YMIR_HOME 2>/dev/null || true; sec="$YMIR_HOME/hodd/secrets"; fi
  [ -r "$sec/age.key" ] || { echo "error: vault key missing" >&2; exit 1; }
  local val; val="$(age -d -i "$sec/age.key" "$sec/platform.env.age" 2>/dev/null || true)"
  get(){ printf '%s\n' "$val" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
  local cid csec rt; cid="$(get GOOGLE_MCP_CLIENT_ID)"; csec="$(get GOOGLE_MCP_CLIENT_SECRET)"; rt="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
  [ -n "$cid" ] && [ -n "$csec" ] && [ -n "$rt" ] || { echo "error: google grant missing" >&2; exit 1; }
  local token; token="$(curl -sS -m 20 -X POST https://oauth2.googleapis.com/token -d "client_id=$cid" -d "client_secret=$csec" -d "refresh_token=$rt" -d "grant_type=refresh_token" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")"
  [ -n "$token" ] || { echo "error: token refresh failed" >&2; exit 1; }
  local title; title="$(python3 -c "import json;print(json.load(open('$STATE')).get('meeting',''))")"
  local q="subject:(\"Sign-off: $title\" OR \"$title — the record\") newer_than:14d"
  local list; list="$(curl -sS -G "https://gmail.googleapis.com/gmail/v1/users/me/messages" --data-urlencode "q=$q" -H "Authorization: Bearer $token")"
  python3 - "$list" "$token" "$STATE" "$dry" "$title" <<'PY'
import json,sys,base64,re,urllib.request
raw,token,state,dry,title=sys.argv[1:]
dry=int(dry or 0)
try: ids=[m['id'] for m in json.loads(raw).get('messages',[])]
except Exception: ids=[]
def get(i):
    req=urllib.request.Request(f'https://gmail.googleapis.com/gmail/v1/users/me/messages/{i}?format=full',headers={'Authorization':'Bearer '+token})
    return json.load(urllib.request.urlopen(req,timeout=30))
def body(p):
    if p.get('mimeType')=='text/plain' and p.get('body',{}).get('data'):
        return base64.urlsafe_b64decode(p['body']['data']+'==').decode('utf-8','replace')
    for c in p.get('parts',[]) or []:
        t=body(c)
        if t: return t
    return ''
def email_of(h):
    m=re.search(r'<([^>]+)>',h or ''); return (m.group(1) if m else (h or '')).strip().lower()
d=json.load(open(state)); by={p['email'].lower():p for p in d['people'] if p.get('email')}
seen=0
for i in ids:
    try: msg=get(i)
    except Exception: continue
    hdr={h['name'].lower():h['value'] for h in msg['payload'].get('headers',[])}
    if 'from' not in hdr: continue
    who=email_of(hdr['from']); person=by.get(who)
    if not person: continue
    text=body(msg['payload'])
    lines=[l.strip() for l in text.splitlines()]
    # ignore quoted history
    lines=[l for l in lines if l and not l.startswith('>') and not l.lower().startswith('on ')]
    status=None; note=''
    for l in lines:
        if re.fullmatch(r'(?i)confirm',l): status='confirmed'; break
        m=re.match(r'(?i)objection\s*:\s*(.*)',l)
        if m: status='objected'; note=m.group(1); break
    if not status: continue
    seen+=1
    if dry:
        print(f'would record\t{person["name"]}\t{status}\t{note}')
        continue
    person['status']=status; person['note']=note or None
    import datetime; person['at']=datetime.datetime.now().astimezone().isoformat(timespec='seconds')
    print(f'recorded\t{person["name"]}\t{status}\t{note}')
if not seen: print('no replies found')
if not dry:
    if d['people'] and all(p['status'] in ('confirmed','abstained') for p in d['people']): d['state']='approved'
    json.dump(d,open(state,'w'),indent=2,ensure_ascii=False)
PY
}
status(){
  [ -r "$STATE" ] || { echo "no sign-off state (run init)"; exit 1; }
  python3 -c "
import json;d=json.load(open('$STATE'));print('state',d.get('state'))
for p in d.get('people',[]): print(p['name'],p['status'],p.get('at') or '')
"
}
case "$ACTION" in init) init;; record) record "$@";; ask) ask "${1-}";; sync) sync "${1-}";; render) render;; status) status;; *) echo "usage" >&2; exit 2;; esac
