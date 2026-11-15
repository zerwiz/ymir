#!/usr/bin/env bash
# behind.sh — the arithmetic of being behind: opened/closed this week, net, stale-30d, unbuilt phases.
set -uo pipefail
_root() { local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ "$d" != "/" ]; do [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }; d="$(dirname "$d")"; done; printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; }
ROOT="$(_root)"
PLAN_DIR="${YMIR_PLAN_DIR:-}"
if [ -z "$PLAN_DIR" ]; then
  # The home is RESOLVED through the one resolver (Rule 07), never read straight from the
  # environment: `hodd.sh path` answers, and a seat that cannot answer is told so rather than
  # computing a plan ledger at `/svartalfaheim/...` (a path on the root of the filesystem).
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  _h="${YMIR_HOME:-}"
  [ -z "$_h" ] && command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _h 2>/dev/null || true
  [ -n "$_h" ] || { printf 'behind: the home is unresolved — set YMIR_HOME, or run from a checkout\n' >&2; exit 2; }
  # The ledger's realm is the OPERATOR's, so it is discovered inside his home — the
  # repository never spells `svartalfaheim/<realm>/…` with our realm in it (RULES/04).
  ymir_plan_dir PLAN_DIR 2>/dev/null || true
  [ -n "$PLAN_DIR" ] || { printf 'behind: no plan ledger under %s — set YMIR_PLAN_DIR, or keep one ledger per home\n' "$_h" >&2; exit 2; }
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
