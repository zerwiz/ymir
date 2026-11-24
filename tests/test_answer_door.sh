#!/usr/bin/env bash
# The return address and the answer door (plan 365 R1–R4): no ask without an address, a busy sender is retried until
# the answer lands, a worker cannot end without answering, and a silent worker is named. Runs in a scratch state dir.
set -u
ROOT="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$(mktemp -d)"; export YMIR_STATE_DIR="$S"; unset YMIR_REPLY_TO HERMES_SESSION_ID HERDR_PANE_ID
fail=0; ok() { printf 'ok   %s\n' "$1"; }; bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
RT="$ROOT/bin/agents/reply-to.sh"; AN="$ROOT/bin/agents/answer.sh"; RP="$ROOT/bin/agents/report.sh"

# R1 — refused without an address, accepted with one, taken from the caller's own identity when it can be
bash "$RT" resolve >/dev/null 2>&1 && bad "an ask with no address was accepted" || ok "an ask with no address is refused"
[ "$(bash "$RT" resolve --reply-to hermes:abc)" = "hermes:abc" ] && ok "an explicit address is taken" || bad "explicit address"
[ "$(HERMES_SESSION_ID=s9 bash "$RT" resolve)" = "hermes:s9" ] && ok "the caller's own session is the address" || bad "own identity"
bash "$RT" resolve --reply-to nonsense:x >/dev/null 2>&1 && bad "a made-up kind was accepted" || ok "a made-up kind is refused"
bash "$RT" record job1 hermes:abc && [ "$(bash "$RT" get job1)" = "hermes:abc" ] && ok "the address is kept with the errand" || bad "record"

# R2 — no handoff, no answer; a busy sender queues; a retry lands it once; a sent answer is never resent
bash "$AN" job1 >/dev/null 2>&1 && bad "answered with no handoff" || ok "no answer without the handoff"
bash "$RP" write job1 --state done --changed x --verified y --not-verified z --next n >/dev/null 2>&1
export YMIR_ANSWER_SEND_CMD="$S/send.sh"
printf '#!/usr/bin/env bash\necho "refused: busy"; exit 1\n' >"$S/send.sh"; chmod +x "$S/send.sh"
[ "$(bash "$AN" job1)" = queued ] && ok "a busy sender queues the answer" || bad "queue"
printf '#!/usr/bin/env bash\necho "$1 $2" >>"%s/delivered"; exit 0\n' "$S" >"$S/send.sh"
bash "$AN" retry >/dev/null; bash "$AN" retry >/dev/null
[ "$(wc -l <"$S/delivered" 2>/dev/null)" = 1 ] && ok "the retry lands it once, and only once" || bad "retry delivered $(wc -l <"$S/delivered" 2>/dev/null) times"

# R3 — the guard holds an errand until the report is complete and the answer is handed
bash "$RT" record job2 hermes:abc
bash "$AN" guard job2 >/dev/null 2>&1 && bad "the guard let a silent errand end" || ok "the guard holds an errand with no report"
bash "$RP" write job2 --state blocked --changed x --verified y --not-verified z --next n >/dev/null 2>&1
bash "$AN" guard job2 >/dev/null 2>&1 && bad "the guard let an unanswered errand end" || ok "the guard holds an errand that has not answered"
printf '#!/usr/bin/env bash\necho "refused: busy"; exit 1\n' >"$S/send.sh"
bash "$AN" job2 >/dev/null; bash "$AN" guard job2 >/dev/null 2>&1 && ok "a queued answer lets the errand end" || bad "queued answer"
hook="$(printf '{}' | YMIR_ERRAND_ID=job3 YMIR_ROOT="$ROOT" bash "$ROOT/.claude/hooks/errand-stop.sh")"
[ -z "$hook" ] && ok "the stop hook does nothing outside an errand with an address" || bad "hook acted: $hook"
bash "$RT" record job3 hermes:abc
hook="$(printf '{}' | YMIR_ERRAND_ID=job3 YMIR_ROOT="$ROOT" bash "$ROOT/.claude/hooks/errand-stop.sh")"
case "$hook" in *'"decision": "block"'*) ok "the stop hook blocks an errand that has not answered" ;; *) bad "hook did not block: $hook" ;; esac
hook="$(printf '{"stop_hook_active": true}' | YMIR_ERRAND_ID=job3 YMIR_ROOT="$ROOT" bash "$ROOT/.claude/hooks/errand-stop.sh")"
[ -z "$hook" ] && ok "the stop hook lets go on the second try" || bad "hook trapped the session"


# the hermes: road — a waiter the sender starts at dispatch exits with the answer when the handoff lands (end to end)
unset YMIR_ANSWER_SEND_CMD
bash "$RT" record job5 hermes:abc
( YMIR_WAIT_POLL=1 bash "$AN" wait job5 >"$S/waiter.out" 2>&1 & echo $! >"$S/waiter.pid" ); sleep 2
[ "$(bash "$AN" pending | grep -c 'job5')" = 0 ] && ok "no answer is claimed before the worker reports" || bad "pending early"
bash "$RP" write job5 --state done --changed x --verified y --not-verified z --next n >/dev/null 2>&1
[ "$(bash "$AN" job5)" = sent ] && ok "a live waiter takes the answer: sent" || bad "waiter did not take it"
for _ in 1 2 3 4 5 6 7 8; do kill -0 "$(cat "$S/waiter.pid")" 2>/dev/null || break; sleep 1; done
kill -0 "$(cat "$S/waiter.pid")" 2>/dev/null && bad "the waiter is still blocking" || ok "the waiter exited (the sender's wake)"
grep -q "\[errand job5\]" "$S/waiter.out" && ok "the waiter printed the answer line" || bad "waiter output: $(cat "$S/waiter.out")"
bash "$RT" record job6 hermes:abc; bash "$RP" write job6 --state done --changed x --verified y --not-verified z --next n >/dev/null 2>&1
[ "$(bash "$AN" job6)" = queued ] && ok "with no waiter the hermes answer stays queued, never claimed handed" || bad "claimed handed with no waiter"

# R4 — a worker silent past its lease is named
touch -d '3 hours ago' "$S/job4.replyto"; printf 'hermes:abc\n' >"$S/job4.replyto"; touch -d '3 hours ago' "$S/job4.replyto"
bash "$AN" silent | grep -q "silent: job4" && ok "a worker silent for 3 hours is named" || bad "silent"
rm -rf "$S"; [ "$fail" = 0 ] && echo "ok: $fail failed" || { echo "FAILED: $fail"; exit 1; }
