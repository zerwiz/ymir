#!/usr/bin/env bash
# test_review_spawn_data_home.sh — the review spine writes its brief in the HOME, never the code
# checkout (2026-11-20).
#
# What happened: bin/agents/eindri-review-spawn.sh derived the errand data shelf from the project
# root (`<checkout>/data`), created `<checkout>/data/<id>-review/`, and handed that path on as
# BROKK_DATA_OVERRIDE — so einherjar-spawn.sh refused every review judge on a developer seat with
# "the house is split — data resolves outside the home", and the helm moved the folder home by
# hand four times in one evening.
#
# What this proves, on a throwaway home and a throwaway checkout:
#
#   · a review spawn in --dry-run writes its brief under <home>/hodd/data and leaves the checkout
#     with NO data/ folder at all;
#   · a caller that hands the spine a BROKK_DATA_OVERRIDE outside the home is refused aloud, and
#     the home's shelf is used — the code tree gains nothing;
#   · with no resolver at all (no hoard-lib beside the spine) the spine REFUSES instead of writing
#     a data folder inside the checkout.
#
# Exit: 0 every case held · 1 a case failed.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-review-spawn-data.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

HOME_ROOT="$TMP/home"
STATE="$HOME_ROOT/state"
CHECKOUT="$TMP/checkout"
mkdir -p "$HOME_ROOT/hodd/data" "$STATE" "$CHECKOUT"

# A throwaway tree shaped like the repo, so ROOT resolves to it and no live door is touched.
tree() {  # <dir> [--with-resolver]
  local t=$1 want_lib=${2-}
  mkdir -p "$t/bin/agents" "$t/bin/vault" "$t/RULES" "$t/.pi" \
           "$t/.agents/assets/templates" "$t/bin/model"
  cp "$ROOT/bin/agents/eindri-review-spawn.sh" "$t/bin/agents/"
  [ "$want_lib" = "--with-resolver" ] && cp "$ROOT/bin/vault/hoard-lib.sh" "$t/bin/vault/"
  cp "$ROOT/.agents/assets/templates/review-brief.template.md" "$t/.agents/assets/templates/"
  printf '#!/usr/bin/env bash\nprintf "test/model\\n"\n' >"$t/bin/model/agent-model.sh"
  chmod +x "$t/bin/model/agent-model.sh"
}

TREE="$TMP/tree"
tree "$TREE" --with-resolver
NO_LIB_TREE="$TMP/tree-no-lib"
tree "$NO_LIB_TREE"

# One shipped errand whose PR is already opened, recorded in the home's state.
ID=spine-fixture
mkdir -p "$STATE"
{
  printf 'id=%s\n' "$ID"
  printf 'kind=ship\n'
  printf 'project=%s\n' "$CHECKOUT"
  printf 'worktree=%s\n' "$CHECKOUT"
} >"$STATE/$ID.meta"
printf 'done: opened PR https://github.com/example/repo/pull/1\n' >"$STATE/$ID.status"

unset BROKK_DATA_OVERRIDE BROKK_STATE_OVERRIDE BROKK_ROOT_OVERRIDE 2>/dev/null || true
export YMIR_HOME="$HOME_ROOT"
export YMIR_CONFIG_DIR="$TMP/config"
export YMIR_STATE_DIR="$STATE"
export YMIR_AUTO_REVIEW=on
export YMIR_REVIEW_MODEL="test/model"
export YMIR_REVIEW_DRY=0

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -3 | tr '\n' ' ')"; }

# ── case 1: the ordinary dry run — the brief is in the home, the checkout is untouched ────────
out="$(bash "$TREE/bin/agents/eindri-review-spawn.sh" "$ID" --dry-run 2>"$TMP/c1.err")"
rc=$?
brief="$HOME_ROOT/hodd/data/$ID-review/brief.md"
[ "$rc" -eq 0 ] && ok "case 1: the dry run succeeded" || bad "case 1: the dry run failed" "$(cat "$TMP/c1.err")"
printf '%s' "$out" | grep -q '^review-spawn\[1\]{' \
  && ok "case 1: it printed the TOON spawn line" || bad "case 1: no TOON line" "$out"
printf '%s' "$out" | grep -q "$brief" \
  && ok "case 1: the brief it named is under the home" || bad "case 1: the brief is not under the home ($brief)" "$out"
[ -s "$brief" ] \
  && ok "case 1: the brief exists at <home>/hodd/data/$ID-review/brief.md" || bad "case 1: no brief written in the home" "$(ls -R "$HOME_ROOT/hodd" 2>&1 | head -20)"
grep -q "HOME/hodd/data/$ID-review/brief.md" <<<"$(printf '%s' "$out" | sed "s#$HOME_ROOT#HOME#g")" \
  && ok "case 1: the printed path is the home's data shelf, not the checkout's" || bad "case 1: wrong shelf printed" "$out"
[ -e "$CHECKOUT/data" ] \
  && bad "case 1: a data folder was created inside the code checkout" "$(ls -R "$CHECKOUT/data" 2>&1 | head -20)" \
  || ok "case 1: NO data folder inside the code checkout"

# ── case 2: a caller hands over a data dir outside the home — refused aloud, nothing written ──
rm -rf "$HOME_ROOT/hodd/data/$ID-review"
out2="$(BROKK_DATA_OVERRIDE="$CHECKOUT/data" bash "$TREE/bin/agents/eindri-review-spawn.sh" "$ID" --dry-run 2>"$TMP/c2.err")"
rc2=$?
err2="$(cat "$TMP/c2.err")"
[ "$rc2" -eq 0 ] && ok "case 2: the dry run still succeeded" || bad "case 2: the dry run failed" "$err2"
grep -q "lies outside the home" <<<"$err2" \
  && ok "case 2: the override outside the home was refused aloud" || bad "case 2: the refusal was silent" "$err2"
[ -s "$brief" ] \
  && ok "case 2: the brief still landed in the home" || bad "case 2: no brief in the home" "$(ls -R "$HOME_ROOT/hodd" 2>&1 | head -20)"
[ -e "$CHECKOUT/data" ] \
  && bad "case 2: the override created a data folder in the checkout" "$(ls -R "$CHECKOUT/data" 2>&1 | head -20)" \
  || ok "case 2: the checkout stayed clean"

# ── case 3: no resolver beside the spine — a refusal, never a folder in the checkout ──────────
rm -rf "$HOME_ROOT/hodd/data/$ID-review"
out3="$(bash "$NO_LIB_TREE/bin/agents/eindri-review-spawn.sh" "$ID" --dry-run 2>"$TMP/c3.err")"
rc3=$?
err3="$(cat "$TMP/c3.err")"
[ "$rc3" -ne 0 ] \
  && ok "case 3: a spine with no resolver refuses (exit $rc3)" || bad "case 3: it answered without a resolver" "$out3"
grep -q "no data shelf resolved" <<<"$err3" \
  && ok "case 3: the refusal names the missing shelf" || bad "case 3: the refusal does not say what is wrong" "$err3"
[ -e "$TMP/data" ] || [ -e "$NO_LIB_TREE/data" ] || [ -e "$CHECKOUT/data" ] \
  && bad "case 3: a data folder appeared in a checkout" "$(ls -R "$TMP/data" "$NO_LIB_TREE/data" "$CHECKOUT/data" 2>&1 | head -20)" \
  || ok "case 3: no data folder inside any checkout"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
