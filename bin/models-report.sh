#!/usr/bin/env bash
# models-report — the user's OWN models, read from the ROOT pi home.
#
# The system must find the user's models rather than assume them: a roster can name a
# model this machine has never seen, and a report that says only "models ensured" leaves
# that broken wiring invisible until an agent fails.
#
#   bin/models-report.sh [path]   default: $HOME/.pi/agent/models.json
#
# Prints one line:  <n> providers / <m> models · <first four providers>
# Exits 1 with no output when the file is absent or does not parse.
set -uo pipefail
file="${1:-$HOME/.pi/agent/models.json}"
[ -r "$file" ] || exit 1
python3 - "$file" <<'PY' 2>/dev/null || exit 1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
prov = d.get("providers") or {}
if not isinstance(prov, dict):
    raise SystemExit(1)
models = sum(len((v or {}).get("models") or []) for v in prov.values() if isinstance(v, dict))
names = ",".join(list(prov)[:4]) or "none"
extra = "" if len(prov) <= 4 else f" +{len(prov) - 4} more"
print(f"{len(prov)} providers / {models} models · {names}{extra}")
PY
