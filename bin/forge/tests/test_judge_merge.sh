#!/usr/bin/env bash
# test_judge_merge.sh — the judge's verdict is the seal (RULES/08, its sections appended 2026-11-21).
#
# A fake gh and a fake verdict drive bin/forge/judge-merge.sh through bin/agents/pr-seal.sh's judge
# road. Every case asserts what reached GitHub (the fake's log), never what a door printed about it:
#
#   APPROVE + green         → exactly one merge, the right method, a written body, the approved head
#   a gathered batch        → a merge commit, never a squash
#   APPROVE + red           → no merge; one comment naming the failing row
#   APPROVE + pending       → no merge, and NOT settled (the same approval is tried again)
#   head moved              → no merge
#   NEEDS-REWORK            → one comment with the items, a wake, no merge
#   hold label · draft      → no merge
#   state/.seal-hold        → no merge
#   wrong gh identity       → refused, no merge
#   a stale report          → a report older than the judged record is never read as approval
#   not the house's repo    → refused, no merge
#
# Hermetic: the home, the state, the registry, gh and the ledger door are temp files this test writes.
# Usage: test_judge_merge.sh        Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
JM="$ROOT/bin/forge/judge-merge.sh"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$(printf '%s' "$2" | head -5)"; return 0; }

HEAD_A=1111111111111111111111111111111111111111
HEAD_B=2222222222222222222222222222222222222222
mkdir -p "$T/bin" "$T/home/hodd/identity" "$T/home/state" "$T/user"
cat >"$T/home/hodd/identity/projects.yaml" <<'YAML'
projects:
  - id: widget
    local_clone: CLONE_PATH
    git: {host: github.com, owner: acme, repo: widget, default_branch: main}
YAML
mkdir -p "$T/clone/.git"; sed -i "s|CLONE_PATH|$T/clone|" "$T/home/hodd/identity/projects.yaml"

# ── the fake gh: answers from $FIX, logs every write to $GHLOG ──────────────────────────────────
cat >"$T/bin/gh" <<'GH'
#!/usr/bin/env bash
F="${FIX:?}"
case "$1 $2" in
  "api user") cat "$F/login" ;;
  "pr view")
    case " $* " in
      *" mergeCommit "*) echo "feedbeef00000000000000000000000000000000" ;;
      *" -q .body "*) python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("body",""))' "$F/pr.json" ;;
      *) cat "$F/pr.json" ;;
    esac ;;
  "pr merge") printf 'MERGE %s\n' "$*" >>"$GHLOG"; printf '%s\n' "$@" >"$GHLOG.lastargs" ;;
  "pr comment") printf 'COMMENT %s\n' "$*" >>"$GHLOG" ;;
  *) echo "fake gh: unhandled $*" >&2; exit 1 ;;
esac
GH
cat >"$T/bin/runes" <<'R'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RUNELOG"
R
for d in rodd notify armsend; do printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"$WAKELOG.%s"\n' "$d" >"$T/bin/$d"; done
chmod +x "$T/bin/gh" "$T/bin/runes" "$T/bin/rodd" "$T/bin/notify" "$T/bin/armsend"

export PATH="$T/bin:$PATH" HOME="$T/user" YMIR_HOME="$T/home" YMIR_STATE_DIR="$T/home/state" \
  PROJECTS_YAML="$T/home/hodd/identity/projects.yaml" YMIR_RUNES_DOOR="$T/bin/runes" \
  FIX="$T/fix" GHLOG="$T/gh.log" RUNELOG="$T/runes.log" WAKELOG="$T/wake" \
  YMIR_RODD_DOOR="$T/bin/rodd" YMIR_NOTIFY_DOOR="$T/bin/notify" YMIR_ARM_SEND_DOOR="$T/bin/armsend" \
  YMIR_FLEET_REGISTRY="$T/no-fleet.json"
unset YMIR_MERGE_IDENTITY YMIR_HOARD_LIB_LOADED

pr_json() {  # <head> <ci: green|red|pending> [draft] [labels-json] [branch]
  local head="$1" ci="$2" draft="${3:-false}" labels="${4:-[]}" branch="${5:-eindri/widget-fix}" roll
  case "$ci" in
    green)   roll='[{"__typename":"CheckRun","name":"whole-tree","status":"COMPLETED","conclusion":"SUCCESS"}]' ;;
    red)     roll='[{"__typename":"CheckRun","name":"whole-tree","status":"COMPLETED","conclusion":"FAILURE"}]' ;;
    pending) roll='[{"__typename":"CheckRun","name":"whole-tree","status":"IN_PROGRESS","conclusion":""}]' ;;
  esac
  cat >"$FIX/pr.json" <<JSON
{"number":7,"headRefName":"$branch","headRefOid":"$head","title":"widget: mend the hinge","url":"https://github.com/acme/widget/pull/7",
 "mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":$roll,"isDraft":$draft,"labels":$labels,
 "state":"OPEN","body":"The hinge is mended.\nArm: here-only"}
JSON
}

fresh() {  # <verdict-row> [repo] — a clean state, a judged record for HEAD_A, then the report after it
  rm -rf "$T/home/state" "$FIX" "$GHLOG" "$GHLOG.lastargs" "$RUNELOG" "$WAKELOG".*
  mkdir -p "$T/home/state/.reviewed" "$T/home/state/eindri-reports" "$FIX"
  printf 'acme\n' >"$FIX/login"
  printf 'review=pr-7-review\ntask=pr-7\nrepo=%s\npr=7\nhead=%s\nurl=https://github.com/acme/widget/pull/7\n' \
    "${2:-acme/widget}" "$HEAD_A" >"$T/home/state/.reviewed/pr-7-review.judged"
  touch -d '-1 minute' "$T/home/state/.reviewed/pr-7-review.judged"
  printf '# review of #7\n\njudged-head: %s\n\nverdict[1]{result,count,list,seal}:\n  %s\n' "$HEAD_A" "$1" \
    >"$T/home/state/eindri-reports/pr-7-review.md"
}
merges() { local n; n=$(grep -c "^MERGE" "$GHLOG" 2>/dev/null); echo "${n:-0}"; }
comments() { local n; n=$(grep -c "^COMMENT" "$GHLOG" 2>/dev/null); echo "${n:-0}"; }
APPROVE='"APPROVE","0","","seal-ready"'
REWORK='"NEEDS-REWORK","2","1. the fix note is missing 2. the test never runs","holds seal"'

echo "judge-merge: the verdict is the seal"

# 1 · APPROVE + green → exactly one merge, squash, written body, the approved head
fresh "$APPROVE"; pr_json "$HEAD_A" green
out="$("$JM" act pr-7-review 2>&1)"
if [ "$(merges)" = 1 ]; then ok "APPROVE + green merges exactly once"; else bad "APPROVE + green merges exactly once" "$out"; fi
args="$(cat "$GHLOG.lastargs" 2>/dev/null)"
printf '%s\n' "$args" | grep -qx -- '--squash' && ok "a single PR is squashed" || bad "a single PR is squashed" "$args"
printf '%s\n' "$args" | grep -A1 -x -- '--match-head-commit' | grep -qx "$HEAD_A" \
  && ok "the merge is pinned to the approved head" || bad "the merge is pinned to the approved head" "$args"
printf '%s\n' "$args" | grep -qx -- '--body' && ! grep -qi 'co-authored-by' "$GHLOG.lastargs" \
  && ok "the squash carries a written body and no co-author trailer" || bad "written body" "$args"
printf '%s\n' "$args" | grep -qx -- '-R' && printf '%s\n' "$args" | grep -qx 'acme/widget' \
  && ok "the merge names the repository" || bad "the merge names the repository" "$args"
[ "$(wc -l <"$RUNELOG" 2>/dev/null || echo 0)" = 1 ] && ok "one Rune per merge" || bad "one Rune per merge"
[ -e "$T/home/state/.reviewed/pr-7-review.$HEAD_A.acted" ] && ok "the review is settled for its head" || bad "settled"
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 1 ] && ok "a second act merges nothing more" || bad "a second act merges nothing more"

# 2 · a gathered batch takes a merge commit
fresh "$APPROVE"; pr_json "$HEAD_A" green false '[]' yggdrasil/gather-20261121
"$JM" act pr-7-review >/dev/null 2>&1
grep -qx -- '--merge' "$GHLOG.lastargs" 2>/dev/null && ok "a gathered batch takes a merge commit" || bad "a gathered batch takes a merge commit" "$(cat "$GHLOG" 2>/dev/null)"

# 3 · APPROVE + red → no merge, a comment naming the failing row
fresh "$APPROVE"; pr_json "$HEAD_A" red
out="$("$JM" act pr-7-review 2>&1)"
[ "$(merges)" = 0 ] && ok "APPROVE + red merges nothing" || bad "APPROVE + red merges nothing" "$out"
grep '^COMMENT' "$GHLOG" 2>/dev/null | grep -q 'whole-tree=failure' && ok "the comment names the failing row" || bad "the comment names the failing row" "$(cat "$GHLOG" 2>/dev/null) $out"

# 4 · APPROVE + pending → no merge, not settled; turning green later merges the same approval
fresh "$APPROVE"; pr_json "$HEAD_A" pending
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && [ ! -e "$T/home/state/.reviewed/pr-7-review.$HEAD_A.acted" ] \
  && ok "APPROVE + pending waits, unsettled" || bad "APPROVE + pending waits, unsettled"
pr_json "$HEAD_A" green
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 1 ] && ok "the same approval merges once the gate turns green" || bad "pending then green merges once"

# 5 · the head moved since the approval → no merge
fresh "$APPROVE"; pr_json "$HEAD_B" green
out="$("$JM" act pr-7-review 2>&1)"
[ "$(merges)" = 0 ] && ok "a moved head merges nothing" || bad "a moved head merges nothing" "$out"

# 6 · NEEDS-REWORK → one comment with the items, a wake, no merge
fresh "$REWORK"; pr_json "$HEAD_A" green
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && ok "NEEDS-REWORK merges nothing" || bad "NEEDS-REWORK merges nothing"
[ "$(comments)" = 1 ] && grep -q 'fix note is missing' "$GHLOG" && ok "NEEDS-REWORK posts the items as one comment" || bad "rework comment" "$(cat "$GHLOG" 2>/dev/null)"
grep -q 'NEEDS-REWORK' "$T/home/state/.wake-queue" 2>/dev/null && ok "NEEDS-REWORK wakes the author's seat" || bad "rework wake"
grep -q '^here-only .*start a coder errand on branch eindri/widget-fix' "$WAKELOG.armsend" 2>/dev/null \
  && ok "the opener's arm holder (Arm: here-only) is handed a coder errand over the arm wire" || bad "arm wire to the opener" "$(cat "$WAKELOG".* 2>/dev/null)"
# the opener is this seat (no Arm line): both local roads — the arm wire AND a turn typed into the pane
fresh "$REWORK"; pr_json "$HEAD_A" green
python3 - "$FIX/pr.json" <<'PY'
import json, sys; p = json.load(open(sys.argv[1])); p["body"] = "no arm line"; json.dump(p, open(sys.argv[1], "w"))
PY
"$JM" act pr-7-review >/dev/null 2>&1
grep -q 'coder errand' "$WAKELOG.rodd" 2>/dev/null && grep -q 'coder errand' "$WAKELOG.notify" 2>/dev/null \
  && ok "a local opener is reached by the arm wire and in its herdr pane" || bad "local rework roads" "$(ls "$T"/wake.* 2>/dev/null)"

# 7 · hold label and draft → no merge
fresh "$APPROVE"; pr_json "$HEAD_A" green false '[{"name":"hold"}]'
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && ok "a hold label merges nothing" || bad "a hold label merges nothing"
fresh "$APPROVE"; pr_json "$HEAD_A" green true
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && ok "a draft merges nothing" || bad "a draft merges nothing"

# 8 · the brake
fresh "$APPROVE"; pr_json "$HEAD_A" green
printf 'the operator is moving the house\n' >"$T/home/state/.seal-hold"
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && ok "state/.seal-hold merges nothing" || bad "state/.seal-hold merges nothing"

# 9 · the wrong hand
fresh "$APPROVE"; pr_json "$HEAD_A" green
printf 'someone-else\n' >"$FIX/login"
out="$("$JM" act pr-7-review 2>&1)"
[ "$(merges)" = 0 ] && printf '%s' "$out" | grep -q 'wrong identity' \
  && ok "a gh identity that is not the registry's owner is refused" || bad "wrong identity refused" "$out"

# 10 · a report older than the judged record is an earlier head's verdict
fresh "$APPROVE"; pr_json "$HEAD_A" green
touch -d '-1 hour' "$T/home/state/eindri-reports/pr-7-review.md"
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && ok "a stale report is never read as approval" || bad "a stale report is never read as approval"

# 11 · a repository the registry does not name
fresh "$APPROVE" stranger/thing; pr_json "$HEAD_A" green
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && ok "a repository outside the registry merges nothing" || bad "outside the registry"

# 12 · the template's placeholder is not a verdict
fresh '"APPROVE or NEEDS-REWORK","the count","list","seal"'; pr_json "$HEAD_A" green
"$JM" act pr-7-review >/dev/null 2>&1
[ "$(merges)" = 0 ] && [ "$(comments)" = 0 ] && ok "an unfilled verdict does nothing" || bad "an unfilled verdict does nothing"

# 13 · the keeper: one judge at a time; a second PR is handed to a developer seat
echo "review-watch --keeper: a judge for every head, one at a time"
rm -rf "$T/home/state" "$GHLOG"; mkdir -p "$T/home/state/.reviewed" "$FIX"; printf 'acme\n' >"$FIX/login"
printf 'review-watch:\n  enabled: on\n' >"$T/wardens.yaml"
printf '{"heart":"nobody","hosts":{"devbox":{"roles":["dev"]}}}\n' >"$T/fleet.json"
cat >"$FIX/list.json" <<JSON
[{"number":8,"headRefOid":"$HEAD_B","isDraft":false,"url":"https://github.com/acme/widget/pull/8"},
 {"number":7,"headRefOid":"$HEAD_A","isDraft":false,"url":"https://github.com/acme/widget/pull/7"},
 {"number":9,"headRefOid":"3333333333333333333333333333333333333333","isDraft":true,"url":"https://github.com/acme/widget/pull/9"}]
JSON
cat >"$T/bin/gh" <<'GH'
#!/usr/bin/env bash
F="${FIX:?}"
case "$1 $2" in
  "api user") cat "$F/login" ;;
  "auth status") exit 0 ;;
  "pr list") cat "$F/list.json" ;;
  *) echo "fake gh: unhandled $*" >&2; exit 1 ;;
esac
GH
chmod +x "$T/bin/gh"
out="$(YMIR_WARDENS_FILE="$T/wardens.yaml" YMIR_FLEET_REGISTRY="$T/fleet.json" YMIR_REVIEW_KEEPER=1 YMIR_REVIEW_SEAT_HERE=1 \
  timeout 120 bash "$ROOT/bin/forge/review-watch.sh" --keeper --dry-run 2>&1)"
printf '%s\n' "$out" | grep -q "\"acme/widget#7\".*would seat the judge.*--project $T/clone" && ok "the oldest open PR gets the judge, in its own clone" || bad "the oldest open PR gets the judge" "$out"
printf '%s\n' "$out" | grep -q '"acme/widget#8".*would hand to devbox' && ok "the next PR is handed to a developer seat" || bad "hand-off to a developer seat" "$out"
printf '%s\n' "$out" | grep -q 'widget#9' && bad "a draft is never offered" "$out" || ok "a draft is never offered"
printf 'review=pr-7-review\nrepo=acme/widget\npr=7\nhead=%s\n' "$HEAD_A" >"$T/home/state/.reviewed/pr-7-review.judged"
out="$(YMIR_WARDENS_FILE="$T/wardens.yaml" YMIR_FLEET_REGISTRY="$T/fleet.json" YMIR_REVIEW_KEEPER=1 YMIR_REVIEW_SEAT_HERE=1 \
  timeout 120 bash "$ROOT/bin/forge/review-watch.sh" --keeper --dry-run 2>&1)"
printf '%s\n' "$out" | grep -q 'widget#7' && bad "a judged head is not judged twice" "$out" || ok "a judged head is not judged twice"
printf '%s\n' "$out" | grep -q '"acme/widget#8".*would hand to devbox' && ok "while a judge is in flight the next PR is handed on" || bad "in-flight hand-off" "$out"

# 14 · a keeper with no judge harness (the heart has no claude CLI) seats nothing and hands every
#      review to a developer seat — the arm wire and the holder's pane
rm -rf "$T/home/state" "$WAKELOG".*; mkdir -p "$T/home/state/.reviewed"
printf '{"heart":"nobody","hosts":{"devbox":{"roles":["dev"]},"devtwo":{"roles":["dev"]}}}\n' >"$T/fleet.json"
out="$(YMIR_WARDENS_FILE="$T/wardens.yaml" YMIR_FLEET_REGISTRY="$T/fleet.json" YMIR_REVIEW_KEEPER=1 YMIR_REVIEW_SEAT_HERE=0 \
  YMIR_SEAL_DOOR=/bin/false timeout 120 bash "$ROOT/bin/forge/review-watch.sh" --keeper 2>&1)"
printf '%s\n' "$out" | grep -q 'would seat\|judge is seated' && bad "a keeper with no judge harness seats nothing" "$out" || ok "a keeper with no judge harness seats nothing"
[ "$(grep -c 'eindri-review-spawn.sh --pr' "$WAKELOG.armsend" 2>/dev/null)" = 2 ] \
  && grep -q '^devbox ' "$WAKELOG.armsend" && grep -q '^devtwo ' "$WAKELOG.armsend" \
  && ok "every open head is handed to the developer seats in turn" || bad "hand-off of every head" "$(cat "$WAKELOG.armsend" 2>/dev/null) $out"
[ -e "$T/home/state/.reviewed/handed-pr-7.$HEAD_A" ] && ok "a handed head is marked, so it is handed once" || bad "handed marker"

printf 'judge-merge: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
