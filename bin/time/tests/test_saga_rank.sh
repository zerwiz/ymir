#!/usr/bin/env bash
# test_saga_rank.sh — the digest prints the RANKS, so a seat knows what it is (plan 310 §5.5).
#
# THE LAW THIS PROVES. Three ranks, one lock each: the machine arm (the right to act on this
# machine), a project orchestrator (a LEASE's holder — hands, not sovereignty) and the crown
# (one for the fleet). A seat that does not know which it holds either overreaches or sits
# silent. So the head prints ONE line naming its rank, who holds what, and — for a seat with
# no rank — the one door it keeps: it may always ASK the holder.
#
#   1 · the head carries a `rank:` line, in the HELM section, right after the helm line
#   2 · with a live lease the line names the PROJECT LEASE and its numbers
#   3 · with no lease and no arm the line says read-only, and names lock-ask
#   4 · the crown gets a row of its own, vacant or not, and never a name it invents
#   5 · a read-only page still prints it (a page load is not a hand on the helm, but it is a
#       reader that must know whose hand is on it)
#
# Usage: test_saga_rank.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/time/saga-session-start.sh"
LEASE="$ROOT/bin/voice/arm-lease.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_ARM_LEASE_STATE="$TMP/state"
export SAGA_STATE_DIR="$TMP/state"
export BROKK_STATE_OVERRIDE="$TMP/state"
mkdir -p "$YMIR_HOME/hodd/data" "$TMP/state"
printf '{"hosts":{"heimdall":{"user":"probe","tailnet":"probe"}}}\n' >"$YMIR_HOME/hodd/data/fleet.json"

printf 'test_saga_rank\n'

# ── 1 · the head carries a rank line, in the HELM section ──────────────────
head_out="$(timeout 90 bash "$DOOR" --page 2>&1)"
case "$head_out" in *"rank: "*"read-only"*) ok "the head prints a rank line, and a seat with no rank says read-only" ;; *) bad "the head prints a rank line" "$(printf '%s' "$head_out" | sed -n '/HELM/,/NEEDS/p' | head -6)" ;; esac
case "$head_out" in *"may still ASK: bin/seat/lock-ask.sh ask"*) ok "a read-only seat is told its one door: it may ASK" ;; *) bad "a read-only seat is told its one door" "$(printf '%s' "$head_out" | grep '^rank:' | head -2)" ;; esac
helm_section="$(printf '%s' "$head_out" | sed -n '/^== HELM ==$/,/^== /p')"
case "$helm_section" in *"rank: "*) ok "the rank line sits in the HELM section, where the helm is named" ;; *) bad "the rank line sits in the HELM section" "$helm_section" ;; esac
[ "$(printf '%s\n' "$helm_section" | grep -c '^rank: ')" = 1 ] && ok "there is exactly ONE rank line (a digest line is not a table)" \
  || bad "there is exactly ONE rank line" "$(printf '%s\n' "$helm_section" | grep -c '^rank: ')"

# ── 2 · a live lease is named as the rank this seat holds ──────────────────
bash "$LEASE" grant ymir --holder the-foringi --hands 3 >/dev/null 2>&1
head_out="$(timeout 90 bash "$DOOR" --page 2>&1)"
case "$head_out" in *"PROJECT LEASE"*) ok "with a live lease the seat holds a PROJECT LEASE" ;; *) bad "with a live lease the seat holds a PROJECT LEASE" "$(printf '%s' "$head_out" | grep '^rank:')" ;; esac
case "$head_out" in *"3 hand(s)"*) ok "the line names how many hands the lease grants" ;; *) bad "the line names how many hands the lease grants" "$(printf '%s' "$head_out" | grep '^rank:')" ;; esac
case "$head_out" in *"arm hand"*) ok "the line names the machine's hand beside it" ;; *) bad "the line names the machine's hand beside it" "$(printf '%s' "$head_out" | grep '^rank:')" ;; esac

# ── 3 · the crown has a row of its own, and invents no name ────────────────
rows="$(bash "$LEASE" ranks 2>&1)"
case "$rows" in *'"the crown"'*) ok "the crown has its own row" ;; *) bad "the crown has its own row" "$rows" ;; esac
case "$rows" in *'nobody","the crown'*) ok "a vacant crown is rendered as nobody, never an invented holder" ;; *) bad "a vacant crown is rendered as nobody" "$rows" ;; esac
case "$rows" in *ranks\{who,rank,machine,scope,hands,standing,proof\}*) ok "the ranks row names its columns" ;; *) bad "the ranks row names its columns" "$rows" ;; esac

# ── 4 · the head still fits its budget with the rank line in it ────────────
budget="$(timeout 90 bash "$DOOR" --check 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "the head still fits its budget with the rank line (54 lines ≤ 60)" || bad "the head still fits its budget" "$budget"

printf 'test_saga_rank: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
