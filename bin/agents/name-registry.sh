#!/usr/bin/env bash
# name-registry.sh — the collision system for Ymir's names.
#
# One name, one role. A subsystem may not become a host, a host may not become an
# agent, and a seat persona may not take the name of a service. This door scans the
# naming law and the shelves into ONE registry and answers collisions.
#
# Usage:
#   name-registry.sh scan                 rebuild <home>/hodd/identity/names.yaml
#   name-registry.sh check <name> [--as seat-persona|agent|subsystem|host]
#   name-registry.sh list [--kind K]
#   name-registry.sh collisions           # duplicate names across incompatible kinds
#
# Exit: 0 free · 3 collision/refused · 1 error · 2 usage
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh"; do [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }; done; unset _c
fi
ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?YMIR_HOME unresolved}"
OUT="$YMIR_HOME/hodd/identity/names.yaml"
NAMING="$ROOT/.agents/assets/agents/naming.md"

python3 - "$ACTION" "$ROOT" "$YMIR_HOME" "$OUT" "$NAMING" "$@" <<'PY'
import sys, os, re, json, glob, unicodedata
action, root, home, out, naming = sys.argv[1:6]
args = sys.argv[6:]
try:
    import yaml
except Exception:
    yaml = None

def norm(s):
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"\(.*?\)", "", s)
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s

def entries():
    if not yaml or not os.path.exists(out):
        print("error: registry not built — run: name-registry.sh scan", file=sys.stderr); sys.exit(1)
    return yaml.safe_load(open(out)) or {"names": {}}

def scan():
    names = {}
    def add(name, kind, source, owner=""):
        n = norm(name)
        if not n or n in ("topology",): return
        names.setdefault(n, []).append({"kind": kind, "source": source, "owner": owner})
    # subsystems from the naming law's TOON block
    if os.path.exists(naming):
        for line in open(naming):
            m = re.match(r'\s*"([^"]*)","([^"]*)"', line)
            if m:
                add(m.group(2), "subsystem", naming)
    # agents
    for p in sorted(glob.glob(f"{root}/.agents/agents/*.md")):
        n = os.path.basename(p)[:-3]
        n = re.sub(r"-(developer|marketer|reviewer|documenter|researcher|planner|stow|check|scout|designer|consent|bearings|recovery|diagnostics|projects|hold|update|smith)$", "", n)
        add(n, "agent", p, n)
    # skills
    for p in sorted(glob.glob(f"{root}/.agents/skills/*/SKILL.md")):
        head = open(p, errors="replace").read(800)
        m = re.search(r"^---.*?^name:\s*(\S+)", head, re.S | re.M)
        add(m.group(1) if m else os.path.basename(os.path.dirname(p)), "skill", p)
    # extensions
    for p in sorted(glob.glob(f"{root}/.pi/extensions/*.ts")) + sorted(glob.glob(f"{root}/.pi/extensions/*/index.ts")):
        add(os.path.basename(os.path.dirname(p)) if p.endswith("index.ts") else os.path.basename(p)[:-3], "extension", p)
    # reserved infrastructure names (a seat may never take one)
    res = os.path.join(home, "hodd/identity/reserved-names.txt")
    if os.path.exists(res):
        for line in open(res):
            line = line.strip()
            if line and not line.startswith("#"): add(line, "reserved-infra", res)
    # hosts and seat personas
    seats = os.path.join(home, "hodd/identity/seats.yaml")
    if os.path.exists(seats):
        d = yaml.safe_load(open(seats)) or {}
        for h, i in (d.get("seats") or {}).items():
            add(h, "host", seats)
            if i.get("primary"): add(i["primary"], "seat-persona", seats, h)
    doc = {"version": 1, "generated": __import__("datetime").datetime.now().astimezone().isoformat(timespec="seconds"),
           "names": names}
    open(out, "w").write(yaml.safe_dump(doc, sort_keys=True))
    print(f"scanned\t{len(names)} names\t{out}")
    # collisions among reserved kinds
    bad = 0
    for n, es in names.items():
        kinds = {e["kind"] for e in es}
        # A subsystem and its own agent/skill may share a name. A HOST may not.
        if "host" in kinds and len(kinds) > 1:
            bad += 1; print(f"collision\t{n}\t{','.join(sorted(kinds))}\thost")
        # A seat persona may not take a service's name.
        if "seat-persona" in kinds and (kinds & {"reserved-infra", "host", "extension"}):
            bad += 1; print(f"collision\t{n}\t{','.join(sorted(kinds))}\tseat-persona")
    print(f"collisions\t{bad}")

def check(name, as_kind):
    d = entries(); es = d.get("names", {}).get(norm(name))
    if not es:
        print(f"free\t{name}"); return 0
    kinds = {e["kind"] for e in es}
    if as_kind == "seat-persona":
        bad = kinds & {"reserved-infra", "host", "extension"}
        if bad:
            print(f"refused\t{norm(name)} is {','.join(sorted(bad))} — not a seat persona")
            return 3
        print(f"ok\t{norm(name)} is {','.join(sorted(kinds))}")
        return 0
    if as_kind in ("agent",) and (kinds & {"subsystem", "host"}):
        print(f"refused\t{norm(name)} is {','.join(sorted(kinds & {'subsystem','host'}))}")
        return 3
    print(f"used\t{norm(name)} is {','.join(sorted(kinds))}")
    return 0

def list_names(kind=None):
    d = entries()
    for n in sorted(d.get("names", {})):
        es = d["names"][n]
        ks = sorted({e["kind"] for e in es})
        if kind and kind not in ks: continue
        print(f"{n}\t{','.join(ks)}")

if action == "scan": scan()
elif action == "check":
    if not args: print("error: check needs a name", file=sys.stderr); sys.exit(2)
    name = args[0]; as_kind = "seat-persona"
    if "--as" in args: as_kind = args[args.index("--as")+1]
    sys.exit(check(name, as_kind))
elif action == "list":
    list_names(args[args.index("--kind")+1] if "--kind" in args else None)
elif action == "collisions":
    d = entries(); bad=0
    for n, es in sorted(d.get("names", {}).items()):
        ks = {e["kind"] for e in es}
        if "host" in ks and len(ks) > 1:
            print(f"collision\t{n}\t{','.join(sorted(ks))}\thost"); bad+=1
        if "seat-persona" in ks and (ks & {"reserved-infra","host","extension"}):
            print(f"collision\t{n}\t{','.join(sorted(ks))}\tseat-persona"); bad+=1
    print(f"collisions\t{bad}")
else:
    print("error: usage: name-registry.sh scan|check|list|collisions", file=sys.stderr); sys.exit(2)
PY
