#!/usr/bin/env bash
# snotra-provenance.sh — a tamper-evident record of every meeting artifact.
#
#   snotra-provenance.sh seal   <meeting-dir> [--note TEXT]
#   snotra-provenance.sh verify <meeting-dir>
#   snotra-provenance.sh status <meeting-dir>
#
# A seal writes a SHA-256 manifest of every file and appends a hash-chained entry to
# provenance.jsonl. Re-sealing after a legitimate change appends a new entry; it never
# rewrites the old one. verify recomputes and refuses on any mismatch.
#
# This is the LOCAL proof. A qualified eIDAS timestamp is an external trust service:
# set TSA_URL and the printed root must be sent to it (or use a QTSP) — the script does
# not pretend a local clock is a qualified timestamp.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ACTION="${1:-status}"; DIR="${2-}"; shift 2 2>/dev/null || true
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: snotra-provenance.sh seal|verify|status <meeting-dir>" >&2; exit 2; }
NOTE=""; while [ $# -gt 0 ]; do case "$1" in --note) NOTE="${2-}"; shift 2;; *) shift;; esac; done
python3 - "$DIR" "$ACTION" "$NOTE" "$ROOT" <<'PY'
import hashlib,json,os,sys,datetime
d,action,note,root=sys.argv[1:5]
manifest=os.path.join(d,'provenance.json'); log=os.path.join(d,'provenance.jsonl')
skip={'provenance.json','provenance.jsonl','record.pdf','TEST-REPORT.md'}
def files():
    out=[]
    for base,dirs,names in os.walk(d):
        for n in sorted(names):
            p=os.path.join(base,n); rel=os.path.relpath(p,d)
            if rel in skip: continue
            h=hashlib.sha256(open(p,'rb').read()).hexdigest()
            out.append({'path':rel,'sha256':h,'bytes':os.path.getsize(p)})
    return sorted(out,key=lambda x:x['path'])
def root_of(fs):
    h=hashlib.sha256()
    for f in fs: h.update((f['path']+'\0'+f['sha256']+'\n').encode())
    return h.hexdigest()
def now(): return datetime.datetime.now().astimezone().isoformat(timespec='seconds')
fs=files(); r=root_of(fs)
if action=='verify':
    if not os.path.isfile(manifest): print('FAIL no provenance.json'); sys.exit(1)
    m=json.load(open(manifest)); bad=[]
    for f in m['files']:
        p=os.path.join(d,f['path'])
        if not os.path.isfile(p) or hashlib.sha256(open(p,'rb').read()).hexdigest()!=f['sha256']: bad.append(f['path'])
    if root_of(fs)!=m['root']: bad.append('manifest root changed (files added/removed)')
    if bad: print('FAIL', ', '.join(bad[:10])); sys.exit(1)
    print(f"OK\t{m['root']}\t{len(fs)} files\t{m['sealed_at']}")
    sys.exit(0)
if action=='status':
    if not os.path.isfile(log): print('no seal'); sys.exit(0)
    e=[json.loads(l) for l in open(log) if l.strip()][-1]
    print(json.dumps(e,indent=2)); sys.exit(0)
if action!='seal': print('usage'); sys.exit(2)
prev=''
if os.path.isfile(log):
    rows=[json.loads(l) for l in open(log) if l.strip()]
    if rows: prev=rows[-1]['entry']
entry={'seq': 1 if not os.path.isfile(log) else len(open(log).read().splitlines())+1,
       'at': now(), 'action':'seal', 'actor': os.environ.get('USER','unknown'),
       'note': note or '', 'root': r, 'files': len(fs), 'prev': prev}
canon=json.dumps(entry,sort_keys=True,separators=(',',':')).encode()
entry['entry']=hashlib.sha256(canon).hexdigest()
m={'meeting': os.path.basename(d.rstrip('/')), 'sealed_at': entry['at'], 'root': r,
   'files': fs, 'previous': prev, 'entry': entry['entry']}
with open(manifest,'w') as f: json.dump(m,f,indent=2)
os.chmod(manifest,0o600)
with open(log,'a') as f: f.write(json.dumps(entry,sort_keys=True)+'\n')
os.chmod(log,0o600)
print(f"sealed\t{r}\t{len(fs)} files\tentry {entry['entry'][:16]}")
PY
