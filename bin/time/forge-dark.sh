#!/usr/bin/env bash
# forge-dark.sh — has the forge been dark for more than 24 hours? (plan 365, Nornir fallback)
#
#   forge-dark.sh [--state DIR] [--hours N]    exit 0 = dark (prints "dark <days>d"), 1 = up or unknown
#
# The forge hosts are read from the fleet registry (hosts whose roles include `forge`), never named here.
# A host that answers ssh is "seen"; the stamp is kept in <state>/.forge-seen/<host>. A host never seen by
# this seat counts from the registry's `dark_since`. The verdict is cached for 10 minutes so the scheduler
# can ask every tick. With no forge host in the registry the answer is "not dark": nothing owns those jobs.
set -u
STATE="${BROKK_STATE_OVERRIDE:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"; HOURS=24
while [ $# -gt 0 ]; do
  case "$1" in --state) STATE=$2; shift ;; --hours) HOURS=$2; shift ;; esac; shift
done
REG="${YMIR_FLEET_REGISTRY:-${YMIR_HOME:-$HOME/Documents/ymirhome}/hodd/data/fleet.json}"
mkdir -p "$STATE/.forge-seen" 2>/dev/null
CACHE="$STATE/.forge-dark.cache"
now=$(date +%s)
if [ -r "$CACHE" ] && [ $((now - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0))) -lt 600 ]; then
  v=$(cat "$CACHE"); case "$v" in dark*) echo "$v"; exit 0 ;; *) exit 1 ;; esac
fi
verdict=$(REG="$REG" STATE="$STATE" HOURS="$HOURS" NOW="$now" python3 - <<'PY'
import json, os, subprocess, datetime
reg, state, hours, now = os.environ["REG"], os.environ["STATE"], float(os.environ["HOURS"]), int(os.environ["NOW"])
try: hosts = json.load(open(reg)).get("hosts", {})
except Exception: hosts = {}
forges = {h: v for h, v in hosts.items() if "forge" in (v.get("roles") or [])}
if not forges: print("up"); raise SystemExit
worst = None
for h, v in forges.items():
    seen_f = os.path.join(state, ".forge-seen", h)
    target = v.get("tailnet") or v.get("lan") or h
    user = v.get("user")
    dest = f"{user}@{target}" if user else target
    ok = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", dest, "true"],
                        capture_output=True).returncode == 0
    if ok:
        open(seen_f, "w").write(str(now)); last = now
    else:
        try: last = int(open(seen_f).read().strip())
        except Exception:
            ds = v.get("dark_since")
            try: last = int(datetime.datetime.fromisoformat(ds).replace(tzinfo=datetime.timezone.utc).timestamp()) if ds else now
            except Exception: last = now
            if not ds: open(seen_f, "w").write(str(now))
    age = now - last
    if age > hours * 3600: worst = max(worst or 0, age)
print("up" if worst is None else f"dark {int(worst // 86400)}d")
PY
)
printf '%s\n' "$verdict" >"$CACHE"
case "$verdict" in dark*) echo "$verdict"; exit 0 ;; *) exit 1 ;; esac
