#!/usr/bin/env bash
# test_project_target.sh — a worker for another project starts in THAT project's folder
# (plan 291 part 3, at the Allfather's word: *"when we sending workers for diffrent projects the
# need to be send from the project foldeers they are going to work in so they dont do the updates
# in ymirs repo"*).
#
# What is proved here:
#   · `--project` takes a path, an id or an alias, and resolves through the registry to THIS
#     machine's clone — never a guess;
#   · a project with its own convention is seated by that convention, in ITS repository;
#   · a project without one gets `git worktree add` in ITS repository;
#   · the row of this very tree is `kind=ymir` and makes no worktree here (the engine owns those);
#   · a row with no clone on this machine is REFUSED, naming the row;
#   · the Ymir tree is untouched: `git status --porcelain` is identical before and after, and no
#     `.yggdrasil/<id>` of another project's errand is created in it.
#
# FENCED: a PLANTED home and PLANTED repositories in a temp directory. Nothing real is read.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
door="$root/bin/agents/project-target.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
out=""; rc=0
run() { out="$(env YMIR_HOME="$home" "$@" 2>&1)"; rc=$?; }
field() { printf '%s\n' "$out" | awk -F'\t' -v k="$1" '$1 == k {print $2}'; }

echo "test_project_target"
[ -x "$door" ] || { bad "the door is not executable: $door"; exit 1; }

home="$tmp/home"; mkdir -p "$home/hodd/identity"
# a planted project with ITS OWN worktree convention
conv="$tmp/repos/conventional"; mkdir -p "$conv/scripts"
git -C "$conv" init -q .; git -C "$conv" config user.email t@ymir; git -C "$conv" config user.name t
printf 'one\n' >"$conv/README.md"; git -C "$conv" add -A; git -C "$conv" commit -qm base
cat >"$conv/scripts/worktree.sh" <<'SH'
#!/usr/bin/env bash
# the project's own convention: .yggdrasil/<id> on agent/<id>
set -eu
id="$2"
exec git worktree add -b "agent/$id" ".yggdrasil/$id" HEAD
SH
chmod +x "$conv/scripts/worktree.sh"
# a planted project with NO convention (the default road)
plain="$tmp/repos/plain"; mkdir -p "$plain"
git -C "$plain" init -q .; git -C "$plain" config user.email t@ymir; git -C "$plain" config user.name t
printf 'one\n' >"$plain/README.md"; git -C "$plain" add -A; git -C "$plain" commit -qm base

cat >"$home/hodd/identity/projects.yaml" <<YAML
projects:
  - id: conventional
    name: Conventional Project
    aliases: [conv, cp]
    realm: work
    clones:
      local: $conv
    worktree:
      command: scripts/worktree.sh new {id}
      path: .yggdrasil/{id}
      branch: agent/{id}
  - id: plain
    name: Plain Project
    realm: work
    local_clone: $plain
  - id: elsewhere
    name: Elsewhere
    realm: work
    clones:
      another-machine: /nonexistent/elsewhere
YAML

# the Ymir tree as it stands, so "untouched" can be measured rather than assumed
ymir_before="$(git -C "$root" status --porcelain)"

# 1 · an id resolves to this machine's clone
run "$door" resolve conventional
[ "$rc" = 0 ] && ok "a project id resolves" || bad "the id did not resolve: $out"
[ "$(field kind)" = other ] && ok "another project is kind=other" || bad "kind is $(field kind), not other"
[ "$(field path)" = "$conv" ] && ok "the id resolves to this machine's clone" || bad "path is $(field path)"

# 2 · an alias, and a path, resolve to the same target
run "$door" resolve conv
[ "$(field path)" = "$conv" ] && ok "an alias resolves to the same clone" || bad "the alias did not resolve"
run "$door" resolve "$conv"
[ "$(field id)" = conventional ] && ok "a path resolves to its registry row" || bad "the path did not resolve to a row"

# 3 · a row with no clone on this machine is refused, and names the row
run "$door" resolve elsewhere
[ "$rc" = 1 ] && ok "a project with no clone here is refused" || bad "a clone-less project resolved (rc=$rc)"
case "$out" in *"elsewhere"*) ok "the refusal names the row to fix" ;;
  *) bad "the refusal did not name the row" ;; esac

# 4 · the project's own convention is used, in its own repository
run "$door" worktree conventional probe
[ "$rc" = 0 ] && ok "a worktree is made for the conventional project" || bad "worktree failed: $out"
[ "$(field worktree)" = "$conv/.yggdrasil/probe" ] && ok "the worktree lands in the project's repository" \
  || bad "the worktree landed at $(field worktree)"
[ "$(field branch)" = "agent/probe" ] && ok "the project's own branch convention is used" \
  || bad "the branch is $(field branch)"
git -C "$conv" worktree list | grep -q ".yggdrasil/probe" \
  && ok "git itself lists the worktree in the project's repository" \
  || bad "git does not list the worktree"

# 5 · no convention: the default road, still in the project's repository
run "$door" worktree plain probe
[ "$rc" = 0 ] && ok "a worktree is made for the plain project" || bad "default worktree failed: $out"
[ "$(field worktree)" = "$plain/.yggdrasil/probe" ] && ok "the default lands in the project's repository" \
  || bad "the default landed at $(field worktree)"
[ "$(field branch)" = "eindri/probe" ] && ok "the default branch is eindri/<id>" || bad "the default branch is $(field branch)"

# 6 · this very tree is kind=ymir and makes no worktree here
run "$door" resolve "$root"
[ "$rc" = 0 ] && [ "$(field kind)" = ymir ] && ok "this tree is kind=ymir" || bad "this tree is $(field kind)"
run "$door" worktree "$root" probe
[ "$rc" = 0 ] && [ "$(field created)" = no ] && [ -z "$(field worktree)" ] \
  && ok "no worktree is made in this tree by this door" || bad "this door made a worktree in this tree"

# 7 · the Ymir tree is untouched by an errand for another project
[ ! -e "$root/.yggdrasil/probe" ] && ok "no .yggdrasil/probe of another project's errand stands in the Ymir tree" \
  || bad "another project's worktree was created in the Ymir tree"
ymir_after="$(git -C "$root" status --porcelain)"
[ "$ymir_before" = "$ymir_after" ] && ok "the Ymir tree's status is identical before and after" \
  || bad "the Ymir tree moved: $(diff <(printf '%s\n' "$ymir_before") <(printf '%s\n' "$ymir_after") | head -5)"

# 8 · --dry-run plans and makes nothing
run "$door" worktree conventional other --dry-run
[ "$rc" = 0 ] && [ "$(field created)" = would-be-made ] && ok "--dry-run plans without making" \
  || bad "--dry-run refused or made something: $out"
[ ! -e "$conv/.yggdrasil/other" ] && ok "--dry-run created nothing" || bad "--dry-run created a worktree"

printf 'test_project_target: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
