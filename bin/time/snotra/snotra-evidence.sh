#!/usr/bin/env bash
# snotra-evidence.sh — timestamp, immutable copy, certification and retention.
#
#   snotra-evidence.sh timestamp <dir> [--tsa URL]
#   snotra-evidence.sh worm      <dir>
#   snotra-evidence.sh certify   <dir> --reviewer NAME [--note TEXT]
#   snotra-evidence.sh retention <dir> --days N
#   snotra-evidence.sh enforce   <dir> [--dry-run]
#   snotra-evidence.sh status    <dir>
#
# Local controls are labelled as such. A qualified eIDAS timestamp requires a QTSP/RFC
# 3161 authority; without one the token is stored as local-unqualified.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR="${YMIR_HOME:-}"; [ -n "$HOME_DIR" ] || ymir_home_root HOME_DIR 2>/dev/null || true
[ -n "$HOME_DIR" ] || { echo "error: no Ymir home" >&2; exit 1; }
ACTION="${1:-status}"; DIR="${2-}"; shift 2 2>/dev/null || true
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: snotra-evidence.sh timestamp|worm|certify|retention|enforce|status <dir>" >&2; exit 2; }
TSA=""; REVIEWER=""; NOTE=""; DAYS=""; DRY=0; KEY="${HOME}/.ssh/id_ed25519"
while [ $# -gt 0 ]; do case "$1" in --tsa) TSA="${2-}"; shift 2;; --reviewer) REVIEWER="${2-}"; shift 2;; --note) NOTE="${2-}"; shift 2;; --days) DAYS="${2-}"; shift 2;; --key) KEY="${2-}"; shift 2;; --dry-run) DRY=1; shift;; *) shift;; esac; done
PROV="$DIR/provenance.json"; [ -f "$PROV" ] || { echo "error: seal the record first (snotra-provenance.sh seal)" >&2; exit 1; }
ROOT_HASH="$(python3 -c "import json,sys;print(json.load(open('$PROV'))['root'])")"

timestamp() {
  local out="$DIR/timestamp"; mkdir -p "$out"
  if [ -n "$TSA" ]; then
    openssl ts -query -data "$PROV" -sha256 -cert -out "$out/request.tsq" >/dev/null 2>&1 || { echo "error: openssl ts query failed" >&2; exit 1; }
    curl -sS -m 30 -H 'Content-Type: application/timestamp-query' --data-binary "@$out/request.tsq" "$TSA" -o "$out/response.tsr" || { echo "error: TSA request failed" >&2; exit 1; }
    openssl ts -reply -in "$out/response.tsr" -text > "$out/response.txt" 2>/dev/null || true
    python3 - "$out" "$ROOT_HASH" "$TSA" <<'PY'
import json,sys,os,datetime
out,root,tsa=sys.argv[1:]
json.dump({'type':'rfc3161','root':root,'tsa':tsa,'at':datetime.datetime.now().astimezone().isoformat(timespec='seconds'),'request':'request.tsq','response':'response.tsr'},open(os.path.join(out,'timestamp.json'),'w'),indent=2)
PY
    echo "timestamp	rfc3161	$ROOT_HASH"
  else
    python3 - "$out" "$ROOT_HASH" <<'PY'
import json,sys,os,datetime
out,root=sys.argv[1:]
json.dump({'type':'local-unqualified','root':root,'at':datetime.datetime.now().astimezone().isoformat(timespec='seconds'),'note':'Not an eIDAS qualified timestamp; use --tsa with a QTSP for legal weight.'},open(os.path.join(out,'timestamp.json'),'w'),indent=2)
PY
    echo "timestamp	local-unqualified	$ROOT_HASH"
  fi
  chmod 600 "$out"/* 2>/dev/null || true
}

worm() {
  local dest="$HOME_DIR/hodd/evidence/$(basename "$DIR")-$ROOT_HASH"
  mkdir -p "$dest"
  cp -a "$DIR/." "$dest/"
  chmod -R a-w "$dest"
  python3 - "$DIR" "$dest" "$ROOT_HASH" <<'PY'
import json,sys,datetime,os
src,dest,root=sys.argv[1:]
json.dump({'root':root,'copy':os.path.basename(dest),'at':datetime.datetime.now().astimezone().isoformat(timespec='seconds'),'type':'local-immutable-copy','note':'Local read-only copy; object-lock/WORM storage is an external facility.'},open(os.path.join(src,'worm.json'),'w'),indent=2)
PY
  echo "worm	local-immutable-copy	$dest"
}

certify() {
  [ -n "$REVIEWER" ] || { echo "error: --reviewer is required" >&2; exit 1; }
  local at; at="$(date --iso-8601=seconds)"
  cat > "$DIR/certified-copy.md" <<MD
# Certified copy — $(basename "$DIR")

**Reviewer:** $REVIEWER  
**Reviewed at:** $at  
**Provenance root:** \`$ROOT_HASH\`  
**Scope:** the reviewer compared the transcript against the audio and checked every decision and action against the record.

**Statement:** I certify that this copy accurately reflects the transcript and the record, subject to the corrections below. The machine transcript remains the evidence; this copy is the human reading of it.

**Corrections:** ${NOTE:-none}
MD
  printf '{"at":"%s","reviewer":"%s","root":"%s","note":"%s"}\n' "$at" "$REVIEWER" "$ROOT_HASH" "${NOTE//\"/\'}" >> "$DIR/certification.jsonl"
  chmod 600 "$DIR/certified-copy.md" "$DIR/certification.jsonl"
  cat > "$DIR/verification-note.md" <<MD
# How to verify this record

1. Recompute the SHA-256 of each file listed in \`provenance.json\`.
2. Confirm the manifest root is \`$ROOT_HASH\`.
3. Check the timestamp token in \`timestamp/\` against the same root.
4. Compare the certified copy with the transcript and the correction log.
5. Do not rely on a local clock alone; a qualified timestamp is the external proof.
MD
  chmod 600 "$DIR/verification-note.md"
  echo "certified	$REVIEWER	$ROOT_HASH"
}

retention() {
  [ -n "$DAYS" ] || { echo "error: --days is required" >&2; exit 1; }
  cat > "$DIR/retention.yaml" <<YML
version: 1
days: $DAYS
legal_hold: false
YML
  echo "retention	$DAYS days"
}

enforce() {
  [ -f "$DIR/retention.yaml" ] || { echo "error: no retention.yaml" >&2; exit 1; }
  local days hold
  days="$(sed -n 's/^days: *//p' "$DIR/retention.yaml")"; hold="$(sed -n 's/^legal_hold: *//p' "$DIR/retention.yaml")"
  [ "$hold" = "true" ] && { echo "held	legal hold is active"; exit 0; }
  local age=$(( ( $(date +%s) - $(stat -c %Y "$DIR") ) / 86400 ))
  if [ "$age" -gt "$days" ]; then
    if [ "$DRY" = 1 ]; then echo "would-retire	$age days"; else
      local ref="$HOME_DIR/hodd/reference/retired-$(basename "$DIR")"; mkdir -p "$ref"; mv "$DIR" "$ref"; echo "retired	$ref"
    fi
  else echo "retained	$age of $days days"; fi
}

worm_s3() {
  python3 - "$DIR" "$ROOT_HASH" "$DRY" <<'PY'
import boto3,hashlib,json,os,sys,datetime
d,root,dry=sys.argv[1],sys.argv[2],int(sys.argv[3])
endpoint=os.environ.get('SNOTRA_WORM_ENDPOINT'); bucket=os.environ.get('SNOTRA_WORM_BUCKET')
mode=os.environ.get('SNOTRA_WORM_MODE','COMPLIANCE'); days=int(os.environ.get('SNOTRA_WORM_RETENTION_DAYS','3650'))
ak=os.environ.get('SNOTRA_WORM_ACCESS_KEY'); sk=os.environ.get('SNOTRA_WORM_SECRET_KEY')
if not endpoint or not bucket: raise SystemExit('error: set SNOTRA_WORM_ENDPOINT and SNOTRA_WORM_BUCKET')
prefix=f"meetings/{os.path.basename(d.rstrip('/'))}-{root[:12]}"
files=[]
for base,dirs,names in os.walk(d):
    for n in sorted(names):
        p=os.path.join(base,n); rel=os.path.relpath(p,d)
        if rel.startswith('access.jsonl') or rel.startswith('worm.json'): continue
        files.append((p,rel))
if dry:
    print(f"dry-run\t{endpoint}\t{bucket}\t{prefix}\t{len(files)} files\t{mode} {days}d"); raise SystemExit(0)
s3=boto3.client('s3',endpoint_url=endpoint,aws_access_key_id=ak,aws_secret_access_key=sk)
until=datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=days)
for p,rel in files:
    body=open(p,'rb').read(); sha=hashlib.sha256(body).hexdigest(); key=f"{prefix}/{rel}"
    s3.put_object(Bucket=bucket,Key=key,Body=body,ChecksumAlgorithm='SHA256',
                  ObjectLockMode=mode,ObjectLockRetainUntilDate=until,
                  Metadata={'root':root,'sha256':sha,'meeting':os.path.basename(d)})
    print('put',key)
json.dump({'endpoint':endpoint,'bucket':bucket,'prefix':prefix,'root':root,'mode':mode,'until':until.isoformat(),'files':len(files)},open(os.path.join(d,'worm-s3.json'),'w'),indent=2)
print('worm-s3',prefix,len(files),'files')
PY
}

verify_ts() {
  local ts="$DIR/timestamp/response.tsr" ca="${SNOTRA_TSA_CA:-$DIR/timestamp/ca.pem}"
  if [ ! -f "$ts" ]; then echo "no timestamp token"; return 1; fi
  if [ ! -f "$ca" ]; then echo "no CA bundle ($ca); set SNOTRA_TSA_CA"; return 1; fi
  openssl ts -verify -in "$ts" -data "$PROV" -CAfile "$ca" >/dev/null 2>&1 && { echo "timestamp	valid	$ROOT_HASH"; return 0; } || { echo "timestamp	INVALID"; return 1; }
}

sign() {
  [ -f "$DIR/certified-copy.md" ] || { echo "error: certify first" >&2; exit 1; }
  [ -f "$KEY" ] || { echo "error: key not found: $KEY" >&2; exit 1; }
  ssh-keygen -Y sign -f "$KEY" -n snotra-evidence "$DIR/certified-copy.md" >/dev/null 2>&1 || { echo "error: signing failed" >&2; exit 1; }
  cp "${KEY}.pub" "$DIR/signer.pub"
  { printf 'operator '; cat "${KEY}.pub"; } > "$DIR/allowed_signers"
  ssh-keygen -lf "$DIR/signer.pub" | awk '{print $2}' > "$DIR/signer.fingerprint"
  chmod 600 "$DIR/certified-copy.md.sig" "$DIR/allowed_signers" "$DIR/signer.fingerprint" 2>/dev/null || true
  echo "signed	$(cat "$DIR/signer.fingerprint")"
}

verify_sign() {
  [ -f "$DIR/certified-copy.md.sig" ] || { echo "no signature"; exit 1; }
  [ -f "$DIR/allowed_signers" ] || { echo "no allowed_signers"; exit 1; }
  ssh-keygen -Y verify -f "$DIR/allowed_signers" -I operator -n snotra-evidence -s "$DIR/certified-copy.md.sig" < "$DIR/certified-copy.md" >/dev/null 2>&1 && echo "signature	valid" || { echo "signature	INVALID"; exit 1; }
}

bundle() {
  local out="$DIR/evidence-bundle.tar.gz"
  local files="provenance.json provenance.jsonl timestamp certified-copy.md certification.jsonl verification-note.md signer.pub allowed_signers certified-copy.md.sig signer.fingerprint"
  local present=""; for f in $files; do [ -e "$DIR/$f" ] && present="$present $f"; done
  tar -czf "$out" -C "$DIR" $present 2>/dev/null || { echo "error: bundle failed" >&2; exit 1; }
  sha256sum "$out" | awk '{print $1}' > "$out.sha256"
  chmod 600 "$out" "$out.sha256"
  echo "bundle	$out	$(cat "$out.sha256")"
}

verify_access() {
  python3 - "$DIR/access.jsonl" <<'PY'
import json,sys,os,hashlib
p=sys.argv[1]
if not os.path.isfile(p): print('no access log'); raise SystemExit(1)
rows=[json.loads(l) for l in open(p) if l.strip()]
prev=''; checked=0; legacy=0
for r in rows:
    if not r.get('entry'):
        legacy+=1; continue
    claimed=r.pop('entry')
    ok=(r.get('prev')==prev)
    calc=hashlib.sha256(json.dumps(r,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    if not ok or calc!=claimed:
        print('access log INVALID at',r.get('at')); raise SystemExit(1)
    prev=claimed; checked+=1
print(f'access log valid\t{checked} chained\t{legacy} legacy')
PY
}

status(){ python3 - "$DIR" <<'PY'
import json,sys,os
d=sys.argv[1]
for f in ('provenance.json','timestamp/timestamp.json','worm.json','certification.jsonl','retention.yaml','access.jsonl'):
 p=os.path.join(d,f); print(f, 'present' if os.path.isfile(p) else 'missing')
PY
}
case "$ACTION" in timestamp) timestamp;; worm) worm;; worm-s3) worm_s3;; certify) certify;; retention) retention;; enforce) enforce;; verify-ts) verify_ts;; verify-access) verify_access;; sign) sign;; verify-sign) verify_sign;; bundle) bundle;; status) status;; *) echo "usage" >&2; exit 2;; esac
