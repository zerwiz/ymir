#!/usr/bin/env bash
# jev-doors.sh — where the decision models answer, in one read.
#
#   bin/model/jev-doors.sh list [--json]     # the registry, with a live probe
#   bin/model/jev-doors.sh url <id>          # the base URL for one door
#   bin/model/jev-doors.sh ask <id> <state-json> <questions-json>   # one call, raw JSON back
#
# The models are not chat models: they answer `POST /v1/systemone` with typed questions.
# The registry says which door is which, what it may be used for, and its licence — so a
# gate cannot accidentally pick the non-commercial one.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_DIR 2>/dev/null || { printf "%s: the home is unresolved — call bin/vault/hoard-lib.sh\n" "$(basename "$0")" >&2; exit 2; }
REG="${JEV_DOORS:-$HOME/.config/ymir/jev-doors.yaml}"
[ -r "$REG" ] || REG="$HOME_DIR/config/jev-doors.yaml"
HOST="${JEV_DOOR_HOST:-}"   # never a default host: the operator names the door (Rule 24/39)
# WHICH MACHINE HOLDS THE DOORS (2026-11-09). This used to call
# bin/bridge/seat-host.sh — a script that does not exist anywhere in the tree, so HOST was
# always empty, every URL was hollow (`http://:8099`), and all four registered doors read
# "down" forever. That is how a registry of standing doors was mistaken for a dead rail.
# The order is now explicit and each step is a door that really exists:
#   1 · JEV_DOOR_HOST                     — the operator's word wins
#   2 · `host:` in the registry itself    — the shelf names its own machine
#   3 · the fleet registry's forge, else heart — the models machine, read once (Rule 25)
#   4 · nothing                           — reported as `no-host`, never as `down`
if [ -z "$HOST" ] && [ -r "$REG" ]; then
  HOST="$(grep -m1 '^host:' "$REG" | cut -d: -f2- | sed 's/[[:space:]]*#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//' | tr -d "\"'")"
fi
if [ -z "$HOST" ] && [ -r "$ROOT/bin/skuld/fleet-host.sh" ]; then
  HOST="$(bash "$ROOT/bin/skuld/fleet-host.sh" forge 2>/dev/null || true)"
fi
if [ -z "$HOST" ]; then
  for _f in "$HOME_DIR/config/fleet.json" "$HOME_DIR/hodd/data/fleet.json"; do
    [ -r "$_f" ] || continue
    HOST="$(python3 - "$_f" <<'PY' 2>/dev/null || true
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: raise SystemExit(0)
print(d.get("forge") or d.get("heart") or "")
PY
)"
    [ -n "$HOST" ] && break
  done
fi

key() { bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | sed -n 's/^export LLAMA_SWAP_API_KEY=//p' | head -1 | tr -d '"'"'"''; }
rows() {
  [ -r "$REG" ] || return 0
  python3 - "$REG" <<'PY'
import sys
try:
    import yaml
except Exception:
    raise SystemExit(0)
d = yaml.safe_load(open(sys.argv[1])) or {}
for door in d.get("doors") or []:
    if not isinstance(door, dict):
        continue
    print("\t".join(str(door.get(k, "")) for k in ("id","model","port","license","role","gguf")))
PY
}
case "${1-}" in
  list)
    JSON=0; [ "${2-}" = "--json" ] && JSON=1
    K="$(key)"; tmp="$(mktemp)"; rows >"$tmp"
    python3 - "$tmp" "$HOST" "$K" "$JSON" <<'PY'
import json, subprocess, sys
path, host, key, as_json = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"

# THE PROBE MUST BE A VALID QUESTION (2026-11-09). It used to post
#   {"state":"x","questions":{"q":{"type":"noul","instructions":"ok?"}}}
# which the engine refuses with 400 — `questions.<id>: "criteria" must be a non-empty
# object`. Nothing counted but 200, so a door that was standing and answering its real
# traffic was reported `down`. Measured on the dev machine with jev build 12138: a criteria-less
# body → 400, a body carrying criteria → 200 in one forward pass.
PROBE = json.dumps({
    "state": "the probe asks one question to learn whether this door answers",
    "questions": {"probe": {
        "type": "choice",
        "instructions": "which word appears in the text above?",
        "options": [{"label": "probe", "description": "the word probe, lowercase"},
                    {"label": "door", "description": "the word door, lowercase"}],
        "criteria": {"probe": "the word probe", "door": "the word door"},
    }},
})

# One code, one meaning. `down` is silence; everything else NAMES what answered — a 404 is
# an engine without the /v1/systemone route, not a missing door, and the two want
# different remedies.
STATES = {"200": "up", "400": "up-refused-probe", "401": "unauthorized", "403": "unauthorized",
          "404": "route-missing", "405": "wrong-endpoint", "501": "not-a-decision-model",
          "503": "loading", "000": "down"}

def ask(url, body, timeout="6"):
    return subprocess.run(["curl","-s","-o","/dev/null","-w","%{http_code}","--max-time",timeout,
                           "-X","POST",url,"-H","content-type: application/json",
                           "-H",f"Authorization: Bearer {key}","-d",body],
                          capture_output=True, text=True).stdout.strip() or "000"

def engine(base):
    r = subprocess.run(["curl","-s","--max-time","4","-H",f"Authorization: Bearer {key}",
                        f"{base}/props"], capture_output=True, text=True)
    try:
        return json.loads(r.stdout).get("build_info") or ""
    except Exception:
        return ""

out = []
if not host:
    # A registry that cannot name its machine is a fault of the registry, not evidence that
    # four doors are dead. Say which it is.
    for line in open(path).read().splitlines():
        if not line.strip(): continue
        ident, model, port, lic, role, gguf = (line.split("\t") + [""]*6)[:6]
        out.append({"id": ident, "model": model, "port": port, "license": lic, "role": role,
                    "gguf": gguf, "url": None, "state": "no-host", "build": ""})
    if as_json:
        print(json.dumps({"transport": "unknown", "wire": "systemone", "error":
                          "no host resolved: set JEV_DOOR_HOST or a `host:` line in the registry",
                          "doors": out}, indent=1))
    else:
        print('jev_doors[%d]{id,model,port,license,state}:' % len(out))
        for d in out:
            print(f'  "{d["id"]}","{d["model"]}","{d["port"]}","{d["license"]}","{d["state"]}"')
        print('help: no host resolved — name it with JEV_DOOR_HOST, or a `host:` line in ' + path, file=sys.stderr)
    raise SystemExit(3)
for line in open(path).read().splitlines():
    if not line.strip(): continue
    ident, model, port, lic, role, gguf = (line.split("\t") + [""]*6)[:6]
    base = f"http://{host}:{port}" if port and port.lower() not in ("null", "none", "") else ""
    state, build = "no-door", ""
    if base:
        code = ask(f"{base}/v1/systemone", PROBE)
        state = STATES.get(code, f"http-{code}")
        if state.startswith("up"):
            build = engine(base)
    out.append({"id": ident, "model": model, "port": port, "license": lic, "role": role,
                "gguf": gguf, "url": base or None, "state": state, "build": build})
if as_json:
    print(json.dumps({"transport":"tailscale","wire":"systemone","host":host,"doors":out}, indent=1))
else:
    print(f'jev_doors[{len(out)}]{{id,model,port,license,state}}:')
    for d in out:
        print(f'  "{d["id"]}","{d["model"]}","{d["port"]}","{d["license"]}","{d["state"]}"')
PY
    rm -f "$tmp" ;;
  url)
    id="${2-}"; rows | awk -F'\t' -v want="$id" '$1==want {print $3}' | head -1 | { read -r p; [ -n "$p" ] && [ "$p" != "null" ] && printf 'http://%s:%s/v1/systemone\n' "$HOST" "$p" || printf 'jev-doors: no reachable door for %s\n' "$id" >&2; } ;;
  ask)
    id="${2-}"; state="${3-}"; questions="${4-}"
    port="$(rows | awk -F'\t' -v want="$id" '$1==want {print $3}' | head -1)"
    [ -n "$port" ] && [ "$port" != "null" ] || { printf 'jev-doors: no door for %s\n' "$id" >&2; exit 2; }
    # ONE RAIL, ON DEMAND (2026-11-06): the router names the model in the body and swaps it
    # in; four always-on units held 11.6 GiB of a 16 GiB card and starved a 35B coder.
    model="$(rows | awk -F'\t' -v want="$id" '$1==want {print $2}' | head -1 | tr '[:upper:]' '[:lower:]')"
    curl -s -X POST "http://$HOST:$port/v1/systemone" -H 'content-type: application/json' \
      -H "Authorization: Bearer $(key)" \
      -d "{\"model\":\"$model\",\"state\":$state,\"questions\":$questions}" ;;
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
