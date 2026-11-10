#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }; done; unset _c
fi
STATE=""; hoard_state_dir STATE 2>/dev/null || true
[ -n "$STATE" ] || { echo "finding-tally: state dir unresolved" >&2; exit 1; }
CONFIG="${YMIR_HOME:-}/config/review-learning.yaml"
[ -r "$CONFIG" ] || CONFIG="$YMIR_HOME/config/review-learning.yaml"

DAYS=14; CLASS=""; JSON=0; OPEN_CARDS=0; WEEK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2;;
    --class) CLASS="$2"; shift 2;;
    --json) JSON=1; shift;;
    --open-cards) OPEN_CARDS=1; shift;;
    --week) WEEK=1; shift;;
    *) echo "finding-tally: unknown arg $1" >&2; exit 2;;
  esac
done

python3 - "$STATE" "$CONFIG" "$DAYS" "$CLASS" "$JSON" "$OPEN_CARDS" "$WEEK" <<'PY'
import json,sys,os,datetime
state,config,days,cls,jsonflag,open_cards,week = sys.argv[1],sys.argv[2],int(sys.argv[3]),sys.argv[4],sys.argv[5]=='1',sys.argv[6]=='1',sys.argv[7]=='1'

# parse config
threshold=3; window_days=14; classes=[]
incls=False
for line in open(config):
    s=line.rstrip('\n')
    t=s.strip()
    if t.startswith('threshold:'):
        threshold=int(t.split(':',1)[1].strip()); continue
    if t.startswith('window_days:'):
        window_days=int(t.split(':',1)[1].strip()); continue
    if t=='classes:':
        incls=True; continue
    if incls:
        if t=='' : continue
        if not s.startswith(' ') and not s.startswith('\t'):
            incls=False; continue
        if t.startswith('- '):
            classes.append(t[2:].strip())

# days override window? --days sets window length
W=days
now=datetime.datetime.now(datetime.timezone.utc)
cur_start=now-datetime.timedelta(days=W)
prev_start=now-datetime.timedelta(days=2*W)

findings=[]
logpath=os.path.join(state,'review-findings.jsonl')
if os.path.exists(logpath):
    for line in open(logpath):
        line=line.strip()
        if not line: continue
        try: findings.append(json.loads(line))
        except: pass

def parse_date(d):
    try:
        return datetime.datetime.fromisoformat(d.replace('Z','+00:00'))
    except Exception:
        return None

# filter class
if cls:
    classes=[c for c in classes if c==cls]

rows=[]
for c in classes:
    cur=[f for f in findings if f.get('class')==c and (lambda dt: dt is not None and cur_start<=dt<now)(parse_date(f.get('date','')))]
    prv=[f for f in findings if f.get('class')==c and (lambda dt: dt is not None and prev_start<=dt<cur_start)(parse_date(f.get('date','')))]
    cur_prs=len(set(f.get('pr') for f in cur))
    prv_prs=len(set(f.get('pr') for f in prv))
    # trend
    if len(cur)>len(prv): trend='rising'
    elif len(cur)<len(prv): trend='falling'
    else: trend='flat'
    rows.append((c,len(cur),cur_prs,len(prv),trend,cur,prv))

# print
if jsonflag:
    import json as J
    out=[]
    for c,fc,pc,fp,trend,cur,prv in rows:
        out.append({"class":c,"findings":fc,"distinct_prs":pc,"this_window":fc,"previous_window":fp,"trend":trend})
    print(J.dumps(out))
else:
    for c,fc,pc,fp,trend,cur,prv in rows:
        print(f"{c} · {fc} findings · {pc} distinct PRs · this window {fc} · previous window {fp} · trend {trend}")

# cards
if open_cards or True:
    # always evaluate cards (print when threshold met)
    card_lines=[]
    for c,fc,pc,fp,trend,cur,prv in rows:
        if fc>=threshold:
            card=f"card: {c} · {fc} findings in {pc} PRs · decide: rule | guard | mend"
            # reasons
            reasons=[
              "rule: the law the finding cites is absent or unclear, so add it",
              "guard: the law exists but nothing catches it before review, so add a check",
              "mend: the fix is mechanical and one branch at a time will not prevent recurrence",
            ]
            card_lines.append((c,card,reasons,cur_start.date().isoformat()))
    # print cards
    for c,card,reasons,ws in card_lines:
        print(card)
        for r in reasons:
            print(f"  {r}")
    # write to review-cards.md if open_cards, dedupe by class+window
    if open_cards:
        path=os.path.join(state,'review-cards.md')
        existing=''
        if os.path.exists(path):
            existing=open(path).read()
        to_write=[]
        for c,card,reasons,ws in card_lines:
            marker=f"<!-- {c} {ws} -->"
            if marker in existing:
                continue
            block=marker+"\n"+card+"\n"+"\n".join(f"  {r}" for r in reasons)+"\n"
            to_write.append(block)
        if to_write:
            with open(path,'a') as fh:
                for b in to_write:
                    fh.write(b)

# --week
if week:
    fell=sum(1 for r in rows if r[4]=='falling' and r[1]>0)
    flat=sum(1 for r in rows if r[4]=='flat' and r[1]>0)
    new=sum(1 for r in rows if r[5] and len(r[6])==0 and r[1]>0)
    print(f"classes: {fell} fell · {flat} flat · {new} new")
PY
