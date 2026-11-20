#!/usr/bin/env bash
# Unit tests for bin/gates/doc-sweep.sh — the shelf-sweeper (plan 63).
#
# Every fixture here is SYNTHETIC: a temp home, a temp documents root, names that
# exist nowhere else. The sweeper's whole errand is moving private material, so a
# test that used the operator's real documents would be the one test that must never
# run (Rule 04: no private data, and none of it touched by a test).
#
# The laws under test, one block each:
#   1. scan is REPORT ONLY, and the tree is byte-identical afterwards
#   2. classification by evidence, in the plan's order
#   3. apply moves EXACTLY the MOVE lines, and only those
#   4. a second apply is a no-op, and verify passes by name
#   5. a destination outside the home is REFUSED, with a reason
#   6. a symlink, an archive and a credential are REPORTED, never moved
#   7. a PROPOSE line is a proposal: apply never moves it
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWEEP="$ROOT/bin/gates/doc-sweep.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

HOME_DIR="$TMP/home"
HOARD="$HOME_DIR/hodd"
DOCS="$TMP/docs"
REPO="$TMP/repo"          # stands in for the public code tree
export YMIR_HOME="$HOME_DIR"
export YMIR_STATE_DIR="$TMP/state"

mkdir -p "$HOARD/identity" "$HOARD/life/marketing" "$HOARD/life/personal" \
         "$HOARD/life/work" "$HOARD/life/meetings" \
         "$HOME_DIR/svartalfaheim/work/projects/ymir/plans" "$DOCS" "$REPO/docs"

cat >"$HOARD/identity/projects.yaml" <<'YAML'
# synthetic registry for the test only
projects:
  - id: lantern-platform
    name: Lantern
    about: "a synthetic project that exists only inside this test"
    realm: work
    repo: .
    posture: local-only
  - id: moss
    name: Moss
    about: "a second synthetic project, one word"
    realm: work
    repo: .
    posture: local-only
YAML

printf 'a note for the operator\n'  >"$DOCS/lantern-platform notes.txt"
mkdir -p "$DOCS/moss"
printf 'a second note, same project\n' >"$DOCS/moss/plan.md"
printf 'notes for the marketing shelf\n' >"$DOCS/2026-09-30-marketing-notes.md"
printf 'a personal note\n'            >"$DOCS/personal diary.md"
printf 'a plan in waiting\n'           >"$DOCS/42-the-second-plan.md"
printf 'nothing names this shelf\n'    >"$DOCS/plain scratch.txt"
printf 'the same bytes twice\n'        >"$DOCS/copy one.txt"
printf 'the same bytes twice\n'        >"$DOCS/copy two.txt"
printf 'a credential by name\n'        >"$DOCS/some-service-token.txt"
printf 'PK\003\004not-a-document'      >"$DOCS/bundle.zip"
ln -s "$DOCS/plain scratch.txt" "$DOCS/a link to the scratch note"

tree_fingerprint() { find "$1" -mindepth 0 | LC_ALL=C sort | md5sum | cut -d' ' -f1; }
ALL="$TMP/all"; mkdir -p "$ALL"
all_fingerprint() { find "$HOME_DIR" "$DOCS" "$REPO" -mindepth 0 2>/dev/null | LC_ALL=C sort | md5sum | cut -d' ' -f1; }

# ── 1. scan is REPORT ONLY ────────────────────────────────────────────────────
docs_before="$(tree_fingerprint "$DOCS")"
all_before="$(all_fingerprint)"
plan="$TMP/sweep.plan"
out="$(bash "$SWEEP" scan "$DOCS" 2>&1)"; rc=$?
printf '%s\n' "$out" >"$plan"

if [ "$rc" -eq 0 ]; then ok "scan exits 0"; else bad "scan exited $rc"; printf '%s\n' "$out" | head -5 >&2; fi

if [ "$(tree_fingerprint "$DOCS")" = "$docs_before" ]; then
  ok "the scanned tree is byte-identical after scan"
else
  bad "scan CHANGED the scanned tree"
fi
if [ "$(all_fingerprint)" = "$all_before" ]; then
  ok "scan wrote no file anywhere (home, docs, repo)"
else
  bad "scan WROTE somewhere it must not"
fi

n_items="$(find "$DOCS" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
n_lines="$(grep -cE '^(MOVE|PROPOSE|REPORT) ' "$plan")"
if [ "$n_items" = "$n_lines" ]; then
  ok "every item is reported ($n_items items, $n_lines lines)"
else
  bad "the report covers $n_lines of $n_items items"
fi
if grep -q "doc_sweep\[$n_items\]" "$plan"; then
  ok "the tally counts what it claims ($n_items)"
else
  bad "the tally does not match the item count"
fi

# ── 2. classification, by evidence, in the plan's order ───────────────────────
if grep -qE "^MOVE .*lantern-platform notes\.txt  ->  $HOME_DIR/svartalfaheim/work/projects/lantern-platform/docs/" "$plan"; then
  ok "a path naming a known project lands on that project's shelf"
else
  bad "a known-project path was not placed on the project shelf"
  grep -E 'lantern' "$plan" | head -2 >&2
fi
if grep -qE "^MOVE .*/docs/moss  ->  .*/projects/moss(/docs)?/moss   because: names the known project moss" "$plan"; then
  ok "a one-word project id places a directory named after it"
else
  bad "a one-word project id did not place its directory"
  grep -E '/docs/moss' "$plan" | head -2 >&2
fi
if grep -qE "^PROPOSE .*42-the-second-plan\.md  ->  .*/plans/42-the-second-plan\.md" "$plan"; then
  ok "a numbered plan is PROPOSED to the ledger, not moved"
else
  bad "a numbered plan was not proposed to the ledger"
  grep -E '42-the-second' "$plan" | head -2 >&2
fi
if grep -qE "^MOVE .*2026-09-30-marketing-notes\.md  ->  $HOARD/life/marketing/" "$plan"; then
  ok "a dated note carrying a known domain lands in hodd/life/<domain>/"
else
  bad "a dated domain note was not placed in hodd/life/marketing/"
fi
if grep -qE "^MOVE .*personal diary\.md  ->  $HOARD/life/personal/" "$plan"; then
  ok "a note naming the personal domain lands in hodd/life/personal/"
else
  bad "a personal note was not placed in hodd/life/personal/"
fi
if grep -qE "^REPORT .*plain scratch\.txt .*because: no evidence" "$plan"; then
  ok "an unplaceable file is reported as unplaceable, never dumped into docs/"
else
  bad "an unplaceable file was not reported as unplaceable"
fi
if grep -qE "^REPORT .*some-service-token\.txt .*credential" "$plan"; then
  ok "a credential by name is held, never moved"
else
  bad "a credential by name was not held"
fi
if grep -qE "^REPORT .*bundle\.zip .*not a document" "$plan"; then
  ok "an archive is reported, never moved"
else
  bad "an archive was not reported as a non-document"
fi
if grep -qE "^REPORT .*a link to the scratch note .*symlink" "$plan"; then
  ok "a symlink is reported, never moved"
else
  bad "a symlink was not reported as a symlink"
fi
if grep -qE "^REPORT .*copy two\.txt .*duplicate" "$plan"; then
  ok "a duplicate is reported as a duplicate, never resolved by removing one"
else
  bad "a duplicate was not reported as a duplicate"
fi
if [ -e "$DOCS/copy one.txt" ] && [ -e "$DOCS/copy two.txt" ]; then
  ok "both copies survive the report (nothing is ever deleted)"
else
  bad "a copy was REMOVED by the sweep"
fi
if grep -qE '^MOVE .*bundle\.zip' "$plan" || grep -qE '^MOVE .*a link to' "$plan"; then
  bad "a non-document was proposed to MOVE"
else
  ok "no non-document is ever proposed to move"
fi

# ── 3. apply moves EXACTLY the MOVE lines ─────────────────────────────────────
small="$TMP/small.plan"
{
  printf '# a hand-written plan: two lines, two moves\n'
  printf 'MOVE    %s  ->  %s   because: a dated note carrying a known domain\n' \
    "$DOCS/2026-09-30-marketing-notes.md" "$HOARD/life/marketing/2026-09-30-marketing-notes.md"
  printf 'PROPOSE %s  ->  %s   because: a machine proposes, a human moves\n' \
    "$DOCS/42-the-second-plan.md" "$HOME_DIR/svartalfaheim/work/projects/ymir/plans/42-the-second-plan.md"
  printf 'MOVE    %s  ->  %s   because: names the known project lantern-platform\n' \
    "$DOCS/lantern-platform notes.txt" "$HOME_DIR/svartalfaheim/work/projects/lantern-platform/docs/lantern-platform notes.txt"
} >"$small"

out="$(bash "$SWEEP" apply --plan "$small" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "apply exits 0"; else bad "apply exited $rc"; printf '%s\n' "$out" >&2; fi
if [ -f "$HOARD/life/marketing/2026-09-30-marketing-notes.md" ] \
   && [ -f "$HOME_DIR/svartalfaheim/work/projects/lantern-platform/docs/lantern-platform notes.txt" ]; then
  ok "both MOVE lines landed where the plan said"
else
  bad "a MOVE line did not land"
fi
if [ -f "$DOCS/42-the-second-plan.md" ] && [ ! -e "$HOME_DIR/svartalfaheim/work/projects/ymir/plans/42-the-second-plan.md" ]; then
  ok "a PROPOSE line is NOT moved by apply"
else
  bad "apply moved a PROPOSE line"
fi
if printf '%s' "$out" | grep -q 'moved  '; then ok "apply records what it did"; else bad "apply printed no record of the move"; fi

# ── 4. a second apply is a no-op, and verify passes by name ───────────────────
out2="$(bash "$SWEEP" apply --plan "$small" 2>&1)"; rc2=$?
if [ "$rc2" -eq 0 ] && printf '%s' "$out2" | grep -q 'doc_sweep_apply\[4\]{moved,already,refused,ledger}:' \
   && printf '%s' "$out2" | grep -qE '^  0,2,0,'; then
  ok "a second apply is a no-op (moved=0, already=2)"
else
  bad "a second apply was NOT a no-op (rc=$rc2)"; printf '%s\n' "$out2" >&2
fi
out3="$(bash "$SWEEP" verify 2>&1)"; rc3=$?
if [ "$rc3" -eq 0 ] && printf '%s' "$out3" | grep -qE '^  2,2,0$' \
   && printf '%s' "$out3" | grep -q '2026-09-30-marketing-notes.md'; then
  ok "verify passes BY NAME: 2 checked, 2 ok, 0 failed"
else
  bad "verify did not pass by name (rc=$rc3)"; printf '%s\n' "$out3" >&2
fi

# ── 5. a destination OUTSIDE the home is refused, with a reason ───────────────
outside="$TMP/outside.plan"
printf 'MOVE    %s  ->  %s   because: someone tried to write into the code tree\n' \
  "$DOCS/plain scratch.txt" "$REPO/docs/plain scratch.txt" >"$outside"
out4="$(bash "$SWEEP" apply --plan "$outside" 2>&1)"; rc4=$?
if [ "$rc4" -ne 0 ] && printf '%s' "$out4" | grep -q 'OUTSIDE the home' \
   && [ -f "$DOCS/plain scratch.txt" ] && [ ! -e "$REPO/docs/plain scratch.txt" ]; then
  ok "a destination under the repo is REFUSED with a reason, and the file stays put"
else
  bad "a destination outside the home was not refused (rc=$rc4)"; printf '%s\n' "$out4" >&2
fi

# a plan where ONE line is bad must move NOTHING at all
mixed="$TMP/mixed.plan"
{
  printf 'MOVE    %s  ->  %s   because: a good line\n' \
    "$DOCS/personal diary.md" "$HOARD/life/personal/personal diary.md"
  printf 'MOVE    %s  ->  %s   because: a bad line\n' \
    "$DOCS/copy one.txt" "$REPO/docs/copy one.txt"
} >"$mixed"
out5="$(bash "$SWEEP" apply --plan "$mixed" 2>&1)"; rc5=$?
if [ "$rc5" -ne 0 ] && [ -f "$DOCS/personal diary.md" ] && [ ! -e "$HOARD/life/personal/personal diary.md" ]; then
  ok "one bad line refuses the WHOLE plan — a half-applied plan is worse than none"
else
  bad "a plan with one bad line still moved the good line (rc=$rc5)"; printf '%s\n' "$out5" >&2
fi

# ── 6. a plan may not move a symlink, an archive or a credential ───────────────
forbidden="$TMP/forbidden.plan"
{
  printf 'MOVE    %s  ->  %s   because: a plan may not move a symlink\n' \
    "$DOCS/a link to the scratch note" "$HOARD/life/personal/a link to the scratch note"
  printf 'MOVE    %s  ->  %s   because: a plan may not move a credential\n' \
    "$DOCS/some-service-token.txt" "$HOARD/life/work/some-service-token.txt"
} >"$forbidden"
out6="$(bash "$SWEEP" apply --plan "$forbidden" 2>&1)"; rc6=$?
if [ "$rc6" -ne 0 ] && [ -L "$DOCS/a link to the scratch note" ] && [ -f "$DOCS/some-service-token.txt" ]; then
  ok "a plan may not move a symlink or a credential — both refused"
else
  bad "a plan moved a symlink or a credential (rc=$rc6)"; printf '%s\n' "$out6" >&2
fi

# an overwrite is refused: nothing is ever overwritten
overwrite="$TMP/overwrite.plan"
printf 'MOVE    %s  ->  %s   because: the destination exists\n' \
  "$DOCS/copy one.txt" "$HOARD/life/marketing/2026-09-30-marketing-notes.md" >"$overwrite"
out7="$(bash "$SWEEP" apply --plan "$overwrite" 2>&1)"; rc7=$?
if [ "$rc7" -ne 0 ] && printf '%s' "$out7" | grep -q 'overwritten' \
   && [ -f "$DOCS/copy one.txt" ]; then
  ok "a line that would overwrite an existing file is refused"
else
  bad "an overwrite was not refused (rc=$rc7)"; printf '%s\n' "$out7" >&2
fi

# ── 7. a file already on its shelf is a no-op, and inside the home the sweep ──
#       reports what is already filed rather than proposing a move
mkdir -p "$HOARD/life/work"
printf 'a filed note\n' >"$HOARD/life/work/2026-01-01-work-note.md"
out8="$(bash "$SWEEP" scan --depth 2 "$HOARD/life" 2>&1)"
if printf '%s' "$out8" | grep -qE '^REPORT .*2026-01-01-work-note\.md .*already on its shelf'; then
  ok "a document already on its shelf is reported in place, not re-moved"
else
  bad "an in-place document was not reported as in place"; printf '%s\n' "$out8" | head -12 >&2
fi

# ── 8. the vault's own machine shelves are never swept ───────────────────────
mkdir -p "$HOARD/secrets" "$TMP/state"
printf 'a key\n' >"$HOARD/secrets/platform.env"
out9="$(bash "$SWEEP" scan --depth 2 "$HOARD" 2>&1)"
if printf '%s' "$out9" | grep -qE '^REPORT .*secrets/platform\.env .*(machine record|credential)'; then
  ok "the vault's own machine shelves are reported, never swept"
else
  bad "the sweeper reached into the vault's machine shelves"; printf '%s\n' "$out9" | grep secrets >&2
fi

if [ "$fail" -eq 0 ]; then
  printf 'doc-sweep: every law held\n'
  exit 0
fi
printf 'doc-sweep: a law broke — see the not-ok lines\n' >&2
exit 1
