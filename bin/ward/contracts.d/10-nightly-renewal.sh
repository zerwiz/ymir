#!/usr/bin/env bash
# The nightly renewal ran, and finished, on this machine: Gróa's unit is not failed, and Eir's last night is recent
# and did not fail (plan 350 C). Caught on 2026-11-22: the renewal failed on three machines, unseen.
command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1 || { echo "skip: no user service manager here"; exit 0; }
systemctl --user cat groa-agent.timer >/dev/null 2>&1 || { echo "red: Gróa's nightly timer is not seated — bash bin/agents/groa-agent/seat.sh"; exit 1; }
if [ "$(systemctl --user is-failed groa-agent.service 2>/dev/null)" = failed ]; then
  echo "red: Gróa's last night failed — journalctl --user -u groa-agent.service -n 20; tail \$YMIR_STATE/groa-agent.log"; exit 1
fi
last="$YMIR_STATE/renewal/last-night.json"
if [ -r "$last" ]; then
  python3 - "$last" <<'PY'
import json, sys, time
r = json.load(open(sys.argv[1])); age = (time.time() - r.get("ts", 0)) / 3600
if r.get("result") == "failed":
    print(f"red: Eir's last night failed — {r.get('hung') or r.get('failed')}"); sys.exit(1)
if age > 26:
    print(f"red: no night has run for {age:.0f} h — systemctl --user list-timers groa-agent.timer"); sys.exit(1)
print(f"ok: the night ran {age:.0f} h ago: {r.get('result')}, Gróa rc {r.get('groa_rc')}")
PY
  exit $?
fi
echo "ok: Gróa's unit is not failed (Eir's night has not run here yet)"
