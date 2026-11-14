#!/usr/bin/env bash
# test_soak.sh — the planted world for bin/gates/soak.sh (plan 286 P1, P2, P5).
#
# The soak raises real Electron windows, which a CI runner cannot do — so what is proved here
# is everything around the window: the registry and its fixed ports, the desk refusal, which
# apps a pull request touches, the process measurement, and the judge (a leak fails, a flat
# soak passes, a bounded step is not a leak). The window itself is proved by the errand's
# report, on the machine, with the numbers in $YMIR_HOME/state/soak/.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"; ROOT="$(cd "$ROOT/.." && pwd)"
SOAK="$ROOT/bin/gates/soak.sh"
DRIVER="$ROOT/bin/gates/soak/cdp.mjs"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; [ -n "${SLEEPER_PIDS:-}" ] && kill $SLEEPER_PIDS 2>/dev/null' EXIT
export YMIR_HOME="$TMP/home"; mkdir -p "$YMIR_HOME/state" "$YMIR_HOME/config"
n=0; bad=0
ok()   { n=$((n+1)); printf '  "%s","PASS"\n' "$1"; }
fail() { n=$((n+1)); bad=$((bad+1)); printf '  "%s","FAIL","%s"\n' "$1" "${2-}"; }
check() { if [ "$1" = 0 ]; then ok "$2"; else fail "$2" "${3-}"; fi }

printf 'soak_tests[?]{check,status,detail}:\n'

# 1 · the registry: every app and server, and the FIXED loopback DevTools ports (9311-9316)
out="$("$SOAK" --list 2>&1)"
rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '"hlidskjalf","electron","9311"' && printf '%s' "$out" | grep -q '"rodd","electron","9316"'
check $? "the registry lists every app on its fixed DevTools port"

printf '%s' "$out" | grep -q '"hlidskjalf-gate","server","3889"' && printf '%s' "$out" | grep -q '"smidja-server","server","8437"'
check $? "the registry lists the servers a leak also hides in"

# 2 · status prints the budgets AND the desk, never a bare banner
out="$("$SOAK" --status 2>&1)"
printf '%s' "$out" | grep -q '"budgets"' && printf '%s' "$out" | grep -q '"desk"'
check $? "status prints the budgets and the desk holder" "$out"

# 3 · an unknown app and a missing runtime are refusals, not a launch
"$SOAK" not-an-app >/dev/null 2>&1; [ $? = 2 ]; check $? "an unknown app is refused (exit 2)"
"$SOAK" smidja --root "$TMP/no-runtime" >/dev/null 2>&1; [ $? = 2 ]; check $? "a missing runtime is refused (exit 2)"

# 4 · the desk guard: a planted call refuses to raise anything, and says who holds it
mkdir -p "$TMP/bin"
cat >"$TMP/bin/pactl" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "list source-outputs")
    printf 'Source Output #7\n\tapplication.name = "Discord"\n\tSource Output #8\n\tapplication.name = "x"\n'
    exit 0 ;;
  "list short") printf '[Out] monitor\n' ; exit 0 ;;
esac
exit 0
FAKE
chmod +x "$TMP/bin/pactl"
PATH="$TMP/bin:$PATH" YMIR_DESK_ROLE=dev "$SOAK" smidja --quick >/dev/null 2>&1
rc=$?
[ "$rc" = 4 ] || printf 'soak[1]{note}\n  "desk-guard","exit %s (pactl fixture may not match this pactl)"\n' "$rc"
if [ "$rc" = 4 ]; then ok "a held desk refuses the soak (exit 4)"; else fail "a held desk refuses the soak" "exit $rc"; fi

# 5 · P5: which apps does a change touch?
mkdir -p "$TMP/repo/apps/sessrumnir" "$TMP/repo/docs"
( cd "$TMP/repo" && git init -q . && git config user.email t@t && git config user.name t \
  && printf 'a\n' >apps/sessrumnir/x.ts && printf 'a\n' >docs/x.md && git add -A && git commit -qm base \
  && printf 'b\n' >apps/sessrumnir/x.ts && printf 'b\n' >docs/x.md && git commit -qam change ) >/dev/null 2>&1
out="$(YMIR_SOAK_REPO="$TMP/repo" YMIR_HOME="$TMP/home" "$SOAK" --pr-range HEAD~1..HEAD 2>&1)"
printf '%s' "$out" | grep -q 'sessrumnir'
check $? "a PR touching an app names that app" "$out"
printf '%s' "$out" | grep -q 'hlidskjalf'
[ $? != 0 ] && ok "a PR touching no other app does not soak it" || fail "a PR touching no other app does not soak it"

# 6 · the measurement: a real process tree, counted from /proc
sleep 30 & p1=$!
sleep 30 & p2=$!
SLEEPER_PIDS="$p1 $p2"
sleep 0.3
row="$(node "$DRIVER" --measure-pid "$p1" 2>/dev/null)"
printf '%s' "$row" | grep -q '"procs":1' && printf '%s' "$row" | grep -qE '"rss_mb":[0-9.]+'
check $? "measure-pid reads a process from /proc" "$row"
printf '%s' "$row" | grep -q '"kind"'
[ $? != 0 ] && ok "a measurement row does not name its own kind (the caller owns it)" || fail "a measurement row names its own kind"
kill "$p1" 2>/dev/null; SLEEPER_PIDS="$p2"

# 7 · the judge: a leak fails, a flat soak passes, a bounded step is not a leak
plant() {  # <file> <run> <baseline-rss> <cycle-rss-list> <watches-list> <boot-cpu-list>
  local f="$1" run="$2" base="$3" cycles="$4" watches="$5" boot="$6" i=0
  : >"$f"
  for c in $(printf '%s' "$cycles" | tr ',' ' '); do
    i=$((i+1))
    printf '{"run":"%s","kind":"cycle","fds":20,"watches":%s,"children":0,"rss_mb":%s}\n' \
      "$run" "$(printf '%s' "$watches" | cut -d, -f$i)" "$c" >>"$f"
  done
  printf '{"run":"%s","kind":"baseline","rss_mb":%s,"heap_mb":7,"fds":20,"watches":%s,"children":0}\n' \
    "$run" "$base" "$(printf '%s' "$watches" | cut -d, -f1)" >>"$f"
  printf '{"run":"%s","kind":"after_cycles","rss_mb":%s,"heap_mb":7.2,"fds":20,"watches":%s,"children":0}\n' \
    "$run" "$(printf '%s' "$cycles" | tr ',' '\n' | tail -1)" "$(printf '%s' "$watches" | cut -d, -f3)" >>"$f"
  printf '{"run":"%s","kind":"sample","rss_mb":%s,"heap_mb":7.2,"fds":20,"watches":%s,"children":0}\n' \
    "$run" "$(printf '%s' "$cycles" | tr ',' '\n' | tail -1)" "$(printf '%s' "$watches" | cut -d, -f3)" >>"$f"
  for b in $(printf '%s' "$boot" | tr ',' ' '); do
    printf '{"run":"%s","kind":"boot","rss_mb":400,"main_rss_mb":120,"main_cpu_pct":%s}\n' "$run" "$b" >>"$f"
  done
}

plant "$TMP/leak.jsonl" R1 800 "820,900,1100" "5947,5948,5949" "10,10,10,10,10"
node "$DRIVER" --judge-only --ledger "$TMP/leak.jsonl" --app t --run R1 >/dev/null 2>&1
[ $? = 1 ] && ok "a soak that keeps 300 MB and adds watches is a LEAK (exit 1)" || fail "a growing soak is a LEAK"

plant "$TMP/flat.jsonl" R2 800 "805,801,800" "5949,5949,5949" "5,5,5,5,5"
node "$DRIVER" --judge-only --ledger "$TMP/flat.jsonl" --app t --run R2 >/dev/null 2>&1
check $? "a flat soak PASSES (exit 0)"

plant "$TMP/step.jsonl" R3 800 "810,812,812" "5947,5949,5949" "5,5,5,5,5"
node "$DRIVER" --judge-only --ledger "$TMP/step.jsonl" --app t --run R3 >/dev/null 2>&1
check $? "a bounded step in watches and descriptors is not a leak"

plant "$TMP/frozen.jsonl" R4 900 "900,900,900" "10,10,10" "120,140,130,20,10"
node "$DRIVER" --judge-only --ledger "$TMP/frozen.jsonl" --app t --run R4 >/dev/null 2>&1
[ $? = 1 ] && ok "a main thread pegged through boot is a START-UP LEAK" || fail "a pegged main thread is a start-up leak"

# 8 · one ledger, one run: yesterday's 1.5 GB can never make today's pass look flat
printf '{"run":"OLD","kind":"baseline","rss_mb":1800,"heap_mb":7,"fds":20,"watches":9,"children":0}\n' >>"$TMP/flat.jsonl"
printf '{"run":"OLD","kind":"after_cycles","rss_mb":1900,"heap_mb":7,"fds":20,"watches":9,"children":0}\n' >>"$TMP/flat.jsonl"
node "$DRIVER" --judge-only --ledger "$TMP/flat.jsonl" --app t --run R2 >/dev/null 2>&1
check $? "a judge reads only its own run's rows"

# 9 · the ledger shape: every row carries the run id, the app and a kind
plant "$TMP/shape.jsonl" R5 800 "800,800,800" "1,1,1" "1,1,1,1,1"
node "$DRIVER" --judge-only --ledger "$TMP/shape.jsonl" --app shape --run R5 >/dev/null 2>&1
tail -1 "$TMP/shape.jsonl" | python3 -c 'import json,sys; r=json.loads(sys.stdin.read()); assert r["run"]=="R5" and r["kind"]=="judge" and r["verdict"]=="pass"'
check $? "the judge row is one JSON row on the ledger, with its run id"

printf 'soak_test[1]{checks,failed}\n  %s,%s\n' "$n" "$bad"
[ "$bad" = 0 ] && printf 'PASS\n' || printf 'FAIL\n'
[ "$bad" = 0 ]
