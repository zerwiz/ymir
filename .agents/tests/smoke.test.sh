#!/usr/bin/env bash
# smoke.test.sh — the repo smoke test. Boots the Brokk runtime lifecycle and
# asserts it holds together. Galdr-style TOON output; exit 1 on any failure.
#
# Usage: bash .agents/tests/smoke.test.sh [--quiet] ; --version
set -u

VERSION="1.0.0"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$TEST_DIR/../.." && pwd)"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac
QUIET=0; [ "${1-}" = "--quiet" ] && QUIET=1

export BROKK_HOME="$ROOT"
export BROKK_ROOT_OVERRIDE="$ROOT"
export BROKK_CONFIG_OVERRIDE="$ROOT/.agents/config"
export BROKK_STATE_OVERRIDE="$ROOT/state"
export BROKK_SESSION_PID="$$"
STATE="$BROKK_STATE_OVERRIDE"
declare -a STEP S; fails=0
add() { STEP+=("$1"); S+=("$2"); [ "$2" = FAIL ] && fails=$((fails + 1)); }
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$1"; }

# 1. loader resolves agents
if [ -f "$ROOT/bin/valknut-load.sh" ] && bash "$ROOT/bin/valknut-load.sh" --status >/dev/null 2>&1; then
  add "loaders" OK
else
  add "loaders" FAIL
fi

# 2. Sága digest runs (starts Nornir + lock)
if out=$(bash "$ROOT/bin/saga-session-start.sh" 2>&1); then
  add "saga digest" OK
else
  add "saga digest" FAIL
fi

# 3. lock present and held by a live session (or this test)
owner=$(tr -d "[:space:]" <"$STATE/.lock" 2>/dev/null)
if [ -n "$owner" ] && { [ "$owner" = "$$" ] || kill -0 "$owner" 2>/dev/null; }; then
  add "gleipnir lock" OK
else
  add "gleipnir lock" FAIL
fi

# 4. Nornir cron running
if bash "$ROOT/bin/nornir-cron-start.sh" --status 2>/dev/null | grep -q 'running'; then
  add "nornir cron" OK
else
  add "nornir cron" FAIL
fi

# 5. Sýn arms and exits on a signal
touch "$STATE/smoke.signal"
if out=$(timeout 8 bash "$ROOT/bin/syn-watch-arm.sh" --restart 2>&1) && printf '%s' "$out" | grep -q '^signal:'; then
  add "syn watch-arm" OK
else
  add "syn watch-arm" FAIL
fi
rm -f "$STATE/smoke.signal" "$STATE/.supervision-armed"

# 6. turn-end guard inert when not armed
if echo '{}' | bash "$ROOT/bin/syn-turnend-guard.sh"; then
  add "syn guard inert" OK
else
  add "syn guard inert" FAIL
fi

# 7. Galdr/Tyr compliance
if bash "$ROOT/.agents/skills/galdr/scripts/compliance-check.sh" >/dev/null 2>&1; then
  add "galdr compliance" OK
else
  add "galdr compliance" FAIL
fi

# 8. config resolves under .agents/config
if [ -f "$BROKK_CONFIG_OVERRIDE/cron.yaml" ] && [ -f "$BROKK_CONFIG_OVERRIDE/ro" ]; then
  add "config repo-local" OK
else
  add "config repo-local" FAIL
fi

if [ "$QUIET" = 0 ]; then
  printf 'smoke[%s]{step,status}:\n' "${#STEP[@]}"
  for i in "${!STEP[@]}"; do printf '  "%s","%s"\n' "${STEP[$i]}" "${S[$i]}"; done
fi
if [ "$fails" -gt 0 ]; then
  printf 'error: %s smoke step(s) failed\n' "$fails" >&2
  exit 1
fi
exit 0
