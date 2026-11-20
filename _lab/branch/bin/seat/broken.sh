#!/usr/bin/env bash
# broken.sh — the register of broken things (RULES/50).
#
#   bin/seat/broken.sh add --function F --shows "cmd" --state open --closes "the proof"
#   bin/seat/broken.sh list [--open] [--json]
#   bin/seat/broken.sh close <id> --sha <sha>
#   bin/seat/broken.sh count --class
#
# Data: $YMIR_HOME/hodd/state/broken.md — APPEND-ONLY, one line per finding.
# A close appends a CLOSING LINE; it never edits the original (RULES/06).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_DIR 2>/dev/null || { printf "%s: home unresolved\n" "$(basename "$0")" >&2; exit 2; }
FILE="$HOME_DIR/hodd/state/broken.md"
mkdir -p "$(dirname "$FILE")"
touch "$FILE"

CMD="${1-}"; shift || true

python3 - "$FILE" "$CMD" "$@" <<'PY'
import json, os, sys, datetime

file_path = sys.argv[1]
cmd = sys.argv[2]
args = sys.argv[3:]

def now():
    return datetime.date.today().isoformat()

def read_lines():
    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        return [ln.rstrip("\n") for ln in f]

def append(line):
    with open(file_path, "a", encoding="utf-8") as f:
        f.write(line + "\n")

# parse args into dict
def parse(argv):
    d = {}
    i = 0
    pos = []
    while i < len(argv):
        a = argv[i]
        if a.startswith("--"):
            key = a[2:]
            if i + 1 < len(argv) and not argv[i+1].startswith("--"):
                d[key] = argv[i+1]; i += 2; continue
            d[key] = True; i += 1; continue
        pos.append(a); i += 1
    d["_pos"] = pos
    return d

# aggregate state per finding id
def aggregate(lines):
    findings = {}   # id -> dict
    order = []
    closes = {}     # id -> list of (date, sha)
    for ln in lines:
        if not ln.strip():
            continue
        parts = ln.split("|")
        if parts and parts[0] == "F":
            # F|id|date|function|shows|state|closes
            if len(parts) < 7:
                continue
            fid = parts[1]
            rec = {"id": fid, "date": parts[2], "function": parts[3],
                   "shows": parts[4], "state": parts[5], "closes": parts[6]}
            findings[fid] = rec
            if fid not in order:
                order.append(fid)
        elif parts and parts[0] == "C":
            # C|id|date|sha
            if len(parts) < 4:
                continue
            closes.setdefault(parts[1], []).append((parts[2], parts[3]))
    # apply closes
    for fid, rec in findings.items():
        if fid in closes:
            last = closes[fid][-1]
            rec["state"] = "mended " + last[1]
            rec["mended_date"] = last[0]
            rec["mended_sha"] = last[1]
    return findings, order

p = parse(args)

if cmd == "add":
    fn = p.get("function")
    shows = p.get("shows", "")
    state = p.get("state", "open")
    closes = p.get("closes", "")
    if not fn:
        print("broken: --function required", file=sys.stderr); sys.exit(2)
    lines = read_lines()
    findings, order = aggregate(lines)
    # next id
    n = len(order) + 1
    fid = "br-%04d" % n
    # ensure uniqueness
    while fid in findings:
        n += 1
        fid = "br-%04d" % n
    line = "F|%s|%s|%s|%s|%s|%s" % (fid, now(), fn, shows, state, closes)
    append(line)
    print(fid)
    sys.exit(0)

elif cmd == "list":
    lines = read_lines()
    findings, order = aggregate(lines)
    open_only = bool(p.get("open"))
    as_json = bool(p.get("json"))
    out = []
    for fid in order:
        rec = findings[fid]
        if open_only and rec["state"] != "open":
            continue
        out.append(rec)
    if as_json:
        print(json.dumps(out))
    else:
        for rec in out:
            print("%s | %s | %s | %s | %s | %s" % (rec["id"], rec["date"], rec["function"],
                                                     rec["shows"], rec["state"], rec["closes"]))
    sys.exit(0)

elif cmd == "close":
    pos = p["_pos"]
    if not pos:
        print("broken: id required", file=sys.stderr); sys.exit(2)
    fid = pos[0]
    sha = p.get("sha")
    if not sha:
        print("broken: --sha required", file=sys.stderr); sys.exit(2)
    lines = read_lines()
    findings, order = aggregate(lines)
    if fid not in findings:
        print("broken: unknown id %s" % fid, file=sys.stderr); sys.exit(2)
    append("C|%s|%s|%s" % (fid, now(), sha))
    print("closed %s -> %s" % (fid, sha))
    sys.exit(0)

elif cmd == "count":
    # count --class
    lines = read_lines()
    findings, order = aggregate(lines)
    from collections import Counter
    c = Counter(rec["function"] for rec in findings.values())
    for fn, n in c.most_common():
        flag = "  <-- rule candidate (>=3)" if n >= 3 else ""
        print("%s\t%d%s" % (fn, n, flag))
    sys.exit(0)

else:
    print("broken: unknown verb %s" % cmd, file=sys.stderr)
    print("usage: broken.sh add --function F --shows CMD --state open --closes PROOF", file=sys.stderr)
    print("       broken.sh list [--open] [--json]", file=sys.stderr)
    print("       broken.sh close <id> --sha SHA", file=sys.stderr)
    print("       broken.sh count --class", file=sys.stderr)
    sys.exit(2)
PY