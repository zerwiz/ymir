#!/usr/bin/env bash
# test_fleet_tell.sh — the one road for talking to and steering any agent (fleet-tell.sh).
# A fake ssh and a fake herdr; the real fleet, the real arm and the real panes are never touched.
set -u
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/fleet/fleet-tell.sh"
ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_STATE_HOME="$T/home/.local/state"; mkdir -p "$HOME" "$T/bin" "$T/rt/bin/agents" "$T/rt/bin/fleet" "$T/rt/bin/voice"
export LOG="$T/log"; : >"$LOG"
export YMIR_RUNTIME_DIR="$T/rt" FLEET_TELL_ME=here FLEET_TELL_TIMEOUT=5 YMIR_SEAT_NAME=Ada
cat >"$T/fleet.json" <<'J'
{"hosts":{"here":{"user":"u","tailnet":"here.example"},"far":{"user":"u","tailnet":"far.example"},"dead":{"user":"u","tailnet":"dead.example"}}}
J
export FLEET_TELL_REGISTRY="$T/fleet.json"
export FLEET_TELL_WAKE_CMD='printf "WAKE %s\n" "$1" >>"$LOG"'
# a fake herdr that knows no pane: the signed lines must not depend on the pane this test runs in
printf '#!/usr/bin/env bash\nexit 1\n' >"$T/bin/herdr"; chmod +x "$T/bin/herdr"
# fake ssh: logs, fails for the dead host, otherwise runs the remote command here
cat >"$T/bin/ssh" <<'S'
#!/usr/bin/env bash
host=""; for a in "$@"; do case "$a" in *@*) host="$a" ;; esac; done
printf 'ssh %s\n' "$host" >>"$LOG"
case "$host" in *dead*) exit 255 ;; esac
eval "${@: -1}"
S
chmod +x "$T/bin/ssh"; export PATH="$T/bin:$PATH"
# the fake runtime: each door logs its argv; behaviour is steered by env
cat >"$T/rt/bin/agents/tell.sh" <<'S'
#!/usr/bin/env bash
printf 'tell %s\n' "$*" >>"$LOG"; [ "${ARM_HELD:-1}" = 1 ] || { echo "no arm is held"; exit 3; }; echo handed
S
cat >"$T/rt/bin/agents/eindri-send.sh" <<'S'
#!/usr/bin/env bash
printf 'send %s\n' "$*" >>"$LOG"; echo sent
S
cat >"$T/rt/bin/agents/eindri-answer.sh" <<'S'
#!/usr/bin/env bash
printf 'answer %s\n' "$*" >>"$LOG"; [ "${ANSWER_RC:-0}" = 0 ] || exit "$ANSWER_RC"; echo answered
S
cat >"$T/rt/bin/fleet/arm-holder-pane.sh" <<'S'
#!/usr/bin/env bash
echo "${HOLDER_PANE:-w1:p1}"; [ "${HOLDER_PANE:-w1:p1}" != not-found ]
S
cat >"$T/rt/bin/voice/rodd-arm.sh" <<'S'
#!/usr/bin/env bash
printf 'a\n"Ada","counsellor"\n'
S
chmod +x "$T/rt/bin"/*/*.sh
run() { : >"$LOG"; "$DOOR" "$@" 2>/dev/null; }

o="$(run --to far "hello")"
grep -q '"far","arm holder","tell","Ada,counsellor","handed","w1:p1","yes"' <<<"$o" && good "arm handed and pane typed" || bad "arm handed + pane typed" "$o"
grep -q 'tell --from Ada (here) arm Ada (here) to the arm holder: hello' "$LOG" && good "the arm line is signed" || bad "signed line" "$(cat "$LOG")"
grep -q 'send --from Ada (here) w1:p1 Ada (here) to the arm holder: hello' "$LOG" && good "the pane line is signed" || bad "pane signed" "$(cat "$LOG")"

o="$(ARM_HELD=0 run --to far "hello")"
grep -q '"refused","w1:p1","yes"' <<<"$o" && good "arm refused and pane typed" || bad "refused+typed" "$o"
grep -q "WAKE far's arm is not held — re-arm needed" "$LOG" && good "the wake is raised on the sender's queue" || bad "wake raised" "$(cat "$LOG")"

o="$(run --to dead "hello")"
grep -q '"no-answer","-","no"' <<<"$o" && good "a machine with no answer is reported, with no hang" || bad "no-answer" "$o"
! grep -q '^tell\|^send' "$LOG" && good "nothing was typed for an unreachable machine" || bad "typed to dead" "$(cat "$LOG")"

o="$(run --dry-run --to far --to dead "hello")"
grep -q '"dry-run"' <<<"$o" && ! grep -q '^ssh\|^tell\|^send' "$LOG" && good "--dry-run sends nothing and makes no call" || bad "dry-run" "$(cat "$LOG")"

o="$(HOLDER_PANE=not-found run --to far "hello")"
grep -q '"not-found","no"' <<<"$o" && ! grep -q '^send' "$LOG" && good "no agent pane: nothing is typed" || bad "no pane" "$o"

o="$(run --all "hi")"
[ "$(grep -c '^  "' <<<"$o")" = 3 ] && good "--all reaches every machine in the registry" || bad "--all" "$o"

# the other targets, and the steer verbs
o="$(run --steer --to far:gimle-move "go left")"
grep -q 'tell --from Ada (here) gimle-move steer: go left' "$LOG" && good "steer an errand on a machine through its own tell.sh" || bad "steer" "$(cat "$LOG")"
o="$(run --to far:wBA:p1 "hi")"
grep -q 'tell --from Ada (here) wBA:p1 hi' "$LOG" && good "machine:pane target" || bad "machine:pane" "$(cat "$LOG")"
o="$(ARM_HELD=0 run --steer --to rework-875 "x")"
grep -q 'send --from Ada (here) rework-875 steer: x' "$LOG" && grep -q '"refused","rework-875","yes"' <<<"$o" && good "steer falls back to typing into the pane" || bad "steer fallback" "$o $(cat "$LOG")"
o="$(run --answer --to far:q1 "use B")"
grep -q 'answer --from Ada (here) q1 use B' "$LOG" && good "answer speaks and records through eindri-answer" || bad "answer" "$(cat "$LOG")"
o="$(ANSWER_RC=1 run --answer --to q1 "use B")"
grep -q 'answer --from Ada (here) --record-only q1 use B' "$LOG" && grep -q '^send' "$LOG" && good "an answer whose speak half failed is typed, then recorded" || bad "answer fallback" "$(cat "$LOG")"
o="$(ANSWER_RC=3 run --answer --to q9 "x")"
grep -q 'no open question' <<<"$o" && good "an answer with no open question says so" || bad "no question" "$o"
o="$(run --stop --to far:gimle-move)"
grep -q 'stop at the next safe point' "$LOG" && good "--stop asks for a safe stop" || bad "stop" "$(cat "$LOG")"

# the resolver never returns a pane that is not an agent pane
cat >"$T/bin/herdr" <<'S'
#!/usr/bin/env bash
echo '{"result":{"agents":[{"pane_id":"w9:p9","agent":""},{"pane_id":"w2:p2","agent":"pi"}]}}'
S
chmod +x "$T/bin/herdr"
for p in w9:p9 w2:p2 w7:p7; do
  printf '#!/usr/bin/env bash\nprintf "x\\n  \\"1\\",\\"yes\\",\\"%s\\",\\"via\\"\\n"\n' "$p" >"$T/notify.sh"
  r="$(ARM_HOLDER_NOTIFY="$T/notify.sh" bash "$ROOT/bin/fleet/arm-holder-pane.sh")"
  case "$p" in w2:p2) [ "$r" = w2:p2 ] && good "the resolver returns an agent pane" || bad "agent pane" "$r" ;;
               *) [ "$r" = not-found ] && good "the resolver refuses $p (not an agent pane)" || bad "refuse $p" "$r" ;; esac
done
printf '\n%s passed, %s failed\n' "$ok" "$fail"; [ "$fail" = 0 ]
