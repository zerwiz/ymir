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

RUN=(env "BROKK_STATE_OVERRIDE=$PROJ/state")

# 1. the sync contract: bash -n clean
bash -n "$SPAWN" 2>/dev/null && ok "eindri-review-spawn.sh is syntactically clean" || bad "bash -n eindri-review-spawn.sh"
bash -n "$ACCLAIM" 2>/dev/null && ok "eindri-acclaim.sh is syntactically clean" || bad "bash -n eindri-acclaim.sh"

# 2. the exact spawn line: scout, herdr, pi, the pinned judge model, high effort
out="$("${RUN[@]}" YMIR_REVIEW_DRY=1 "$SPAWN" litmus-ship)"
printf '%s' "$out" | grep -q -- '--scout --backend herdr --harness pi --model opencode-go/deepseek-v4.1-flash --effort high' \
  && ok "the spawn line is the exact einherjar review road" || bad "spawn line: $out"
printf '%s' "$out" | grep -q 'pull/999' && ok "the PR is read from the task status" || bad "PR not resolved: $out"
printf '%s' "$out" | grep -q 'litmus-ship-review' && ok "the review id is <task>-review" || bad "review id: $out"

# 3. the brief is filled for THIS task
brief="$PROJ/data/litmus-ship-review/brief.md"
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

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
