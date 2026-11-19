#!/usr/bin/env bash
# test_ack_holder.sh — the arm's ack door answers its own holder and still refuses a stranger (plan 325 step 3).
#
# Fenced: HOME, the state dir and the machine state dir all point into a throwaway folder, so the real
# queue and the real lock are never read or written. The "sessions" are two `sleep` processes; the
# harness pid is handed in through BROKK_SESSION_PID, the same door a harness uses.
set -u
SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRAIN="$SELF/../saga-wake-drain.sh"
tmp="$(mktemp -d)"
sleep 300 & holder=$!
sleep 300 & stranger=$!
trap 'kill "$holder" "$stranger" 2>/dev/null; rm -rf "$tmp"' EXIT

export HOME="$tmp/home" BROKK_STATE_OVERRIDE="$tmp/state" BROKK_MACHINE_STATE_DIR="$tmp/machine"
unset YMIR_ACK_ANY
mkdir -p "$HOME" "$BROKK_STATE_OVERRIDE" "$BROKK_MACHINE_STATE_DIR"
printf '%s\n' "$holder" > "$BROKK_MACHINE_STATE_DIR/brokk.lock"
printf 'pid=%s state=%s\n' "$holder" "$BROKK_STATE_OVERRIDE" > "$BROKK_STATE_OVERRIDE/.arm.lease"

seed() {  # one wake in the queue, presented by a drain (the snapshot the ack consumes)
  printf '1 2 signal test-wake hello\n' > "$BROKK_STATE_OVERRIDE/.wake-queue"
  cp "$BROKK_STATE_OVERRIDE/.wake-queue" "$BROKK_STATE_OVERRIDE/.wake-drained"
}
pass=0; fail=0
ok()  { echo "ok   $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

# 1 · a stranger's session is refused, and the queue is untouched
seed
out="$(BROKK_SESSION_PID="$stranger" bash "$DRAIN" ack 2>&1)"; rc=$?
[ "$rc" = 3 ] && ok "stranger refused (exit 3)" || bad "stranger: exit $rc — $out"
[ -s "$BROKK_STATE_OVERRIDE/.wake-queue" ] && ok "stranger left the queue whole" || bad "stranger ate the queue"

# 2 · the holder's own session acknowledges with no override
seed
out="$(BROKK_SESSION_PID="$holder" bash "$DRAIN" ack 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "holder acknowledged (exit 0, no YMIR_ACK_ANY)" || bad "holder: exit $rc — $out"
[ ! -s "$BROKK_STATE_OVERRIDE/.wake-queue" ] && ok "holder consumed what was presented" || bad "holder left the wake"

echo "test_ack_holder: $pass passed, $fail failed"
[ "$fail" = 0 ]
