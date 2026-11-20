#!/usr/bin/env bash
# landed-gate-proof.sh — the teardown gate at the DOOR, run live (plan 58, Phase 5).
#
# The gate that decides whether a worktree may be discarded used to live in the
# vendored teardown's shell. It lives in the engine now (`src/ymir_runtime/landed.py`,
# behind `bin/ymir-engine.sh landed`), and this proof runs the vendored suite's
# own documented matrix against the door, on real repositories with a real bare
# origin, so the verdicts are earned rather than asserted.
#
#   landed-gate-proof.sh proof   the matrix below, then the refusals
#
# Matrix (the vendored suite's cases (a)–(f), by name):
#   (a) local-only + HEAD on a remote-tracking branch   -> landed   remote
#   (b) local-only + truly unpushed, not in main        -> refused  unlanded/inconclusive
#   (c) local-only + merged into the local default      -> landed   local-default
#   (d) ship + HEAD pushed to origin                    -> landed   remote
#   (e) ship + dirty worktree, even when work landed     -> refused  dirty
#   (f) ship + --force (the approved discard)            -> landed   forced
#
# Every fixture lives in a throwaway temp dir; nothing here touches a real
# project, a real remote, or the operator's home.
#
# Exit: 0 every case held · 1 a case failed · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="$ROOT/bin/ymir-engine.sh"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  proof) : ;;
  *) printf 'error: unknown verb %s\nhelp: tests/e2e/landed-gate-proof.sh proof\n' "${1-}" >&2; exit 2 ;;
esac

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-landed-proof.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=gate GIT_AUTHOR_EMAIL=gate@example.invalid
export GIT_COMMITTER_NAME=gate GIT_COMMITTER_EMAIL=gate@example.invalid

ORIGIN="$TMP/origin.git"
PROJ="$TMP/project"
WT="$TMP/wt"
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"

# `gh-axi pr list` finds no PR; `gh pr view` always fails: the common "no GitHub
# PR" baseline, so the content fallback is what the gate must rest on.
cat > "$FAKEBIN/gh-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)"; exit 0 ;;
esac
exit 1
SH
cat > "$FAKEBIN/gh" <<'SH'
#!/usr/bin/env bash
echo "error: pull request not found" >&2
exit 1
SH
chmod +x "$FAKEBIN/gh-axi" "$FAKEBIN/gh"
export PATH="$FAKEBIN:$PATH"

git init --bare -q -b main "$ORIGIN"
git clone -q "$ORIGIN" "$PROJ" 2>/dev/null
printf 'one\n' > "$PROJ/file.txt"
git -C "$PROJ" add file.txt
git -C "$PROJ" commit -qm one
git -C "$PROJ" push -q -u origin main
git -C "$PROJ" remote set-head origin main >/dev/null 2>&1
git -C "$PROJ" worktree add -q -b work "$WT"

rows=""
fail=0
record() {  # <case> <ok|FAIL> <expected> <got> <verdict> <detail>
  rows="${rows}  \"$1\",\"$2\",\"$3\",\"$4\",\"$5\",\"$6\"\n"
  [ "$2" = "ok" ] || fail=1
}

# The gate's TOON row, parsed without jq: verdict, landed, how.
gate() {  # <args...> -> "landed|how"
  local out
  out="$("$ENGINE" landed "$@" 2>/dev/null || true)"
  printf '%s\n' "$out" | awk -F'","' '
    /^  "/ { gsub(/^  "/, "", $0); split($0, f, "\",\"");
             printf "%s|%s\n", f[2], f[3]; exit }'
}

commit() {  # <text> <message>
  printf '%b' "$1" > "$WT/file.txt"
  git -C "$WT" add file.txt
  git -C "$WT" commit -qm "$2"
}

# (c) local-only + merged into the local default branch -> landed, local-default.
commit 'one\ntwo\n' two
git -C "$PROJ" merge --ff-only -q work
got="$(gate "$WT" --mode local-only)"
record "c-local-only-merged" "$([ "$got" = "yes|local-default" ] && echo ok || echo FAIL)" "yes|local-default" "$got" "landed" ""
git -C "$PROJ" reset --hard -q origin/main
git -C "$WT" checkout -q -B work main

# (a)/(d) HEAD on a remote-tracking branch -> landed, remote.
commit 'one\ntwo\n' two
git -C "$WT" push -q -u origin work
got="$(gate "$WT" --mode no-mistakes)"
record "a-remote-reachable" "$([ "$got" = "yes|remote" ] && echo ok || echo FAIL)" "yes|remote" "$got" "landed" ""
got="$(gate "$WT" --mode local-only)"
record "d-local-only-on-remote" "$([ "$got" = "yes|remote" ] && echo ok || echo FAIL)" "yes|remote" "$got" "landed" ""

# (b) truly unpushed, no PR, content not in the default branch -> refused.
commit 'one\ntwo\nthree\n' three
got="$(gate "$WT" --mode no-mistakes)"
case "$got" in
  no|no|*|"no|unlanded"|"no|inconclusive")
    record "b-unlanded" "$([ "${got%%|*}" = no ] && echo ok || echo FAIL)" "no|<proof>" "$got" "refused" "" ;;
  *) record "b-unlanded" FAIL "no|<proof>" "$got" "refused" "" ;;
esac

# (e) dirty, even though the previous commit is on a remote -> refused, dirty.
printf 'one\nunsaved\n' > "$WT/file.txt"
got="$(gate "$WT" --mode no-mistakes)"
record "e-dirty" "$([ "$got" = "no|dirty" ] && echo ok || echo FAIL)" "no|dirty" "$got" "refused" ""

# (f) --force is the approved discard: it short-circuits every check above.
got="$(gate "$WT" --mode no-mistakes --force)"
record "f-forced" "$([ "$got" = "yes|forced" ] && echo ok || echo FAIL)" "yes|forced" "$got" "landed" ""

printf 'landed-gate-proof[1]{verb,verdict}:\n  "%s","%s"\n' "proof" "$([ "$fail" = 0 ] && echo PASS || echo FAIL)"
printf 'cases[6]{case,state,expected,got,verdict,detail}:\n'
printf '%b' "$rows"
[ "$fail" = 0 ] || printf 'landed-gate-proof: a case failed — see the FAIL row\n' >&2
exit "$fail"
