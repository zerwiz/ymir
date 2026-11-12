#!/usr/bin/env bash
# test_arm_pin.sh — plan 257 H6: the helm runs the PINNED code, never a working tree.
#
#   1. no runtime.env → the tree's client stands read-only and names why (exit 0)
#   2. a pin with a client → the tree's client hands over to it, BROKK_ROOT_OVERRIDE dropped
#   3. a pin with no client → read-only, named
#   4. the code IS the pin → admitted (arm_pin_admit 0)
#   5. YMIR_ARM_TREE=1 → admitted by the loud override, and it says so
#   6. every harness adapter names the pin's client (arm_pin_client), not only the tree's
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
ARM="$ROOT/bin/pi/syn-watch-arm.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" YMIR_HOME="$T/ymirhome"
unset YMIR_RUNTIME_DIR YMIR_ARM_TREE YMIR_ARM_PINNED 2>/dev/null || true
mkdir -p "$HOME" "$YMIR_HOME/config" "$T/state"
export BROKK_STATE_OVERRIDE="$T/state"

# 1 — no pin configured
out="$(bash "$ARM" --restart 2>&1)"; rc=$?
t "no pin: exit 0 (read-only, never a failure the harness retries)" [ "$rc" -eq 0 ]
t "no pin: the refusal names the missing pin" grep -q 'read-only - helm: refused — no pinned runtime' <<<"$out"

# 2 — a pin whose client is a stub that reports how it was called
PIN="$T/pin"; mkdir -p "$PIN/bin/pi"
cat >"$PIN/bin/pi/syn-watch-arm.sh" <<'STUB'
#!/usr/bin/env bash
printf 'PINNED args=%s override=%s pinned=%s\n' "$*" "${BROKK_ROOT_OVERRIDE-unset}" "${YMIR_ARM_PINNED-unset}"
STUB
chmod +x "$PIN/bin/pi/syn-watch-arm.sh"
printf 'YMIR_RUNTIME_DIR="$HOME/../pin"\nYMIR_RUNTIME_BRANCH="main"\n' >"$YMIR_HOME/config/runtime.env"
out="$(BROKK_ROOT_OVERRIDE="$ROOT" bash "$ARM" --restart 2>&1)"
t "a pin: the tree's client hands over to the pin's" grep -q '^PINNED args=--restart' <<<"$out"
t "a pin: the tree's BROKK_ROOT_OVERRIDE does not follow it" grep -q 'override=unset' <<<"$out"
t "a pin: the hand-over is marked, so it can never loop" grep -q 'pinned=1' <<<"$out"

# 3 — a pin with no client
rm -f "$PIN/bin/pi/syn-watch-arm.sh"
out="$(bash "$ARM" --restart 2>&1)"; rc=$?
t "a pin with no client: exit 0, read-only" [ "$rc" -eq 0 ]
t "a pin with no client: named" grep -q 'has no bin/pi/syn-watch-arm.sh' <<<"$out"

# 4 — the code IS the pin
. "$ROOT/bin/pi/arm-pin-lib.sh"
YMIR_RUNTIME_DIR="$ROOT" arm_pin_admit; rc=$?
t "the code is the pin: admitted" [ "$rc" -eq 0 ]

# 5 — the loud override
YMIR_ARM_TREE=1 arm_pin_admit; rc=$?
t "YMIR_ARM_TREE=1: admitted" [ "$rc" -eq 0 ]
t "YMIR_ARM_TREE=1: it says so" grep -q 'loud override' <<<"$ARM_PIN_REASON"

# 6 — every adapter resolves the pin's client
for a in .claude/hooks/ymir-arm.sh bin/gates/checks/claude-stop-arm.sh .agents/harness/opencode/plugins/syn-watch-arm.js; do
  t "adapter $a calls the pin's client" grep -q 'arm_pin_client' "$ROOT/$a"
done
t "adapter .pi/extensions/gna-pi-watch.ts calls the pin's client" \
  bash -c "git -C '$ROOT' show :.pi/extensions/gna-pi-watch.ts 2>/dev/null | grep -q arm_pin_client || grep -q arm_pin_client '$ROOT/.pi/extensions/gna-pi-watch.ts'"

printf 'test_arm_pin: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
