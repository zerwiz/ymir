#!/usr/bin/env bash
# test_gather_orders_by_base.sh — plan 293 part 7: a packet names the branch it was cut from, and
# the gather merges that base FIRST, whatever order the branches are named on the command line.
#
# The fault it fences: `kaia-to-volundr` stands on `smidja-header-chat`. Gathered in the wrong
# order, the dependent is merged before its base and the base's own commits land twice or conflict.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
G="$ROOT/bin/forge/gather.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# a repository with an origin/main and two errand branches, the dependent cut FROM the base
git init -q --bare -b main "$T/origin.git"
R="$T/repo"; git init -q -b main "$R"; git -C "$R" remote add origin "$T/origin.git"
git -C "$R" config user.email t@example.test; git -C "$R" config user.name t
printf 'base\n' >"$R/f"; git -C "$R" add f; git -C "$R" commit -qm "main"; git -C "$R" push -q origin main
git -C "$R" checkout -q -b eindri/base-x; printf 'b\n' >"$R/bf"; git -C "$R" add bf; git -C "$R" commit -qm "base-x its own commit"
BASE_SHA="$(git -C "$R" rev-parse HEAD)"
git -C "$R" checkout -q -b eindri/dep-y; printf 'd\n' >"$R/df"; git -C "$R" add df; git -C "$R" commit -qm "dep-y built on base-x"
DEP_SHA="$(git -C "$R" rev-parse HEAD)"
git -C "$R" checkout -q main

# the packets: dep-y names eindri/base-x; base-x names origin/main
S="$T/state"; mkdir -p "$S/handoff"
cat >"$S/handoff/dep-y.packet" <<EOF
packet[1]{task,plan,branch,base,head,author,written_at,ruleset,floor}:
  "dep","plan","eindri/dep-y","eindri/base-x","$DEP_SHA","t","2026-11-14T00:00:00Z","none","complete"
EOF
cat >"$S/handoff/base-x.packet" <<EOF
packet[1]{task,plan,branch,base,head,author,written_at,ruleset,floor}:
  "base","plan","eindri/base-x","origin/main","$BASE_SHA","t","2026-11-14T00:00:00Z","none","complete"
EOF

# the DEPENDENT is named first on purpose: the gather must still merge its base first.
out="$(GATHER_REPO="$R" GATHER_STATE="$S" GATHER_REMOTE=origin GATHER_BASE=main GATHER_SKIP_WELL=1 \
       bash "$G" dep-y base-x --dry-run 2>&1)"
base_line="$(printf '%s\n' "$out" | grep -n '"eindri/base-x"' | head -1 | cut -d: -f1)"
dep_line="$(printf '%s\n' "$out"  | grep -n '"eindri/dep-y"'  | head -1 | cut -d: -f1)"

if [ -n "$base_line" ] && [ -n "$dep_line" ]; then
  [ "$base_line" -lt "$dep_line" ] \
    && ok "the base is ordered before the branch cut from it" \
    || bad "dep was ordered before its base (base line $base_line, dep line $dep_line)"
else
  bad "the dry-run did not name both branches"
  printf '%s\n' "$out" >&2
fi

# a branch whose packet names NO unmerged base (origin/main) keeps the order given
out2="$(GATHER_REPO="$R" GATHER_STATE="$S" GATHER_REMOTE=origin GATHER_BASE=main GATHER_SKIP_WELL=1 \
        bash "$G" base-x --dry-run 2>&1)"
printf '%s' "$out2" | grep -q '"eindri/base-x"' && ok "a base on origin/main needs no reordering" || bad "single branch not named"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
