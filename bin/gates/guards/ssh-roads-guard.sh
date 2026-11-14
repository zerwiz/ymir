#!/usr/bin/env bash
set -u
FILE="${1:-${SSH_CONFIG:-$HOME/.ssh/config}}"
if [ ! -e "$FILE" ]; then
  echo "PASS: no ssh config ($FILE)"; exit 0
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# The home is RESOLVED, never guessed (Rule 07) — the same door every other ward uses.
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
if [ -z "${YMIR_HOME:-}" ]; then
  echo "SKIP: the home is unresolved — set YMIR_HOME, or run from a checkout"; exit 0
fi
# The registry is the HOME's, and $YMIR_FLEET_REGISTRY may name another one (the same override
# bin/skuld/role.sh and the public ward honour) so a test can judge a fleet of its own.
REG="${YMIR_FLEET_REGISTRY:-$YMIR_HOME/hodd/data/fleet.json}"
python3 - "$FILE" "$REG" <<'PY'
import json,sys,re
f=sys.argv[1]; reg=sys.argv[2]
try:
    d=json.load(open(reg))
except Exception as e:
    print(f"{f}: cannot read registry: {e}"); sys.exit(1)
hosts=set(d.get("hosts",{}).keys())
lan_re=re.compile(r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)')
lines=open(f).read().splitlines()
# only the marked block is governed
start=None; end=None
for i,l in enumerate(lines):
    if "fleet-roads BEGIN" in l: start=i
    if "fleet-roads END" in l: end=i
if start is None or end is None or end<=start:
    print(f"PASS: no fleet-roads block in {f}")
    sys.exit(0)
block=lines[start+1:end]
rc=0
cur=[]
for idx,line in enumerate(block, start+2):
    s=line.strip()
    if s.lower().startswith("host "):
        cur=s.split()[1:]
        for h in cur:
            if h not in hosts:
                print(f"{f}:{idx}: host '{h}' not in fleet registry"); rc=1
    m=re.match(r'(?i)hostname\s+(.+)', s)
    if m:
        val=m.group(1).strip()
        if lan_re.match(val):
            print(f"{f}:{idx}: HostName dials private LAN address {val}"); rc=1
sys.exit(rc)
PY
