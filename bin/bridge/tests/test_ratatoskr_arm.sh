#!/usr/bin/env bash
# test_ratatoskr_arm.sh — a task for a MACHINE goes to its one arm holder, or is refused by name.
#
# Why this test exists: a task addressed to a machine has no pane to wake, so it must go to
# the single live agent that answers for that machine — and a machine with nobody holding the
# arm must say so instead of sitting on a shelf looking delivered. The two doors this one
# joins are stubbed, so no real holder is ever spoken to.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../ratatoskr-arm.sh"
relay="$here/../ratatoskr-relay.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_ratatoskr_arm"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

me="$(hostname -s 2>/dev/null || hostname)"
mkdir -p "$tmp/home/hodd/data" "$tmp/bin"
cat >"$tmp/home/hodd/data/fleet.json" <<JSON
{"hosts":{"$me":{"user":"someone","tailnet":"$me.example.org"},
          "far-machine":{"user":"someone","tailnet":"far.example.org"}}}
JSON
export YMIR_HOME="$tmp/home"

# the local door: succeeds, fails, or says there is no holder
cat >"$tmp/bin/notify-ok" <<'SH'
#!/usr/bin/env bash
printf 'injected[1]{from,pane,owner}:\n  "ratatoskr","w1:p1","99"\n'; exit 0
SH
cat >"$tmp/bin/notify-none" <<'SH'
#!/usr/bin/env bash
printf 'arm-holder[2]{lock_owner,alive,pane,via}:\n  "0","no","NOT FOUND","nothing matched"\n'; exit 1
SH
chmod +x "$tmp/bin/notify-ok" "$tmp/bin/notify-none"

# the fleet door: hands it on, or answers with the far door's own refusal
cat >"$tmp/bin/fleet-ok" <<'SH'
#!/usr/bin/env bash
printf 'arm-send\thanded\tseat\tto the arm holder on %s; it is delivered when they answer\n' "$1"; exit 0
SH
cat >"$tmp/bin/fleet-none" <<'SH'
#!/usr/bin/env bash
printf 'arm-send\tREFUSED\tnobody holds the arm on %s — nothing was handed\n' "$1"; exit 3
SH
chmod +x "$tmp/bin/fleet-ok" "$tmp/bin/fleet-none"

# 1 · a machine the registry does not know is refused by name, and nothing is handed
out="$(RATATOSKR_NOTIFY_DOOR="$tmp/bin/notify-ok" "$door" a-machine-that-is-not-in-the-registry "hello" 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "an unknown machine exits 1" || bad "an unknown machine exited $rc"
printf '%s' "$out" | grep -q 'is not in the fleet registry' && ok "an unknown machine is named" || bad "unknown: $out"

# 2 · this machine's holder takes the line, and the door says handed, never delivered
out="$(RATATOSKR_NOTIFY_DOOR="$tmp/bin/notify-ok" "$door" "$me" "a line for the holder" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a live holder takes the line" || bad "the holder refused: $out"
printf '%s' "$out" | grep -q 'handed' && ok "the door says handed" || bad "no handed: $out"
printf '%s' "$out" | grep -qi 'delivered only when the holder answers' && ok "the door says what delivered means" || bad "no delivery caveat: $out"

# 3 · no live holder here is a refusal that names the machine, never a silent shelf
out="$(RATATOSKR_NOTIFY_DOOR="$tmp/bin/notify-none" "$door" "$me" "a line for nobody" 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "no live holder exits 1" || bad "no holder exited $rc"
printf '%s' "$out" | grep -q "nobody holds the arm on $me" && ok "no holder is refused by name" || bad "no holder: $out"

# 4 · a far machine's refusal is carried through, not swallowed
out="$(RATATOSKR_ARM_SEND_DOOR="$tmp/bin/fleet-none" "$door" far-machine "a line across" 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "a far refusal exits 1" || bad "far refusal exited $rc"
printf '%s' "$out" | grep -q 'nobody holds the arm on far-machine' && ok "a far refusal keeps its own words" || bad "far refusal: $out"

# 5 · a far machine with a holder hands it over the road
out="$(RATATOSKR_ARM_SEND_DOOR="$tmp/bin/fleet-ok" "$door" far-machine "a line across" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a far holder takes the line" || bad "far holder: $out"

# 6 · the RELAY routes a machine-addressed task to the arm door, and a refusal is a miss
mkdir -p "$tmp/bin"
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = agent ] || exit 0
case "${2:-}" in
  --help) printf 'herdr agent commands:\n  herdr agent prompt <target> <text>\n' ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmp/bin/herdr"
export HDR_BIN="$tmp/bin/herdr"
export RATATOSKR_QUEUE="$tmp/queue"
export YMIR_MACHINE=host-a
printf 'idle\n' >/dev/null
"$here/../ratatoskr.sh" send "far-machine" "a task for a machine" >/dev/null 2>&1
out="$(RATATOSKR_ARM_SEND_DOOR="$tmp/bin/fleet-none" RATATOSKR_ARM_DOOR="$door" "$relay" --once --confirm 0 2>&1)"
printf '%s' "$out" | grep -q 'nobody holds the arm on far-machine' \
  && ok "the relay names a machine with no holder as a miss" || bad "relay arm miss: $out"

printf '\ntest_ratatoskr_arm: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
