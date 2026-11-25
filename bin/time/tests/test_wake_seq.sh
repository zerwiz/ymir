#!/usr/bin/env bash
# test_wake_seq.sh — a wake the helm was not shown is never acknowledged away (plan 369 item 16).
# A copy of the drain runs in a scratch tree and scratch state; the real queue is never read.
set -u
ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"
TREE="$T/tree"; S="$T/state"; M="$T/machine"
mkdir -p "$TREE/bin" "$TREE/.pi" "$TREE/RULES" "$S" "$M"
cp -R "$ROOT/bin/time" "$ROOT/bin/vault" "$ROOT/bin/records" "$ROOT/bin/fleet" "$TREE/bin/"
ln -s "$ROOT/src" "$TREE/src"
sleep 300 & OTHER=$!
trap 'kill "$OTHER" 2>/dev/null; rm -rf "$T"' EXIT
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }
Q="$S/.wake-queue"
line() { printf '1700000000\t%s\tsignal\t%s\t%s\tclass=report\n' "$1" "$2" "$3"; }
drain() {
  env -i PATH="$PATH" HOME="$T" XDG_STATE_HOME="$T/xdg" YMIR_HOME="$T/home" BROKK_STATE_OVERRIDE="$S" \
    BROKK_MACHINE_STATE_DIR="$M" "$@" 2>&1
}
D="$TREE/bin/time/saga-wake-drain.sh"

# 1 · a wake that arrives while the drain is printing survives the ack (the open-work line runs after printing)
cat > "$TREE/bin/records/open-work.sh" <<X
#!/usr/bin/env bash
printf '1700000001\t2\tsignal\tlate\tfiled while the drain printed\tclass=report\n' >> "$Q"
printf '{"items":[]}\n'
X
chmod +x "$TREE/bin/records/open-work.sh"
line 1 early "shown to the helm" > "$Q"
out="$(drain bash "$D" drain)"
case "$out" in *"shown to the helm"*) ok "the queued wake is shown" ;; *) no "not shown: $out" ;; esac
drain bash "$D" ack >/dev/null
grep -q 'filed while the drain printed' "$Q" 2>/dev/null && ! grep -q 'shown to the helm' "$Q" \
  && ok "the late wake stays queued; only the shown one is consumed" || no "queue after ack: $(cat "$Q" 2>/dev/null)"

# 2 · a session that may not ack writes no record, so the holder's record stands
rm -f "$TREE/bin/records/open-work.sh" "$S"/.wake-drained "$Q"
printf '%s\n' "$OTHER" > "$M/brokk.lock"
printf 'role=helm state=%s \n' "$S" > "$S/.arm.lease"
line 3 first "the holder saw this" > "$S/.wake-drained"
{ line 3 first "the holder saw this"; line 4 second "nobody saw this yet"; } > "$Q"
drain bash "$D" drain >/dev/null
[ "$(grep -c . "$S/.wake-drained")" = 1 ] && ok "a stranger's drain leaves the holder's record" || no "record: $(cat "$S/.wake-drained")"
drain bash "$D" ack >/dev/null; rc=$?
[ "$rc" = 3 ] && [ "$(grep -c . "$Q")" = 2 ] && ok "a stranger's ack is refused" || no "stranger ack rc=$rc"
drain YMIR_ACK_ANY=1 bash "$D" ack >/dev/null
[ "$(cut -f4 "$Q")" = second ] && ok "the ack consumes exactly the holder's record" || no "queue: $(cat "$Q")"
rm -f "$S/.arm.lease" "$M/brokk.lock" "$Q" "$S/.wake-drained"

# 3 · appends racing many acks: every wake is either shown or still queued
( for i in $(seq 1 600); do line "$i" "k$i" "wake-$i." >> "$Q"; sleep 0.005; done; touch "$T/done" ) & writer=$!
: > "$T/shown"
while [ ! -f "$T/done" ]; do drain bash "$D" drain --full >> "$T/shown"; drain bash "$D" ack >/dev/null; done
wait "$writer"
cat "$Q" >> "$T/shown" 2>/dev/null
lost=0; for i in $(seq 1 600); do grep -qF "wake-$i." "$T/shown" || lost=$((lost+1)); done
[ "$lost" = 0 ] && ok "600 wakes appended during repeated acks, none lost" || no "$lost of 600 wakes lost"

[ "$fail" = 0 ] && echo "test_wake_seq: PASS" || echo "test_wake_seq: FAIL"
exit "$fail"
