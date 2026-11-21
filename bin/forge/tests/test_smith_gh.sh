#!/usr/bin/env bash
# test_smith_gh.sh — the smith's gh refuses every road to a merge, and lets every read through.
#
# The judge's two reviews of #870 (2026-11-21) found merges the shim passed: `gh -R <repo> pr merge`
# (the flag before `pr`), `gh pr -R <repo> merge` (the flag after it), an alias (`gh alias set m
# 'pr merge'`, then `gh m 7`), and the merge API with a trailing slash, in upper case, through
# `POST …/merges` or through a GraphQL query read from a file. Each is a row below, run as a smith
# (YMIR_SMITH set) against a fake real gh that records what reached it. Reads must still pass.
#
# Run: bash bin/forge/tests/test_smith_gh.sh   ·   exit 0 all pass, 1 a failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHIM="$ROOT/bin/forge/smith-bin/gh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

mkdir -p "$T/real"
cat >"$T/real/gh" <<'GH'
#!/usr/bin/env bash
if [ "$1 $2" = "alias list" ]; then printf 'm: pr merge\nv: pr view\nx: api -X PUT repos/o/r/pulls/1/merge\nsh: !gh pr merge 1\n'; exit 0; fi
printf 'REAL %s\n' "$*"
GH
chmod +x "$T/real/gh"
printf '{"query":"mutation{mergePullRequest(input:{}){clientMutationId}}"}\n' >"$T/q.json"
printf '{"query":"query{viewer{login}}"}\n' >"$T/read.json"

run() {  # <args…> → REFUSED | PASSED | other
  local out
  out="$(cd "$T" && YMIR_SMITH=test PATH="$T/real:$PATH" "$SHIM" "$@" 2>&1)"
  case "$out" in *"reviewer's act"*) echo REFUSED ;; REAL*|*": pr "*) echo PASSED ;; *) echo "OTHER: $out" ;; esac
}
expect() {  # <want> <args…>
  local want="$1"; shift
  local got; got="$(run "$@")"
  [ "$got" = "$want" ] && ok "$want: gh $*" || bad "gh $* -> $got (want $want)"
}

echo "smith gh: every road to a merge is refused"
expect REFUSED pr merge 1
expect REFUSED -R o/r pr merge 1
expect REFUSED --repo=o/r pr merge 1
expect REFUSED pr -R o/r merge 1
expect REFUSED pr --repo o/r merge 1
expect REFUSED pr --repo=o/r merge 1
expect REFUSED m 1
expect REFUSED x
expect REFUSED sh
expect REFUSED alias set z 'pr merge'
expect REFUSED alias import f.yml
expect REFUSED api -X PUT repos/o/r/pulls/1/merge
expect REFUSED api -X PUT repos/o/r/pulls/1/merge/
expect REFUSED api -X PUT repos/o/r/pulls/1/MERGE
expect REFUSED api -X PUT 'repos/o/r/pulls/1/merge?x=1'
expect REFUSED api -X POST repos/o/r/merges -f base=main -f head=x
expect REFUSED api graphql -f 'query=mutation{mergePullRequest(input:{}){clientMutationId}}'
expect REFUSED api graphql -f 'query=mutation{mergeBranch(input:{}){clientMutationId}}'
expect REFUSED api graphql --input "$T/q.json"
expect REFUSED api graphql -F "query=@$T/q.json"
expect REFUSED pr close 1
expect REFUSED pr -R o/r close 1

echo "smith gh: reads pass"
expect PASSED pr view 870 --json mergeable,mergeStateStatus
expect PASSED pr -R o/r view 870
expect PASSED v 870
expect PASSED api repos/o/r/pulls/1
expect PASSED api graphql --input "$T/read.json"
expect PASSED alias list

echo "smith gh: the operator (no smith signal, outside a worktree) is never refused"
out="$(cd "$T" && env -u YMIR_SMITH PATH="$T/real:$PATH" "$SHIM" pr -R o/r merge 1 2>&1)"
case "$out" in REAL*) ok "the operator's merge passes through" ;; *) bad "the operator was refused: $out" ;; esac

printf 'smith-gh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
