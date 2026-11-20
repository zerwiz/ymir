#!/usr/bin/env bash
# test_mjollnir_clone.sh — the door that turns a FAR repo into a workable one (plan 210 P3).
#
# Why it exists: `intake` can read a repo with no tree, but a FIX needs one — and the first
# measurement found 67 of 78 registered rows with no clone at all. So `clone` must land where
# the registry resolver says, and must refuse the three things that would be worse than no clone.
#
# Proved here, with a local bare repo and no network:
#   1 · a row with a git{} block clones into the canonical hall and the door PRINTS the path;
#   2 · the same row then resolves as `here` — the resolver and the door cannot disagree;
#   3 · cloning twice is refused (a tree is never cloned over);
#   4 · a row that cannot name a remote is refused, and the refusal names the remedy;
#   5 · a destination inside the public code tree is refused (Rule 04);
#   6 · a failed clone leaves nothing behind.
#
# Usage: bash bin/gates/tests/test_mjollnir_clone.sh
# Exit: 0 every proof held · 1 one failed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
HOME_FIX="$TMPD/home"
mkdir -p "$HOME_FIX/hodd/identity"

# A real git remote, on disk: no network, no credential, nothing to authenticate.
BARE="$TMPD/probe-hall.git"
SEED="$TMPD/seed"
git init -q --bare "$BARE"
git init -q "$SEED"
git -C "$SEED" -c user.email=t@example.invalid -c user.name=probe commit -q --allow-empty -m "the first commit"
git -C "$SEED" branch -M main
git -C "$SEED" remote add origin "$BARE"
git -C "$SEED" push -q origin main
git -C "$BARE" symbolic-ref HEAD refs/heads/main

cat >"$HOME_FIX/hodd/identity/projects.yaml" <<'YAML'
projects:
- id: probe-hall
  realm: work
  repo: probe-hall
  git:
    host: github.com
    owner: probe-org
    repo: probe-hall
    remote: origin
    default_branch: main
    auth: gh
- id: probe-silent
  realm: work
  repo: probe-silent
YAML

mj() {  # <args…>
  YMIR_HOME="$HOME_FIX" bash "$ROOT/bin/forge/mjollnir.sh" "$@"
}
pg() {  # <args…>
  YMIR_HOME="$HOME_FIX" bash "$ROOT/bin/agents/project-git.sh" "$@"
}

HALL="$HOME_FIX/halls/probe-org/probe-hall"

# 1 · before any clone, the resolver says where a clone WOULD land
want="$(pg probe-hall --field clone 2>/dev/null)"
if [ "$want" = "$HALL" ]; then ok "the resolver names the hall a clone would land in"; else bad "resolver said '$want' (wanted $HALL)"; fi
if pg probe-hall --field path >/dev/null 2>&1; then bad "a row with no tree claimed a path"; else ok "a row with no tree refuses to name one"; fi

# 2 · the clone lands there and says so
out="$(mj clone probe-hall --from "file://$BARE" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -d "$HALL/.git" ]; then ok "the clone lands in the canonical hall"; else bad "clone failed (rc=$rc): $out"; fi
case "$out" in
  hall\[1\]*) ok "the door prints the path as a TOON row" ;;
  *) bad "the door did not print a hall row: $out" ;;
esac

# 3 · and now the resolver agrees — one resolver, one answer
after="$(pg probe-hall --field path 2>/dev/null)"
if [ "$after" = "$HALL" ]; then ok "the resolver now answers with the same path (here)"; else bad "resolver says '$after' but the tree is at $HALL"; fi

# 4 · never clone over a tree
out="$(mj clone probe-hall --from "file://$BARE" 2>&1)"
case "$out" in *"already exists"*) ok "a second clone is refused, naming the tree" ;; *) bad "a second clone was not refused: $out" ;; esac

# 5 · a row that cannot name a remote is refused, with the remedy
out="$(mj clone probe-silent 2>&1)"
case "$out" in
  *"cannot name a remote"*) ok "a row with no git{} block is refused" ;;
  *) bad "an unnamed row was not refused: $out" ;;
esac
case "$out" in *"project-git.sh doctor"*) ok "the refusal names the remedy (doctor)" ;; *) bad "the refusal names no remedy: $out" ;; esac

# 6 · a destination inside the public code tree is refused (Rule 04)
out="$(mj clone probe-hall --dir "$ROOT/.tmp-should-never-exist" --from "file://$BARE" 2>&1)"
case "$out" in *"inside the public tree"*) ok "a hall inside the public tree is refused" ;; *) bad "an in-tree destination was allowed: $out" ;; esac
[ -e "$ROOT/.tmp-should-never-exist" ] && bad "the refused clone left a directory in the tree" || ok "the refused in-tree clone left nothing"

# 7 · a failed clone leaves nothing behind
out="$(mj clone probe-hall --dir "$TMPD/nowhere" --from "file://$TMPD/does-not-exist.git" 2>&1)"
[ -e "$TMPD/nowhere" ] && bad "a failed clone left a directory behind" || ok "a failed clone leaves nothing behind"
case "$out" in *"clone failed"*) ok "a failed clone says so" ;; *) bad "a failed clone said nothing: $out" ;; esac

if [ "$fail" -ne 0 ]; then
  printf '\n%d proof(s) failed\n' "$fail"
  exit 1
fi
printf '\nall proofs held\n'
