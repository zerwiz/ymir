#!/usr/bin/env bash
# housekeeping.test.sh — the reclaim rules, proved against a FIXTURE repo.
#
# The danger of a cleanup tool is not that it misses space; it is that it deletes work that
# exists nowhere else. So every case here is a repo state, and the assertion is a VERDICT:
#
#   merged work   → reclaimable:merged   (and clean --yes removes it)
#   pushed work   → reclaimable:pushed   (HEAD equals its remote branch)
#   dirty work    → keep:dirty           (and clean --yes REFUSES it)
#   unpushed work → keep:unpushed:N      (and check exits 1)
#   unmerged work → keep:unpushed:N      (unique commits, no remote, not on main)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HK="$ROOT/bin/forge/housekeeping.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── a fixture world: a bare "origin" and a clone with worktrees ──────────────
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/repo" 2>/dev/null
cd "$TMP/repo" || exit 1
git config user.email t@t.t; git config user.name t
git checkout -q -b main
printf 'seed\n' > f.txt; git add f.txt; git commit -qm seed
git remote set-head origin -a >/dev/null 2>&1 || true
git push -q -u origin main
# The script resolves ROOT from its OWN location (it belongs to the repo it treats), so the
# fixture must carry a copy — that is exactly how it runs after install.
mkdir -p .pi RULES bin/forge
cp "$HK" bin/forge/housekeeping.sh
chmod +x bin/forge/housekeeping.sh

# a worktree whose work is MERGED into main
git checkout -q -b merged-work; printf 'a\n' > a.txt; git add a.txt; git commit -qm "merged work"
git push -q -u origin merged-work
git checkout -q main; git merge -q --no-ff merged-work -m "merge merged-work"; git push -q origin main
git worktree add -q .yggdrasil/merged merged-work

# a worktree whose work is PUSHED but not merged
git checkout -q -b pushed-work main; printf 'b\n' > b.txt; git add b.txt; git commit -qm "pushed work"
git push -q -u origin pushed-work; git checkout -q main
git worktree add -q .yggdrasil/pushed pushed-work

# a DIRTY worktree (the branch is created WITHOUT checking it out in main, so the worktree
# can hold it — `git worktree add` refuses a branch the main checkout already owns)
git branch -q dirty-work main
git worktree add -q .yggdrasil/dirty dirty-work
printf 'uncommitted\n' >> "$TMP/repo/.yggdrasil/dirty/f.txt"

# an UNPUSHED worktree (a local commit, no upstream, not on main)
git worktree add -q -b unpushed-work .yggdrasil/unpushed main
( cd .yggdrasil/unpushed && printf 'c\n' > c.txt && git add c.txt && git commit -qm "only here" ) >/dev/null 2>&1
# and an UNMERGED branch with no worktree
git checkout -q -b unmerged-bare main
printf 'd\n' > d.txt; git add d.txt; git commit -qm "unmerged bare"; git checkout -q main

run_hk() { ( cd "$TMP/repo" && bash "$TMP/repo/bin/forge/housekeeping.sh" "$@" 2>&1 ); }

# ── the report's verdicts ───────────────────────────────────────────────────
out="$(run_hk report)"
check() {  # <needle> <label>
  if grep -qF "$1" <<<"$out"; then ok "$2"; else bad "$2 (missing: $1)"; printf '%s\n' "$out" | head -12 >&2; fi
}
check '"merged","merged-work","reclaimable:merged"' 'a merged worktree is reclaimable'
check '"pushed","pushed-work","reclaimable:pushed"' 'a pushed worktree is reclaimable'
check '"dirty","dirty-work","keep:dirty"' 'a dirty worktree is kept'
check '"unpushed","unpushed-work","keep:unpushed:1"' 'a worktree with a local-only commit is kept, with its count'
check '"unmerged-bare","keep:unpushed:1"' 'an unmerged branch with no worktree is kept as unpushed'

# ── check exits 1 while unpushed work exists ────────────────────────────────
if ( cd "$TMP/repo" && bash "$HK" check >/dev/null 2>&1 ); then
  bad 'check must fail while unpushed work exists'
else
  ok 'check fails while unpushed work exists'
fi

# ── clean without --yes removes nothing ─────────────────────────────────────
before="$(cd "$TMP/repo" && git worktree list | wc -l)"
run_hk clean >/dev/null 2>&1
after="$(cd "$TMP/repo" && git worktree list | wc -l)"
if [ "$before" = "$after" ]; then ok 'clean without --yes is a plan, not an action'; else bad 'clean removed something without --yes'; fi

# ── clean --yes removes the reclaimable and REFUSES the rest ────────────────
run_hk clean --yes >/dev/null 2>&1
left="$(cd "$TMP/repo" && git worktree list | awk '{print $1}')"
keep_needed=1
for w in merged pushed dirty unpushed; do
  if grep -q "/.yggdrasil/$w$" <<<"$left"; then
    case "$w" in
      merged|pushed) bad "clean --yes kept $w (it was reclaimable)" ;;
      dirty|unpushed) ok "clean --yes refused $w (work that exists only here)" ;;
    esac
  else
    case "$w" in
      merged|pushed) ok "clean --yes removed $w" ;;
      dirty|unpushed) bad "clean --yes REMOVED $w — that work existed only here" ;;
    esac
  fi
done
unset keep_needed

# ── and the unpushed work still exists as a branch ─────────────────────────
if ( cd "$TMP/repo" && git rev-parse --verify --quiet unpushed-work >/dev/null ); then
  ok 'the unpushed branch survives a clean'
else
  bad 'the unpushed branch was deleted'
fi

[ "$fail" = 0 ] && printf '\nhousekeeping: all laws hold\n'
exit "$fail"
