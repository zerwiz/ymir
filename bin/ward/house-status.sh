#!/usr/bin/env bash
# house-status.sh — the heart's answer: what it hosts, and whether it is up.
# Reads $YMIR_HOME/config/services.yaml (32 rows) and ~/.cloudflared/config-*.yml.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR; fi

SERVICES="${HOUSE_STATUS_SERVICES:-${HOME_DIR:+$HOME_DIR/config/services.yaml}}"
CFDIR="${HOUSE_STATUS_CFDIR:-$HOME/.cloudflared}"
STATE="${HOUSE_STATUS_STATE:-${HOME_DIR:+$HOME_DIR/state/house-status-state.json}}"
[ -n "$STATE" ] || STATE="/tmp/house-status-state.json"

exec python3 - "$SERVICES" "$CFDIR" "$STATE" <<'PY'
import json, os, re, socket, subprocess, sys, urllib.request, datetime

services_path, cfdir, state_path = sys.argv[1], sys.argv[2], sys.argv[3]
today = datetime.date.today().isoformat()

def listening_ports():
    try:
        out = subprocess.run(["ss", "-tln"], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return set()
    ports = set()
    for line in out.splitlines()[1:]:
        f = line.split()
        if len(f) < 4: continue
        for addr in f[3].split():
            m = re.search(r":(\d+)$", addr)
            if m: ports.add(int(m.group(1)))
    return ports

LIVE_PORTS = listening_ports()

def http_probe(url, timeout=4):
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return None

def classify_edge(status):
    if status is None: return "DARK"
    if status in (530, 522): return "DARK"
    return "UP"

rows_out = []
deltas = {}
findings = []

# Load state
state = {}
try:
    if os.path.exists(state_path):
        state = json.load(open(state_path))
except Exception:
    state = {}

def record_delta(key, is_delta):
    if is_delta:
        if key not in state:
            state[key] = today
    else:
        state.pop(key, None)

# Services
try:
    import yaml
    doc = yaml.safe_load(open(services_path).read()) if services_path and os.path.exists(services_path) else {}
    services = [r for r in (doc.get("services") or []) if isinstance(r, dict)] if doc else []
except Exception:
    services = []

for r in services:
    name = str(r.get("name") or "").strip()
    cls = str(r.get("class") or "").strip()
    port = r.get("port")
    try:
        port = int(port) if port not in (None, "", "null") else None
    except Exception:
        port = None
    raw = r.get("expect", None)
    if isinstance(raw, bool):
        expect = "on" if raw else "off"
    else:
        expect = str(raw or "").strip().lower()
    if expect not in ("on", "off", "declared"):
        expect = ""  # missing -> finding
    road = str(r.get("road") or "").strip() or "-"
    host = str(r.get("host") or "").strip()

    # live
    if port is not None:
        live = "up" if port in LIVE_PORTS else "down"
    else:
        live = "down"

    # edge
    edge = "-"
    if host and host not in ("", "127.0.0.1", "localhost"):
        st = http_probe(f"https://{host}/", timeout=5)
        if st is None:
            st = http_probe(f"http://{host}/", timeout=5)
        edge = classify_edge(st)

    # missing expect finding
    if expect == "":
        findings.append(f"{name}: row has no expect: key")

    # off + listening finding
    if expect == "off" and port is not None and port in LIVE_PORTS:
        findings.append(f"{name}: listener on port {port} but row says off")

    rows_out.append({
        "kind": "service", "name": name, "class": cls, "port": port if port is not None else "-",
        "expect": expect if expect else "MISSING", "live": live, "road": road, "edge": edge,
    })

    # delta
    exp_norm = "on" if expect == "on" else ("off" if expect in ("off", "declared") else expect)
    # declared counts as off (not expected up)
    expected_up = (expect == "on")
    live_up = (live == "up")
    is_delta = (expected_up != live_up)
    record_delta(f"svc:{name}", is_delta)
    if is_delta:
        deltas.setdefault(f"{name} (service)", state.get(f"svc:{name}", today))

# Tunnels
cfgs = []
try:
    for fn in sorted(os.listdir(cfdir)):
        if re.match(r"config-.+\.yml$", fn) and not fn.endswith(".bak") and ".bak" not in fn:
            cfgs.append(os.path.join(cfdir, fn))
except Exception:
    pass

for cfg in cfgs:
    try:
        import yaml
        doc = yaml.safe_load(open(cfg).read()) or {}
    except Exception:
        doc = {}
    tunnel_name = os.path.basename(cfg).replace("config-", "").replace(".yml", "")
    ingress = doc.get("ingress") or []
    hostnames = []
    origin_port = None
    for entry in ingress:
        if not isinstance(entry, dict): continue
        h = entry.get("hostname")
        if h: hostnames.append(h)
        svc = str(entry.get("service") or "")
        m = re.search(r":(\d+)$", svc)
        if m and origin_port is None:
            origin_port = int(m.group(1))
    # one row per tunnel config
    # live = origin answering
    if origin_port is not None:
        if origin_port in LIVE_PORTS:
            st = http_probe(f"http://127.0.0.1:{origin_port}/", timeout=3)
            live = "up" if st is not None else "down"
        else:
            live = "down"
    else:
        live = "down"
    # edge: probe first hostname
    edge = "-"
    if hostnames:
        st = http_probe(f"https://{hostnames[0]}/", timeout=5)
        if st is None:
            st = http_probe(f"http://{hostnames[0]}/", timeout=5)
        edge = classify_edge(st)
    host_disp = ",".join(hostnames) if hostnames else "-"
    rows_out.append({
        "kind": "tunnel", "name": tunnel_name, "class": "tunnel",
        "port": origin_port if origin_port is not None else "-",
        "expect": "on", "live": live, "road": "tunnel", "edge": edge,
    })
    # delta for tunnel: expected on
    is_delta = (live != "up")
    record_delta(f"tun:{tunnel_name}", is_delta)
    if is_delta:
        deltas.setdefault(f"{tunnel_name} (tunnel)", state.get(f"tun:{tunnel_name}", today))

# Print table
print("house-status[{n}]{{name,class,port,expect,live,road,edge}}:".format(n=len(rows_out)))
for r in rows_out:
    print('  "{name}","{cls}","{port}","{exp}","{live}","{road}","{edge}"'.format(
        name=r["name"], cls=r["class"], port=r["port"], exp=r["expect"],
        live=r["live"], road=r["road"], edge=r["edge"]))

# Findings
if findings:
    print(f"house-status findings[{len(findings)}]:")
    for f in findings:
        print(f"  - {f}")

# Deltas
if deltas:
    print(f"house-status deltas[{len(deltas)}]{{service,changed}}:")
    for k, v in deltas.items():
        print(f'  "{k}","{v}"')
else:
    print("house-status deltas[0]: none")

# Save state
try:
    os.makedirs(os.path.dirname(state_path), exist_ok=True) if os.path.dirname(state_path) else None
    with open(state_path, "w") as fh:
        json.dump(state, fh, indent=2)
except Exception:
    pass
PY
