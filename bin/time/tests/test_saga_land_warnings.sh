#!/usr/bin/env bash
# test_saga_land_warnings.sh — the digest SEES work that finished and never landed.
#
# Plan 293 part 3. The audit of 36 panes found 22 clean worker branches on origin, four merged, and
# nothing in the session start said so; one machine's local main held 19 commits on no remote at all.
# This proves the door that now says it, on a planted repository — and proves it stays QUIET where
# it must:
#
#   · a pushed worker branch older than the threshold, with no PR, IS named, with its age
#   · a pushed branch with an OPEN or MERGED PR is NOT named
#   · a branch already merged into origin/main is NOT named
#   · a branch younger than the threshold is NOT named (it is work in hand, not lost work)
#   · a local branch whose commits are on no remote IS counted, and its name is printed
#   · offline: the PR state is reported as UNREAD, never claimed as "no PR", and nothing hangs
#
# Usage: test_saga_land_warnings.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/time/saga-land-warnings.sh"
DIGEST="$ROOT/bin/time/saga-session-start.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global init.defaultBranch main >/dev/null 2>&1
git config --global commit.gpgsign false >/dev/null 2>&1

OLD_DATE="$(date -u -d '9 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-9H '+%Y-%m-%dT%H:%M:%SZ')"

# ── the planted repository: a bare origin, and a clone that stands in for a seat ──
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/seat" 2>/dev/null
cd "$TMP/seat" || exit 1
printf 'base\n' > base.txt
git add base.txt && git commit -q -m "base: the trunk"
git push -q origin main

commit_at() { # <branch> <date|""> <file>
  git checkout -q -B "$1" main || return 1
  printf '%s\n' "$1" >"$3"
  git add "$3"
  if [ -n "$2" ]; then
    GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git commit -q -m "worker: $1"
  else
    git commit -q -m "worker: $1"
  fi
  git push -q origin "$1"
  git checkout -q main
}

commit_at eindri/old    "$OLD_DATE" old.txt        # pushed 9h ago, no PR      → WARN
commit_at eindri/young  ""         young.txt       # pushed now                → quiet
commit_at eindri/opened "$OLD_DATE" opened.txt     # pushed 9h ago, PR OPEN    → quiet
commit_at eindri/landed "$OLD_DATE" landed.txt     # pushed 9h ago, then merged → quiet
git checkout -q main
git merge -q --no-ff -m "merge landed" eindri/landed
git push -q origin main
git checkout -q main

# a local branch nobody pushed: two commits that exist on no remote
git checkout -q -b wip main
printf 'w1\n' >w1.txt && git add w1.txt && git commit -q -m "wip 1"
printf 'w2\n' >w2.txt && git add w2.txt && git commit -q -m "wip 2"
git checkout -q main

run_door() { # <gh-command> — the door's own rows, with a private gh answering
  SAGA_LAND_REPO="$TMP/seat" SAGA_LAND_GH="$1" SAGA_LAND_MIN_AGE_HOURS=4 SAGA_LAND_ROWS=20 \
    bash "$DOOR" "${2:-}" 2>&1
}

# gh that answers "there are no pull requests"
printf '#!/usr/bin/env bash\ncase "$*" in *--jq*) cat >/dev/null; exit 0 ;; esac\nexit 0\n' >"$TMP/gh-none"
# gh that says eindri/opened has an OPEN pull request #7
printf '#!/usr/bin/env bash\nprintf "eindri/opened\\tOPEN\\t7\\n"\n' >"$TMP/gh-open"
# gh that says both waiting branches carry one
printf '#!/usr/bin/env bash\nprintf "eindri/opened\\tOPEN\\t7\\neindri/old\\tOPEN\\t8\\n"\n' >"$TMP/gh-both"
chmod +x "$TMP/gh-none" "$TMP/gh-open" "$TMP/gh-both"

# ── 1. a pushed branch older than the threshold with no PR is named, with its age ──
out="$(run_door "$TMP/gh-none")"
case "$out" in
  *'"eindri/old — 9h: pushed, no PR, not merged"'*) ok "a pushed branch with no PR is named, with its age" ;;
  *) bad "a pushed branch with no PR is named, with its age" "$(printf '%s' "$out" | head -4)" ;;
esac

# ── 2. the quiet cases (this gh answered: there is no pull request anywhere) ─────
case "$out" in
  *eindri/landed*) bad "the already-merged branch is not named" ;;
  *) ok "the already-merged branch is not named" ;;
esac
case "$out" in
  *eindri/young*) bad "a branch younger than the threshold is not named" ;;
  *) ok "a branch younger than the threshold is not named" ;;
esac
case "$out" in
  *'"eindri/opened — 9h: pushed, no PR, not merged"'*) ok "a pushed branch with no PR of its own is named too" ;;
  *) bad "a pushed branch with no PR of its own is named too" "$(printf '%s' "$out" | head -4)" ;;
esac

# ── 3. commits that exist on no remote, on a local branch ───────────────────────
case "$out" in
  *'"unpushed","2 commit(s) exist on no remote: wip (2)"'*) ok "commits on no remote are counted, and the branch is named" ;;
  *) bad "commits on no remote are counted, and the branch is named" "$(printf '%s' "$out" | grep unpushed | head -2)" ;;
esac

# ── 4. a PR that exists moves the branch out of the warning ─────────────────────
out2="$(run_door "$TMP/gh-open")"
case "$out2" in
  *eindri/opened*) bad "a branch whose OPEN PR gh names is not called PR-less" "$(printf '%s' "$out2" | head -3)" ;;
  *) ok "a branch whose OPEN PR gh names is not called PR-less" ;;
esac
case "$out2" in
  *eindri/old*) ok "the branch gh named no PR for is still named" ;;
  *) bad "the branch gh named no PR for is still named" "$(printf '%s' "$out2" | head -3)" ;;
esac
out3="$(SAGA_LAND_REPO="$TMP/seat" SAGA_LAND_GH="$TMP/gh-both" SAGA_LAND_ROWS=20 bash "$DOOR" | grep -c 'no-pr')"
[ "${out3:-0}" -eq 0 ] && ok "with every branch carrying a PR, no no-PR row is printed" \
  || bad "with every branch carrying a PR, no no-PR row is printed" "no-pr rows: $out3"

# ── 5. offline: PR state is UNREAD, never claimed as "no PR", and it does not hang ──
rc=0
t0="$(date +%s)"
out4="$(SAGA_LAND_REPO="$TMP/seat" SAGA_LAND_GH="$TMP/does-not-exist" SAGA_LAND_ROWS=20 SAGA_LAND_BOUND=2 \
        bash "$DOOR" 2>&1)" || rc=$?
t1="$(date +%s)"
[ "$rc" -eq 0 ] && ok "offline exits 0 (a warning is not a fault)" || bad "offline exits 0 (a warning is not a fault)" "rc=$rc"
case "$out4" in
  *'PR state unread'*'not installed here'*) ok "offline says the PR state was not read, and never claims 'no PR'" ;;
  *) bad "offline says the PR state was not read, and never claims 'no PR'" "$(printf '%s' "$out4" | head -3)" ;;
esac
[ "$((t1 - t0))" -le 30 ] && ok "offline stays inside the bound ($((t1 - t0))s)" \
  || bad "offline stays inside the bound" "$((t1 - t0))s"

# ── 6. a clean repository says so in one honest row ─────────────────────────────
git init -q --bare "$TMP/clean-origin.git"
printf 'base\n' | git -C "$TMP/clean-origin.git" hash-object -w --stdin >/dev/null
git clone -q "$TMP/clean-origin.git" "$TMP/clean" 2>/dev/null
cd "$TMP/clean" || exit 1
printf 'base\n' >base.txt && git add base.txt && git commit -q -m "base: the trunk" && git push -q origin main
cd "$TMP/seat" || exit 1
out5="$(SAGA_LAND_REPO="$TMP/clean" SAGA_LAND_GH="$TMP/gh-none" bash "$DOOR" 2>&1)"
case "$out5" in
  *'"clean","nothing is waiting'*) ok "a clean checkout gets one honest row, not silence" ;;
  *) bad "a clean checkout gets one honest row, not silence" "$(printf '%s' "$out5" | head -3)" ;;
esac

# ── 7. no origin at all is a sentence, not a crash ──────────────────────────────
mkdir -p "$TMP/noorigin"
git -C "$TMP/noorigin" init -q
rc=0
out6="$(SAGA_LAND_REPO="$TMP/noorigin" bash "$DOOR" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] && case "$out6" in
  *'is not in this checkout'*) ok "a checkout with no origin says so and exits 0" ;;
  *) bad "a checkout with no origin says so and exits 0" "$(printf '%s' "$out6" | head -2)" ;;
esac || bad "a checkout with no origin says so and exits 0" "rc=$rc"

# ── 8. the digest actually asks the door (a door nobody calls is decoration) ────
grep -q 'saga-land-warnings.sh' "$DIGEST" \
  && ok "the session digest runs the warning door" \
  || bad "the session digest runs the warning door"

printf '\nlanding-warnings: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
