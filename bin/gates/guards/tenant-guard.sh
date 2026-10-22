#!/usr/bin/env bash
# tenant-guard.sh — the operator's own names never enter the public tree (Rule 29, Rule 04).
#
# Ymir ships as a project; the operator's setup is not the project. Hostnames, domains,
# company names, clients, people and private paths belong to the operator and live in the
# hoard — this ward refuses NEW leakage without demanding the whole backlog be paid tonight.
#
#   tenant-guard.sh check [--update-baseline] [--list]
#
# Terms come from the operator's own list, never from the repo:
#   $YMIR_HOME/config/tenant-terms.txt      one term (or regex) per line, '#' comments
# and the repo ships only a shape: config/tenant-terms.example.txt
#
# A BASELINE (config/tenant-baseline.json) records how many hits each file already carries.
# A file may keep its backlog; a file that gains a hit — or a new file with hits — FAILS.
set -uo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec python3 - "$ROOT" "$@" <<'PY'
import json, os, re, subprocess, sys
root, *argv = sys.argv[1:]
update = "--update-baseline" in argv
listing = "--list" in argv
home = os.environ.get("YMIR_HOME", "")
cand = [os.path.join(home, "config/tenant-terms.txt")] if home else []
cand.append(os.path.join(root, "config/tenant-terms.example.txt"))
terms_file = next((p for p in cand if os.path.isfile(p)), None)
if not terms_file:
    print("tenant-guard: no terms list (neither the operator's nor the shipped example)")
    sys.exit(1)
terms = []
for line in open(terms_file, encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#"):
        terms.append(line)
if not terms:
    print("tenant-guard: SKIP — the terms list is empty"); sys.exit(0)
rx = re.compile("|".join(f"(?:{t})" for t in terms))
try:
    tracked = subprocess.run(["git", "-C", root, "ls-files"], capture_output=True, text=True, check=True).stdout.split()
except Exception:
    print("tenant-guard: not a git checkout"); sys.exit(1)
SKIP_DIRS = (".yggdrasil/", "node_modules/", "data/", "docs/fixes/")
SKIP_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".woff", ".woff2", ".ttf", ".ico", ".pdf", ".zip", ".gz")
hits = {}
for p in tracked:
    if p.startswith(SKIP_DIRS) or p.endswith(SKIP_EXT):
        continue
    try:
        txt = open(os.path.join(root, p), encoding="utf-8", errors="ignore").read()
    except Exception:
        continue
    n = len(rx.findall(txt))
    if n:
        hits[p] = n
base_path = os.path.join(root, "config/tenant-baseline.json")
baseline = {}
if os.path.isfile(base_path):
    try: baseline = json.load(open(base_path))
    except Exception: baseline = {}
if update:
    json.dump(dict(sorted(hits.items())), open(base_path, "w"), indent=1)
    print(f"tenant-guard: baseline written — {len(hits)} files, {sum(hits.values())} hits")
    sys.exit(0)
if listing:
    for p, n in sorted(hits.items(), key=lambda x: -x[1]):
        print(f"{n:5}  {p}")
    sys.exit(0)
new, grown = [], []
for p, n in hits.items():
    was = baseline.get(p, 0)
    if was == 0: new.append((p, n))
    elif n > was: grown.append((p, was, n))
if not baseline:
    print("tenant-guard: SKIP — no baseline yet; run --update-baseline once to record the backlog")
    sys.exit(0)
if new or grown:
    for p, n in new[:10]:
        print(f"tenant-guard: NEW   {p} — {n} hit(s) of the operator's own terms")
    for p, was, n in grown[:10]:
        print(f"tenant-guard: GROWN {p} — {was} → {n}")
    print("help: keep the operator's names in the hoard ($YMIR_HOME), or waive deliberately with --update-baseline")
    sys.exit(1)
print(f"tenant-guard: clean — {len(hits)} files keep their recorded backlog, none grew")
PY
