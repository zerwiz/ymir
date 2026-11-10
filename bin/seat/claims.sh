#!/usr/bin/env bash
set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?}"

HOST="$(hostname -s 2>/dev/null || hostname)"
SEAT="${YMIR_SEAT:-}"
if [ -z "$SEAT" ] && [ -f "$HOME/.pi/agent/extensions/.ymir-seat" ]; then
  SEAT="$(sed -n 's/^primary=//p' "$HOME/.pi/agent/extensions/.ymir-seat" | head -1)"
fi
SEAT="${SEAT:-unnamed}"
CLAIMS_DIR="$YMIR_HOME/state/claims"
mkdir -p "$CLAIMS_DIR"
FILE="$CLAIMS_DIR/${HOST}-${SEAT}.json"
[ -f "$FILE" ] || echo '[]' > "$FILE"

python3 - "$FILE" "$HOST" "$SEAT" "$@" <<'PY'
import json,sys,os,datetime
file_path,host,seat=sys.argv[1],sys.argv[2],sys.argv[3]
args=sys.argv[4:]
def load():
    try:
        return json.load(open(file_path))
    except Exception:
        return []
def save(d):
    tmp=file_path+".tmp"
    with open(tmp,"w") as f: json.dump(d,f,indent=2)
    os.replace(tmp,file_path)
def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z")
verb=args[0] if args else ""
if verb=="claim":
    plan=int(args[1])
    branch=None; errand=None; note=None
    i=2
    while i<len(args):
        if args[i]=="--branch": branch=args[i+1]; i+=2; continue
        if args[i]=="--errand": errand=args[i+1]; i+=2; continue
        if args[i]=="--note": note=args[i+1]; i+=2; continue
        i+=1
    data=load()
    for c in data:
        if c.get("plan")==plan and c.get("branch")==branch:
            print(f"REFUSED: plan {plan} on branch {branch} already claimed by {c.get('seat')}@{c.get('host')}")
            sys.exit(2)
    entry={"host":host,"seat":seat,"plan":plan,"branch":branch,"errand":errand,"note":note,"since":now(),"last_push":None}
    data.append(entry)
    save(data)
    print(f"claimed plan {plan} on {branch}")
elif verb=="release":
    plan=int(args[1])
    data=load()
    data=[c for c in data if c.get("plan")!=plan]
    save(data)
    print(f"released plan {plan}")
elif verb=="list":
    data=load()
    if "--json" in args:
        print(json.dumps(data))
    else:
        for c in data:
            print(f"{c.get('host')} · {c.get('seat')} · plan {c.get('plan')} · {c.get('branch')} · since {c.get('since')}")
elif verb=="who":
    plan=int(args[1])
    data=load()
    holders=[c for c in data if c.get("plan")==plan]
    if holders:
        print(holders[0].get("seat"))
    else:
        print("nobody")
elif verb=="--check":
    data=load()
    nowdt=datetime.datetime.now(datetime.timezone.utc)
    stale=[]
    coll=[]
    for c in data:
        try:
            dt=datetime.datetime.fromisoformat(c.get("since","").replace("Z","+00:00"))
            if (nowdt-dt).total_seconds()/3600.0>24 and not c.get("last_push"):
                stale.append(c)
        except Exception: pass
    from collections import Counter
    plans=[c.get("plan") for c in data]
    for p,n in Counter(plans).items():
        if n>1:
            coll.append(p)
    if stale:
        for c in stale:
            print(f"STALE: plan {c.get('plan')} branch {c.get('branch')} since {c.get('since')}")
    if coll:
        for p in coll:
            print(f"COLLISION: plan {p}")
    if not stale and not coll:
        print("OK")
else:
    print("usage: claims.sh claim|release|list|who|--check")
    sys.exit(1)
PY
