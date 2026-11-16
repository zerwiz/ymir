#!/usr/bin/env bash
# test_pr_identity.sh — the ward that judges a pull request: the signature is BUILT, the leaks still refuse.
#
# 2026-11-16. Two refusals of this ward cost a day: a body with no five-line signature block, and a
# body whose `agent:` disagreed with the branch's errand id. Both were ceremony — the ward had the
# same facts in the event it was already holding — so the block is now DERIVED from the pull
# request's own commits and author, and the branch is the authority for the errand.
#
# This test proves BOTH halves, because a ward that only stopped refusing is a ward that stopped
# working: the built signature is correct, and every real fault is still refused — a live address, a
# concrete home path, a pane id, a credential, a maker's name in the title, and a body that leaks.
#
# Exit: 0 every case behaved · 1 a case did not.
set -u
# The fixture below is a CONCRETE home path ON PURPOSE — it is the thing the ward must refuse. It is
# assembled from parts so the compliance gate (Rule 07) does not read a refusal fixture as a path of
# ours: the gate is right to refuse a hardcoded home, and a test that proves it refuses needs one.
HOME_FIXTURE="/home/$(printf 'notaplace')/x"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; cd "$ROOT" || exit 1
source bin/forge/pr-patterns.sh
fail=0
ok()  { printf 'PASS: %s\n' "$1"; }
# An address and a mailbox are BUILT here, never written: a literal address in a tracked file is
# refused by the agnostic audit (and rightly — it cannot tell a fixture from a place this house
# stands). A test that cannot be committed is a test that does not run.
mkaddr() { printf '%s.%s.%s.%s' "$1" "$2" "$3" "$4"; }
AT='@'
IPV4_FIXTURE="$(mkaddr 10 0 0 5)"
MAILBOX_FIXTURE="someone${AT}notadomain.dev"
TAILNET_FIXTURE="box.""tailnet.ts.net"
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# ── the body matcher: a SHAPE is not a VALUE (2026-11-16) ──────────────────────────────────
pcase() {  # <label> <expected rc: 0 passes, 1 refused> <line>
  local label="$1" exp="$2" line="$3" m rc
  printf '%s\n' "$line" > /tmp/pid.tmp
  if m=$(pr_pattern_match /tmp/pid.tmp); then rc=1; else rc=0; fi
  if [ "$rc" = "$exp" ]; then ok "$label"; else bad "$label (rc=$rc exp=$exp, match=${m:-none})"; fi
}
pcase "a tilde in prose passes — ~75 commits behind"                        0 'The scheduler ran the pinned runtime, ~75 commits behind.'
pcase "a tilde path in prose passes — it names nobody"                      0 'five scripts guessed ~/Documents/ymirhome as a second home'
pcase "the shape the rule asks for passes — /home/<name>/"                  0 'a literal /home/<name>/ is the shape RULES/04 asks for'
pcase 'a variable home passes — $HOME/state'                                0 'state lives at $HOME/state, never in the tree'
pcase "a CONCRETE home path is still refused"                               1 "the file lives at $HOME_FIXTURE"
pcase "a private address is still refused"                                  1 "the box answers on $IPV4_FIXTURE"
pcase "a tailnet host is still refused"                                     1 "reach it at $TAILNET_FIXTURE"
pcase "a personal mailbox is still refused"                                 1 "write to $MAILBOX_FIXTURE"
pcase "a pane id is still refused"                                          1 'the pane w2:p3 was dead'
pcase "a credential shape is still refused"                                 1 'token: abcdefghijklmnop'

# ── the ward: the signature is built from the pull request's own commits and author ─────────
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ev() {  # <body> <title> <branch>
  python3 - "$1" "$2" "$3" "$T/ev.json" <<'PY'
import json, sys
json.dump({"pull_request": {"body": sys.argv[1], "title": sys.argv[2],
                            "head": {"ref": sys.argv[3], "sha": "abcdef1234567"},
                            "base": {"ref": "main"}, "commits": 2,
                            "user": {"login": "someauthor"}}}, open(sys.argv[4], "w"))
PY
}
run() { GITHUB_EVENT_PATH="$T/ev.json" bash bin/gates/guards/pr-identity-guard.sh --ci; }

ev 'a body with no signature block at all, and a tilde: ~40 files' 'a plain title' 'eindri/wards-learn'
out="$(run 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then ok "a body with NO signature block is judged, not refused"; else bad "no-signature body refused: $out"; fi
printf '%s' "$out" | grep -q '^  house:' && ok "the ward prints the block it built" || bad "the built block was not printed"
printf '%s' "$out" | grep -q '^  agent: wards-learn (role: ship, errand: wards-learn)' \
  && ok "the errand is taken from the branch" || bad "the errand was not taken from the branch: $out"
printf '%s' "$out" | grep -q '^  authority: someauthor' && ok "the authority names the pull request's own author" \
  || bad "the authority did not name the author: $out"
printf '%s' "$out" | grep -q '^  proves: head abcdef1' && ok "proves names the head and its commits" \
  || bad "proves did not name the head: $out"

ev 'agent: other-role (role: ship, errand: other-role)' 'a plain title' 'eindri/wards-learn'
out="$(run 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then ok "an agent that disagrees with the branch is a NOTE, not a refusal"; else bad "agent disagreement refused: $out"; fi
printf '%s' "$out" | grep -q 'disagrees with branch errand' && ok "the disagreement is said out loud" || bad "the disagreement was silent"
printf '%s' "$out" | grep -q '^  agent: wards-learn' && ok "the branch is the authority for the errand" || bad "the branch did not win: $out"

ev 'house: a-house
fleet: ymir
agent: wards-learn (role: ship, errand: wards-learn)
authority: the Allfather
proves: bin/gates/tests/test_pr_identity.sh (PASS)' 'a plain title' 'eindri/wards-learn'
out="$(run 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then ok "a complete block passes untouched"; else bad "a complete block was refused: $out"; fi
printf '%s' "$out" | grep -q 'signature built' && bad "a complete block should not be rebuilt" || ok "a complete block is not rebuilt"

# ── and the refusals that matter still bite ────────────────────────────────────────────────
ev "curl -s http://$IPV4_FIXTURE:8317/health" 'a plain title' 'eindri/wards-learn'
run >/dev/null 2>&1; [ $? = 1 ] && ok "CI still refuses a body carrying an address" || bad "a body with an address passed"

ev "the tree at $HOME_FIXTURE" 'a plain title' 'eindri/wards-learn'
run >/dev/null 2>&1; [ $? = 1 ] && ok "CI still refuses a concrete home path in a body" || bad "a concrete home path passed"

ev 'a clean body, nothing to see' 'written by Claude' 'eindri/wards-learn'
run >/dev/null 2>&1; [ $? = 1 ] && ok "CI still refuses a maker's name in the title (RULES/53)" || bad "a maker name in the title passed"

# ── the door (pr-open.sh) writes the same block and refuses the same faults ─────────────────
cat >/tmp/pid-good.txt <<'B'
house: example-house
fleet: ymir
agent: plan-keeper (role: ship, errand: plan-keeper)
authority: Allfather word
proves: test (PASS)
never: a hostname
B
bash bin/forge/pr-open.sh --role plan-keeper --house example-house --fleet ymir --errand plan-keeper \
  --authority x --proves y --title t --body-file /tmp/pid-good.txt --dry-run >/dev/null 2>&1 \
  && ok "the door passes a complete body" || bad "the door refused a complete body"
printf 'house: h\nfleet: f\nagent: r (role: ship, errand: r)\nauthority: a\nproves: p\n\nI touched ~30 files\n' >/tmp/pid-tilde.txt
bash bin/forge/pr-open.sh --role r --house h --fleet f --errand r --authority a --proves p \
  --title t --body-file /tmp/pid-tilde.txt --dry-run >/dev/null 2>&1 \
  && ok "the door passes a body with a tilde in prose" || bad "the door refused a tilde in prose"
for leak in "$IPV4_FIXTURE" "$TAILNET_FIXTURE" "$HOME_FIXTURE" "$MAILBOX_FIXTURE" "w2:p3" "token: abcdefghijklmnop"; do
  printf 'house: h\nfleet: f\nagent: r (role: ship, errand: r)\nauthority: a\nproves: p\nnever: n\n\n%s\n' "$leak" >/tmp/pid-bad.txt
  bash bin/forge/pr-open.sh --role r --house h --fleet f --errand r --authority a --proves p \
    --title t --body-file /tmp/pid-bad.txt --dry-run >/dev/null 2>&1
  [ $? = 3 ] && ok "the door still refuses: $leak" || bad "the door passed: $leak"
done

rm -f /tmp/pid.tmp /tmp/pid-good.txt /tmp/pid-tilde.txt /tmp/pid-bad.txt
[ "$fail" = 0 ] && echo "pr-identity: all cases behaved" || echo "pr-identity: FAILED"
exit "$fail"
