#!/usr/bin/env bash
# omarchy-sense.sh — learn the Allfather's Omarchy machine.
#
# Ymir runs on an Omarchy host, and that host changes: packages get installed,
# configs get edited, Omarchy itself updates. This records what is stable, what
# changed since the last look, and when Omarchy itself moved — so the agent can
# help with *this* machine rather than a generic one.
#
# It is a sensor, not a fixer: it observes, records, and reports. Nothing on the
# user's machine is modified.
#
# Usage:
#   bin/omarchy-sense.sh observe [--quiet]   # record the current state, diff vs last
#   bin/omarchy-sense.sh status              # show the latest snapshot + last change
#   bin/omarchy-sense.sh --version
#
# State: state/omarchy-setup.json (gitignored — this is per-user, per-machine).
# Output: Galdr TOON.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${BROKK_STATE_OVERRIDE:-$ROOT/state}"
SNAP="$STATE_DIR/omarchy-setup.json"
QUIET=0

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-observe}"; shift || true
[ "${1:-}" = "--quiet" ] && QUIET=1

is_omarchy() { [ -d /usr/share/omarchy ]; }

# A stable, comparable fingerprint of the machine. Keep keys short (TOON).
snapshot() {
  local ov="" pkgs cnf monitors scale wm
  is_omarchy && ov="$(omarchy version 2>/dev/null | head -1)"
  # Explicitly installed packages (the user's own choices, not the base image).
  pkgs="$(pacman -Qe 2>/dev/null | wc -l | tr -d ' ')"
  # The user's config surface: what they have customised.
  cnf="$(find "$HOME/.config" -maxdepth 3 -type f \
          \( -name '*.lua' -o -name 'shell.json' -o -name '*.conf' -o -name '*.jsonc' \) \
          2>/dev/null | wc -l | tr -d ' ')"
  monitors="$(hyprctl monitors -j 2>/dev/null \
    | python3 -c 'import json,sys
try:
  m=json.load(sys.stdin); print(len(m))
except Exception: print(0)' 2>/dev/null || echo 0)"
  scale="$(hyprctl monitors -j 2>/dev/null \
    | python3 -c 'import json,sys
try:
  m=json.load(sys.stdin); print(m[0].get("scale") if m else 0)
except Exception: print(0)' 2>/dev/null || echo 0)"
  wm="${XDG_CURRENT_DESKTOP:-unknown}"
  python3 - "$ov" "$pkgs" "$cnf" "$monitors" "$scale" "$wm" <<'PY'
import json, sys
ov, pkgs, cnf, monitors, scale, wm = sys.argv[1:7]
print(json.dumps({
  "omarchy": ov,
  "explicit_pkgs": int(pkgs or 0),
  "config_files": int(cnf or 0),
  "monitors": int(monitors or 0),
  "scale": scale,
  "wm": wm,
}, sort_keys=True))
PY
}

observe() {
  mkdir -p "$STATE_DIR"
  local now; now="$(snapshot)"
  local prev="{}"
  [ -r "$SNAP" ] && prev="$(cat "$SNAP")"

  # Diff the scalars that matter, so we can report what the user changed.
  local report
  report="$(python3 - "$prev" "$now" <<'PY'
import json, sys
prev = json.loads(sys.argv[1] or "{}")
now = json.loads(sys.argv[2] or "{}")
keys = ["omarchy", "explicit_pkgs", "config_files", "monitors", "scale", "wm"]
changes = []
for k in keys:
    if k in prev and prev[k] != now.get(k):
        changes.append((k, prev[k], now.get(k)))
print(json.dumps({"changes": changes, "now": now}))
PY
)"
  # Persist the new snapshot with a timestamp (the snapshot itself stays comparable).
  python3 - "$SNAP" "$now" <<'PY'
import json, sys, datetime, os, tempfile
path, now = sys.argv[1], json.loads(sys.argv[2])
now["observed_at"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
d = os.path.dirname(path) or "."
fd, tmp = tempfile.mkstemp(dir=d)
with os.fdopen(fd, "w") as f:
    json.dump(now, f, indent=2, sort_keys=True)
os.replace(tmp, path)
PY

  [ "$QUIET" = 1 ] && return 0
  printf 'omarchy-sense[1]{omarchy,monitors,scale,configs,pkgs,changes}:\n'
  python3 - "$report" "$SNAP" <<'PY'
import json, sys
rep = json.loads(sys.argv[1])
n = rep["now"]
ch = rep["changes"]
print(f'  "{n.get("omarchy") or "not-omarchy"}",{n.get("monitors",0)},"{n.get("scale",0)}",'
      f'{n.get("config_files",0)},{n.get("explicit_pkgs",0)},{len(ch)}')
PY
  python3 - "$report" <<'PY'
import json, sys
rep = json.loads(sys.argv[1])
for k, a, b in rep["changes"]:
    print(f'changed[1]{{field,was,now}}:\n  "{k}","{a}","{b}"')
PY
}

case "$ACTION" in
  observe) observe ;;
  status)
    if [ -r "$SNAP" ]; then
      printf 'omarchy-sense[1]{snapshot}:\n'
      python3 - "$SNAP" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(f'  "{d.get("omarchy") or "not-omarchy"} · monitors={d.get("monitors")} '
      f'scale={d.get("scale")} configs={d.get("config_files")} '
      f'pkgs={d.get("explicit_pkgs")} · seen {d.get("observed_at")}"')
PY
    else
      printf 'omarchy-sense[1]{snapshot}:\n  "none yet — run bin/omarchy-sense.sh observe"\n'
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/omarchy-sense.sh [observe|status]\n' "$1" >&2; exit 2 ;;
esac
