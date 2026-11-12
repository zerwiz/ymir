#!/usr/bin/env bash
# fleet-status.sh — the fleet, in one answer: every machine, the road that reached it, and its state (plan 232 R6,
# plan 253 — "one command, every role: a fleet status that names the road that answered"; built 2026-11-12, plan 275).
#
#   bin/fleet/fleet-status.sh           every machine in the registry, as TOON
#   bin/fleet/fleet-status.sh --json    the same, machine-readable
#   bin/fleet/fleet-status.sh <host>    one machine
#
# The registry is $YMIR_HOME/hodd/data/fleet.json (hosts, roles, tailnet name, ssh user) — never a second table.
# For each machine, read-only, in parallel, each bounded by a time limit:
#   road      local (this machine) · tailnet (ssh user@tailnet-name) · down (no answer in time)
#   ymir      the pinned runtime's commit and age, and whether it is a release
#   update    the last line of the nightly update (Gróa's log)
#   load      the 1-minute load and the core count
#   failed    the user units systemd counts as failed
#   voice     whether Rödd's engine answers on :8890
# A row a machine cannot answer is said ("down"), never guessed. A registry row with no ssh user or tailnet name
# (a placeholder such as "localhost" or "unknown") is listed as "no road", not probed.
set -u
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"   # allow-home-default: the one home
REG="$HOME_DIR/hodd/data/fleet.json"
LIMIT="${YMIR_FLEET_STATUS_TIMEOUT:-8}"
JSON=0; ONLY=""
for a in "$@"; do case "$a" in --json) JSON=1 ;; -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) ONLY="$a" ;; esac; done
[ -r "$REG" ] || { printf 'fleet-status: no registry at %s\n' "$REG" >&2; exit 1; }

# the probe each machine runs on itself (read-only; no secret, no write)
PROBE='pin="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
c=$(git -C "$pin" log -1 --format="%h %cr" 2>/dev/null || echo "none")
rel=$([ -L "$pin" ] && echo release || echo checkout)
h=$(ls -d "$HOME/Documents/ymirhome" 2>/dev/null)
u=$(grep -E "^UPDATED|^GUARD|Model unavailable" "$h/hodd/state/groa-agent.log" 2>/dev/null | tail -1 | cut -c1-70); t=$(grep -oE "^── [0-9T:+-]+ tick finished \(rc [0-9]+\)" "$h/hodd/state/groa-agent.log" 2>/dev/null | tail -1 | sed -E "s/^── ([0-9-]+)T([0-9:]{5}).*\(rc ([0-9]+)\)/\1 \2 rc \3/"); u="${t:-never} · ${u:-no outcome line}"
l=$(cut -d" " -f1 /proc/loadavg 2>/dev/null); n=$(nproc 2>/dev/null)
f=$(systemctl --user --failed --no-legend 2>/dev/null | wc -l)
v=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://127.0.0.1:8890/docs 2>/dev/null)
printf "%s\t%s\t%s\t%s/%s\t%s\t%s\n" "$c" "$rel" "${u:-no nightly log}" "${l:-?}" "${n:-?}" "$f" "$([ "$v" = 200 ] && echo up || echo down)"'

me="$(hostname -s)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
python3 - "$REG" "$ONLY" > "$TMP/hosts" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); only = sys.argv[2]
for name, h in (d.get("hosts") or {}).items():
    if only and name != only: continue
    print("\t".join([name, ",".join(h.get("roles") or []), h.get("user") or "", h.get("tailnet") or ""]))
PY
while IFS=$'\t' read -r name roles user tail; do
  (
    out="$TMP/$name"
    if [ "$name" = "$me" ]; then
      r="$(timeout "$LIMIT" bash -c "$PROBE" 2>/dev/null)" && printf 'local\t%s\n' "$r" > "$out" || printf 'down\t\n' > "$out"
    elif [ -z "$user" ] || [ -z "$tail" ]; then
      printf 'no road\t\n' > "$out"
    else
      r="$(timeout "$LIMIT" ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$user@$tail" "bash -lc '$(printf %s "$PROBE" | sed "s/'/'\\\\''/g")'" 2>/dev/null)" \
        && printf 'tailnet\t%s\n' "$r" > "$out" || printf 'down\t\n' > "$out"
    fi
  ) &
done < "$TMP/hosts"
wait

python3 - "$TMP" "$JSON" "$me" <<'PY'
import json, os, sys
tmp, as_json, me = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
rows = []
for line in open(os.path.join(tmp, "hosts")):
    name, roles, user, tail = (line.rstrip("\n").split("\t") + ["", "", ""])[:4]
    raw = open(os.path.join(tmp, name)).read().rstrip("\n").split("\t") if os.path.exists(os.path.join(tmp, name)) else ["down"]
    road = raw[0]
    f = raw[1:] + [""] * 6
    rows.append({"host": name, "role": roles, "road": road, "ymir": f[0], "pin": f[1], "update": f[2],
                 "load": f[3], "failed_units": f[4], "voice": f[5], "this_machine": name == me})
if as_json:
    print(json.dumps({"fleet": rows}, indent=1))
else:
    print(f"fleet[{len(rows)}]{{host,role,road,ymir,pin,load,failed,voice,update}}:")
    for r in rows:
        cells = [r["host"] + (" (this)" if r["this_machine"] else ""), r["role"], r["road"], r["ymir"] or "-", r["pin"] or "-",
                 r["load"] or "-", r["failed_units"] or "-", r["voice"] or "-", r["update"] or "-"]
        print("  " + ",".join('"' + str(c).replace('"', "'") + '"' for c in cells))
PY
