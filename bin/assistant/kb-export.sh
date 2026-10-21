#!/usr/bin/env bash
# kb-export.sh — build Skírnir's digest from facts the Allfather APPROVED, and nothing else.
#
# The digest is not a filtered copy of the house; it is a set of separately approved facts, one
# file each, in $YMIR_HOME/hodd/state/assistant/approved/. A fact without an approval header is
# refused. The vault is never read, never mounted, never indexed.
#
#   bin/assistant/kb-export.sh           # rebuild digest.jsonl
#   bin/assistant/kb-export.sh --list    # what is approved right now
#
# Exit: 0 ok · 1 a file is unapprovable · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }
APPROVED="$HOME_R/hodd/state/assistant/approved"
DIGEST="$HOME_R/hodd/state/assistant/digest.jsonl"

[ "${1:-}" = "--list" ] && { ls -1 "$APPROVED"/*.md 2>/dev/null | sed 's|.*/||;s|\.md$||'; exit 0; }

ROOT_DIR="$ROOT" APPROVED_Q="$APPROVED" DIGEST_Q="$DIGEST" python3 - <<'PY'
import hashlib, json, os, re, sys

approved = os.environ["APPROVED_Q"]
digest = os.environ["DIGEST_Q"]
rows, refused = [], []
for name in sorted(os.listdir(approved) if os.path.isdir(approved) else []):
    if not name.endswith(".md"):
        continue
    path = os.path.join(approved, name)
    text = open(path, encoding="utf8").read()
    if not text.startswith("---"):
        refused.append((name, "no approval header"))
        continue
    try:
        _, header, body = text.split("---", 2)
    except ValueError:
        refused.append((name, "malformed header"))
        continue
    meta = {}
    for line in header.strip().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    if meta.get("approved_by", "").lower() not in ("the allfather", "allfather"):
        refused.append((name, "not approved by the Allfather"))
        continue
    if "expires" in meta and meta["expires"] < "2026-10-21":
        refused.append((name, "expired"))
        continue
    claim = re.sub(r"\s+", " ", body).strip()
    rows.append({"slug": name[:-3], "class": meta.get("class", "public"),
                 "approved_by": meta.get("approved_by"), "approved_at": meta.get("approved_at", ""),
                 "expires": meta.get("expires", ""), "claim": claim,
                 "hash": hashlib.sha256(claim.encode()).hexdigest()[:16],
                 "source": os.path.basename(path)})

os.makedirs(os.path.dirname(digest), exist_ok=True)
with open(digest, "w") as fh:
    for row in rows:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
print(f'kb-export[1]{{approved,refused,digest}}:"{len(rows)}","{len(refused)}","{digest}"')
for name, why in refused:
    print(f'  "refused {name}: {why}"')
PY
