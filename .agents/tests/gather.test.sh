#!/usr/bin/env bash
# Unit tests for bin/forge/gather.sh — the batch road (RULES/08, appended 2026-11-12).
#
# The Allfather's word: errands sent out together commit on their own branches and never push;
# the helm merges them locally into ONE push and ONE PR, so everybody goes through the gates.
# These tests build a scratch repository with a bare `origin`, three errand branches and one
# helm branch, and prove: --dry-run merges nothing; --list-finished/--finished pick only the
# acclaimed-but-unpushed errands; a conflict stops naming the branch and its files and
# --continue resumes after the helm resolves it; a refusing gate stops the batch; and the full
# road pushes one branch, opens one PR (through a stand-in pr-open.sh), and marks each errand.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ORIGIN="$TMP/origin.git"
REPO="$TMP/repo"
STATE="$TMP/state"
mkdir -p "$STATE"
git init -q --bare -b main "$ORIGIN"
git init -q -b main "$REPO"
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t
git -C "$REPO" remote add origin "$ORIGIN"

mkdir -p "$REPO/bin/forge" "$REPO/.pi" "$REPO/RULES" "$REPO/docs"
cp "$ROOT/bin/forge/gather.sh" "$ROOT/bin/forge/yggdrasil.sh" "$REPO/bin/forge/"
# A stand-in PR door: prints a URL and records that it was called once.
cat >"$REPO/bin/forge/pr-open.sh" <<'EOF'
#!/usr/bin/env bash
echo called >> "$GATHER_TEST_PRLOG"
echo "https://example.invalid/pull/1"
EOF
printf 'shared line\n' > "$REPO/docs/shared.md"
printf '.yggdrasil/\n' > "$REPO/.gitignore"
git -C "$REPO" add -A >/dev/null
git -C "$REPO" commit -qm base
git -C "$REPO" push -q origin main

branch() {  # <name> <file> <text>
  git -C "$REPO" checkout -q -b "$1" main
  printf '%s\n' "$3" > "$REPO/$2"
  git -C "$REPO" add -A >/dev/null
  git -C "$REPO" commit -qm "$1"
  git -C "$REPO" checkout -q main
}
branch eindri/alpha docs/alpha.md "alpha"
branch eindri/beta  docs/beta.md  "beta"
branch hoenir/helm-test docs/helm.md "helm"
branch eindri/pushed docs/pushed.md "pushed"
printf 'working: x\ndone: committed on eindri/alpha (not pushed): alpha page\n' > "$STATE/alpha.status"
printf 'done: committed on eindri/beta (not pushed): beta page\n' > "$STATE/beta.status"
printf 'done: opened PR https://example.invalid/pull/9\n' > "$STATE/pushed.status"
printf 'working: still forging\n' > "$STATE/busy.status"

GATE="$TMP/gate.sh"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho gate-ran >> %s/gate.log\nexit 0\n' "$TMP" > "$GATE"
export GATHER_REPO="$REPO" GATHER_STATE="$STATE" GATHER_SKIP_WELL=1 GATHER_GATES="$GATE" \
       GATHER_TEST_PRLOG="$TMP/pr.log" GATHER_HOUSE=h GATHER_FLEET=f
G="$REPO/bin/forge/gather.sh"

# ── --list-finished picks only acclaimed, unpushed errands ──────────────────
out="$(bash "$G" --list-finished 2>&1)"
case "$out" in *'"alpha"'*'"beta"'*) ok "--list-finished names alpha and beta" ;; *) bad "--list-finished missed an errand: $out" ;; esac
case "$out" in *'"pushed"'*|*'"busy"'*) bad "--list-finished named an errand that pushed or is still working" ;; *) ok "a pushed or working errand is not finished" ;; esac

# ── --dry-run merges nothing ────────────────────────────────────────────────
out="$(bash "$G" --finished hoenir/helm-test --dry-run 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "--dry-run exits 0" || bad "--dry-run exited $rc: $out"
case "$out" in *eindri/alpha*) case "$out" in *eindri/beta*) case "$out" in *hoenir/helm-test*) ok "--dry-run lists the errands and the helm branch" ;; *) bad "--dry-run lacks the helm branch" ;; esac ;; *) bad "--dry-run lacks beta" ;; esac ;; *) bad "--dry-run lacks alpha: $out" ;; esac
[ -d "$REPO/.yggdrasil" ] && [ -n "$(ls "$REPO/.yggdrasil" 2>/dev/null)" ] && bad "--dry-run made a worktree" || ok "--dry-run made no worktree"

# ── an unknown branch is refused ────────────────────────────────────────────
bash "$G" nosuch --no-pr >/dev/null 2>&1 && bad "a missing branch was gathered" || ok "a missing branch is refused"

# ── the full road: one push, one PR, every errand marked ────────────────────
out="$(bash "$G" alpha beta hoenir/helm-test 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "the batch gathers" || bad "the batch failed ($rc): $out"
[ "$(grep -c gate-ran "$TMP/gate.log" 2>/dev/null)" = 1 ] && ok "the gates ran exactly once" || bad "the gates ran $(grep -c gate-ran "$TMP/gate.log" 2>/dev/null) times"
[ "$(grep -c called "$TMP/pr.log" 2>/dev/null)" = 1 ] && ok "one PR was opened" || bad "the PR door was called $(grep -c called "$TMP/pr.log" 2>/dev/null) times"
pushed="$(git --git-dir="$ORIGIN" for-each-ref --format='%(refname:short)' refs/heads/yggdrasil/ | grep -c .)"
[ "$pushed" = 1 ] && ok "one branch was pushed" || bad "$pushed branches were pushed"
pb="$(git --git-dir="$ORIGIN" for-each-ref --format='%(refname:short)' refs/heads/yggdrasil/ | head -1)"
for f in alpha beta helm; do
  git --git-dir="$ORIGIN" cat-file -e "$pb:docs/$f.md" 2>/dev/null && ok "the pushed branch carries $f" || bad "the pushed branch lacks $f"
done
git --git-dir="$ORIGIN" log --format=%s "$pb" | grep -q 'gather: eindri/alpha — committed on eindri/alpha (not pushed): alpha page' \
  && ok "the merge commit carries the acclaim" || bad "the merge commit lacks the acclaim"
tail -1 "$STATE/alpha.status" | grep -q '^done: shipped in PR https://example.invalid/pull/1' && ok "alpha is marked shipped" || bad "alpha not marked"
tail -1 "$STATE/beta.status" | grep -q '^done: shipped in PR' && ok "beta is marked shipped" || bad "beta not marked"
[ -z "$(bash "$G" --list-finished | tail -n +2)" ] && ok "a shipped errand is not gathered twice" || bad "a shipped errand is still listed as finished"
[ "$(git --git-dir="$ORIGIN" rev-parse main)" = "$(git -C "$REPO" rev-parse main)" ] && ok "main itself was not touched" || bad "main moved"

# ── a conflict stops, names the branch and file, and --continue resumes ────
branch eindri/c1 docs/shared.md "one side"
branch eindri/c2 docs/shared.md "other side"
branch eindri/c3 docs/c3.md "after"
: > "$TMP/gate.log"
out="$(bash "$G" c1 c2 c3 --no-pr 2>&1)"; rc=$?
[ "$rc" = 3 ] && ok "a conflict exits 3" || bad "a conflict exited $rc: $out"
case "$out" in *eindri/c2*docs/shared.md*) ok "the conflict names the branch and the file" ;; *) bad "the conflict report is wrong: $out" ;; esac
batch="$(ls "$STATE/gather" | grep -v "$(basename "$pb" | sed 's#.*/##')" | sed 's/\.manifest$//' | tail -1)"
wt="$(grep '^worktree=' "$STATE/gather/$batch.manifest" | cut -d= -f2-)"
bash "$G" --continue "$batch" --no-pr >/dev/null 2>&1 && bad "--continue went on with conflicts unresolved" || ok "--continue refuses while conflicts remain"
printf 'both sides\n' > "$wt/docs/shared.md"
git -C "$wt" add docs/shared.md && git -C "$wt" -c rerere.enabled=false commit -q --no-edit >/dev/null 2>&1
out="$(bash "$G" --continue "$batch" --no-pr 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "--continue finishes the batch" || bad "--continue failed ($rc): $out"
[ -f "$wt/docs/c3.md" ] && ok "the branch after the conflict was merged" || bad "c3 was not merged after the conflict"
[ "$(grep -c gate-ran "$TMP/gate.log")" = 1 ] && ok "the gates ran once for the resumed batch" || bad "gates ran $(grep -c gate-ran "$TMP/gate.log") times"

# ── a refusing gate stops the batch before any push ─────────────────────────
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 1\n' > "$GATE"
branch eindri/d1 docs/d1.md "d1"
before="$(git --git-dir="$ORIGIN" for-each-ref refs/heads | wc -l)"
bash "$G" d1 >/dev/null 2>&1 && bad "a refused gate still shipped" || ok "a refusing gate stops the batch"
[ "$(git --git-dir="$ORIGIN" for-each-ref refs/heads | wc -l)" = "$before" ] && ok "nothing was pushed past a refusing gate" || bad "a branch was pushed past a refusing gate"

# ── the signature is never invented ─────────────────────────────────────────
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' > "$GATE"
branch eindri/e1 docs/e1.md "e1"
GATHER_HOUSE= GATHER_FLEET= bash "$G" e1 >/dev/null 2>&1 && bad "a PR was opened with no house/fleet" || ok "no house/fleet is a refusal, never a guess"

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'gather.test.sh: all passed\n'; else printf 'gather.test.sh: FAILED\n' >&2; fi
exit "$fail"
