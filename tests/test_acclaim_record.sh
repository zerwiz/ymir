#!/usr/bin/env bash
# test_acclaim_record.sh — a done report carries its record (plan 339.2, 2026-11-20).
#
# Three errands reported done that day against an empty, an unpushed or a nonexistent branch.
# So the terminal act (bin/agents/eindri-acclaim.sh) writes a `## Record` block from git itself:
# the commit, the branch, the repo, the machine, where the commit is, the files and git status.
# The arm then checks that record (src/ymir_runtime/watch.py, verify_record).
#
#   · a committed, unpushed branch  → `commit: <sha> <subject>` · `where: local only` · its files
#   · the same branch pushed        → `where: pushed`
#   · nothing ahead of the base     → `commit: none — nothing committed`
#   · a report that already has a record is not given a second one
#   · the record the act wrote is the record the arm accepts, and a doctored one is false-done
#
# acclaim runs from a copy of the tree with no voice door, no reviewer and no notify door, and the
# well is a throwaway log, so nothing real is touched. Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-acclaim-record.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tree/bin/agents" "$TMP/tree/bin/vault" "$TMP/tree/RULES" "$TMP/tree/.pi" "$TMP/state"
cp "$ROOT/bin/agents/eindri-acclaim.sh" "$ROOT/bin/agents/eindri-wake-lib.sh" "$TMP/tree/bin/agents/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$TMP/tree/bin/vault/"
ln -s "$ROOT/bin/records" "$TMP/tree/bin/records"
ACCLAIM="$TMP/tree/bin/agents/eindri-acclaim.sh"
export YMIR_HOME="$TMP/home" BROKK_ROOT_OVERRIDE="$TMP/tree" BROKK_STATE_OVERRIDE="$TMP/state"
export ENGRAM_LOG="$TMP/episodes.jsonl" MIMIRSBRUNN_URL="http://127.0.0.1:9" YMIR_AUTO_REVIEW=off
mkdir -p "$YMIR_HOME"

g() { git -c user.name=t -c user.email=t@example.org "$@"; }
git init -q --bare -b main "$TMP/origin.git"
git init -q -b main "$TMP/work"
g -C "$TMP/work" commit -q --allow-empty -m base
git -C "$TMP/work" remote add origin "$TMP/origin.git"
git -C "$TMP/work" push -q origin main
git -C "$TMP/work" fetch -q origin

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -12 | tr '\n' ' ')"; }
meta() { printf 'id=%s\nmode=batch\nworktree=%s\n' "$1" "$TMP/work" >"$TMP/state/$1.meta"; }
verdict() {  # <id> → what the arm says of the record on the shelf
  PYTHONPATH="$ROOT/src" python3 - "$TMP/state" "$1" <<'PY'
import sys
from pathlib import Path
from ymir_runtime import watch
state, seat = Path(sys.argv[1]), sys.argv[2]
meta = watch._read_kv(state / f"{seat}.meta")
report = (state / "eindri-reports" / f"{seat}.md").read_text()
print(repr(watch.done_verdict(seat, meta, report=report)))
PY
}

# 1. committed, not pushed
git -C "$TMP/work" checkout -q -b eindri/one
printf 'x\n' >"$TMP/work/a.txt"; git -C "$TMP/work" add a.txt; g -C "$TMP/work" commit -q -m "add a"
meta one
( cd "$TMP/work" && "$ACCLAIM" one --terminal done --line "committed on eindri/one (not pushed)" ) >/dev/null 2>&1
shelf="$TMP/state/eindri-reports/one.md"
sha="$(git -C "$TMP/work" log --oneline -1)"
grep -qxF "commit: $sha" "$shelf" && grep -qx 'where: local only' "$shelf" && grep -qx '    a.txt' "$shelf" \
  && grep -qx 'branch: eindri/one' "$shelf" && grep -q '^machine: ' "$shelf" && grep -qx '    (clean)' "$shelf" \
  && ok "an unpushed commit is recorded as local only, with its files and a clean status" || bad "an unpushed commit is recorded" "$(cat "$shelf")"
[ "$(verdict one)" = "''" ] && ok "the arm accepts the record the act wrote" || bad "the arm accepts the record the act wrote" "$(verdict one)"

# a doctored record is false-done
sed -i "s/^commit: .*/commit: deadbeef12 a commit that never was/" "$shelf"
case "$(verdict one)" in *"deadbeef12, which"*"does not hold"*) ok "a doctored sha is caught by the arm" ;; *) bad "a doctored sha is caught" "$(verdict one)" ;; esac

# 2. pushed
git -C "$TMP/work" checkout -q -b eindri/two
printf 'y\n' >"$TMP/work/b.txt"; git -C "$TMP/work" add b.txt; g -C "$TMP/work" commit -q -m "add b"
git -C "$TMP/work" push -q origin eindri/two
meta two
( cd "$TMP/work" && "$ACCLAIM" two --terminal done --line "committed and pushed" ) >/dev/null 2>&1
grep -qx 'where: pushed' "$TMP/state/eindri-reports/two.md" && [ "$(verdict two)" = "''" ] \
  && ok "a pushed branch is recorded as pushed and verified against origin" || bad "a pushed branch is recorded as pushed" "$(cat "$TMP/state/eindri-reports/two.md"; verdict two)"

# 3. nothing committed
git -C "$TMP/work" checkout -q -b eindri/three main
meta three
( cd "$TMP/work" && "$ACCLAIM" three --terminal done --line "done" ) >/dev/null 2>&1
grep -q '^commit: none — nothing committed' "$TMP/state/eindri-reports/three.md" \
  && ok "nothing ahead of the base says nothing committed" || bad "nothing ahead says nothing committed" "$(cat "$TMP/state/eindri-reports/three.md")"

# 4. one record only
( cd "$TMP/work" && "$ACCLAIM" three --terminal done --line "done again" ) >/dev/null 2>&1
[ "$(grep -c '^## Record' "$TMP/state/eindri-reports/three.md")" = 1 ] \
  && ok "a shelf that has a record is not given a second" || bad "one record only" "$(cat "$TMP/state/eindri-reports/three.md")"

printf '\nacclaim-record: %s ok · %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
