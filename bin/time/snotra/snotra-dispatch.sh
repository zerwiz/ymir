#!/usr/bin/env bash
# snotra-dispatch.sh — one draft per person, and the team follow-up, from a record.
#
#   snotra-dispatch.sh prepare <meeting-dir> [--followup]
#   snotra-dispatch.sh send <meeting-dir> [--person "Name"]
#   snotra-dispatch.sh status <meeting-dir>
#
# prepare creates Gmail drafts only. send is the approval and sends every prepared
# draft (or one person's). The dispatch state lives in <meeting-dir>/dispatch.json.
set -euo pipefail
ACTION="${1:-status}"; DIR="${2-}"; shift 2 2>/dev/null || true
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: snotra-dispatch.sh prepare|send|status <meeting-dir>" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MAIL="$ROOT/bin/time/snotra/mail-send.sh"
STATE="$DIR/dispatch.json"
REC="$DIR/record.json"; [ -r "$REC" ] || REC="$DIR/meeting.json"
[ -r "$REC" ] || { echo "error: no record in $DIR" >&2; exit 1; }

slugify(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//'; }

prepare(){
  local followup=0; [ "${1-}" = "--followup" ] && followup=1
  python3 - "$REC" "$STATE" "$DIR" <<'PY' > /tmp/dispatch-plan.tsv
import json,sys
rec,state,dirp=sys.argv[1:]
d=json.load(open(rec)); m=d.get('meeting',d)
print(f"MEETING\t{m.get('title')}\t{m.get('started_at','')[:10]}")
for p in d.get('participants',[]):
    if p.get('email'): print(f"PERSON\t{p.get('name')}\t{p['email']}")
PY
  local meeting title
  meeting="$(awk -F'\t' '$1=="MEETING"{print $2}' /tmp/dispatch-plan.tsv)"; title="$meeting"
  local out="{}"
  while IFS=$'\t' read -r kind name email; do
    [ "$kind" = PERSON ] || continue
    local slug brief; slug="$(slugify "$name")"; brief="$DIR/briefs/$slug.md"
    [ -r "$brief" ] || { echo "skip\t$name\tno brief" >&2; continue; }
    local res id; res="$(bash "$MAIL" draft --to "$email" --subject "Your actions — $title" --body "$brief" --record "$meeting")"
    id="$(printf '%s\n' "$res" | awk -F'\t' '$1=="draft" && $2 ~ /^r-[0-9]+$/ {print $2; exit}')"
    [ -n "$id" ] || { echo "failed\t$name\t$res" >&2; continue; }
    out="$(python3 - "$out" "$name" "$email" "$id" <<'PY'
import json,sys
base,name,email,did=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
d=json.loads(base); d.setdefault('people',[]).append({'name':name,'email':email,'draftId':did,'sent':None}); print(json.dumps(d))
PY
)"
    printf 'draft\t%s\t%s\t%s\n' "$name" "$email" "$id"
  done < /tmp/dispatch-plan.tsv
  python3 - "$STATE" "$out" <<'PY'
import json,sys
p=sys.argv[1]; d=json.loads(sys.argv[2]); json.dump(d,open(p,'w'),indent=2)
PY
  echo "prepared $(python3 -c "import json;print(len(json.load(open('$STATE')).get('people',[])))") draft(s)"
}
send(){
  local who="${1-}"; [ "${1-}" = "--person" ] && who="${2-}"
  [ -r "$STATE" ] || { echo "error: nothing prepared (run prepare)" >&2; exit 1; }
  python3 - "$STATE" "$who" <<'PY' > /tmp/dispatch-send.tsv
import json,sys
d=json.load(open(sys.argv[1])); who=sys.argv[2] if len(sys.argv)>2 else ''
for p in d.get('people',[]):
    if who and p['name']!=who: continue
    if not p.get('sent'): print(p['draftId']+"\t"+p['name'])
PY
  while IFS=$'\t' read -r id name; do
    [ -n "$id" ] || continue
    res="$(bash "$MAIL" send "$id")"; echo "$res	$name"
    python3 - "$STATE" "$name" "$res" <<'PY'
import json,sys,datetime,re
p,name,res=sys.argv[1:]
d=json.load(open(p)); hit=re.search(r'sent\t(\S+)',res)
for x in d.get('people',[]):
    if x['name']==name and hit: x['sent']={'id':hit.group(1),'at':datetime.datetime.now().astimezone().isoformat(timespec='seconds')}
json.dump(d,open(p,'w'),indent=2)
PY
  done < /tmp/dispatch-send.tsv
}
status(){ [ -r "$STATE" ] && python3 -c "
import json;d=json.load(open('$STATE'))
for p in d.get('people',[]): print(p['name'],p['email'],'sent' if p.get('sent') else 'draft', (p.get('sent') or {}).get('id',''))
" || echo "no dispatch state"; }
case "$ACTION" in prepare) prepare "${1-}";; send) send "${1-}";; status) status;; *) echo "usage" >&2; exit 2;; esac
