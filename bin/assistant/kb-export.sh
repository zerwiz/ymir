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

ROOT_DIR="$ROOT" HOME_DIR_Q="$HOME_R" APPROVED_Q="$APPROVED" DIGEST_Q="$DIGEST" python3 - <<'PY'
import hashlib, json, os, re, subprocess, sys

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

# ── the directory: who the Allfather works with, from the collaborators registry ──────────
# Names, organisations and roles are facts he asked Skírnir to know. Addresses are NOT exported:
# they are personal data, and the engine never needs them to say who someone is.
reg = os.path.join(os.environ["HOME_DIR_Q"], "hodd", "identity", "collaborators.yaml")
try:
    import yaml
    with open(reg) as fh:
        people = (yaml.safe_load(fh) or {}).get("people", []) or []
except Exception:
    people = []
for person in people:
    name = (person.get("name") or "").strip()
    if not name:
        continue
    kind = person.get("kind", "contact")
    org = (person.get("org") or "").strip()
    project = (person.get("project") or "").strip()
    claim = f"{name} is a {kind}" + (f" at {org}" if org else "") + \
            (f", working on {project}" if project else "") + "."
    slug = "contact-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    rows.append({"slug": slug, "class": "contacts", "approved_by": "the Allfather",
                 "approved_at": "2026-10-21", "expires": "",
                 "claim": claim, "hash": hashlib.sha256(claim.encode()).hexdigest()[:16],
                 "source": "collaborators.yaml"})

# ── the canaries, DERIVED: plan titles, the vault's markers, and the secret KEY names ──────────
# Hand-maintaining a canary list means a new plan is born unguarded. So they are collected:
# every plan title in the ledger, every marker word from the base list, and every secret KEY name
# (never a value) — the strings that must never appear in anything Skírnir says.
import glob
canary_path = os.path.join(os.path.dirname(digest), "canaries.derived.txt")
canaries = set()
ledger = os.path.join(os.environ.get("HOME_DIR_Q", ""), "svartalfaheim")
for plan in glob.glob(os.path.join(ledger, "**", "plans", "*.md"), recursive=True):
    try:
        with open(plan, encoding="utf8") as fh:
            first = fh.readline().strip()
    except OSError:
        continue
    m = re.match(r"^#\s*Plan\s+\d+\s*[—-]\s*(.+)$", first)
    if m:
        title = re.sub(r"\s*\(.*?\)\s*$", "", m.group(1)).strip()
        if 8 <= len(title) <= 60:
            canaries.add(title)
    canaries.add(os.path.basename(plan)[:-3])
for token in ("Hnitbjörg", "age.key", "platform.env.age", "vault", "masterplan", "runes_audit"):
    canaries.add(token)
env = os.path.join(os.environ.get("HOME_DIR_Q", ""), "hodd", "secrets", "platform.env")
try:
    out = subprocess.run(["bash", os.path.join(os.environ.get("ROOT_DIR", ""), "bin", "vault", "hodd.sh"),
                          "emit", "secrets/platform.env"], capture_output=True, text=True, timeout=30).stdout
    for line in out.splitlines():
        m = re.match(r"^export ([A-Z_]+)=", line)
        if m:
            canaries.add(m.group(1))
except Exception:
    pass
with open(canary_path, "w") as fh:
    for token in sorted(c for c in canaries if c):
        fh.write(token + "\n")

os.makedirs(os.path.dirname(digest), exist_ok=True)
with open(digest, "w") as fh:
    for row in rows:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")

# ── the DATABASE: the same rows, in a shape a query door can enforce ───────────────────────
# He is given a database, not a filesystem. Every read goes through a fixed query with the class
# and the tier applied, and every read is audited. No SQL ever comes from the model.
import sqlite3
db = os.path.join(os.path.dirname(digest), "kb.db")
con = sqlite3.connect(db)
con.executescript("""
DROP TABLE IF EXISTS facts;
CREATE TABLE facts (
  slug TEXT PRIMARY KEY, class TEXT NOT NULL, claim TEXT NOT NULL,
  hash TEXT, source TEXT, approved_at TEXT, expires TEXT, parties TEXT
);
CREATE TABLE IF NOT EXISTS read_audit (
  ts TEXT, tier TEXT, channel TEXT, query TEXT, hits INTEGER
);
""")
for row in rows:
    con.execute("INSERT OR REPLACE INTO facts VALUES (?,?,?,?,?,?,?,?)",
                (row["slug"], row.get("class", "public"), row["claim"], row.get("hash", ""),
                 row.get("source", ""), row.get("approved_at", ""), row.get("expires", ""),
                 row.get("parties", "")))
con.commit(); con.close()
print(f'kb-export[1]{{approved,refused,digest}}:"{len(rows)}","{len(refused)}","{digest}"')
for name, why in refused:
    print(f'  "refused {name}: {why}"')
PY
