#!/usr/bin/env bash
# fleet-plans.sh — read every LIVE host's claims over the tailnet; merge; report collisions + dark hosts.
set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?}"
FLEET="$YMIR_HOME/hodd/data/fleet.json"
python3 - "$FLEET" "$ROOT" <<'PY'
import json,sys,subprocess,os,datetime
fleet=sys.argv[1]; root=sys.argv[2]
d=json.load(open(fleet))
hosts=d.get("hosts",{})
now=datetime.datetime.now(datetime.timezone.utc)
# last seen store (best effort)
lastseen_path=os.path.join(os.path.dirname(fleet),"..","state","lastseen.json") if False else None
ls_file=os.path.join(os.environ.get("YMIR_HOME",""),"state","lastseen.json")
lastseen={}
try:
    lastseen=json.load(open(ls_file))
except Exception:
    lastseen={}
allclaims=[]
dark=[]
for name,h in hosts.items():
    tailnet=h.get("tailnet") or h.get("lan")
    user=h.get("user")
    if not tailnet or not user:
        continue
    # refuse LAN: if no tailnet, skip (should not happen)
    if not tailnet.endswith(".ts.net") and not tailnet.endswith("ts.net"):
        # allow tailnet names only; a bare IP is refused
        if all(c.isdigit() or c=='.' for c in tailnet):
            dark.append((name,"no tailnet name")); continue
    addr=tailnet
    # ssh host alias via roads if possible
    cmd=["ssh","-o","ConnectTimeout=8","-o","StrictHostKeyChecking=no",f"{user}@{addr}",
         "bash -lc 'bin/seat/claims.sh list --json'"]
    try:
        out=subprocess.run(cmd,capture_output=True,text=True,timeout=15)
        if out.returncode!=0 or not out.stdout.strip():
            raise RuntimeError(out.stderr.strip() or "no answer")
        data=json.loads(out.stdout)
        for c in data:
            c["_host"]=name
            allclaims.append(c)
    except Exception as e:
        seen=lastseen.get(name,"unknown")
        dark.append((name,seen))

# print merged
print("host · seat · plan · branch · since · last push")
for c in allclaims:
    stale=""
    try:
        dt=datetime.datetime.fromisoformat(c.get("since","").replace("Z","+00:00"))
        if (now-dt).total_seconds()/3600.0>24: stale=" STALE"
    except Exception: pass
    print(f"{c.get('host','?')} · {c.get('seat','?')} · plan {c.get('plan')} · {c.get('branch')} · since {c.get('since')} · last push {c.get('last_push')}{stale}")

# collisions
from collections import defaultdict
byplan=defaultdict(list); bybranch=defaultdict(list)
for c in allclaims:
    byplan[str(c.get("plan"))].append(c)
    bybranch[c.get("branch")].append(c)
colls=[]
for p,lst in byplan.items():
    hosts=set(x.get("_host") for x in lst)
    if len(lst)>1 and (len(hosts)>1 or len(lst)>1):
        # two live claims on one plan (any two claims counts as collision)
        if len(lst)>1:
            colls.append(f"plan {p} "+ "+".join(f"{x.get('_host')}" for x in lst))
for b,lst in bybranch.items():
    hosts=set(x.get("_host") for x in lst)
    if len(hosts)>1:
        colls.append(f"branch {b} "+ "+".join(f"{x.get('_host')}" for x in lst))
print("")
print("COLLISIONS:")
if colls:
    for c in colls: print("  "+c)
else:
    print("  none")
print("")
print("DARK:")
if dark:
    for name,seen in dark: print(f"  {name} DARK (last seen {seen})")
else:
    print("  none")
PY
