#!/usr/bin/env bash
# test_gather_notice.sh — the LAST errand of a batch calls the gather.
#
# Plan 293 part 4. A batch errand's brief promises it will never push and never open a PR: the helm
# gathers the batch into ONE push and ONE PR (RULES/08). Nothing ever told the helm the batch was
# ready — twenty-two clean batch branches were found sitting on origin. This proves the door that
# now says it, and the silences that keep it from crying wolf:
#
#   · aLONE errand (mode is not `batch`) → silent
#   · a batch with any errand still open → silent
#   · the last one finishing → ONE prompt naming the finished ids and the exact gather command
#   · a second run for the same batch → no second prompt (marker)
#   · an errand already shipped is not gathered twice
#   · both the arm's close and the worker's terminal act ask the door
#
# Usage: test_gather_notice.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/forge/gather-notice.sh"
CLOSE="$ROOT/bin/agents/eindri-dispatch.sh"
ACCLAIM="$ROOT/bin/agents/eindri-acclaim.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global init.defaultBranch main >/dev/null 2>&1
git config --global commit.gpgsign false >/dev/null 2>&1

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

STATE="$TMP/state"
HOME_TMP="$TMP/home"
export BROKK_STATE_OVERRIDE="$STATE" GATHER_NOTICE_STATE="$STATE" YMIR_HOME="$HOME_TMP"
unset GATHER_NOTICE_DRY
mkdir -p "$STATE" "$HOME_TMP/hodd/identity"

# ── the fixture: a checkout with a batch's two branches on it ────────────────────
git init -q --bare "$TMP/origin.git"
printf 'x\n' | git -C "$TMP/origin.git" hash-object -w --stdin >/dev/null
git clone -q "$TMP/origin.git" "$TMP/repo" 2>/dev/null
cd "$TMP/repo" || exit 1
printf 'base\n' >base.txt && git add base.txt && git commit -q -m "base: the trunk" && git push -q origin main
for b in a b; do
  git checkout -q -B "eindri/$b" main
  printf '%s\n' "$b" >"$b.txt" && git add "$b.txt" && git commit -q -m "worker: $b"
  git checkout -q main
done
cd - >/dev/null || exit 1

meta() { # <id> <mode> <wave>
  printf 'id=%s\nkind=ship\nmode=%s\nwave=%s\nlaunched=1\n' "$1" "$2" "$3" >"$STATE/$1.meta"
}
status() { printf '%s\n' "$2" >"$STATE/$1.status"; }
queue() { cat "$STATE/.wake-queue" 2>/dev/null | grep -c . || true; }
run() { # <id> [extra env...]
  GATHER_NOTICE_REPO="$TMP/repo" bash "$DOOR" "$@" 2>&1
}

meta a batch W1
meta b batch W1
status a "working: launched"
status b "working: launched"

# ── 1. a lone errand is never a batch ───────────────────────────────────────────
meta solo direct-PR W1
status solo "done: opened PR https://example.invalid/pull/1 — nothing"
out="$(run solo)"
[ -z "$out" ] && ok "a lone errand is silent" || bad "a lone errand is silent" "$out"

# ── 2. a batch with an errand still open is silent ──────────────────────────────
status a "done: committed on eindri/a (batch road: not pushed)"
out="$(run b)"
[ -z "$out" ] && ok "a batch with an errand still open says nothing" || bad "a batch with an errand still open says nothing" "$out"

# ── 3. the last one finishing prompts ONCE, and names the command ───────────────
status b "done: committed on eindri/b (batch road: not pushed)"
out="$(run b)"
case "$out" in
  *'batch W1 is finished — gather it: bin/forge/gather.sh a b'*) ok "the last errand prompts the gather, naming the ids and the command" ;;
  *) bad "the last errand prompts the gather, naming the ids and the command" "$out" ;;
esac
q1="$(queue)"
[ "${q1:-0}" -eq 1 ] && ok "the prompt lands in the durable wake queue, exactly once" || bad "the prompt lands in the durable wake queue, exactly once" "queue lines: ${q1:-0}"
grep -q 'bin/forge/gather.sh a b' "$STATE/.wake-queue" 2>/dev/null \
  && ok "the queued line carries the exact gather command" \
  || bad "the queued line carries the exact gather command" "$(cat "$STATE/.wake-queue" 2>/dev/null | head -2)"

# ── 4. a second run does not prompt again ───────────────────────────────────────
out="$(run b)"
[ -z "$out" ] && ok "a second run for the same batch is silent" || bad "a second run for the same batch is silent" "$out"
q2="$(queue)"
[ "${q2:-0}" -eq "${q1:-0}" ] && ok "no duplicate wake line" || bad "no duplicate wake line" "queue lines: ${q2:-0} (was ${q1:-0})"

# ── 5. an errand already shipped is not gathered twice ──────────────────────────
meta c batch W2
meta d batch W2
status c "done: shipped in PR https://example.invalid/pull/9 (batch gather-1)"
status d "done: committed on eindri/d (batch road: not pushed)"
for b in c d; do
  git -C "$TMP/repo" checkout -q -B "eindri/$b" main
  printf '%s\n' "$b" >"$TMP/repo/$b.txt"
  git -C "$TMP/repo" add "$b.txt"
  git -C "$TMP/repo" commit -q -m "worker: $b"
  git -C "$TMP/repo" checkout -q main
done
out="$(run d)"
case "$out" in
  *'bin/forge/gather.sh d'*) ok "a shipped errand is excluded from the gather" ;;
  *) bad "a shipped errand is excluded from the gather" "$out" ;;
esac
case "$out" in
  *'gather.sh c'*) bad "a shipped errand is not named in the command" ;;
  *) ok "a shipped errand is not named in the command" ;;
esac

# ── 6. nothing gatherable is said plainly, never as a fake command ──────────────
meta e batch W3
meta f batch W3
status e "done: shipped in PR https://example.invalid/pull/10 (batch gather-2)"
status f "failed: could not build"
out="$(run f)"
[ -z "$out" ] && ok "a batch that is finished with nothing to gather prompts nothing" || bad "a batch that is finished with nothing to gather prompts nothing" "$out"

# ── 7. both roads ask the door (a door nobody calls is decoration) ──────────────
grep -q 'gather-notice.sh' "$CLOSE" && ok "the arm's close asks the door" || bad "the arm's close asks the door"
grep -q 'gather-notice.sh' "$ACCLAIM" && ok "the worker's terminal act asks the door" || bad "the worker's terminal act asks the door"

printf '\ngather-notice: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
