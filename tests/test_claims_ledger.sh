#!/usr/bin/env bash
# test_claims_ledger.sh — the fleet's claims ledger, with a fake home and two fake seats (plan 343.12/.14).
#
# Two seats (seat-a, seat-b) each hold their OWN clone of one shared home (a bare origin), exactly as
# two machines do. Nothing real is touched: YMIR_HOME points at the throwaway clones.
#
#   · a claim reaches the other seat through the home's git, and `list --fleet` shows both seats' work
#   · a second seat asking for a claimed PR as coder is refused, naming the holder's seat and errand
#   · a judge and a coder may hold the same PR; two coders may not; a judge on a NEW head may be taken
#   · a stale claim (no heartbeat for 2 h) is offered, never stolen: refused without --adopt-stale
#   · release lets go (file kept, state=released) and only the holder may release
#   · two seats racing for one key: exactly one wins
#   · the push ward (bin/gates/guards/claim-guard.sh) refuses a push to a branch another seat claims
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CLAIM="$ROOT/bin/agents/claim.sh"
GUARD="$ROOT/bin/gates/guards/claim-guard.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-claims.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
export HOME_SYNC_TRIES=2

git init -q --bare -b main "$TMP/origin.git"
git init -q -b main "$TMP/seed"
mkdir -p "$TMP/seed/hodd"; : >"$TMP/seed/hodd/README.md"
# the home's own ignore rule, as shipped: state/ is private EXCEPT the claims shelf
printf 'state/*\n!state/claims/\n*.lock\n' >"$TMP/seed/.gitignore"
git -C "$TMP/seed" add -A; git -C "$TMP/seed" commit -q -m seed
git -C "$TMP/seed" remote add origin "$TMP/origin.git"; git -C "$TMP/seed" push -q origin main
git clone -q "$TMP/origin.git" "$TMP/home-a"; git clone -q "$TMP/origin.git" "$TMP/home-b"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n       %s\n' "$1" "${2:-}"; }
# as <a|b> <args…> — run claim.sh as that seat, against that seat's own clone of the home
as() { local s="$1"; shift; YMIR_HOME="$TMP/home-$s" YMIR_SEAT="seat-$s" "$CLAIM" "$@"; }
# at <a|b> <epoch> <args…> — the same, with the clock set
at() { local s="$1" t="$2"; shift 2; CLAIM_NOW="$t" YMIR_HOME="$TMP/home-$s" YMIR_SEAT="seat-$s" "$CLAIM" "$@"; }

PR="pr:Example/Repo#876"
echo "claims ledger"

# 1. a take is shared through git
out="$(as a take "$PR" --errand rework-a 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'shared' && ok "seat-a takes the PR and it is shared" || bad "seat-a take" "$out"
git -C "$TMP/origin.git" log --oneline main | grep -q 'seat-a takes pr:example/repo#876 as coder' \
  && ok "the claim is a commit on the home's origin" || bad "no claim commit on origin"

# 2. a second seat is refused, with the holder named
out="$(as b take "$PR" --errand rework-b 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'seat seat-a' && printf '%s' "$out" | grep -q 'errand rework-a'; then
  ok "seat-b is refused and told seat-a / rework-a hold it"
else bad "seat-b refusal" "rc=$rc $out"; fi
# the key is case-insensitive on owner/repo
out="$(as b take "pr:EXAMPLE/repo#876" --errand rework-b 2>&1)"; [ "$?" = 1 ] && ok "owner/repo case does not dodge the claim" || bad "case dodge" "$out"

# 3. a judge may hold the same PR as the coder; a second judge seat may not (same head)
out="$(as b take "$PR" --role judge --errand judge-b --head h1 2>&1)"; [ "$?" = 0 ] && ok "a judge holds the PR beside the coder" || bad "judge beside coder" "$out"
out="$(as a take "$PR" --role judge --errand judge-a --head h1 2>&1)"; [ "$?" = 1 ] && ok "a second judge on the same head is refused" || bad "second judge" "$out"
out="$(as a take "$PR" --role judge --errand judge-a2 --head h2 2>&1)"; [ "$?" = 0 ] && ok "a judge on a NEW head may be taken" || bad "new head" "$out"

# 4. the fleet list shows both seats side by side (seat-b's judge claim was superseded by the new
#    head above, so seat-b takes a plan step of its own first)
as b take "plan:343.12" --errand plan-b >/dev/null 2>&1
out="$(as a list --fleet 2>&1)"
if printf '%s' "$out" | grep -q '"seat-a"' && printf '%s' "$out" | grep -q '"seat-b"'; then ok "list --fleet shows seat-a and seat-b together"
else bad "fleet list" "$out"; fi
out="$(as a list 2>&1)"
printf '%s' "$out" | grep -q '"seat-b"' && bad "plain list leaked another seat" "$out" || ok "plain list shows only this seat"

# 5. a different key, a different task: independent
out="$(as b take "plan:343.13" --errand plan-b2 2>&1)"; [ "$?" = 0 ] && ok "another key is free" || bad "plan key" "$out"
out="$(as b take "not-a-key" 2>&1)"; [ "$?" = 2 ] && ok "a malformed key is a usage error" || bad "bad key" "$out"

# 6. stale: offered, never stolen
T0=$(date +%s); LATE=$((T0 + 7300)); NEAR=$((T0 + 600))
# plan-b is seat-b's own, so use a key seat-a holds for the stale cases
as a take "branch:example/repo:eindri/old" --errand old-a >/dev/null 2>&1
out="$(at b "$NEAR" take "branch:example/repo:eindri/old" --errand b2 2>&1)"; [ "$?" = 1 ] && ok "a fresh claim holds (10 min)" || bad "fresh held" "$out"
out="$(at b "$LATE" take "branch:example/repo:eindri/old" --errand b2 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'STALE and offered'; then ok "after 2 h it is offered, not taken"; else bad "stale offered" "rc=$rc $out"; fi
out="$(at b "$LATE" take "branch:example/repo:eindri/old" --errand b2 --adopt-stale 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -q 'adopted from seat-a/old-a' "$TMP/home-b"/state/claims/*/coder 2>/dev/null \
  && ok "--adopt-stale takes it, recording the old holder" || bad "adopt" "rc=$rc $out"

# 7. heartbeat keeps a claim fresh
as a take "branch:example/repo:eindri/hb" --errand hb-a >/dev/null 2>&1
at a "$((T0 + 7000))" heartbeat "branch:example/repo:eindri/hb" >/dev/null 2>&1
out="$(at b "$((T0 + 7300))" take "branch:example/repo:eindri/hb" --errand hb-b 2>&1)"; [ "$?" = 1 ] && ok "a heartbeat at 7000 s keeps it held at 7300 s" || bad "heartbeat" "$out"
out="$(as b heartbeat "branch:example/repo:eindri/hb" 2>&1)"; [ "$?" = 1 ] && ok "only the holder may heartbeat" || bad "foreign heartbeat" "$out"

# 8. release: only the holder; the file is kept; the key is free after
out="$(as b release "$PR" 2>&1)"; [ "$?" = 1 ] && ok "a non-holder cannot release" || bad "foreign release" "$out"
out="$(as a release "$PR" 2>&1)"; [ "$?" = 0 ] && ok "the holder releases" || bad "release" "$out"
ls "$TMP/home-a"/state/claims/*/coder >/dev/null 2>&1 && grep -q '^state=released' "$(ls "$TMP"/home-a/state/claims/pr_example*/coder)" \
  && ok "the file is kept, state=released (never deleted)" || bad "released file" "$(ls "$TMP"/home-a/state/claims 2>&1)"
out="$(as b take "$PR" --errand rework-b 2>&1)"; [ "$?" = 0 ] && ok "seat-b takes the PR once it is released" || bad "take after release" "$out"

# 9. a race: both seats take one key from the same base; exactly one wins
RACE="branch:example/repo:eindri/race"
as a take "$RACE" --errand race-a >"$TMP/ra.out" 2>&1 &
pa=$!
as b take "$RACE" --errand race-b >"$TMP/rb.out" 2>&1 &
pb=$!
wait $pa; ra=$?; wait $pb; rb=$?
wins=0; [ "$ra" = 0 ] && wins=$((wins+1)); [ "$rb" = 0 ] && wins=$((wins+1))
[ "$wins" = 1 ] && ok "a race for one key has exactly one winner" || bad "race" "a=$ra b=$rb $(cat "$TMP/ra.out" "$TMP/rb.out")"

# 10. the push ward
git -C "$TMP/home-b" pull -q origin main 2>/dev/null
as a take "branch:example/repo:feature/x" --errand ward-a >/dev/null 2>&1
mkdir -p "$TMP/repo" && git -C "$TMP/repo" init -q -b main && git -C "$TMP/repo" remote add origin https://github.com/Example/Repo.git
guard() { # <seat> <ref> → runs the ward as a pre-push hook for that seat
  local s="$1" ref="$2"
  ( cd "$TMP/repo" && printf 'refs/heads/%s deadbeef refs/heads/%s 0000000000000000000000000000000000000000\n' "$ref" "$ref" \
      | YMIR_HOME="$TMP/home-$s" YMIR_SEAT="seat-$s" "$GUARD" origin https://github.com/Example/Repo.git ) 2>&1
}
out="$(guard b feature/x)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'seat-a' && printf '%s' "$out" | grep -q 'ward-a'; then ok "the ward refuses seat-b's push to seat-a's branch, naming the holder"
else bad "ward refusal" "rc=$rc $out"; fi
out="$(guard a feature/x)"; [ "$?" = 0 ] && ok "the holder's own push passes" || bad "holder push" "$out"
out="$(guard b feature/unclaimed)"; [ "$?" = 0 ] && ok "an unclaimed branch passes" || bad "unclaimed push" "$out"
out="$(guard b main)"; [ "$?" = 0 ] && ok "a protected branch is branch-guard's, not the claim ward's" || bad "main passes" "$out"
out="$(cd "$TMP/repo" && printf 'refs/heads/feature/x deadbeef refs/heads/feature/x 0\n' | CLAIM_NO_SYNC=1 YMIR_HOME="$TMP/home-b" YMIR_SEAT=seat-b YMIR_SKIP_CLAIM_GUARD=1 "$GUARD" origin https://github.com/Example/Repo.git 2>&1)"
[ "$?" = 0 ] && ok "YMIR_SKIP_CLAIM_GUARD=1 is the loud override" || bad "override" "$out"

echo
echo "claims ledger: $pass passed, $fail failed"
[ "$fail" = 0 ]
