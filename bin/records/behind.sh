#!/usr/bin/env bash
# behind.sh — the arithmetic of being behind: opened/closed this week, net, stale-30d, unbuilt phases.
set -uo pipefail
_root() { local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ "$d" != "/" ]; do [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }; d="$(dirname "$d")"; done; printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; }
ROOT="$(_root)"
PLAN_DIR="${YMIR_PLAN_DIR:-}"
if [ -z "$PLAN_DIR" ]; then
  _h="${YMIR_HOME:-}"; [ -z "$_h" ] && _h="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
  PLAN_DIR="$_h/svartalfaheim/whynotproductions/projects/ymir/plans"
fi
python3 - "$PLAN_DIR" <<'PY'
import os,sys,time,datetime,glob
d=sys.argv[1]
now=time.time(); week=7*86400; month=30*86400
opened=closed=stale=unbuilt=0
for f in glob.glob(os.path.join(d,'*.md')):
    if os.path.basename(f)=='README.md': continue
    mtime=os.path.getmtime(f)
    txt=open(f,errors='replace').read()
    # opened this week: "Opened YYYY-MM-DD" or "**Opened ...**"
    import re
    for m in re.finditer(r'Opened\s+(\d{4}-\d{2}-\d{2})', txt):
        try:
            dt=datetime.datetime.strptime(m.group(1),'%Y-%m-%d').timestamp()
            if now-dt <= week: opened+=1
        except: pass
    st=''
    for line in txt.splitlines()[:25]:
        if line.lower().startswith('status:'): st=line.split(':',1)[1].strip()
    if st=='done' and now-mtime<=week: closed+=1
    if now-mtime > month: stale+=1
    # phases with no accept line
    if 'accept' not in txt.lower(): unbuilt+=1
print(f"behind: opened_this_week={opened} closed_this_week={closed} net={opened-closed} untouched_30d={stale} phases_no_accept={unbuilt}")
PY
