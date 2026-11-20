#!/usr/bin/env bash
# nornir-job-plan-watch.sh — the clock that watches the master plan.
set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?}"
STATE_DIR="$YMIR_HOME/state"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/plan-watch.json"
LAST_FILE="$STATE_DIR/plan-watch.last"
DRY=0; INSTALL=0; INSTALL_DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --install) INSTALL=1 ;;
  esac
done
# detect --install --dry-run
if [ "$INSTALL" = 1 ]; then
  for a in "$@"; do [ "$a" = "--dry-run" ] && INSTALL_DRY=1; done
fi

if [ "$INSTALL" = 1 ]; then
  cat <<'UNIT'
[Unit]
Description=Plan watch (Nornir job)
[Service]
Type=oneshot
ExecStart=/bin/bash -lc 'cd __ROOT__ && bin/time/nornir-job-plan-watch.sh'
UNIT
  # substitute root
  sed "s#__ROOT__#$ROOT#g" >/dev/null 2>&1
  cat <<'TIMER'
[Timer]
OnCalendar=*-*-* 07:30:00
Persistent=true
Unit=nornir-job-plan-watch.service
[Install]
WantedBy=timers.target
TIMER
  if [ "$INSTALL_DRY" = 1 ]; then
    echo "(--dry-run: not installing)"
  fi
  exit 0
fi

# Gather plans from all registered ledgers
export ROOT="$ROOT"
python3 - "$YMIR_HOME" "$STATE_FILE" "$LAST_FILE" "$DRY" <<'PY'
import json,os,glob,subprocess,datetime,sys
ymir=sys.argv[1]; state_file=sys.argv[2]; last_file=sys.argv[3]; dry=int(sys.argv[4])
plans=[]
for root,_,_ in os.walk(os.path.join(ymir,"svartalfaheim")):
    if root.endswith("/plans") and "/projects/" in root:
        for f in glob.glob(os.path.join(root,"*.md")):
            if os.path.basename(f)=="README.md": continue
            plans.append(f)
# read header fields
now=datetime.datetime.now(datetime.timezone.utc)
week_ago=now-datetime.timedelta(days=7)
opened_this_week=0; closed_this_week=0
untouched_30=0
no_accept=0; no_owner=0
unknown=0
for p in plans:
    head=""
    try:
        with open(p) as fh:
            lines=fh.readlines()[:20]
        head="".join(lines)
    except Exception:
        head=""
    status=None; owner=None
    for l in lines:
        if l.strip().lower().startswith("status:"):
            status=l.split(":",1)[1].strip()
        if l.strip().lower().startswith("owner:"):
            owner=l.split(":",1)[1].strip()
    if status is None:
        status="unknown"; unknown+=1
    # git log mtime for untouched 30d
    try:
        out=subprocess.run(["git","-C",os.path.dirname(p),"log","-1","--format=%ct","--",os.path.basename(p)],
                          capture_output=True,text=True,timeout=10)
        ts=int(out.stdout.strip() or "0")
        if ts==0 or (now.timestamp()-ts)>30*86400:
            untouched_30+=1
    except Exception:
        untouched_30+=1
    # phases but no accept line
    if "phase" in head.lower() and "accept" not in head.lower():
        no_accept+=1
    if not owner:
        no_owner+=1
    # opened/closed this week: heuristic by git add? Use file mtime week
    try:
        mt=os.path.getmtime(p)
        if now.timestamp()-mt < 7*86400:
            # treat as opened if status not done/closed
            if status and status.lower() in ("done","closed","complete"):
                closed_this_week+=1
            else:
                opened_this_week+=1
    except Exception:
        pass

root=os.environ.get("ROOT","")
if not root:
    print("ROOT unset"); sys.exit(1)
# queue freshness
try:
    q=subprocess.run(["bash",os.path.join(root,"bin/gates/queue.sh"),"--check"],capture_output=True,text=True,timeout=30)
    queue_stale = q.returncode != 0
except Exception:
    queue_stale = True

queue_str = "STALE" if queue_stale else "fresh"
net = opened_this_week - closed_this_week
total = len(plans)

# fleet claims summary (best effort)
fleet_claims=0; fleet_machines=0; collisions=0
try:
    import subprocess as sp
    # run fleet-plans? just count local claims
    cdir=os.path.join(ymir,"state","claims")
    if os.path.isdir(cdir):
        fleet_claims=len([f for f in os.listdir(cdir) if f.endswith(".json")])
except Exception:
    pass

line = f"plans: {total} · +{opened_this_week} opened / -{closed_this_week} closed (net {net:+d}) · {untouched_30} untouched 30d · {no_accept} no accept line · {no_owner} no Owner · queue {queue_str}"
# fleet half
fleet_half = f"fleet: {fleet_machines} machines · {fleet_claims} claims · {collisions} collision"
full_line = line + " · " + fleet_half

# idempotency: same minute -> no second send
minute=datetime.datetime.now().strftime("%Y-%m-%dT%H:%M")
last=None
try:
    last=open(last_file).read().strip()
except Exception:
    last=None

state={"total":total,"opened_this_week":opened_this_week,"closed_this_week":closed_this_week,"net":net,
       "untouched_30d":untouched_30,"no_accept_line":no_accept,"no_owner":no_owner,
       "queue":queue_str,"line":full_line,"minute":minute,"unknown":unknown}
import json as J
with open(state_file,"w") as fh:
    J.dump(state,fh,indent=2)

if dry:
    print(full_line)
    print("dry-run: nothing sent")
    sys.exit(0)

# send only if changed minute or first run
if last==minute:
    print("plans: unchanged")
    sys.exit(0)

# claim own run
subprocess.run(["bash",os.path.join(root,"bin/seat/claims.sh"),"claim","0","plan-watch","plan-watch"],capture_output=True)

# send one line
sent=subprocess.run(["bash",os.path.join(root,"bin/agents/eindri-notify.sh"),"--from","plan-watch","--",full_line],
                    capture_output=True,text=True)
print(full_line)
if sent.returncode!=0:
    print("notify failed:",sent.stderr.strip(),file=sys.stderr)

# release
subprocess.run(["bash",os.path.join(root,"bin/seat/claims.sh"),"release","0"],capture_output=True)
# record last minute
with open(last_file,"w") as fh:
    fh.write(minute)
PY
