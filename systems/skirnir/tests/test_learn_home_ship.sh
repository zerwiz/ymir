#!/usr/bin/env bash
# test_learn_home_ship.sh — Skírnir's nightly home map ships itself, and an unchanged night is silent.
#
# THE FAULT THIS PROVES GONE (measured 2026-11-20 on a second machine): the Nornir row
# `systems/skirnir/services/learn-home.sh` rewrote ~1,300 fact files every night — nearly all of
# them only an `approved_at:` / `generated_at:` stamp — and committed none of them, so the home
# showed 489 modified + 30 untracked files by morning and had to be cleaned by hand.
#
# The proof runs on a throwaway git home with a local bare remote, so nothing of the operator's
# home is touched:
#
#   (a) an unchanged second run writes 0 facts, makes 0 commits, and says `no-change`
#   (b) a changed source document ships exactly ONE commit to the remote
#   (c) `--no-ship` writes the fact and leaves the commit unmade
#   (d) a source document that is gone RETIRES its copy by moving it into `approved/_retired/`,
#       and the ship carries the move — no tracked path is deleted (Rule 11)
#   (e) `--dry-run` touches nothing: no write, no commit, no push
#
# Usage: bash systems/skirnir/tests/test_learn_home_ship.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
LEARN="$ROOT/systems/skirnir/services/learn-home.sh"
[ -x "$LEARN" ] || { printf 'FAIL: no door at %s\n' "$LEARN" >&2; exit 1; }

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
row() { printf '%s' "$1" | sed -n '1p'; }              # the TOON summary line
counts() {  # <summary row> -> "written unchanged retired"
  printf '%s' "$1" | sed -n 's/.*}:"\([0-9]*\)","\([0-9]*\)","\([0-9]*\)".*/\1 \2 \3/p' | head -1
}
written_of() { counts "$1" | cut -d' ' -f1; }

echo "test_learn_home_ship"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
remote="$T/remote.git"; home="$T/home"

git init -q --bare "$remote"
mkdir -p "$home/hodd/docs"
git -C "$home" init -q -b main
git -C "$home" config user.email "test@example.org"
git -C "$home" config user.name "the test"
git -C "$home" remote add origin "$remote"
printf '# A Living Document\n\nThe first body.\n' > "$home/hodd/docs/a-living-document.md"
git -C "$home" add -A
git -C "$home" commit -qm "seed the home"
git -C "$home" push -q origin HEAD:main
git -C "$home" branch --set-upstream-to=origin/main main >/dev/null 2>&1

count()   { git -C "$remote" rev-list --count main 2>/dev/null || echo 0; }
run()     { YMIR_HOME="$home" bash "$LEARN" "$@" 2>&1; }

before="$(count)"

# ── (first run) the map is written and shipped ───────────────────────────────────────────────
out="$(run)"
if [ "$(count)" -eq "$((before + 1))" ]; then
  ok "the first run ships its facts as one commit"
else
  bad "the first run did not ship: $(row "$out") (commits $before -> $(count))"
fi
[ -f "$home/hodd/identity/assistant/approved/home-doc-hodd-docs-a-living-document-md.md" ] \
  && ok "the fact for the home document exists" \
  || bad "the fact for the home document was not written"

# ── (a) an unchanged night is silent ────────────────────────────────────────────────────────
before="$(count)"
out="$(run)"
written="$(written_of "$(row "$out")")"
if [ "${written:-x}" = 0 ]; then ok "the unchanged run rewrites 0 facts"; else bad "the unchanged run rewrote ${written:-?} facts: $(row "$out")"; fi
if [ "$(count)" -eq "$before" ]; then ok "the unchanged run makes 0 commits"; else bad "the unchanged run committed ($before -> $(count))"; fi
case "$out" in
  *'"no-change"'*) ok "the unchanged run says no-change" ;;
  *) bad "the unchanged run did not say no-change: $out" ;;
esac
[ -z "$(git -C "$home" status --porcelain)" ] \
  && ok "the unchanged run leaves the home clean" \
  || bad "the unchanged run left the home dirty: $(git -C "$home" status --porcelain | head -3)"

# ── (c) --no-ship writes the fact and leaves the commit unmade ──────────────────────────────
printf '# A Living Document, Revised\n\nThe same body.\n' > "$home/hodd/docs/a-living-document.md"
git -C "$home" commit -qam "the document changed" && git -C "$home" push -q origin HEAD:main
before="$(count)"
out="$(run --no-ship)"
written="$(written_of "$(row "$out")")"
[ "${written:-x}" = 1 ] && ok "--no-ship still rewrites the changed fact" || bad "--no-ship did not rewrite the fact: $(row "$out")"
[ "$(count)" -eq "$before" ] && ok "--no-ship makes no commit" || bad "--no-ship committed ($before -> $(count))"
case "$out" in
  *'--no-ship'*) ok "--no-ship says so" ;;
  *) bad "--no-ship did not say so: $out" ;;
esac
grep -q "Revised" "$home/hodd/identity/assistant/approved/home-doc-hodd-docs-a-living-document-md.md" \
  && ok "the rewritten fact carries the new claim" \
  || bad "the fact still carries the old claim"
[ -n "$(git -C "$home" status --porcelain)" ] && ok "--no-ship leaves the change uncommitted" || bad "--no-ship left nothing to commit"

# ── (e) --dry-run touches nothing at all ────────────────────────────────────────────────────
dirty_before="$(git -C "$home" status --porcelain)"
before="$(count)"
out="$(run --dry-run)"
[ "$(count)" -eq "$before" ] && ok "--dry-run makes no commit" || bad "--dry-run committed ($before -> $(count))"
[ "$(git -C "$home" status --porcelain)" = "$dirty_before" ] \
  && ok "--dry-run changes not one file" \
  || bad "--dry-run changed the tree"
case "$out" in
  *'dry-run'*) ok "--dry-run says so" ;;
  *) bad "--dry-run did not say so: $out" ;;
esac

# ── (b) a changed source ships exactly one commit ───────────────────────────────────────────
before="$(count)"
out="$(run)"
if [ "$(count)" -eq "$((before + 1))" ]; then
  ok "a changed source ships exactly one commit"
else
  bad "a changed source shipped $(( $(count) - before )) commits: $(row "$out")"
fi
[ -z "$(git -C "$home" status --porcelain)" ] \
  && ok "the shipped run leaves the home clean" \
  || bad "the shipped run left the home dirty: $(git -C "$home" status --porcelain | head -3)"

# ── (d) a gone source retires its copy by moving it, never by deleting it ───────────────────
git -C "$home" rm -q hodd/docs/a-living-document.md
git -C "$home" commit -qm "the document is gone"
git -C "$home" push -q origin HEAD:main
before="$(count)"
out="$(run)"
snapshot="$(git -C "$home" ls-tree -r --name-only HEAD)"
case "$snapshot" in
  *hodd/identity/assistant/approved/_retired/home-doc-hodd-docs-a-living-document-md.md*)
    ok "the retired fact moved into approved/_retired/" ;;
  *) bad "the retired fact was not moved into _retired/: $(row "$out")" ;;
esac
case "$snapshot" in
  *"hodd/identity/assistant/approved/home-doc-hodd-docs-a-living-document-md.md"*)
    bad "the retired fact is still answering at the top level" ;;
  *) ok "the retired fact no longer answers" ;;
esac
[ -z "$(git -C "$home" diff --diff-filter=D --name-only HEAD~1 HEAD)" ] \
  && ok "the retirement deleted no tracked path (Rule 11)" \
  || bad "the retirement deleted a tracked path: $(git -C "$home" diff --diff-filter=D --name-only HEAD~1 HEAD)"
[ "$(count)" -eq "$((before + 1))" ] && ok "the retirement ships as one commit" || bad "the retirement shipped $(( $(count) - before )) commits"

printf 'test_learn_home_ship: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
