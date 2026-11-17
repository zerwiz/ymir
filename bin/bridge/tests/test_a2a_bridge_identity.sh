#!/usr/bin/env bash
# test_a2a_bridge_identity.sh — every session's bridge names itself, from its own environment.
#
# Why this test exists: every bridge was spawned with the same name, the same id, the same
# state dir and `127.0.0.1` as its address. Two sessions on one machine collided on the port,
# shared one inbox, and a non-pi agent was called `brokk-…` — which is a lie about which
# harness is answering (RULES/44) and a card no other machine can dial. The identity is read
# from the environment here, and nothing is spawned: the door has a --dry face for exactly
# this.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../a2a-bridge-session.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_a2a_bridge_identity"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

export HOME="$tmp/home"; mkdir -p "$HOME"
mkdir -p "$tmp/home/hodd/data"
cat >"$tmp/home/hodd/data/fleet.json" <<'JSON'
{"hosts":{"host-a":{"user":"someone","tailnet":"host-a.example.org"},
          "host-b":{"user":"someone","tailnet":"host-b.example.org"}}}
JSON
me="$(hostname -s 2>/dev/null || hostname)"
python3 - "$tmp/home/hodd/data/fleet.json" "$me" <<'PY'
import json, sys
p, me = sys.argv[1], sys.argv[2]
d = json.load(open(p)); d["hosts"][me] = {"user": "someone", "tailnet": "host-a.example.org"}
json.dump(d, open(p, "w"))
PY
export YMIR_HOME="$tmp/home"

# 1 · a pi session in a pane is named for its harness AND its pane
out="$(HERDR_PANE_ID=w1:p2 PI_SESSION_ID=abc-123 "$door" --identity 2>&1)"
printf '%s' "$out" | grep -q '"pi","pi-w1-p2"' && ok "a pi session is named pi-<pane>" || bad "identity: $out"

# 2 · a non-pi harness is never called brokk, and carries its own harness name
out="$(HERDR_PANE_ID=w3:p4 A2A_HARNESS=claude "$door" --identity 2>&1)"
printf '%s' "$out" | grep -q '"claude","claude-w3-p4"' && ok "a claude session is named claude-<pane>" || bad "claude: $out"
printf '%s' "$out" | grep -q 'brokk' && bad "a claude bridge was named brokk" || ok "no non-pi bridge is named brokk (RULES/44)"

# 3 · a hermes session names itself too
out="$(A2A_HARNESS=hermes HERMES_SESSION_ID=local-abc "$door" --identity 2>&1)"
printf '%s' "$out" | grep -q '"hermes","hermes-' && ok "a hermes session is named for hermes" || bad "hermes: $out"

# 4 · a harness nobody can name says `unknown`, never an invented one
out="$(env -u PI_SESSION_ID -u BROKK_SESSION_ID -u A2A_HARNESS -u CLAUDE_SESSION_ID -u HERMES_HOME -u CODEX_HOME HERDR_PANE_ID=w9:p9 "$door" --identity 2>&1)"
printf '%s' "$out" | grep -q '"unknown","unknown-w9-p9"' && ok "an unnamed harness is unknown, not brokk" || bad "unknown: $out"

# 5 · on a fleet seat the address is the registry's name, never loopback
out="$(HERDR_PANE_ID=w1:p2 "$door" --identity 2>&1)"
printf '%s' "$out" | grep -q '"host-a.example.org"' && ok "the fleet seat advertises its registry name" || bad "advertise: $out"
printf '%s' "$out" | grep -q '127.0.0.1' && bad "a fleet seat advertised loopback" || ok "a fleet seat never advertises loopback"

# 6 · a lone box advertises loopback, because that is the truth there
out="$(YMIR_HOME="$tmp/nohome" HERDR_PANE_ID=w1:p2 "$door" --identity 2>&1)"
printf '%s' "$out" | grep -q '"127.0.0.1"' && ok "a box with no registry advertises loopback" || bad "lone box: $out"

# 7 · --dry prints the exact argv, and claims no port
out="$(HERDR_PANE_ID=w1:p2 "$door" --dry 2>&1)"
printf '%s' "$out" | grep -q '^-name$' && printf '%s' "$out" | grep -q '^pi-w1-p2$' \
  && ok "--dry prints the argv it would run" || bad "dry: $out"
[ -z "$(ls -A "$HOME/.a2abridge/ports" 2>/dev/null)" ] && ok "--dry claims no port" || bad "--dry left a reservation"

# 8 · a dead port reservation is swept, and the span is not exhausted by graveyards
mkdir -p "$HOME/.a2abridge/ports/8391" "$HOME/.a2abridge/ports/8392"
printf '999999' >"$HOME/.a2abridge/ports/8391/pid"   # a pid that is gone
printf '999998' >"$HOME/.a2abridge/ports/8392/pid"
out="$(herdr_pane=1 HERDR_PANE_ID=w1:p2 timeout 5 "$door" --identity 2>&1)"
"$door" --dry >/dev/null 2>&1
ls -d "$HOME/.a2abridge/ports/8391" >/dev/null 2>&1 && bad "a dead claim survived the sweep" || ok "a dead port claim is released"

printf '\ntest_a2a_bridge_identity: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
