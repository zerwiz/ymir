#!/usr/bin/env bash
# push-road.test.sh — prove the push road mends of plan 339.1, in a THROWAWAY CLONE.
#
# On 2026-11-20 one push took over thirteen minutes and failed on four wards. Each mend is proved
# here, and none of the proofs touches this checkout, its remotes or any network:
#
#   1  fork      a branch behind main is judged on what IT adds (the fork point), not on main's changes
#   2  commits   the push posture judges commits only — an untracked scratch file is not in the scope
#   3  wall      the ward budget is a wall: a ward still running at the budget is cut off and DEFERRED
#   4  mask      the public-data ward names the line and `--mask` rewrites only the refused mailbox
#   5  park-off  refs/parked/* is refused by the hook, and park.sh exits 3, until a remote is named
#   6  secret    secret-guard --range bites on a credential the range adds, and passes a clean range
#   7  exec      exec-bits.sh names a new door without its bit, and --fix sets it in the index
#   8  stamp     a sha the hook passed is not judged twice; the second push skips the tree wards
#   9  nda-line  the NDA ward, handed a base, refuses an added name and not one the file already had
#  10  catch-up  gather.sh's catch_up merges a base that moved under the batch, instead of refusing it
#
# Usage: push-road.test.sh        Exit: 0 all hold · 1 one does not · 2 usage.
set -u
case "${1-}" in -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; "") ;; *) exit 2 ;; esac

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/push-road-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  "%s","PASS","%s"\n' "$1" "$2"; }
bad() { fail=$((fail+1)); printf '  "%s","FAIL","%s"\n' "$1" "$2"; }
printf 'push_road_test[10]{check,status,detail}:\n'

git clone --quiet --shared "$ROOT" "$WORK/tree" 2>/dev/null || { bad clone "could not clone"; exit 1; }
T="$WORK/tree"
# the stamps live in the CLONE's git dir, never in the checkout under test
export YMIR_GUARD_CACHE="$WORK/cache" YMIR_GUARD_NO_CACHE=1
GATE_FILES=(.githooks/pre-push bin/gates/guards.sh bin/gates/guards/nda-guard.sh bin/gates/guards/public-guard.py
            bin/gates/guards/secret-guard.sh bin/gates/guards/rules-compliance-guard.sh bin/forge/park.sh bin/forge/exec-bits.sh)
overlay() { local f; for f in "${GATE_FILES[@]}"; do mkdir -p "$T/$(dirname "$f")"; cp "$ROOT/$f" "$T/$f"; done; }

cd "$T" || exit 1
# A CI checkout is shallow (one commit, no local `main`), so the clone has no origin/main five deep.
# Stand one in the clone: six empty commits on its own HEAD, named origin/main. The probe needs a
# history to be behind, not the house's real one; a full checkout takes the real origin/main.
if ! git rev-parse -q --verify origin/main~5 >/dev/null; then
  for i in 1 2 3 4 5 6; do git -c user.name=probe -c user.email=probe@example.org commit -q --allow-empty -m "probe base $i" || break; done
  git update-ref refs/remotes/origin/main HEAD
fi
git rev-parse -q --verify origin/main >/dev/null || { bad clone "the clone has no origin/main"; exit 1; }
# A branch cut five commits behind main, with one commit of its own.
git checkout -q -b probe/behind origin/main~5 2>/dev/null || { bad clone "origin/main~5 does not exist"; exit 1; }
printf 'a probe line\n' >docs/zz-push-road-probe.md
git add docs/zz-push-road-probe.md && git commit -q -m "probe: one file" || { bad clone "could not commit"; exit 1; }
overlay   # the gate as it stands in the checkout under test, uncommitted (so never in the push scope)

# ── 1/2/3. fork point, commits only, the wall ────────────────────────────────
printf 'scratch\n' >zz-untracked-scratch.md
t0=$(date +%s)
out="$(YMIR_GUARD_PUSH=1 YMIR_PREPUSH_BUDGET=2 bash bin/gates/guards.sh 2>&1)"
el=$(( $(date +%s) - t0 ))
if printf '%s' "$out" | grep -q '^guards: 1 changed path(s) judged'; then
  ok fork "a branch 5 commits behind main judged its own 1 file, not main's changes"
else
  bad fork "the scope was not the fork point: $(printf '%s' "$out" | grep -m1 'changed path')"
fi
if ! printf '%s' "$out" | grep -q 'zz-untracked-scratch'; then
  ok commits "an untracked scratch file stayed out of the push scope"
else
  bad commits "an untracked file was judged in the push posture"
fi
if [ "$el" -le 20 ] && printf '%s' "$out" | grep -q '"DEFERRED"'; then
  ok wall "a 2 s budget ended the run in ${el}s with the overrunning wards DEFERRED"
else
  bad wall "the budget did not cut the wards (${el}s)"
fi
rm -f zz-untracked-scratch.md

# ── 4. the masked form ───────────────────────────────────────────────────────
M="$WORK/mask"; mkdir -p "$M"
local_part="jane.probe"; dom="probe-$(printf 'corp').se"           # built at run time: no address in the source
printf 'one\nmail %s@%s or ops@example.org\n' "$local_part" "$dom" >"$M/note.md"
msg="$(YMIR_GUARD_ROOT="$M" python3 bin/gates/guards/public-guard.py note.md 2>&1)"
YMIR_GUARD_ROOT="$M" python3 bin/gates/guards/public-guard.py --mask note.md:2 >/dev/null 2>&1
if printf '%s' "$msg" | grep -q 'note.md:2: a personal mailbox' && printf '%s' "$msg" | grep -q -- '--mask note.md:2' \
   && grep -q '<a personal address> or ops@example.org' "$M/note.md" && ! grep -q "$dom" "$M/note.md"; then
  ok mask "the ward named note.md:2, offered --mask, and the mask kept the allowed address"
else
  bad mask "the masked form was not offered or not applied"
fi

# ── 5. parking is off until named ───────────────────────────────────────────
head_sha="$(git rev-parse HEAD)"
pk="$(printf 'HEAD %s refs/parked/probe %s\n' "$head_sha" 0000000000000000000000000000000000000000 | env -u YMIR_PARK_ALLOW bash .githooks/pre-push 2>&1)"; prc=$?
YMIR_PARK_REMOTE="" YMIR_HOME="$WORK/nohome" bash bin/forge/park.sh probe >/dev/null 2>&1; src=$?
if [ "$prc" -eq 1 ] && printf '%s' "$pk" | grep -q 'parking road is OFF' && [ "$src" -eq 3 ]; then
  ok park-off "the hook refused refs/parked/* and park.sh answered 3 (off) with no remote named"
else
  bad park-off "parking was not off by default (hook rc=$prc, park rc=$src)"
fi

# ── 6. secret --range ────────────────────────────────────────────────────────
base6="$(git rev-parse HEAD)"
printf 'token %s%s\n' "ghp_" "$(printf 'a%.0s' $(seq 1 36))" >docs/zz-secret-probe.md   # built at run time
git add docs/zz-secret-probe.md && git commit -q -m "probe: a planted credential"
bash bin/gates/guards/secret-guard.sh --range "$base6" HEAD >/dev/null 2>&1; s_bad=$?
bash bin/gates/guards/secret-guard.sh --range "$base6~1" "$base6" >/dev/null 2>&1; s_ok=$?
git reset -q --hard "$base6"; overlay
if [ "$s_bad" -eq 1 ] && [ "$s_ok" -eq 0 ]; then
  ok secret "secret-guard --range refused the planted credential and passed the clean range"
else
  bad secret "secret-guard --range did not judge the range (bad=$s_bad ok=$s_ok)"
fi

# ── 7. exec bits ────────────────────────────────────────────────────────────
printf '#!/usr/bin/env bash\necho probe\n' >bin/zz-probe-door.sh; chmod 644 bin/zz-probe-door.sh
git add bin/zz-probe-door.sh && git commit -q -m "probe: a door without its bit"
bash bin/forge/exec-bits.sh >/dev/null 2>&1; e_bad=$?
bash bin/forge/exec-bits.sh --fix >/dev/null 2>&1; e_fix=$?
mode="$(git ls-files -s -- bin/zz-probe-door.sh | awk '{print $1}')"
git reset -q --hard "$base6"; overlay
if [ "$e_bad" -eq 1 ] && [ "$e_fix" -eq 0 ] && [ "$mode" = 100755 ]; then
  ok exec "exec-bits named the door, and --fix staged it as 100755"
else
  bad exec "exec-bits did not mend the bit (check=$e_bad fix=$e_fix mode=$mode)"
fi

# ── 8. the stamp: one judgement per sha ──────────────────────────────────────
git checkout -q -b probe/current origin/main
overlay; git add "${GATE_FILES[@]}"; git commit -q -m "probe: the gate under test" || true
br="$(git rev-parse --abbrev-ref HEAD)"; sha="$(git rev-parse HEAD)"
line="refs/heads/$br $sha refs/heads/$br 0000000000000000000000000000000000000000"
r1="$(printf '%s\n' "$line" | YMIR_SKIP_FIXES_GUARD=1 YMIR_PREPUSH_BUDGET=2 bash .githooks/pre-push 2>&1)"; rc1=$?
r2="$(printf '%s\n' "$line" | YMIR_SKIP_FIXES_GUARD=1 YMIR_PREPUSH_BUDGET=2 bash .githooks/pre-push 2>&1)"; rc2=$?
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && printf '%s' "$r2" | grep -q 'judged once, not twice' \
   && ! printf '%s' "$r2" | grep -q '"guards"'; then
  ok stamp "the second push of the same sha skipped the tree wards"
elif [ "$rc1" -ne 0 ]; then
  bad stamp "the first push did not pass here, so no stamp could be proved: $(printf '%s' "$r1" | grep -m1 '^pre-push:')"
else
  bad stamp "the same sha was judged twice"
fi

# ── 9. the NDA ward judges added lines when handed a base ───────────────────
nda_out="$(YMIR_GUARD_BASE="$(git rev-parse HEAD)" bash bin/gates/guards/nda-guard.sh check README.md 2>&1)"; nrc=$?
if [ "$nrc" -eq 0 ] || printf '%s' "$nda_out" | grep -q UNARMED; then
  ok nda-line "a file touched with no added line passes the NDA ward when a base is handed (or it is unarmed here)"
else
  bad nda-line "the NDA ward refused lines the push did not add"
fi

# ── 10. gather catches up a moved base ──────────────────────────────────────
# The real function, lifted out of gather.sh, run against a scratch bare remote whose main moves.
fn="$(sed -n '/^catch_up() {/,/^}/p' "$ROOT/bin/forge/gather.sh")"
R="$WORK/remote.git"; C="$WORK/batch"
git init -q --bare "$R" && git clone -q "$R" "$C" 2>/dev/null
( cd "$C" && git checkout -q -b main && echo one >a && git add a && git commit -q -m one && git push -q origin main ) >/dev/null 2>&1
( cd "$C" && git checkout -q -b yggdrasil/batch && echo batch >b && git add b && git commit -q -m batch ) >/dev/null 2>&1
git clone -q "$R" "$WORK/other" 2>/dev/null
( cd "$WORK/other" && git checkout -q -B main origin/main && echo two >c && git add c && git commit -q -m "main moved" && git push -q origin main ) >/dev/null 2>&1
cu="$(WTP="$C" REMOTE=origin BASE=main BATCH=probe bash -c "$fn"'; catch_up; echo "rc=$?"' 2>&1)"
if printf '%s' "$cu" | grep -q 'rc=10' && git -C "$C" merge-base --is-ancestor origin/main HEAD \
   && printf '%s' "$cu" | grep -q 'merged into the batch, not refused'; then
  ok catch-up "a base that moved one commit under the batch was merged in (rc 10), not refused"
else
  bad catch-up "catch_up did not merge the moved base: $cu"
fi
cu2="$(WTP="$C" REMOTE=origin BASE=main BATCH=probe bash -c "$fn"'; catch_up; echo "rc=$?"' 2>&1)"
printf '%s' "$cu2" | grep -q 'rc=0' || bad catch-up "a base that had not moved was not left alone: $cu2"

printf 'push-road-test: %s pass, %s fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
