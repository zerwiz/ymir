#!/usr/bin/env bash
# smoke_test.sh — does the stack actually work? (the lifecycle interface)
#
# Answers more than "a port is open": the SPA answers HTTP, the gate API answers,
# the well bridge is reachable, the Smiðja database exists, and the skills are
# bound. Exit 0 when every check passes, 1 otherwise — a gate can rely on it.
#
# Usage: smoke_test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"

declare -a C S D
check() { C+=("$1"); S+=("$2"); D+=("$3"); }
fail=0
bad() { check "$1" FAIL "$2"; fail=1; }
ok()  { check "$1" OK   "$2"; }

# 1. the SPA answers over HTTP, not merely that the port accepts
if curl -fsS -m 5 http://127.0.0.1:3888/ >/dev/null 2>&1; then ok spa "Hlidskjalf answers on :3888"
else bad spa "no HTTP answer on :3888 — scripts/start.sh"; fi

# 2. the gate API
if curl -fsS -m 5 http://127.0.0.1:3889/health >/dev/null 2>&1 \
   || curl -fsS -m 5 http://127.0.0.1:3889/ >/dev/null 2>&1; then ok api "gate API answers on :3889"
else bad api "no answer on :3889 — bin/ start-services or scripts/start.sh"; fi

# 3. the well (Mimirsbrunn bridge)
if curl -fsS -m 5 http://127.0.0.1:4602/health >/dev/null 2>&1; then ok well "well bridge answers on :4602"
else bad well "well bridge not answering — see state/mimir-bridge.log"; fi

# 4. the Smiðja database exists and has the schema
if [ -f "$ROOT/smidja/smidja_data/smidja.db" ]; then
  t=$(python3 -c "
import sqlite3,sys
try: print(sqlite3.connect('$ROOT/smidja/smidja_data/smidja.db').execute(\"select count(*) from sqlite_master where type='table'\").fetchone()[0])
except Exception: print(0)" 2>/dev/null || echo 0)
  if [ "${t:-0}" -ge 5 ]; then ok smidja-db "$t tables"
  else bad smidja-db "database present but schema looks empty ($t tables) — bin/smidja-bootstrap.sh"; fi
else
  bad smidja-db "no smidja.db — bin/smidja-bootstrap.sh"
fi

# 5. the skills are bound into the harnesses
if [ -x "$ROOT/bin/valknut-load.sh" ] && bash "$ROOT/bin/valknut-load.sh" --status >/dev/null 2>&1; then
  ok loaders "agents bound into the harnesses"
else
  bad loaders "valknut-load.sh --status reported a problem"
fi

printf 'smoke_test[%s]{check,status,detail}:\n' "${#C[@]}"
for i in "${!C[@]}"; do printf '  "%s","%s","%s"\n' "${C[$i]}" "${S[$i]}" "${D[$i]}"; done
exit "$fail"
