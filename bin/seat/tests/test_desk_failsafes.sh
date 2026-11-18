#!/usr/bin/env bash
# test_desk_failsafes.sh — prove the five failsafes of plan 001 §4 (the dead desk) without a desk.
#
# Every case here runs on a temp state dir and a saved `herdr agent list` document, so no real pane, no
# real unit and no real alarm is touched. What it proves is the JUDGEMENT each door makes:
#
#   F1  the ceiling is sized from the machine's own numbers, and the drop-in says so
#       the scope wrapper reports a clean skip rather than failing where it cannot scope
#   F2  an inventory written from a claim, and a verdict that asks the MACHINE (a pane whose agent
#       process is gone reads `shell`, and `lost` names it; a pane with a live process reads `live`)
#   F4  a dead transport pid is released at once, a live one is refused
#   F3  a caller with no agent harness in its process tree is refused the helm, with the reason
#   F5  a death line is said exactly once — a second run is `suppressed`
#
# Run: bash bin/seat/tests/test_desk_failsafes.sh
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n     %s\n' "$1" "${2:-}"; }
has() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3" "want '$2' in: $(printf '%s' "$1" | head -3 | tr '\n' ' ')" ;; esac; }

# ── F1 · the ceiling is arithmetic on the machine's numbers ───────────────────
CEIL="$(YMIR_DESK_FREE_MB=11869 YMIR_DESK_SWAP_MB=4095 bash "$ROOT/bin/seat/desk-ceiling.sh" choose 2>&1)"
has "$CEIL" '"herdr-server.service","11869"' "F1 choose reads the measured total"
has "$CEIL" '3560' "F1 MemoryHigh is 30% of the measured total (3560 MB of 11869)"
has "$CEIL" '4747' "F1 MemoryMax is 40% of the measured total (4747 MB of 11869)"
has "$CEIL" '1023' "F1 MemorySwapMax is 25% of the measured swap (1023 MB of 4095)"
has "$CEIL" 'OOMPolicy' "F1 the rule names OOMPolicy, without which a killed child still stops the desk"

D="$T/unit.d"
YMIR_DESK_FREE_MB=11869 YMIR_DESK_SWAP_MB=4095 YMIR_DESK_DROPIN_DIR="$D" \
  bash "$ROOT/bin/seat/desk-ceiling.sh" dropin >/dev/null 2>&1
CONF="$(cat "$D/20-desk-ceiling.conf" 2>/dev/null)"
has "$CONF" 'MemoryMax=4747M' "F1 the drop-in carries the ceiling"
has "$CONF" 'OOMPolicy=continue' "F1 the drop-in stops systemd killing the desk for one child"

SCOPE="$(YMIR_AGENT_SCOPE=0 bash "$ROOT/bin/seat/agent-scope.sh" --check 2>&1)"
has "$SCOPE" 'clean skip' "F1 a host that cannot scope says so instead of pretending"
has "$SCOPE" 'ABSENT' "F1 the clean skip names the failsafe as absent"

# ── F2 · the inventory asks the machine, not the desk ────────────────────────
# A real process whose comm is `pi` (a copy of sleep under that name) stands in one worktree; a second
# pane's agent has no process at all — the exact shape of the 07:21 death.
mkdir -p "$T/live-cwd" "$T/dead-cwd"
cp "$(command -v sleep)" "$T/pi" 2>/dev/null && chmod +x "$T/pi"
( cd "$T/live-cwd" && "$T/pi" 60 >/dev/null 2>&1 & )
sleep 1

cat >"$T/agents.json" <<JSON
{"result":{"agents":[
 {"agent":"pi","agent_status":"idle","cwd":"$T/live-cwd","foreground_cwd":"$T/live-cwd","pane_id":"w1:p1","workspace_id":"w1","agent_session":{"agent":"pi","kind":"path","source":"herdr:pi","value":"$T/live.jsonl"}},
 {"agent":"pi","agent_status":"idle","cwd":"$T/dead-cwd","foreground_cwd":"$T/dead-cwd","pane_id":"w2:p1","workspace_id":"w2","agent_session":{"agent":"pi","kind":"path","source":"herdr:pi","value":"$T/dead.jsonl"}}
]}}
JSON
: >"$T/live.jsonl"; : >"$T/dead.jsonl"

export YMIR_STATE_DIR="$T/state"
export YMIR_DESK_INVENTORY="$T/state/desk-inventory.json"
export YMIR_DESK_AGENTS_JSON="$T/agents.json"
mkdir -p "$YMIR_STATE_DIR"

CHECK="$(bash "$ROOT/bin/seat/desk-inventory.sh" check 2>&1)"
has "$CHECK" '"w1:p1","idle","live"' "F2 a pane with a standing agent process reads live"
has "$CHECK" '"w2:p1","idle","shell"' "F2 a pane the desk calls idle but nothing runs in reads shell"
has "$CHECK" '"2","1","1"' "F2 the verdict counts one live and one shell"

SAVE="$(bash "$ROOT/bin/seat/desk-inventory.sh" save 2>&1)"
has "$SAVE" '"1"' "F2 the snapshot keeps only the pane that holds a live agent"

LOST="$(bash "$ROOT/bin/seat/desk-inventory.sh" lost 2>&1)"; LOST_RC=$?
has "$LOST" '"1","1","0"' "F2 nothing is lost while that agent stands"
[ "$LOST_RC" -eq 0 ] && ok "F2 lost exits 0 when the desk is whole" || bad "F2 lost exits 0 when the desk is whole" "rc=$LOST_RC"

# Now the death: the agent process goes away, the pane stays, the desk still says idle.
pkill -f "$T/pi" >/dev/null 2>&1; sleep 1
LOST="$(bash "$ROOT/bin/seat/desk-inventory.sh" lost 2>&1)"; LOST_RC=$?
has "$LOST" 'the pane holds a shell, not an agent' "F2 after the process dies the pane is named as lost"
[ "$LOST_RC" -eq 1 ] && ok "F2 lost exits 1 when a hand is gone" || bad "F2 lost exits 1 when a hand is gone" "rc=$LOST_RC"

WATCH="$(bash "$ROOT/bin/seat/desk-watch.sh" check 2>&1)"; WATCH_RC=$?
has "$WATCH" '"lost","1","' "F2 the watcher reports one lost hand"
has "$WATCH" 'the desk lost 1 hand(s) to a restart' "F2 the operator gets ONE line, not a per-pane dribble"
[ "$WATCH_RC" -eq 1 ] && ok "F2 check exits 1 while a hand is missing" || bad "F2 check exits 1 while a hand is missing" "rc=$WATCH_RC"

# ── F5 · exactly one message per event ──────────────────────────────────────
export YMIR_DESK_NOTIFY_SEEN="$T/state/desk-notify.seen"
export YMIR_DESK_NOTIFY_SINK="$T/state/sink.txt"
N1="$(bash "$ROOT/bin/seat/desk-notify.sh" --kind panes-lost --message "one hand lost" 2>&1)"
N2="$(bash "$ROOT/bin/seat/desk-notify.sh" --kind panes-lost --message "one hand lost" 2>&1)"
has "$N1" 'said — one message' "F5 the first run says it"
has "$N2" 'suppressed — already said' "F5 the same death is never said twice"
[ "$(wc -l <"$T/state/sink.txt" 2>/dev/null || echo 0)" = "1" ] \
  && ok "F5 the sink holds exactly one line" \
  || bad "F5 the sink holds exactly one line" "$(cat "$T/state/sink.txt" 2>/dev/null)"

# ── F4 · a stale transport is released at once, a live one is refused ───────
DEAD_PID=999999
cat >"$T/tg-state.json" <<JSON
{"version":2,"profiles":{"default":{"transport":{"pid":$DEAD_PID,"cwd":"/tmp","instanceId":"$DEAD_PID:1"},"workspace":{"version":1}}}}
JSON
export YMIR_TELEGRAM_STATE="$T/tg-state.json"
REL="$(bash "$ROOT/bin/notify/telegram-transport.sh" release 2>&1)"; REL_RC=$?
has "$REL" '"yes"' "F4 a dead transport pid is released"
has "$REL" 'released at once, no wait' "F4 the reason names the fault it removes"
[ "$REL_RC" -eq 0 ] && ok "F4 release exits 0" || bad "F4 release exits 0" "rc=$REL_RC"
grep -q '"transport"' "$T/tg-state.json" \
  && bad "F4 the transport key is gone from the state document" "$(cat "$T/tg-state.json")" \
  || ok "F4 the transport key is gone from the state document"
grep -q '"workspace"' "$T/tg-state.json" \
  && ok "F4 the rest of the document is left alone" \
  || bad "F4 the rest of the document is left alone" "$(cat "$T/tg-state.json")"

cat >"$T/tg-live.json" <<JSON
{"version":2,"profiles":{"default":{"transport":{"pid":$$,"cwd":"/tmp"}}}}
JSON
export YMIR_TELEGRAM_STATE="$T/tg-live.json"
LIVE="$(bash "$ROOT/bin/notify/telegram-transport.sh" release 2>&1)"; LIVE_RC=$?
has "$LIVE" 'REFUSED' "F4 a live holder is never released by another session"
[ "$LIVE_RC" -eq 3 ] && ok "F4 the refusal is exit 3, not a silent success" || bad "F4 the refusal is exit 3" "rc=$LIVE_RC"
grep -q '"transport"' "$T/tg-live.json" && ok "F4 the live transport is still recorded" || bad "F4 the live transport is still recorded" ""

# ── F3 · a caller with no agent harness cannot hold the helm ────────────────
GUARD="$(sed -n '/── THE SPEECH GATE/,/THE HOLDER GATE/p' "$ROOT/bin/voice/rodd-arm.sh")"
has "$GUARD" 'session-pid --shell-pid' "F3 the gate asks the lock module who can speak (one implementation)"
has "$GUARD" 'cannot speak' "F3 the refusal says the session cannot speak"

# A caller with no harness ancestor: the same shape as `ymir_runtime watch run` under systemd, which is
# the shape that held the heart's arm all morning on 2026-11-17. A transient SERVICE (not a scope) is
# used because its parent is the user manager, not this shell.
mkdir -p "$T/state"
if command -v systemd-run >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
  OUT="$(YMIR_STATE_DIR="$T/state" systemd-run --user --wait --pipe --quiet \
        bash -c "cd '$ROOT' && RODD_ARM_LEASE='$T/state/.arm.lease' bash bin/voice/rodd-arm.sh hold" 2>&1)"; RC=$?
  has "$OUT" 'cannot speak' "F3 a watcher-shaped caller IS refused the helm"
  has "$OUT" 'no agent harness stands in its process tree' "F3 the refusal names the missing fact"
  has "$OUT" 'no model heartbeat' "F3 the refusal names why a watcher cannot answer a tell"
  [ "$RC" -ne 0 ] && ok "F3 the refusal is a non-zero exit" || bad "F3 the refusal is a non-zero exit" "rc=$RC"
else
  printf 'skip F3 on-machine case: no systemd user manager here (the gate text above is still asserted)\n'
fi

# ── F3b · an unanswered tell past its deadline escalates, once ──────────────
# A SINK, so this test can never alarm the Allfather: the door writes the escalation to a file instead of
# handing it to bin/notify/send.sh. (Learned at the cost of three synthetic HIGH lines on 2026-11-17.)
export YMIR_RODD_ESCALATE_SINK="$T/state/escalations.txt"
OLD=$(( $(date +%s) - 900 ))
printf '%s\t1\tsignal\trodd-%s\tsomebody to the arm holder: the window is too wide\n' "$OLD" "$OLD" >"$T/state/.wake-queue"
LIST="$(YMIR_STATE_DIR="$T/state" BROKK_WAKE_QUEUE="$T/state/.wake-queue" bash "$ROOT/bin/voice/rodd-tell-deadline.sh" list --deadline 300 2>&1)"
has "$LIST" 'rodd-' "F3b an unacknowledged tell past its deadline is found"
has "$LIST" '"expired"' "F3b the verdict is expired, not quiet"
DRY="$(YMIR_STATE_DIR="$T/state" BROKK_WAKE_QUEUE="$T/state/.wake-queue" bash "$ROOT/bin/voice/rodd-tell-deadline.sh" check --deadline 300 --dry-run 2>&1)"
if printf '%s' "$DRY" | grep -q 'would escalate'; then ok "F3b the escalation is composed for the operator"
else bad "F3b the escalation is composed for the operator" "$(printf '%s' "$DRY" | tail -4 | tr '\n' ' ')"; fi
SAID="$(YMIR_STATE_DIR="$T/state" BROKK_WAKE_QUEUE="$T/state/.wake-queue" bash "$ROOT/bin/voice/rodd-tell-deadline.sh" check --deadline 300 2>&1)"
[ -s "$YMIR_RODD_ESCALATE_SINK" ] && ok "F3b an expired tell reaches the escalation sink" || bad "F3b an expired tell reaches the escalation sink" "$SAID"
AGAIN="$(YMIR_STATE_DIR="$T/state" BROKK_WAKE_QUEUE="$T/state/.wake-queue" bash "$ROOT/bin/voice/rodd-tell-deadline.sh" check --deadline 300 2>&1)"
[ "$(wc -l <"$YMIR_RODD_ESCALATE_SINK")" = "1" ] && ok "F3b one tell escalates exactly once" || bad "F3b one tell escalates exactly once" "$(cat "$YMIR_RODD_ESCALATE_SINK")"
LISTED="$(YMIR_STATE_DIR="$T/state" BROKK_WAKE_QUEUE="$T/state/.wake-queue" bash "$ROOT/bin/voice/rodd-tell-deadline.sh" list --deadline 300 2>&1)"
case "$LISTED" in *'would escalate'*) bad "F3b list never escalates" "$LISTED" ;; *) ok "F3b list never escalates" ;; esac
FRESH="$(( $(date +%s) - 5 ))"
printf '%s\t2\tsignal\trodd-%s\tfive seconds ago\n' "$FRESH" "$FRESH" >>"$T/state/.wake-queue"
QUIET="$(YMIR_STATE_DIR="$T/state" BROKK_WAKE_QUEUE="$T/state/.wake-queue" bash "$ROOT/bin/voice/rodd-tell-deadline.sh" check --deadline 300 --dry-run 2>&1)"
case "$QUIET" in *"five seconds ago"*) bad "F3b a tell inside its deadline is left alone" "$QUIET" ;; *) ok "F3b a tell inside its deadline is left alone" ;; esac

printf '\ntest_desk_failsafes: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
