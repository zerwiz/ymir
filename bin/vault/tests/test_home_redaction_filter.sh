#!/usr/bin/env bash
# test_home_redaction_filter.sh — the mail spine is redacted on commit, on EVERY seat.
#
# Why this test exists: plan 116 §18 keeps a credential out of git with a CLEAN FILTER —
# `.gitattributes` marks `hodd/memory/mail/messages.jsonl` `filter=gna-redact` and the filter is
# `hodd/bin/mail-redact.py`. Git config does not travel with a clone, so the filter was seated by
# hand on one machine and a seat that merely pulled the home would have committed RAW mail with
# passwords in it. It is now seated by `bin/vault/home-sync.sh setup`, and `ship` refuses the spine
# on a seat without it. Both halves are proved here, end to end, against a real git repo:
#
#   1 · setup seats clean / smudge / required from the home's own script
#   2 · a real ship commits the REDACTED blob (the working copy keeps the letter)
#   3 · with the filter unseated, ship REFUSES the spine and commits nothing
#   4 · a path that carries no filter attribute is still shipped normally
#
#   bash bin/vault/tests/test_home_redaction_filter.sh
#
# Exit: 0 all four hold · 1 a case failed (each printed by name).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/vault/home-sync.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
HOME_DIR="$T/home"
SPINE="hodd/memory/mail/messages.jsonl"
rc=0
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; rc=1; }

[ -f "$DOOR" ] || { echo "missing $DOOR"; exit 1; }
command -v git >/dev/null || { echo "git is required"; exit 1; }

# ── a home shaped like the real one: an attribute, a filter script, a spine ──────────────────────
mkdir -p "$HOME_DIR/hodd/bin" "$HOME_DIR/hodd/memory/mail"
cat > "$HOME_DIR/hodd/bin/mail-redact.py" <<'PY'
import sys
sys.stdout.write(sys.stdin.read().replace("hunter2", "[redacted]"))
PY
printf 'hodd/memory/mail/messages.jsonl filter=gna-redact merge=union\n' > "$HOME_DIR/.gitattributes"
printf '{"id":"1","body_text":"the wifi password: hunter2"}\n' > "$HOME_DIR/$SPINE"
printf 'a home note\n' > "$HOME_DIR/note.md"
git -C "$HOME_DIR" init -q -b main
git -C "$HOME_DIR" config user.name tester
git -C "$HOME_DIR" config user.email tester@example.org
git -C "$HOME_DIR" config commit.gpgsign false
git -C "$HOME_DIR" add .gitattributes note.md
git -C "$HOME_DIR" commit -q -m base
git -C "$T" init -q --bare remote.git
git -C "$HOME_DIR" remote add origin "$T/remote.git"

hs() { YMIR_HOME="$HOME_DIR" YMIR_OFFLINE=1 HOME_SYNC_REMOTE=origin HOME_SYNC_BRANCH=main bash "$DOOR" "$@"; }

printf 'setup seats the filter from the home own script\n'
hs setup >/dev/null 2>&1
[ "$(git -C "$HOME_DIR" config --get filter.gna-redact.clean)" = "python3 hodd/bin/mail-redact.py" ] \
  && ok 'filter.gna-redact.clean = python3 hodd/bin/mail-redact.py' \
  || bad "clean driver is $(git -C "$HOME_DIR" config --get filter.gna-redact.clean || echo unset)"
[ "$(git -C "$HOME_DIR" config --get filter.gna-redact.smudge)" = "cat" ] \
  && ok 'filter.gna-redact.smudge = cat' \
  || bad "smudge is $(git -C "$HOME_DIR" config --get filter.gna-redact.smudge || echo unset)"
[ "$(git -C "$HOME_DIR" config --get filter.gna-redact.required)" = true ] \
  && ok 'filter.gna-redact.required = true' \
  || bad "required is $(git -C "$HOME_DIR" config --get filter.gna-redact.required || echo unset)"

printf 'a seated filter redacts the COMMITTED blob, not the working copy\n'
hs ship "carry the mail spine" "$SPINE" >/dev/null 2>&1
committed="$(git -C "$HOME_DIR" show "HEAD:$SPINE")"
case "$committed" in
  *"[redacted]"*) ok 'the committed blob carries [redacted]' ;;
  *) bad "the committed blob carries the raw letter: $committed" ;;
esac
case "$committed" in
  *hunter2*) bad 'the committed blob still holds the password' ;;
  *) ok 'the password is not in git' ;;
esac
if grep -q 'hunter2' "$HOME_DIR/$SPINE"; then ok 'the working copy keeps the letter whole'
else bad 'the working copy was redacted too — the filter ran on the wrong side'; fi

printf 'an unseated filter REFUSES the spine\n'
git -C "$HOME_DIR" config --unset filter.gna-redact.clean
printf '{"id":"2","body_text":"the ftp password: hunter2"}\n' >> "$HOME_DIR/$SPINE"
before="$(git -C "$HOME_DIR" rev-parse HEAD)"
out="$(hs ship "would carry raw mail" "$SPINE" 2>&1)"; got=$?
[ "$got" = 1 ] && ok 'ship exits 1' || bad "ship exited $got"
case "$out" in *"refusing to stage a path this seat cannot redact"*) ok 'the refusal names the fault' ;;
  *) bad "the refusal did not say why: $out" ;; esac
case "$out" in *"home-sync.sh setup"*) ok 'the help names the mend' ;;
  *) bad "the help does not name setup: $out" ;; esac
[ "$(git -C "$HOME_DIR" rev-parse HEAD)" = "$before" ] && ok 'nothing was committed' || bad 'a commit was made anyway'
case "$(git -C "$HOME_DIR" show "HEAD:$SPINE")" in
  *"id\":\"2"*|*'"id": "2"'*) bad 'the unredacted row reached git' ;;
  *) ok 'the unredacted row did not reach git' ;;
esac

printf 'the seat can ask the question directly\n'
out="$(hs filter-check "$SPINE" 2>&1)"; got=$?
[ "$got" = 1 ] && ok 'filter-check answers 1 while the filter is unseated' || bad "filter-check exited $got"
hs setup >/dev/null 2>&1
out="$(hs filter-check "$SPINE" 2>&1)"; got=$?
[ "$got" = 0 ] && ok 'filter-check answers 0 once setup has seated it' || bad "filter-check exited $got after setup: $out"

printf 'a path with no filter attribute still ships\n'
hs ship "a home note" note.md >/dev/null 2>&1; got=$?
[ "$got" = 0 ] && ok 'an ordinary path ships' || bad "an ordinary path exited $got"

printf 'the hourly clock seats it on a seat where no hand ran setup\n'
# The clock is the one thing that touches the home on every seat; it must not depend on a hand
# having run `setup`. Measured by unseating the filter and running the clock alone.
git -C "$HOME_DIR" config --unset filter.gna-redact.clean
YMIR_HOME="$HOME_DIR" YMIR_OFFLINE=1 bash "$ROOT/bin/vault/home-sync-clock.sh" >/dev/null 2>&1 || true
[ "$(git -C "$HOME_DIR" config --get filter.gna-redact.clean)" = "python3 hodd/bin/mail-redact.py" ] \
  && ok 'bin/vault/home-sync-clock.sh seated the filter without a hand' \
  || bad 'the clock left the filter unseated: a fresh clone would commit raw mail'

[ "$rc" = 0 ] && printf 'all cases hold\n'
exit "$rc"
