#!/usr/bin/env bash
# well-door.test.sh — the well answers on every role, and it says which road answered.
#
# The fault this test exists for (2026-10-28): `bin/bridge/mimir-bridge.sh --start`
# printed "error: engram not installed for python3.13" and exited 1 on the Allfather's
# phone — the one device he carries — so the well was dark at every session start while
# a clean skip counted as a pass. Agnostic was satisfied; the fleet was not (RULES/25,
# its 2026-10-28 section).
#
# What is proven here, with no network and no engine:
#   1. `--status` is a TOPN row, always, whatever the state        (never a crash)
#   2. no engine + no door  -> exit 1 and stderr NAMES the door and the repair
#   3. a borrowed door        -> exit 0, row says "door","borrowed from the heart"
#   4. `--status` distinguishes local from borrowed                (up (local) / up (door))
#
# Exit: 0 all pass · 1 a check failed · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIDGE="$ROOT/bin/bridge/mimir-bridge.sh"
[ -x "$BRIDGE" ] || { printf 'error: no bridge at %s\n' "$BRIDGE" >&2; exit 2; }

PORT="${WELL_TEST_PORT:-4699}"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"; [ -n "${SRV_PID:-}" ] && kill "$SRV_PID" 2>/dev/null' EXIT
fails=0
say() { printf '  %-42s %s\n' "$1" "$2"; }
check() { # <name> <ok 0|1> <detail>
  if [ "$2" = 0 ]; then say "$1" PASS; else say "$1" "FAIL ($3)"; fails=$((fails+1)); fi
}

export YMIR_STATE_DIR="$STATE" MIMIRSBRUNN_PORT="$PORT"
export ENGRAM_DB="$STATE/well.engram"

# 3+4 first: a listener with NO pid file is a borrowed door to the bridge's eyes.
python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SRV_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && break; sleep 0.3
done

out=$(bash "$BRIDGE" --status 2>&1)
case "$out" in *up\ \(door\)*) check "a borrowed door reports 'up (door)'" 0 ;; *) check "a borrowed door reports 'up (door)'" 1 "$out" ;; esac

printf '%s\n' "$SRV_PID" >"$STATE/mimir-bridge.pid"
out=$(bash "$BRIDGE" --status 2>&1)
case "$out" in *up\ \(local\)*) check "an owned process reports 'up (local)'" 0 ;; *) check "an owned process reports 'up (local)'" 1 "$out" ;; esac
rm -f "$STATE/mimir-bridge.pid"

# 1: status is a row even with nothing listening anywhere.
kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; SRV_PID=""
out=$(bash "$BRIDGE" --status 2>&1)
case "$out" in *'"down"'*) check "a silent port reports 'down' as a row" 0 ;; *) check "a silent port reports 'down' as a row" 1 "$out" ;; esac

# 2: no engine, no door -> the refusal names the door and the repair (never a bare skip).
err=$(YMIR_ENGRAM_PYTHON="/nonexistent-python" bash "$BRIDGE" --start 2>&1 >/dev/null)
rc=$?
[ "$rc" = 1 ] && check "no engine and no door exits 1" 0 || check "no engine and no door exits 1" 1 "rc=$rc"
case "$err" in *"no local engine"*) check "the refusal names the missing engine" 0 ;; *) check "the refusal names the missing engine" 1 "$err" ;; esac
case "$err" in *"well-door.sh status"*) check "the refusal names the repair" 0 ;; *) check "the refusal names the repair" 1 "$err" ;; esac

if [ "$fails" = 0 ]; then printf 'well-door: PASS\n'; exit 0; fi
printf 'well-door: %s FAILED\n' "$fails" >&2; exit 1
