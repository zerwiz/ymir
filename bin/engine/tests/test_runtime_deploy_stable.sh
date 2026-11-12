#!/usr/bin/env bash
# test_runtime_deploy_stable.sh — plan 275 S6 and S1 for bin/engine/runtime-deploy.sh, with no real unit touched:
#   1. a DIRTY pin is refused (exit 3), its hand edit is still there, and a fault report is filed;
#   2. a good move settles, exits 0 and writes state/runtime/last-good;
#   3. a move whose unit does not settle is ROLLED BACK (exit 4): the pin stands on the previous commit again.
# Everything runs in a temp HOME with a stand-in systemctl first on PATH and a stand-in unit writer in the pin.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$REPO/bin/engine/runtime-deploy.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# the stand-in systemctl: every call is logged; `show` answers the state FAKE_STATE names
mkdir -p "$T/bin" "$T/home/state" "$T/home/hodd/state" "$T/home/config"
cat > "$T/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_LOG"
case "$*" in
  *list-unit-files*) printf 'fake.service enabled enabled\n' ;;
  *"-p ActiveState -p SubState"*) if [ "${FAKE_STATE:-ok}" = ok ]; then printf 'active\nrunning\n'; else printf 'failed\nfailed\n'; fi ;;
  *"-p Type"*) printf 'simple\n' ;;
esac
exit 0
EOF
chmod +x "$T/bin/systemctl"
export FAKE_LOG="$T/systemctl.log"

# an origin with two commits, and a pin cloned from it standing on the first
git init -q "$T/origin"
mkdir -p "$T/origin/bin/engine"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/origin/bin/engine/units.sh"; chmod +x "$T/origin/bin/engine/units.sh"
printf 'one\n' > "$T/origin/app.txt"
git -C "$T/origin" add -A && git -C "$T/origin" -c user.email=t@t -c user.name=t commit -qm one
first=$(git -C "$T/origin" rev-parse HEAD)
git clone -q "$T/origin" "$T/pin"
printf 'two\n' > "$T/origin/app.txt"
git -C "$T/origin" -c user.email=t@t -c user.name=t commit -qam two
second=$(git -C "$T/origin" rev-parse HEAD)

run() { HOME="$T/home" YMIR_HOME="$T/home" PATH="$T/bin:$PATH" YMIR_RUNTIME_DIR="$T/pin" YMIR_RUNTIME_BRANCH=master \
        YMIR_RUNTIME_UNITS=fake bash "$DEPLOY" "$@" 2>&1; }
# the default branch name differs between git versions; follow what the origin used
br=$(git -C "$T/origin" symbolic-ref --short HEAD)
run() { HOME="$T/home" YMIR_HOME="$T/home" PATH="$T/bin:$PATH" YMIR_RUNTIME_DIR="$T/pin" YMIR_RUNTIME_BRANCH="$br" \
        YMIR_RUNTIME_UNITS=fake bash "$DEPLOY" "$@" 2>&1; }

# 1 · a dirty pin is refused and kept
printf 'hand edit\n' > "$T/pin/app.txt"
out=$(FAKE_STATE=ok run); rc=$?
[ "$rc" = 3 ] && ok "a dirty pin is refused (exit 3)" || bad "dirty pin: rc=$rc out=$out"
[ "$(cat "$T/pin/app.txt")" = "hand edit" ] && ok "the hand edit is still there" || bad "the hand edit was wiped"
ls "$T/home/hodd/state/groa/faults/"*dirty-pin.md >/dev/null 2>&1 && ok "a dirty-pin fault report is filed" || bad "no fault report"
git -C "$T/pin" checkout -q -- app.txt

# 2 · a good move settles and records last-good
out=$(FAKE_STATE=ok run); rc=$?
[ "$rc" = 0 ] && ok "a good move exits 0" || bad "good move: rc=$rc out=$out"
[ "$(git -C "$T/pin" rev-parse HEAD)" = "$second" ] && ok "the pin stands on the new commit" || bad "pin not moved"
grep -q "^$second " "$T/home/state/runtime/last-good" 2>/dev/null && ok "last-good names the new commit" || bad "last-good missing"

# 3 · a move whose unit does not settle is rolled back
git -C "$T/pin" reset -q --hard "$first"
out=$(FAKE_STATE=fail run); rc=$?
[ "$rc" = 4 ] && ok "an unsettled move exits 4 (rolled back)" || bad "rollback: rc=$rc out=$out"
[ "$(git -C "$T/pin" rev-parse HEAD)" = "$first" ] && ok "the pin stands on the last good commit again" || bad "pin was not rolled back"
ls "$T/home/hodd/state/groa/faults/"*rolled-back.md >/dev/null 2>&1 && ok "a rolled-back fault report is filed" || bad "no rollback report"

# no real unit was ever addressed: every systemctl call went to the stand-in
grep -q 'restart fake.service' "$FAKE_LOG" && ok "restarts went to the stand-in only" || bad "the stand-in saw no restart"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
