#!/usr/bin/env bash
# snotra-signoff.sh — the assembly signs the record, not the decision.
#
#   snotra-signoff.sh init   <meeting-dir>
#   snotra-signoff.sh record <meeting-dir> <name> confirmed|objected|abstained [--note TEXT]
#   snotra-signoff.sh ask    <meeting-dir> [--dry-run]     # one request per participant
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
status(){
  [ -r "$STATE" ] || { echo "no sign-off state (run init)"; exit 1; }
  python3 -c "
import json;d=json.load(open('$STATE'));print('state',d.get('state'))
for p in d.get('people',[]): print(p['name'],p['status'],p.get('at') or '')
"
}
case "$ACTION" in init) init;; record) record "$@";; ask) ask "${1-}";; render) render;; status) status;; *) echo "usage" >&2; exit 2;; esac
