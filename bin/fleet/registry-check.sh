#!/usr/bin/env bash
# registry-check.sh — is the fleet's registry coherent with itself, with the machine folders, and with reality?
#
# Four sources must agree, and each is the authority for something different:
#   hodd/data/fleet.json            the topology: which machines exist, their roles and addresses
#   hodd/identity/machines.yaml     per-machine config (telegram, folder)
#   hodd/identity/services.yaml     what is hosted, where, and why
#   hodd/machines/<name>/           each machine's own folder and card
#
#   registry-check.sh           human report; exit 1 on any incoherence
#   registry-check.sh --quiet   one line
set -uo pipefail
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"
fails=0
note() { printf '  %s\n' "$1"; fails=$((fails+1)); }
quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1

out=$(python3 - "$HOME_DIR" <<'PY'
import json,sys,os,yaml
h=sys.argv[1]
fleet=json.load(open(os.path.join(h,'hodd/data/fleet.json')))
mach=yaml.safe_load(open(os.path.join(h,'hodd/identity/machines.yaml')))['machines']
svc=yaml.safe_load(open(os.path.join(h,'hodd/identity/services.yaml')))
problems=[]
hosts=set(fleet.get('hosts',{}))
if set(fleet.get('hosts',{}))!=set(mach):
    problems.append(('machines differ', f'fleet.json {sorted(hosts)} vs machines.yaml {sorted(mach)}'))
for name,row in fleet.get('hosts',{}).items():
    folder=row.get('folder') or mach.get(name,{}).get('folder')
    if not folder: problems.append((name,'no folder named'))
    elif not os.path.isdir(os.path.join(h,folder)): problems.append((name,f'folder missing: {folder}'))
    elif not os.path.isfile(os.path.join(h,folder,'README.md')): problems.append((name,f'no card: {folder}/README.md'))
    if not row.get('roles'): problems.append((name,'no roles'))
    if row.get('state')=='up' and not row.get('tailnet') and name!='localhost': problems.append((name,'state up but no tailnet name'))
for s in svc.get('services',[]):
    host=s.get('host')
    if host and host not in hosts: problems.append((s['id'], f'hosted on unknown machine: {host}'))
for r in svc.get('hosts_registry',[]):
    if r['id'] not in hosts: problems.append((r['id'],'in hosts_registry but not in fleet.json'))
    f=r.get('folder')
    if f and not os.path.isdir(os.path.join(h,f)): problems.append((r['id'],f'folder missing: {f}'))
for name,row in fleet.get('hosts',{}).items():
    if row.get('state')=='up' and not row.get('services') and name=='zerwizserver':
        problems.append((name,'heart with no services listed'))
print(json.dumps(problems))
PY
)
count=$(printf '%s' "$out" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')
if [ "$count" -eq 0 ]; then
  [ "$quiet" -eq 1 ] && echo "registry-check: coherent (fleet · machines · services · folders)" || {
    printf 'FLEET REGISTRY — coherent\n\n  fleet.json · machines.yaml · services.yaml · hodd/machines/*/ all agree\n'; }
  exit 0
fi
if [ "$quiet" -eq 1 ]; then printf 'registry-check: %s incoherence(s)\n' "$count"; exit 1; fi
printf 'FLEET REGISTRY — %s incoherence(s)\n\n' "$count"
printf '%s' "$out" | python3 -c '
import json,sys
for name,why in json.load(sys.stdin): print(f"  {name}: {why}")'
exit 1
