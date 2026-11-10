#!/usr/bin/env bash
# claims.sh — a seat declares what it is building (plan number, branch, errand id, host).
# Verbs: claim <plan> <branch> [errand] · release <plan> · list [--json] · who <plan>
set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?}"
CLAIMS_DIR="$YMIR_HOME/state/claims"
mkdir -p "$CLAIMS_DIR"

HOST="$(hostname -s 2>/dev/null || hostname)"
SEAT="${YMIR_SEAT:-${USER:-unknown}}"
FILE="$CLAIMS_DIR/${HOST}-${SEAT}.json"
STALE_HOURS=24

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
epoch() { date -u -d "${1:-}" +%s 2>/dev/null || date -u +%s; }

cmd="${1:-}"; shift || true
case "$cmd" in
  claim)
    plan="${1:?plan required}"; branch="${2:?branch required}"; errand="${3:-}"
    cat > "$FILE" <<JSON
{"host":"$HOST","seat":"$SEAT","plan":"$plan","branch":"$branch","errand":"$errand","since":"$(now_iso)","last_push":"$(now_iso)"}
JSON
    echo "claimed: $plan ($branch) by $HOST/$SEAT"
    ;;
  release)
    plan="${1:-}"
    if [ -n "$plan" ] && [ -f "$FILE" ]; then
      cur=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("plan",""))' "$FILE" 2>/dev/null)
      [ "$cur" = "$plan" ] || { echo "release: held plan is $cur, not $plan" >&2; exit 1; }
    fi
    rm -f "$FILE"
    echo "released: ${plan:-current}"
    ;;
  list)
    json=0; [ "${1:-}" = "--json" ] && json=1
    python3 - "$CLAIMS_DIR" "$STALE_HOURS" "$json" <<'PY'
import json,sys,os,glob,datetime
d=sys.argv[1]; hours=int(sys.argv[2]); asjson=int(sys.argv[3])
now=datetime.datetime.now(datetime.timezone.utc)
rows=[]
for f in sorted(glob.glob(os.path.join(d,"*.json"))):
    try: c=json.load(open(f))
    except Exception: continue
    since=c.get("since","")
    try:
        dt=datetime.datetime.fromisoformat(since.replace("Z","+00:00"))
        age=(now-dt).total_seconds()/3600.0
    except Exception:
        age=9999
    stale = age > hours
    rows.append((c,stale,age))
if asjson:
    print(json.dumps([{"file":os.path.basename(f),"stale":s,"age_hours":round(a,1),**c} for (c,s,a),f in [(r[0],r[1],r[2],f) for r in rows] for f in [os.path.join(d,r[0].get('host','')+'-'+r[0].get('seat','')+'.json')]] , indent=2))
else:
    for c,stale,age in rows:
        flag=" STALE" if stale else ""
        print(f"{c.get('host')} · {c.get('seat')} · plan {c.get('plan')} · {c.get('branch')} · since {c.get('since')} · last push {c.get('last_push')}{flag}")
PY
    ;;
  who)
    plan="${1:?plan required}"
    python3 - "$CLAIMS_DIR" "$plan" "$STALE_HOURS" <<'PY'
import json,sys,os,glob,datetime
d=sys.argv[1]; plan=sys.argv[2]; hours=int(sys.argv[3])
now=datetime.datetime.now(datetime.timezone.utc)
holders=[]
for f in glob.glob(os.path.join(d,"*.json")):
    try: c=json.load(open(f))
    except Exception: continue
    if str(c.get("plan"))!=str(plan): continue
    since=c.get("since","")
    try:
        dt=datetime.datetime.fromisoformat(since.replace("Z","+00:00"))
        age=(now-dt).total_seconds()/3600.0
    except Exception: age=9999
    stale = age>hours
    holders.append((c,stale))
if not holders:
    print(f"plan {plan}: unclaimed")
    sys.exit(0)
for c,stale in holders:
    tag=" STALE" if stale else ""
    print(f"REFUSAL: plan {plan} already claimed by {c.get('host')}/{c.get('seat')} on {c.get('branch')} since {c.get('since')}{tag}")
sys.exit(1)
PY
    ;;
  *)
    echo "usage: claims.sh claim|release|list [--json]|who <plan>" >&2; exit 2 ;;
esac
