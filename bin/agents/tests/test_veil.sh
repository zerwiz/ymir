#!/usr/bin/env bash
# test_veil.sh — the arm contract (plan 350 B): an id on every report, RECEIVED from the holder,
# a resend into the holder's pane when no receipt comes, a red past the line, and the answer
# carried back to the sender. Every road is a fake that writes what it was handed; nothing real
# is told.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/doors"
for d in arm pane reply; do
  cat >"$T/doors/$d" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$T/$d.log"
[ -e "$T/$d.refuse" ] && exit 3
exit 0
EOF
  chmod +x "$T/doors/$d"
done
export VEIL_STATE="$T/veil" VEIL_TELL_DOOR="$T/doors/arm" VEIL_PANE_DOOR="$T/doors/pane" VEIL_REPLY_DOOR="$T/doors/reply"
V="$root/bin/agents/veil.sh"
echo "test_veil"

out="$("$V" send --from "agent x" --reply-to "herdr:w1:p1" "built the door; proof: test green" 2>&1)"; rc=$?
id="$(printf '%s\n' "$out" | sed -n '2s/^  "\([^"]*\)".*/\1/p')"
[ "$rc" = 0 ] && [ -n "$id" ] && ok "send prints an id ($id)" || bad "send: rc=$rc $out"
grep -q "\[veil $id\]" "$T/arm.log" 2>/dev/null && ok "the line reaches the arm with its id" || bad "arm log: $(cat "$T/arm.log" 2>/dev/null)"
grep -q "veil.sh received $id" "$T/arm.log" && ok "the line tells the holder how to answer" || bad "no answer hint"
"$V" pending | grep -q "$id" && ok "an unanswered item is pending" || bad "pending missed it"

"$V" received "$id" --by "the helm" >/dev/null 2>&1 && ok "the holder says RECEIVED" || bad "received failed"
"$V" status "$id" | grep -q '"RECEIVED"' && ok "the status reads RECEIVED" || bad "status: $("$V" status "$id")"
grep -q "w1:p1 RECEIVED $id" "$T/reply.log" 2>/dev/null && ok "the sender hears RECEIVED on its own road" || bad "reply log: $(cat "$T/reply.log" 2>/dev/null)"
"$V" pending | grep -q "$id" && bad "a received item still pending" || ok "a received item leaves the pending list"
"$V" rework "$id" >/dev/null 2>&1 && bad "rework without a why was taken" || ok "rework without its why is refused"
"$V" accepted "$id" "proof read" >/dev/null 2>&1 && "$V" status "$id" | grep -q '"ACCEPTED"' && ok "ACCEPTED is recorded" || bad "accepted"
"$V" wait "$id" --timeout 1 >/dev/null 2>&1 && ok "wait returns once received" || bad "wait"

# the arm refuses: the pane takes it at once
touch "$T/arm.refuse"
out="$("$V" send --from "agent y" "second" 2>&1)"
id2="$(printf '%s\n' "$out" | sed -n '2s/^  "\([^"]*\)".*/\1/p')"
printf '%s' "$out" | grep -q '"pane","yes"' && ok "a refused arm falls back to the holder's pane" || bad "fallback: $out"
rm -f "$T/arm.refuse"

# no receipt: the sweep resends once into the pane, then the item is red past the line
out="$("$V" send --from "agent z" --queued "third" 2>&1)"
id3="$(printf '%s\n' "$out" | sed -n '2s/^  "\([^"]*\)".*/\1/p')"
printf '%s' "$out" | grep -q '"queued-by-caller"' && ok "--queued records the id without a second queue line" || bad "queued: $out"
: >"$T/pane.log"
VEIL_RECEIPT_S=0 VEIL_RED_S=99999 "$V" sweep >/dev/null 2>&1
grep -q "$id3" "$T/pane.log" && ok "the sweep resends an unreceived item into the pane" || bad "sweep resend: $(cat "$T/pane.log")"
: >"$T/pane.log"
VEIL_RECEIPT_S=0 VEIL_RED_S=99999 "$V" sweep >/dev/null 2>&1
grep -q "$id3" "$T/pane.log" && bad "the sweep resent twice" || ok "an item is resent once, not every sweep"
VEIL_RED_S=0 "$V" sweep >/dev/null 2>&1; rc=$?
[ "$rc" = 1 ] && ok "an item past the red line makes the sweep red" || bad "sweep rc=$rc"
"$V" pending --json | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if len(d["items"])==2 else 1)' \
  && ok "pending --json counts the two unreceived items" || bad "pending json: $("$V" pending --json)"
"$V" received nope >/dev/null 2>&1; [ $? = 3 ] && ok "an unknown id is exit 3" || bad "unknown id"
[ "$(wc -l <"$VEIL_STATE/ledger.jsonl")" -ge 10 ] && ok "the ledger only grows" || bad "ledger short"
: "$id2"

# a steer to a Hermes session whose gateway is down: tell.sh refuses, the Hermes command line carries it
cat >"$T/doors/hermes" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$T/hermes.log"
EOF
chmod +x "$T/doors/hermes"
touch "$T/reply.refuse"
out="$(VEIL_HERMES_CLI="$T/doors/hermes" "$V" steer --to hermes:s123 --from "the helm" "check the build" 2>&1)"
sid="$(printf '%s\n' "$out" | sed -n '2s/^  "\([^"]*\)".*/\1/p')"
grep -q -- "--resume s123 -z .*\[veil $sid\] steer: check the build" "$T/hermes.log" 2>/dev/null \
  && ok "a steer reaches a Hermes session through its command line when the gateway is down" || bad "hermes steer: $out / $(cat "$T/hermes.log" 2>/dev/null)"
"$V" pending | grep -q "$sid" && bad "a steer counts against the holder's receipts" || ok "a steer is not the holder's receipt to give"
"$V" received "$sid" --by "hermes s123" >/dev/null 2>&1 && "$V" status "$sid" | grep -q RECEIVED && ok "the steered agent says RECEIVED" || bad "steer receipt"
# a report from Hermes is answered back into its session the same way
out="$("$V" send --from "hermes s123" --reply-to hermes:s123 "built the page" 2>&1)"
hid="$(printf '%s\n' "$out" | sed -n '2s/^  "\([^"]*\)".*/\1/p')"
VEIL_HERMES_CLI="$T/doors/hermes" "$V" received "$hid" --by helm >/dev/null 2>&1
grep -q -- "--resume s123 -z .*RECEIVED $hid" "$T/hermes.log" && ok "Hermes hears RECEIVED in its own session" || bad "hermes receipt: $(cat "$T/hermes.log")"
rm -f "$T/reply.refuse"

# a worker seat's private state is not where the arm reads: the ledger follows the helm's state
mkdir -p "$T/seat" "$T/helm"
( unset VEIL_STATE
  BROKK_STATE_OVERRIDE="$T/seat" BROKK_MACHINE_STATE_DIR="$T/seat" YMIR_STATE_DIR="$T/helm" "$V" send --queued --from "agent s" "seat" >/dev/null 2>&1 )
[ -s "$T/helm/veil/ledger.jsonl" ] && [ ! -e "$T/seat/veil" ] && ok "a seat's private state is skipped: the ledger is the arm's" || bad "ledger landed in the seat"
echo "test_veil: $pass passed, $fail failed"
[ "$fail" = 0 ]
