#!/usr/bin/env bash
# test_trouble_veil.sh — plan 350 B in the trouble panel: a Veil report with no RECEIVED past its
# line is red with the count; Níðhöggr's stamp older than its line is red; a fresh stamp and an
# answered report are not. Also proves the Níðhöggr job stamps its run and tells a loop once.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
st="$T/state"; mkdir -p "$st/veil" "$st/nidhogg" "$T/home"
now="$(date +%s)"
read_sig() { TROUBLE_HOST=t python3 "$root/bin/ward/trouble.py" "$root" "$T/home" "$st" read --only "$1" 2>&1; }
echo "test_trouble_veil"

read_sig receipts | grep -q 'no Veil report' && ok "no ledger is quiet" || bad "empty: $(read_sig receipts)"
{ printf '{"id":"v1","event":"sent","from":"agent a","ts":%s}\n' $((now - 900))
  printf '{"id":"v2","event":"sent","from":"agent b","ts":%s}\n' $((now - 1200))
  printf '{"id":"v3","event":"sent","from":"agent c","ts":%s}\n' $((now - 30))
  printf '{"id":"v2","event":"received","by":"helm","ts":%s}\n' $((now - 1100)); } >"$st/veil/ledger.jsonl"
out="$(read_sig receipts)"
printf '%s' "$out" | grep -q 'RED' && printf '%s' "$out" | grep -q '1 report(s)' && ok "one unanswered report past ten minutes is red, with its count" || bad "receipts: $out"
printf '{"id":"v1","event":"received","by":"helm","ts":%s}\n' "$now" >>"$st/veil/ledger.jsonl"
read_sig receipts | grep -q 'RED' && bad "an answered report stayed red" || ok "RECEIVED clears it (the fresh one is not yet late)"

printf '{"ts": %s}\n' $((now - 7200)) >"$st/nidhogg/last-run.json"
out="$(read_sig loops)"
printf '%s' "$out" | grep -q 'Níðhöggr has not run for 120 min' && ok "a stale Níðhöggr stamp is red" || bad "loops: $out"
printf '{"ts": %s}\n' "$now" >"$st/nidhogg/last-run.json"
read_sig loops | grep -q 'has not run' && bad "a fresh stamp is still red" || ok "a fresh stamp clears the clock"

# the job: a fake Níðhöggr that sees one looping agent, a fake Veil that records what it is told
mkdir -p "$T/bin"
cat >"$T/bin/nid" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  scan) printf 'nidhogg[2]{agent,status,repeats,threshold,verdict,last_repeated}:\n  "w1","working",5,3,"LOOP — the same command ran 5 times","ls"\n  "w2","idle",0,3,"clean",""\n'; exit 3 ;;
  break) printf 'broke %s\n' "$2" >>"$NID_LOG"; exit 0 ;;
  commits) printf '{"loops":[]}\n'; exit 0 ;;
esac
EOF
cat >"$T/bin/veil" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$VEIL_LOG"
EOF
chmod +x "$T/bin/nid" "$T/bin/veil"
export NID_LOG="$T/nid.log" VEIL_LOG="$T/veil.log"
J=(env "BROKK_STATE_OVERRIDE=$st" "NIDHOGG_DOOR=$T/bin/nid" "NIDHOGG_VEIL=$T/bin/veil" bash "$root/bin/time/nornir-job-nidhogg.sh")
rm -f "$st/nidhogg/last-run.json"
out="$("${J[@]}" 2>&1)"; rc=$?
[ "$rc" = 3 ] && ok "a looping agent makes the job exit 3" || bad "job rc=$rc: $out"
grep -q 'broke w1' "$NID_LOG" && ! grep -q 'broke w2' "$NID_LOG" && ok "only the looping agent is broken" || bad "breaks: $(cat "$NID_LOG")"
grep -q -- '--kind finding' "$VEIL_LOG" && grep -q 'w1' "$VEIL_LOG" && ok "the loop is told to the arm holder through the Veil" || bad "veil: $(cat "$VEIL_LOG" 2>/dev/null)"
[ -s "$st/nidhogg/last-run.json" ] && ok "the run is stamped" || bad "no stamp"
"${J[@]}" >/dev/null 2>&1
[ "$(grep -c 'w1' "$VEIL_LOG")" = 1 ] && ok "the same loop is told once, not every run" || bad "told $(grep -c w1 "$VEIL_LOG") times"
echo "test_trouble_veil: $pass passed, $fail failed"
[ "$fail" = 0 ]
