#!/usr/bin/env bash
# test_renewal_night.sh — plan 350 C: Gróa every night, and Eir after it, on every platform layer.
#   · systemd: the seat writes the timer, Gróa's unit chained to eir-night.service (on success AND failure),
#     exit 4 taken as success, and YMIR_NO_SUDO=1 in both units
#   · launchd: one launch agent runs Gróa then Eir; no user service manager: a named clean skip
#   · eir-night: reads Gróa's word, mends ONLY the safe surfaces, names a hung stage, writes the verdict
#   · renewal-check (Eir's surface): red when unseated, when the last night failed, or when it is stale
# Nothing touches the real units, the real Eir or the arm: every door is a fake.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home" "$T/repo"; git -C "$T/repo" init -q
SEAT="$root/bin/agents/groa-agent/seat.sh"; NIGHT="$root/bin/agents/groa-agent/eir-night.sh"; CHECK="$root/bin/agents/groa-agent/renewal-check.sh"
echo "test_renewal_night"

HOME="$T/home" YMIR_REPO="$T/repo" SEAT_PLATFORM=systemd SEAT_UNIT_DIR="$T/units" bash "$SEAT" --quiet --minute 14 >/dev/null 2>&1
g="$T/units/groa-agent.service"
[ -f "$T/units/groa-agent.timer" ] && [ -f "$T/units/eir-night.service" ] && ok "systemd: the timer and Eir's night unit are seated" || bad "units: $(ls "$T/units" 2>&1)"
grep -q '^OnSuccess=eir-night.service' "$g" && grep -q '^OnFailure=eir-night.service' "$g" && ok "Eir runs after Gróa on success and on failure" || bad "chain"
grep -q '^SuccessExitStatus=4' "$g" && ok "Gróa's 'surfaces owed' (exit 4) is not a failed night" || bad "exit 4"
grep -q '^Environment=YMIR_NO_SUDO=1' "$g" && grep -q '^Environment=YMIR_NO_SUDO=1' "$T/units/eir-night.service" && ok "neither unit may ask for root" || bad "no-sudo"
[ -x "$T/home/.local/bin/eir-night.sh" ] && ok "the night runner is installed beside Gróa's" || bad "runner"

HOME="$T/home" YMIR_REPO="$T/repo" SEAT_PLATFORM=launchd SEAT_LAUNCHD_DIR="$T/la" bash "$SEAT" --quiet --minute 18 >/dev/null 2>&1
p="$T/la/org.ymir.renewal.plist"
grep -q 'groa-agent.sh tick; \$HOME/.local/bin/eir-night.sh' "$p" 2>/dev/null && grep -q '<integer>18</integer>' "$p" && ok "launchd: one agent runs Gróa then Eir at the machine's minute" || bad "plist: $(cat "$p" 2>&1 | head -5)"
out="$(HOME="$T/home" YMIR_REPO="$T/repo" SEAT_PLATFORM=none bash "$SEAT" --quiet 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^skip: no user service manager' && ok "no service manager: a named clean skip" || bad "none: $rc $out"

# renewal-check
C=(env RENEWAL_PLATFORM=systemd RENEWAL_UNIT_DIR="$T/units" RENEWAL_STATE="$T/st" bash "$CHECK" --detail)
"${C[@]}" | grep -q 'no night has run yet' && ok "seated, never run: healthy" || bad "fresh: $("${C[@]}")"
env RENEWAL_PLATFORM=systemd RENEWAL_UNIT_DIR="$T/empty" RENEWAL_STATE="$T/st" bash "$CHECK" >/dev/null; [ $? = 1 ] && ok "unseated: red" || bad "unseated not red"
mkdir -p "$T/st/renewal"
printf '{"ts": %s, "result": "failed", "hung": "check (over 600s)", "failed": ""}\n' "$(date +%s)" >"$T/st/renewal/last-night.json"
"${C[@]}" | grep -q 'red: the night of .* failed — hung: check' && ok "a failed night is red and names the hung stage" || bad "failed: $("${C[@]}")"
printf '{"ts": %s, "result": "owed", "groa_rc": "4", "mended": ["armpin"]}\n' "$(( $(date +%s) - 50 * 3600 ))" >"$T/st/renewal/last-night.json"
"${C[@]}" | grep -q 'the timer stopped firing' && ok "a night older than 36 h is red" || bad "stale: $("${C[@]}")"
printf '{"ts": %s, "result": "owed", "groa_rc": "4", "mended": ["armpin"]}\n' "$(date +%s)" >"$T/st/renewal/last-night.json"
"${C[@]}" >/dev/null && ok "a recent night with surfaces owed is not this row's red" || bad "owed"

# eir-night with fakes
mkdir -p "$T/f"
cat >"$T/f/eir" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$T/eir.log"
[ -n "\${EIR_SLEEP:-}" ] && sleep "\$EIR_SLEEP"
case "\$1" in
  check) if [ -e "$T/mended" ]; then printf 'owed: autoboot ask\n'; else printf 'owed: armpin safe\nowed: autoboot ask\nowed: vaultkeys never\n'; fi ;;
  fix) touch "$T/mended" ;;
esac
EOF
chmod +x "$T/f/eir"
printf 'groa-update: NOT whole — owed: armpin (safe), autoboot (ask)\n── 2026-11-22T04:21:31+01:00 tick finished (rc 4) ───\n' >"$T/groa.log"
N=(env EIR_NIGHT_STATE="$T/ns" EIR_NIGHT_EIR="$T/f/eir" EIR_NIGHT_GROA_LOG="$T/groa.log" EIR_NIGHT_APPS="$T/none" EIR_NIGHT_TELL=off YMIR_REPO="$T/repo" bash "$NIGHT")
out="$("${N[@]}" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a night with surfaces still owed runs to its end (exit 0)" || bad "night rc=$rc: $out"
grep -qx 'fix armpin' "$T/eir.log" && ! grep -q 'fix autoboot\|fix vaultkeys' "$T/eir.log" && ok "Eir mends only the safe surface" || bad "mends: $(cat "$T/eir.log")"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["result"]=="owed" and r["groa_rc"]=="4" and r["mended"]==["armpin"] and "autoboot (ask)" in r["owed"] else 1)' "$T/ns/renewal/last-night.json" \
  && ok "the verdict names Gróa's rc, what was mended and what is still owed" || bad "verdict: $(cat "$T/ns/renewal/last-night.json")"
printf '%s' "$out" | grep -q 'still owed: autoboot (ask)' && ok "the verdict line reads plainly" || bad "line: $out"
rm -f "$T/mended"
out="$(EIR_SLEEP=5 EIR_NIGHT_CHECK_S=1 "${N[@]}" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'HUNG: check (over 1s)' && ok "a stage that runs out of time is named, and the night fails" || bad "hung: rc=$rc $out"
printf '── x tick finished (rc 124) ───\n' >"$T/groa124.log"
out="$(env EIR_NIGHT_STATE="$T/ns" EIR_NIGHT_EIR="$T/f/eir" EIR_NIGHT_GROA_LOG="$T/groa124.log" EIR_NIGHT_APPS="$T/none" EIR_NIGHT_TELL=off YMIR_REPO="$T/repo" bash "$NIGHT" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'HUNG: groa (timed out' && ok "a Gróa that timed out is named as hung" || bad "groa 124: rc=$rc $out"
# the home ward: a tracked home folder relinked during a stage fails the night, named by its stage
H2="$T/home2"; mkdir -p "$H2/config" "$H2/hodd"; printf 'x\n' >"$H2/config/cron.yaml"; printf 'y\n' >"$H2/hodd/a"
git -C "$H2" init -q && git -C "$H2" add . && git -C "$H2" -c user.email=a@example.org -c user.name=ada commit -q -m home
cat >"$T/f/eir-relink" <<EOF
#!/usr/bin/env bash
case "\$1" in check) [ -e "$T/relinked" ] || { rm -rf "$H2/config"; ln -s .agents/config "$H2/config"; touch "$T/relinked"; }; printf 'owed: autoboot ask\n' ;; esac
EOF
chmod +x "$T/f/eir-relink"
out="$(env EIR_NIGHT_STATE="$T/ns2" EIR_NIGHT_EIR="$T/f/eir-relink" EIR_NIGHT_GROA_LOG="$T/groa.log" EIR_NIGHT_APPS="$T/none" EIR_NIGHT_TELL=off EIR_NIGHT_HOME="$H2" YMIR_REPO="$T/repo" bash "$NIGHT" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q "the home's tracked folder config/ became a link (-> .agents/config) during check" \
  && ok "a tracked home folder relinked during a stage fails the night, named by the stage" || bad "ward: rc=$rc $out"
printf '%s' "$out" | grep -q "restore: rm $H2/config && git -C $H2 checkout -- config" && ok "the verdict prints the restore, and repairs nothing itself" || bad "restore line"
[ -L "$H2/config" ] && ok "the home is not touched by the ward (the operator restores it)" || bad "the ward changed the home"
rm -f "$H2/config"; git -C "$H2" checkout -q -- config
out="$(env EIR_NIGHT_STATE="$T/ns3" EIR_NIGHT_EIR="$T/f/eir" EIR_NIGHT_GROA_LOG="$T/groa.log" EIR_NIGHT_APPS="$T/none" EIR_NIGHT_TELL=off EIR_NIGHT_HOME="$H2" YMIR_REPO="$T/repo" bash "$NIGHT" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "an untouched home passes the ward" || bad "clean home: rc=$rc $out"
echo "test_renewal_night: $pass passed, $fail failed"
[ "$fail" = 0 ]
