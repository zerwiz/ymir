#!/usr/bin/env bash
# eindri-review-spine.test.sh — the review spine (FORSETI sent after every ship).
#
# The delivery gate says a PR is the only way work leaves; this gate says a PR is
# not done until it is AUDITED. These checks prove the spine's four laws without
# seating a live judge: the spawn line is exact, a second done never re-reviews,
# YMIR_AUTO_REVIEW=off is the loud override, and the acclaim done path reaches
# the spawn.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPAWN="$ROOT/bin/agents/eindri-review-spawn.sh"
ACCLAIM="$ROOT/bin/agents/eindri-acclaim.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/project"
mkdir -p "$PROJ/state" "$PROJ/data"
cat >"$PROJ/state/litmus-ship.meta" <<EOF
id=litmus-ship
kind=ship
mode=direct-PR
project=$PROJ
worktree=$PROJ/.yggdrasil/litmus-ship
brief=$PROJ/data/litmus-ship/brief.md
EOF
printf 'working: x\ndone: opened PR https://github.com/zerwiz/ymir/pull/999\n' >"$PROJ/state/litmus-ship.status"

# THE FENCE (2026-11-21): this suite once reached the REAL helm pane four times — the acclaim done
# path ends in eindri-notify.sh, which types into whichever session holds the arm. A test pages nobody:
# YMIR_NO_INJECT=1 is the switch the notify road honours, and a fake herdr on PATH answers every pane
# lookup with nothing, so even a road that forgot the switch finds no pane to type into.
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\nprintf "fake herdr: %%s\\n" "$*" >>"%s/herdr.log"\nexit 1\n' "$TMP" >"$TMP/bin/herdr"
chmod +x "$TMP/bin/herdr"
# and a temp home, so the spine's brief lands in this suite's tree and never in the operator's data shelf
mkdir -p "$TMP/home/hodd/data" "$TMP/home/state"
export PATH="$TMP/bin:$PATH" YMIR_NO_INJECT=1 YMIR_HOME="$TMP/home"
unset YMIR_HOARD_LIB_LOADED
RUN=(env "BROKK_STATE_OVERRIDE=$PROJ/state" YMIR_REVIEW_HARNESS=pi YMIR_REVIEW_MODEL=litmus/judge "BROKK_DATA_OVERRIDE=$TMP/home/hodd/data" "YMIR_HOME=$TMP/home" YMIR_NO_INJECT=1 "PATH=$PATH")

# 1. the sync contract: bash -n clean
bash -n "$SPAWN" 2>/dev/null && ok "eindri-review-spawn.sh is syntactically clean" || bad "bash -n eindri-review-spawn.sh"
bash -n "$ACCLAIM" 2>/dev/null && ok "eindri-acclaim.sh is syntactically clean" || bad "bash -n eindri-acclaim.sh"

# 2. the exact spawn line: scout, herdr, pi, the pinned judge model, high effort
# the harness and model are pinned per run, so the line does not depend on the home's judge row
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 YMIR_REVIEW_HARNESS=pi YMIR_REVIEW_MODEL=opencode-go/deepseek-v4.1-flash "$SPAWN" litmus-ship)"
printf '%s' "$out" | grep -q -- '--scout --backend herdr --harness pi --model opencode-go/deepseek-v4.1-flash --effort high' \
  && ok "the spawn line is the exact einherjar review road" || bad "spawn line: $out"
printf '%s' "$out" | grep -q 'pull/999' && ok "the PR is read from the task status" || bad "PR not resolved: $out"
printf '%s' "$out" | grep -q 'litmus-ship-review' && ok "the review id is <task>-review" || bad "review id: $out"

# 3. the brief is filled for THIS task
brief="$TMP/home/hodd/data/litmus-ship-review/brief.md"
[ -s "$brief" ] && ok "the fierce brief is written" || bad "brief missing"
grep -q 'pull/999' "$brief" && ok "brief names the PR" || bad "brief PR"
grep -q 'BROKK_STATE_OVERRIDE='"$PROJ"'/state bin/agents/eindri-acclaim.sh litmus-ship-review' "$brief" \
  && ok "brief's terminal act targets the shared wake road" || bad "brief terminal act"
grep -q 'Delivery contract: mode=scout' "$brief" && ok "brief carries the scout delivery contract" || bad "brief contract"
grep -q 'Isolation: herdr' "$brief" && ok "brief declares the ordinary road (herdr)" || bad "brief isolation"
grep -q '{TASK}' "$brief" && bad "brief still carries the unfilled {TASK} placeholder" || ok "no unfilled {TASK}"

# 4. one per task: a .reviewed marker stops the second done
mkdir -p "$PROJ/state/.reviewed"
printf 'review=litmus-ship-review\n' >"$PROJ/state/.reviewed/litmus-ship"
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$SPAWN" litmus-ship)"
printf '%s' "$out" | grep -q '"skipped","already reviewed' && ok "a re-done never re-reviews" || bad "double review: $out"
rm -f "$PROJ/state/.reviewed/litmus-ship"

# 5. YMIR_AUTO_REVIEW=off is the loud override
out="$("${RUN[@]}" YMIR_AUTO_REVIEW=off YMIR_REVIEW_DRY=1 "$SPAWN" litmus-ship)"
printf '%s' "$out" | grep -q 'YMIR_AUTO_REVIEW=off' && ok "off silences the spine, loudly" || bad "off: $out"

# 6. a scout opens no PR — never review a scout
printf 'id=litmus-scout\nkind=scout\nproject=%s\n' "$PROJ" >"$PROJ/state/litmus-scout.meta"
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$SPAWN" litmus-scout)"
printf '%s' "$out" | grep -q 'kind=scout' && ok "a scout is not reviewed" || bad "scout: $out"

# 7. the acclaim done path reaches the spawn (end to end, no live seat)
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$ACCLAIM" litmus-ship --terminal done --line 'done: opened PR https://github.com/zerwiz/ymir/pull/999' 2>&1)"
printf '%s' "$out" | grep -q 'review-spawn\[1\]' && ok "the terminal done auto-sends the judge" || bad "hook: $out"
printf '%s' "$out" | grep -q 'litmus-ship-review' && ok "the hook names the review errand" || bad "hook id: $out"

# 9. ONE HEAD, ONE JUDGE: the errand road and the keeper's PR-only road share the per-head marker,
#    and the PR-only id carries the repository (review of #863, 2026-11-21)
H=abcdefabcdefabcdefabcdefabcdefabcdefabcd
cat >"$TMP/bin/gh" <<GH
#!/usr/bin/env bash
case " \$* " in
  *" -q "*) echo $H ;;
  *" pr view "*) printf '{"headRefOid":"$H","headRefName":"eindri/litmus-ship","mergeable":"MERGEABLE"}\\n' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$TMP/bin/gh"
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$SPAWN" --pr https://github.com/zerwiz/ymir/pull/999 --project "$PROJ" 2>&1)"
printf '%s' "$out" | grep -q 'pr-zerwiz--ymir-999-review' && ok "the PR-only review id carries the repository" || bad "repo in id: $out"
mkdir -p "$TMP/home/state/.reviewed"
: >"$TMP/home/state/.reviewed/pr-zerwiz--ymir-999.$H"
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$SPAWN" litmus-ship 2>&1)"
printf '%s' "$out" | grep -q 'one head, one judge' && ok "the errand road seats no second judge for a head the keeper judged" || bad "one head one judge (task): $out"
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$SPAWN" --pr https://github.com/zerwiz/ymir/pull/999 --project "$PROJ" 2>&1)"
printf '%s' "$out" | grep -q 'already reviewed' && ok "the PR-only road seats no second judge for the same head" || bad "one head one judge (pr): $out"
rm -f "$TMP/home/state/.reviewed/pr-zerwiz--ymir-999.$H"

# 8. the fence held: no line of this suite was typed into a live pane
if grep -qE 'agent (prompt|send|run)|pane (send|run|write)' "$TMP/herdr.log" 2>/dev/null; then
  bad "the acclaim typed into a pane: $(cat "$TMP/herdr.log")"
else
  ok "the acclaim road paged nobody (YMIR_NO_INJECT, fake herdr)"
fi

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
