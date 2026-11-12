#!/usr/bin/env bash
# test_sol_stamps.sh — plan 272 fault 4: every line a person or the helm reads begins with a Sól timestamp,
# in one shape (2026-11-12 14:55 CET). Before: wake lines, status lines and drain lines carried no time at all.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
STAMP_RX='^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [A-Za-z0-9+-]+'

# the door and the lib agree on one shape
d="$(bash "$ROOT/bin/time/sol.sh" line --plain --at 2026-11-12T13:55:00Z --tz Europe/Stockholm)"
[ "$d" = "2026-11-12 14:55 CET" ] && ok "sol.sh line renders the house shape from a fixed instant" || bad "sol.sh line: $d"
. "$ROOT/bin/time/sol-lib.sh"
sol_line | grep -qE "$STAMP_RX" && ok "sol_line has the same shape" || bad "sol_line shape"
[ "$(YMIR_TZ=Europe/Stockholm sol_from_epoch 1794491700)" = "$(YMIR_TZ=Europe/Stockholm date -d @1794491700 '+%Y-%m-%d %H:%M %Z')" ] && ok "an epoch machine field is rendered through the stamp" || bad "sol_from_epoch"
once="$(sol_stamped "a notice")"; twice="$(sol_stamped "$once")"
[ "$once" = "$twice" ] && ok "stamping is idempotent (a line is never stamped twice)" || bad "double stamp"
printf 'one\n\ntwo\n' | sol_prefix | grep -cE "$STAMP_RX" | grep -qx 2 && ok "sol_prefix stamps each non-empty line" || bad "sol_prefix"

# the worker's acclaim: status line, queue line, shelf and printed line
mkdir -p "$T/repo/bin/agents" "$T/repo/bin/vault" "$T/repo/bin/time" "$T/repo/RULES" "$T/repo/.pi" "$T/home/state"
cp "$ROOT/bin/agents/eindri-acclaim.sh" "$ROOT/bin/agents/eindri-wake-lib.sh" "$T/repo/bin/agents/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$T/repo/bin/vault/"; cp "$ROOT/bin/time/sol-lib.sh" "$ROOT/bin/time/saga-wake-drain.sh" "$T/repo/bin/time/"
printf 'working: launched\n' >"$T/home/state/w1.status"
out="$(env -i PATH="$PATH" HOME="$T" YMIR_HOME="$T/home" BROKK_ROOT_OVERRIDE="$T/repo" bash "$T/repo/bin/agents/eindri-acclaim.sh" w1 --terminal failed --line "it stopped" 2>&1)"
tail -n1 "$T/home/state/w1.status" | grep -qE '^failed: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} .+ — it stopped$' && ok "the status line keeps its state first and carries the stamp" || bad "status line: $(tail -n1 "$T/home/state/w1.status")"
head -n1 "$T/home/state/.wake-queue" | grep -qE "$STAMP_RX" && ok "the wake line begins with the stamp" || bad "wake line: $(head -n1 "$T/home/state/.wake-queue")"
head -n1 "$T/home/state/eindri-reports/w1.md" | grep -qE "$STAMP_RX" && ok "the report begins with the stamp" || bad "report"
printf '%s\n' "$out" | grep -E "$STAMP_RX" | grep -q 'acclaimed w1' && ok "the acclaim prints one stamped human line" || bad "printed line: $out"
before="$(wc -l <"$T/home/state/w1.status")"
env -i PATH="$PATH" HOME="$T" YMIR_HOME="$T/home" BROKK_ROOT_OVERRIDE="$T/repo" bash "$T/repo/bin/agents/eindri-acclaim.sh" w1 --terminal failed --line "it stopped" >/dev/null 2>&1
[ "$(wc -l <"$T/home/state/w1.status")" = "$before" ] && ok "a repeat of the same act is recognised through the stamp, not written twice" || bad "repeat written twice"

# the drain: an unstamped queue line is stamped when shown
printf 'eindri old line with no time\n' >"$T/home/state/.wake-queue"
dout="$(env -i PATH="$PATH" HOME="$T" YMIR_HOME="$T/home" BROKK_HOME="$T/repo" BROKK_STATE_OVERRIDE="$T/home/state" bash "$T/repo/bin/time/saga-wake-drain.sh" 2>&1)"
printf '%s\n' "$dout" | grep -E '^WAKE ' | grep -qE "^WAKE [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} " && ok "the drain shows an unstamped wake with a stamp" || bad "drain: $dout"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
