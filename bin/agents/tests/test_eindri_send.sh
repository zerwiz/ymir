#!/usr/bin/env bash
# test_eindri_send.sh — the safe sender's three laws, with a stubbed herdr and a fence.
#
# Plan 293 part 5 (2026-11-14). Every case here was measured in the hall that day:
#   * a brief typed into a box that already holds the operator's words (the runbook's paragraph);
#   * a prompt that never landed, and the resend that rescued it;
#   * a prompt that DID land while `agent get` still said idle — three workers read `idle` with a
#     spinner on screen, the helm resent, and each got two briefs. That is why a resend asks the
#     SCREEN as well, and why this test would fail if the screen check were removed;
#   * a far machine on herdr 0.7.x, where the road is `agent send` and then `pane send-keys Enter`.
#
# Nothing real is touched: a throwaway HOME (so the fleet registry is an invented one), a
# stubbed `herdr` and a stubbed `ssh` on PATH, and no live pane is ever read or written.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/agents/eindri-send.sh"
[ -x "$DOOR" ] || { printf 'FAIL no %s\n' "$DOOR"; exit 1; }

ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" YMIR_HOME="$T/home"
mkdir -p "$HOME/hodd/data" "$T/bin" "$T/stub"
export STUB_DIR="$T/stub"
export EINDRI_SEND_WAIT=0          # the wait is the door's, and it is proven by the state it reads

# ── the invented fleet registry (never a machine of the house) ────────────────────────
cat >"$HOME/hodd/data/fleet.json" <<'JSON'
{"hosts": {"faraway": {"roles": ["heart"], "user": "faruser", "tailnet": "faraway.example"}}}
JSON

# ── the stubs ─────────────────────────────────────────────────────────────────────────
cat >"$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
S="${STUB_DIR:?}"
case "${1:-} ${2:-}" in
  "agent --help") cat "$S/help.txt" ;;
  "agent get")
    [ -f "$S/noagent" ] && { printf '{"error":{"message":"no agent in that pane"}}\n'; exit 1; }
    printf '{"result":{"agent":{"agent":"pi","agent_status":"%s","pane_id":"%s"}}}\n' \
      "$(cat "$S/status" 2>/dev/null || echo unknown)" "${3:-}" ;;
  "agent prompt")
    printf 'prompt\t%s\n' "${4:-}" >>"$S/sent.log"
    # a prompt that arrives while the harness is still starting is TYPED and never submitted:
    # the box then holds it, there is no spinner, and `agent get` still says idle.
    [ -f "$S/typed-after-prompt" ] && cp "$S/pane-typed.txt" "$S/pane.txt"
    exit 0 ;;
  "agent send")    printf 'send\t%s\n'   "${4:-}" >>"$S/sent.log" ;;
  "pane send-keys") printf 'enter\t%s\n' "${3:-}" >>"$S/sent.log" ;;
  "pane read")     cat "$S/pane.txt" ;;
  *) exit 0 ;;
esac
STUB

cat >"$T/bin/ssh" <<'STUB'
#!/usr/bin/env bash
# ssh <opts…> <dest> "<command>" — this stub runs the far command HERE, which is what makes the
# remote road testable at all: the same words, the same verb probe, the same stub herdr.
printf '%s\n' "${!#}" >>"${STUB_DIR:?}/ssh.log"
eval "${!#}"
STUB
chmod +x "$T/bin/herdr" "$T/bin/ssh"

# herdr 0.9.x's verb list (the shape measured on this machine).
printf 'Commands:\n  list       List agents\n  prompt     Submit a prompt to an agent\n  send-keys  Send key presses to an agent\n' >"$T/stub/help.txt"

# ── the two box shapes, as measured on live panes (claude and pi) ────────────────────
R40="$(printf '─%.0s' $(seq 1 70))"
pi_box() {  # pi: the box is the region between the status separator and the rule beneath
  printf ' a transcript line\n── Elapsed 1.2s %s\n%s\n%s\n~/project (main)\n↑1k ↓2k R3M CH99%% $0.01 (auto)\nmesh: unconfigured\n' \
    "$(printf '─%.0s' $(seq 1 40))" "$1" "$R40"
}
claude_box() {  # claude: the box is bounded by two rules, and its prompt marker is ❯
  printf ' some transcript\n%s\n%s\n%s\n  ⏵⏵ auto mode on (shift+tab to cycle)\n' "$R40" "$1" "$R40"
}

# ── the door, fenced ─────────────────────────────────────────────────────────────────
send() {  # send <args…> — the door under the stub PATH and the throwaway home
  env PATH="$T/bin:$PATH" YMIR_FLEET_REGISTRY="$HOME/hodd/data/fleet.json" YMIR_MSG_FROM="agent test-helm (probe)" \
      bash "$DOOR" "$@" >"$T/out" 2>"$T/err"
  echo $?
}
reset() { : >"$T/stub/sent.log"; : >"$T/stub/ssh.log"; printf 'working\n' >"$T/stub/status"; rm -f "$T/stub/noagent"; }

# ── 1. an empty box, a worker that goes working → one send, and it carries the stamp ──
reset; pi_box '' >"$T/stub/pane.txt"
rc="$(send w1:p1 'the brief')"
if [ "$rc" = 0 ]; then good 'delivers to a worker whose box is empty (pi shape)'; else bad 'delivers to a worker whose box is empty (pi shape)' "rc=$rc $(head -3 "$T/err")"; fi
if [ "$(grep -c '^prompt' "$T/stub/sent.log")" = 1 ]; then good 'exactly one prompt was sent'; else bad 'exactly one prompt was sent' "$(cat "$T/stub/sent.log")"; fi
if grep -q '^prompt	\[from ' "$T/stub/sent.log"; then good 'the line carries its origin stamp'; else bad 'the line carries its origin stamp' "$(cat "$T/stub/sent.log")"; fi
grep -q '"working","no"' "$T/out" && good 'the row says working, no resend' || bad 'the row says working, no resend' "$(cat "$T/out")"

# ── 2. the box already holds text → REFUSED, and nothing is typed or cleared ─────────
for shape in pi claude; do
  reset
  if [ "$shape" = pi ]; then pi_box "the operator's half-written sentence" >"$T/stub/pane.txt"
  else claude_box '❯ the operator is mid-sentence' >"$T/stub/pane.txt"; fi
  rc="$(send w1:p1 'the brief')"
  if [ "$rc" = 3 ]; then good "refuses a $shape box that already holds text"; else bad "refuses a $shape box that already holds text" "rc=$rc $(head -2 "$T/err")"; fi
  if [ ! -s "$T/stub/sent.log" ]; then good "nothing was sent into the $shape box"; else bad "nothing was sent into the $shape box" "$(cat "$T/stub/sent.log")"; fi
  grep -q 'nothing was cleared' "$T/err" && good "the refusal says it cleared nothing ($shape)" || bad "the refusal says it cleared nothing ($shape)" "$(head -3 "$T/err")"
done

# ── 3. the claude shape with an EMPTY box still delivers (the marker is not text) ────
reset; claude_box '❯' >"$T/stub/pane.txt"
rc="$(send w1:p1 'the brief')"
if [ "$rc" = 0 ]; then good 'a claude box holding only its ❯ marker counts as empty'; else bad 'a claude box holding only its ❯ marker counts as empty' "rc=$rc $(head -3 "$T/err")"; fi

# ── 4. the send did not land → it is sent ONCE MORE, and the row says so ─────────────
reset; pi_box '' >"$T/stub/pane.txt"; printf 'idle\n' >"$T/stub/status"
rc="$(send w1:p1 'the brief')"
n="$(grep -c '^prompt' "$T/stub/sent.log")"
if [ "$n" = 2 ]; then good 'an idle worker with a quiet screen is sent to twice'; else bad 'an idle worker with a quiet screen is sent to twice' "sends=$n"; fi
if [ "$rc" = 5 ]; then good 'the door says it never saw working (exit 5)'; else bad 'the door says it never saw working (exit 5)' "rc=$rc"; fi
grep -q '"copy"$' "$T/out" && good 'the row records the resend as a copy' || bad 'the row records the resend as a copy' "$(cat "$T/out")"

# ── 5. `agent get` says idle but the SCREEN shows work → NOT resent (the 2026-11-14 bug)
reset; printf 'idle\n' >"$T/stub/status"
printf '── ⠹ Working ──────%s\n\n%s\n~/p (main)\nmesh: unconfigured\n' "$(printf '─%.0s' $(seq 1 40))" "$R40" >"$T/stub/pane.txt"
rc="$(send w1:p1 'the brief')"
n="$(grep -c '^prompt' "$T/stub/sent.log")"
if [ "$n" = 1 ]; then good 'a spinner on the screen stops the resend (no duplicate brief)'; else bad 'a spinner on the screen stops the resend (no duplicate brief)' "sends=$n"; fi
[ "$rc" = 5 ] && good 'and the door still tells the truth about the status' || bad 'and the door still tells the truth about the status' "rc=$rc"

# ── 5b. the brief was TYPED but never submitted (no spinner, status idle) → Enter, not a copy
# Measured by the helm 2026-11-14: a prompt sent while pi is starting stands in the editor above
# the footer with no spinner, and the status reads idle. Sending the text again would double the
# brief; the door must press Enter instead.
reset; pi_box '' >"$T/stub/pane.txt"; printf 'idle\n' >"$T/stub/status"
pi_box "$(printf '[from agent test-helm (probe)] the brief')" >"$T/stub/pane-typed.txt"
: >"$T/stub/typed-after-prompt"
rc="$(send w1:p1 'the brief')"
if [ "$(grep -c '^prompt' "$T/stub/sent.log")" = 1 ] && [ "$(grep -c '^enter' "$T/stub/sent.log")" = 1 ]; then
  good 'a typed-but-unsent brief is submitted with Enter, not sent a second time'
else bad 'a typed-but-unsent brief is submitted with Enter, not sent a second time' "$(cat "$T/stub/sent.log")"; fi
grep -q '"enter"$' "$T/out" && good 'and the row says Enter was pressed' || bad 'and the row says Enter was pressed' "$(cat "$T/out")"
rm -f "$T/stub/typed-after-prompt" "$T/stub/pane-typed.txt"

# ── 6. no agent in the pane → refused before a single key is pressed ────────────────
reset; : >"$T/stub/noagent"
rc="$(send w1:p1 'the brief')"
if [ "$rc" = 3 ] && [ ! -s "$T/stub/sent.log" ]; then good 'refuses a pane with no agent in it'; else bad 'refuses a pane with no agent in it' "rc=$rc $(head -2 "$T/err")"; fi
rm -f "$T/stub/noagent"

# ── 7. a FAR machine on herdr 0.7.x: agent send, then pane send-keys Enter ──────────
reset; pi_box '' >"$T/stub/pane.txt"
printf 'herdr agent commands:\n  herdr agent list\n  herdr agent send <target> <text>\n  herdr agent get <target>\n' >"$T/stub/help.txt"
rc="$(send faraway:w9:p2 'the brief')"
if grep -q '^send' "$T/stub/sent.log" && grep -q '^enter' "$T/stub/sent.log"; then
  good 'a 0.7.x far side is spoken to with `agent send` then `pane send-keys Enter`'
else bad 'a 0.7.x far side is spoken to with `agent send` then `pane send-keys Enter`' "$(cat "$T/stub/sent.log")"; fi
if grep -q '^prompt' "$T/stub/sent.log"; then bad 'a 0.7.x far side is never handed `agent prompt`'; else good 'a 0.7.x far side is never handed `agent prompt`'; fi
[ "$rc" = 0 ] && good 'the far row reports working' || bad 'the far row reports working' "rc=$rc $(head -2 "$T/err")"
grep -q '"faraway"' "$T/out" && good 'the row names the machine, not an address' || bad 'the row names the machine, not an address' "$(cat "$T/out")"

# ── 8. a FAR machine on herdr 0.9.x: the probe finds `prompt` and uses it ───────────
reset; pi_box '' >"$T/stub/pane.txt"
printf 'Commands:\n  list       List agents\n  prompt     Submit a prompt to an agent\n' >"$T/stub/help.txt"
rc="$(send faraway:w9:p2 'the brief')"
grep -q '^prompt' "$T/stub/sent.log" && good 'a 0.9.x far side is spoken to with `agent prompt`' || bad 'a 0.9.x far side is spoken to with `agent prompt`' "$(cat "$T/stub/sent.log")"
[ "$rc" = 0 ] && good 'the 0.9.x far send lands' || bad 'the 0.9.x far send lands' "rc=$rc $(head -2 "$T/err")"

# ── 9. a machine that is not in the registry is refused BY NAME, never guessed ───────
reset; pi_box '' >"$T/stub/pane.txt"
rc="$(send nosuchplace:w1:p1 'the brief')"
if [ "$rc" = 2 ] && grep -q 'nosuchplace' "$T/err"; then good 'refuses a machine the registry does not name'; else bad 'refuses a machine the registry does not name' "rc=$rc $(head -2 "$T/err")"; fi
if [ ! -s "$T/stub/ssh.log" ]; then good 'and dials nothing at all'; else bad 'and dials nothing at all' "$(cat "$T/stub/ssh.log")"; fi

# ── 10. a plain pane id (one colon) stays LOCAL — no ssh ────────────────────────────
reset; pi_box '' >"$T/stub/pane.txt"
rc="$(send w39:p1V 'the brief')"
if [ ! -s "$T/stub/ssh.log" ] && [ "$rc" = 0 ]; then good 'a pane id with one colon never rides ssh'; else bad 'a pane id with one colon never rides ssh' "rc=$rc ssh=$(cat "$T/stub/ssh.log")"; fi

printf '\neindri-send: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]
