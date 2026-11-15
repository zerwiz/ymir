#!/usr/bin/env bash
# test_agent_state.sh — the launcher reads herdr's own word before and after it speaks (plan 291 row 5).
#
# Why this test exists: `herdr agent start` returns when the pane HOLDS an agent, not when the
# harness can take input. Measured 2026-11-14: two hand-seated workers sat idle because the first
# prompt was typed at a harness that was still booting. The launcher now waits for
# `interactive_ready`, sends the prompt, and confirms the agent MOVED — retrying once.
#
# A stub `herdr` answers here, so the test says exactly what the reader does with each answer, and
# the real machine is never touched.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib="$here/../agent-state-lib.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_agent_state"
[ -r "$lib" ] || { bad "the lib is missing: $lib"; exit 1; }

# a stub herdr: `agent get <ref>` answers whatever $STUB_JSON names, `agent get absent` answers nothing
mkdir -p "$tmp/bin"
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "agent" ] && [ "${2:-}" = "get" ] || exit 0
[ "${3:-}" = "absent" ] && exit 1
cat "$STUB_JSON" 2>/dev/null
SH
chmod +x "$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH"
export STUB_JSON="$tmp/agent.json"

# shellcheck source=/dev/null
. "$lib"

# 1 · interactive_ready true → ready
printf '{"result":{"agent":{"agent_status":"idle","interactive_ready":true}}}\n' >"$STUB_JSON"
agent_ready pane && ok "interactive_ready=true is ready" || bad "a ready agent was read as not ready"
[ "$(agent_state pane)" = idle ] && ok "the state is herdr's own word" || bad "state read $(agent_state pane)"

# 2 · interactive_ready false → NOT ready (the measured fault: start returned, the box was not drawn)
printf '{"result":{"agent":{"agent_status":"idle","interactive_ready":false}}}\n' >"$STUB_JSON"
agent_ready pane && bad "a not-ready agent was read as ready" || ok "interactive_ready=false is not ready"

# 3 · no interactive_ready field at all → a harness with no detection is not made to wait
printf '{"result":{"agent":{"agent_status":"idle"}}}\n' >"$STUB_JSON"
agent_ready pane && ok "a harness with no interactive detection is past ready" \
  || bad "a harness without the field was blocked for ever"

# 4 · working, done → past ready, whichever the field says
for st in working done; do
  printf '{"result":{"agent":{"agent_status":"%s","interactive_ready":false}}}\n' "$st" >"$STUB_JSON"
  agent_ready pane && [ "$(agent_state pane)" = "$st" ] && ok "$st is read as $st and past ready" \
    || bad "$st was misread"
done

# 5 · no answer from herdr → unknown, and readiness is NO (a blind reader may not claim ready)
agent_ready absent && bad "an absent agent was read as ready" || ok "an agent herdr cannot see is not ready"
[ "$(agent_state absent)" = unknown ] && ok "an absent agent reads as unknown" || bad "state of an absent agent is $(agent_state absent)"

# 6 · herdr absent entirely → unknown, not a hang
( PATH=/usr/bin:/bin; export PATH; unset STUB_JSON
  # shellcheck source=/dev/null
  . "$lib"
  [ "$(agent_state pane)" = unknown ] ) && ok "herdr absent reads as unknown, never a hang" \
  || bad "herdr absent did not answer unknown"

printf 'test_agent_state: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
