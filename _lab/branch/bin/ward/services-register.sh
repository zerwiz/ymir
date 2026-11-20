#!/usr/bin/env bash
# services-register.sh — is the register of doors READ, or is it prose?
#
# Rule 24's first sentence is "a door is named". Measured 2026-11-06: NOTHING in the
# tree read the register, so every row in it was a claim nobody checked — and the day
# before, a copied port put two services on one number and took the mail desk down
# while every unit showed green.
#
# The register itself is PRIVATE ($YMIR_HOME/config/services.yaml), so this reader
# ships in the repo and the rows stay in the home: the shape travels, the values do
# not (Rule 26).
#
#   services-register.sh [check] [--measure] [--json] [--register PATH]
#
# What it judges — each finding names the row, never a guess:
#   unnamed      a row with no name, no class, or no gate           HIGH
#   class        a class outside the six in Rule 18's vocabulary    HIGH
#   duplicated   two rows claiming one port                        HIGH
#   unroaded     a hosted row (a host or a port) with no `road`    MEDIUM
#   silent       a declared port with nothing listening   LOW, --measure only
#   unreadable   the register cannot be parsed                     exit 2, a refusal
#
# Exit: 0 nothing above MEDIUM · 1 a HIGH finding · 2 the register cannot be read.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi

JSON=0 REGISTER="" MEASURE=0
while [ $# -gt 0 ]; do
  case "$1" in
    check|"") ;;
    --json) JSON=1 ;;
    --measure) MEASURE=1 ;;
    --register) REGISTER="${2:-}"; shift ;;
    --register=*) REGISTER="${1#*=}" ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\nhelp: services-register.sh [check] [--json] [--register PATH]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

[ -n "$REGISTER" ] || REGISTER="${HOME_DIR:+$HOME_DIR/config/services.yaml}"
if [ -z "$REGISTER" ] || [ ! -r "$REGISTER" ]; then
  printf 'services-register: SKIP — no register on this role (%s) — a seat without a door has nothing to declare\n' "${REGISTER:-no home resolved}" >&2
  exit 0
fi
command -v python3 >/dev/null 2>&1 || { printf 'services-register: SKIP — python3 is absent, so the register cannot be read\n' >&2; exit 0; }

exec python3 - "$REGISTER" "$JSON" "$MEASURE" <<'PY'
import json, re, subprocess, sys

path, want_json, measure = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"
CLASSES = {"public", "team", "client", "operator", "confidential", "fleet"}
HOSTED = {"operator", "team", "client"}

rows = []
try:
    import yaml  # noqa: F401
    doc = yaml.safe_load(open(path).read()) or {}
    rows = [r for r in (doc.get("services") or []) if isinstance(r, dict)]
    how = "yaml"
except Exception:
    # No pyyaml: the rows are flow mappings, so read them without it. A refusal is
    # better than a guess, and this is neither — it is the same rows, parsed plainly.
    try:
        text = open(path).read()
        for m in re.finditer(r"\{([^{}]*)\}", text):
            row = {}
            for k, v in re.findall(r'([A-Za-z_]+)\s*:\s*("(?:[^"\\]|\\.)*"|[^,}]+)', m.group(1)):
                row[k] = v.strip().strip('"')
            if row.get("name") and ("class" in row or "host" in row):
                rows.append(row)
        how = "regex"
    except Exception as e:
        print(f"services-register: REFUSED — the register cannot be read ({e})", file=sys.stderr)
        sys.exit(2)

if not rows:
    print(f"services-register: REFUSED — {path} carries no service rows", file=sys.stderr)
    sys.exit(2)

def listening():
    """Ports that answer, per the socket table. No ss → we cannot measure, and say so."""
    try:
        out = subprocess.run(["ss", "-tln"], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return None
    ports = set()
    for line in out.splitlines()[1:]:
        f = line.split()
        if len(f) < 4:
            continue
        for addr in f[3].split():
            m = re.search(r":(\d+)$", addr)
            if m:
                ports.add(int(m.group(1)))
    return ports

findings = []
def add(sev, what, detail, remedy):
    findings.append({"severity": sev, "what": what, "detail": detail, "remedy": remedy})

by_port = {}
for i, r in enumerate(rows, 1):
    name = (r.get("name") or "").strip()
    cls = (r.get("class") or "").strip()
    gate = (r.get("gate") or "").strip()
    road = (r.get("road") or "").strip()
    host = (r.get("host") or "").strip()
    port = str(r.get("port") or "").strip()

    if not name or not cls or not gate:
        missing = ", ".join(k for k in ("name", "class", "gate") if not r.get(k))
        add("HIGH", "a door is not named", f"row {i} ({name or 'no name'}) lacks: {missing}",
            "give the row a name, a class and a gate — an unnamed door is closed or declared")
    if cls and cls not in CLASSES:
        add("HIGH", "a class outside the vocabulary", f"{name}: class '{cls}'",
            "one of: public · team · client · operator · confidential · fleet (Rule 18)")
    if port:
        by_port.setdefault(port, []).append(name or f"row {i}")
    if cls in HOSTED and (host or port) and not road:
        add("MEDIUM", "a hosted door declares no road", f"{name}: class {cls}, host '{host or '-'}', port {port or '-'}",
            "road: window | tailnet | tunnel | none (Rule 24) — a door whose road nobody declared is an assumption")

for port, names in sorted(by_port.items()):
    if len(names) > 1:
        add("HIGH", "two rows claim one port", f"{port}: {', '.join(names)}",
            "one port, one service — a copied port displaced a live service on 2026-11-06")

# The register is the FLEET's: a dev seat runs a handful of these rows, so comparing
# every declared port against THIS machine's sockets is a wall of noise. The measurement
# is asked for explicitly (--measure), and it is Vörðr on the host that asks.
live = listening() if measure else None
if measure and live is None:
    add("LOW", "the sockets could not be measured", "ss is absent or refused",
        "the register's structure was judged; run it where ss answers to judge the ports")
elif measure:
    for port, names in sorted(by_port.items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else 0):
        if port.isdigit() and int(port) not in live:
            add("LOW", "declared but nothing listens", f"{port}: {', '.join(names)}",
                "raise the seat, or mark the row as not deployed here")

high = sum(1 for f in findings if f["severity"] == "HIGH")
if want_json:
    print(json.dumps({"register": path, "parsed_with": how, "rows": len(rows),
                      "findings": findings, "high": high}, indent=2))
else:
    if not findings:
        print(f'services-register[1]{{verdict,detail}}:\n  "clean","{len(rows)} doors declared, all named, every port claimed once ({how})"')
    else:
        print(f"services-register[{len(findings)}]{{severity,what,detail,remedy}}:")
        for f in findings:
            esc = lambda s: str(s).replace('"', "'")
            print(f'  "{f["severity"]}","{esc(f["what"])}","{esc(f["detail"])}","{esc(f["remedy"])}"')
    print(f"services-register: {len(rows)} rows ({how}) — {len(findings)} finding(s), {high} high")
sys.exit(1 if high else 0)
PY
