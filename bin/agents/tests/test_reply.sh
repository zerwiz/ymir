#!/usr/bin/env bash
# test_reply.sh — the road back (bin/agents/reply.sh): a stamped message is answered to whoever sent it.
# A fake herdr (two machines, panes with boxes), a fake ssh and fake room/arm doors; nothing real is touched.
set -u
ROOT="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
REPLY="$ROOT/bin/agents/reply.sh"; SEND="$ROOT/bin/agents/eindri-send.sh"
ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }
has()  { grep -qF -- "$2" <<<"$1"; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" YMIR_HOME="$T/home" XDG_STATE_HOME="$T/home/.local/state"
mkdir -p "$HOME/hodd/data" "$T/bin" "$T/doors"
unset HERDR_PANE_ID HERMES_SESSION_ID YMIR_MSG_FROM YMIR_REPLY_AUTO YMIR_REPLY_STATE
export SENTLOG="$T/sent" DOORS="$T/doors.log"; : >"$SENTLOG"; : >"$DOORS"
ME="$(hostname -s 2>/dev/null || uname -n)"
printf '{"hosts":{"%s":{"user":"u","tailnet":"here.example"},"faraway":{"user":"u","tailnet":"far.example"}}}' "$ME" >"$HOME/hodd/data/fleet.json"
export YMIR_FLEET_REGISTRY="$HOME/hodd/data/fleet.json" FLEET_TELL_REGISTRY="$HOME/hodd/data/fleet.json"
export EINDRI_SEND_WAIT=0 YMIR_RUNTIME_DIR="$ROOT"
cat >"$T/bin/herdr" <<'S'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "agent --help") echo "  prompt   Submit a prompt" ;;
  "agent get") printf '{"result":{"agent":{"agent":"claude","agent_status":"%s"}}}\n' "${PANE_STATUS:-working}" ;;
  "agent prompt") printf '%s\t%s\n' "$3" "$4" >>"$SENTLOG" ;;
  "pane read") r="$(printf '─%.0s' $(seq 1 70))"; box="❯ "; [ "${BOX_PANE:-}" = "$3" ] && box="❯ half written words"
               printf ' t\n%s\n%s\n%s\n  ⏵⏵ auto mode on\n' "$r" "$box" "$r" ;;
  "agent list") echo '{"result":{"agents":[{"agent":"claude","pane_id":"w1:pA"},{"agent":"claude","pane_id":"w1:pB"}]}}' ;;
  "pane list") echo '{"result":{"panes":[]}}' ;;
  "pane process-info") [ "${4:-}" = "${FAKE_PANE:-none}" ] && printf '{"result":{"process_info":{"shell_pid":%s}}}\n' "$FAKE_PANE_PID" ;;
  *) exit 1 ;;
esac
S
cat >"$T/bin/ssh" <<'S'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in *@*) printf 'ssh %s\n' "$a" >>"$DOORS" ;; esac; done
eval "${@: -1}"
S
printf '#!/usr/bin/env bash\necho "${HOLDER:-not-found}"\n' >"$T/doors/holder"
for d in room arm notify tell; do
  printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >>"$DOORS"\nexit "${%s_RC:-0}"\n' "$d" "${d^^}" >"$T/doors/$d"
done
chmod +x "$T/bin"/* "$T/doors"/*; export PATH="$T/bin:$PATH"
export YMIR_REPLY_ROOM="$T/doors/room" YMIR_REPLY_ARM="$T/doors/arm" YMIR_REPLY_NOTIFY="$T/doors/notify" YMIR_REPLY_TELL="$T/doors/tell" YMIR_REPLY_HOLDER="$T/doors/holder" YMIR_REPLY_FOREGROUND=1 YMIR_REPLY_SETTLE=1 YMIR_REPLY_GRACE=0
as() { local pane="$1" name="$2"; shift 2; env YMIR_REPLY_PANE="$pane" YMIR_REPLY_ORIGIN="agent $name · herdr pane $pane · $ME" "$@"; }
reset() { : >"$SENTLOG"; : >"$DOORS"; rm -rf "$XDG_STATE_HOME/ymir/replies"; }
turn() { python3 -c 'import json,sys; print(json.dumps({"session":"s","answer":sys.argv[2],"messages":[{"id":sys.argv[1],"text":sys.argv[3]}]}))' "$@"; }
last() { tail -1 "$SENTLOG" | cut -f2; }

# ── same machine: A asks B, B's turn ends, A gets it, nothing bounces ───────────
reset
YMIR_MSG_FROM="agent A · herdr pane w1:pA · $ME" bash "$SEND" w1:pB "what is 2+2?" >"$T/qlog" 2>&1
q="$(last)"
[ "$q" = "[from agent A · herdr pane w1:pA · $ME] what is 2+2?" ] && good "the question carries A's pane" || bad "question stamp" "$(cat -A "$SENTLOG")"
o="$(turn m1 four "$q" | as w1:pB B bash "$REPLY" --turn-end 2>&1)"
[ "$(tail -1 "$SENTLOG")" = "$(printf 'w1:pA\t[reply from agent B · herdr pane w1:pB · %s] four' "$ME")" ] && good "B's answer lands in A, stamped as B's reply" || bad "round trip" "$o $(cat "$SENTLOG")"
n="$(wc -l <"$SENTLOG")"
turn m1 four "$q" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ "$(wc -l <"$SENTLOG")" = "$n" ] && good "one answer per message: the same turn twice sends once" || bad "dedupe" "$(cat "$SENTLOG")"
r="$(last)"
turn m2 thanks "$r" | as w1:pA A bash "$REPLY" --turn-end >/dev/null 2>&1
turn m3 noted "[from Hermes] $r" | as w1:pA A bash "$REPLY" --turn-end >/dev/null 2>&1
[ "$(wc -l <"$SENTLOG")" = "$n" ] && good "a reply is never auto-answered, even behind a second stamp: no loop" || bad "loop" "$(cat "$SENTLOG")"
reset
turn m4 again "<pasted_content id=\"ab\">
$q" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(last)" "] again" && good "a stamp inside a pasted_content wrapper is read" || bad "pasted" "$(cat "$SENTLOG")"
reset
turn m5 x "please read this: $q" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ ! -s "$SENTLOG" ] && good "a stamp quoted inside a message answers nobody" || bad "quoted" "$(cat "$SENTLOG")"
turn m6 x "$q" | YMIR_REPLY_AUTO=0 as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ ! -s "$SENTLOG" ] && good "YMIR_REPLY_AUTO=0 stops the automatic answer" || bad "opt out"

# ── by hand ───────────────────────────────────────────────────────────────────
reset
YMIR_MSG_FROM="agent A · herdr pane w1:pA · $ME" bash "$SEND" w1:pB "status?" >/dev/null 2>&1
o="$(as w1:pB B bash "$REPLY" "all green" 2>&1)"
has "$(last)" "[reply from agent B" && has "$(last)" "all green" && good "a bare reply answers the last message to this pane" || bad "bare reply" "$o"
python3 -c 'import json,sys; print(json.dumps({"session":"s","answer":"final","messages":[{"id":"m7","text":sys.argv[1],"since":1}]}))' \
  "[from agent A · herdr pane w1:pA · $ME] status?" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
! has "$(cat "$SENTLOG")" "final" && good "answered by hand in the turn: the hook sends no second answer" || bad "double" "$(cat "$SENTLOG")"
o="$(as w1:pB B bash "$REPLY" "once more" 2>&1)"; rc=$?
[ "$rc" = 3 ] && has "$o" "Nothing was sent" && good "an answered message is not answered twice by a bare reply" || bad "consumed" "$rc $o"
o="$(as w1:pB B bash "$REPLY" --to w1:pC "hi" 2>&1)"
has "$(tail -1 "$SENTLOG")" "w1:pC" && good "--to a pane" || bad "--to pane" "$o"

# ── senders with nothing to answer ────────────────────────────────────────────
for who in "script cron · $ME" "script x · herdr pane w1:pS · $ME" "the Allfather · $ME" "a person at terminal not-a-tty · $ME"; do
  reset
  o="$(as w1:pB B bash "$REPLY" --to "[from $who] do it" "done" 2>&1)"; rc=$?
  turn m done "[from $who] do it" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
  [ "$rc" = 3 ] && has "$o" "no way back" && [ ! -s "$SENTLOG" ] && [ ! -s "$DOORS" ] && good "refused in words, nothing sent: $who" || bad "no road: $who" "$rc $o"
done

# ── the other roads ───────────────────────────────────────────────────────────
rodd="[from the Allfather, by voice through Rödd · $ME] how goes it?"
reset; turn r1 well "$rodd" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$DOORS")" "room reply" && [ ! -s "$SENTLOG" ] && good "Rödd is answered into the room" || bad "room" "$(cat "$DOORS")"
reset; turn r2 well "$rodd" | ROOM_RC=3 as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$DOORS")" "arm tell" && has "$(cat "$DOORS")" "relay it there" && good "not the helm: the arm holder is asked to relay it" || bad "relay" "$(cat "$DOORS")"
reset; turn t1 ok "[from the Allfather, via Telegram · $ME] ping" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$DOORS")" "notify --source errand" && good "Telegram is answered through the notify door" || bad "telegram" "$(cat "$DOORS")"
reset; turn h1 ok "[from agent hermes · hermes session abc123 · $ME] ping" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$DOORS")" "hermes:abc123 [reply from agent B" && good "a Hermes session is answered by its id" || bad "hermes" "$(cat "$DOORS")"
reset; turn y1 ok "[from a person at terminal /dev/pts/9999 · $ME] ping" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$DOORS")" "the terminal is gone" && good "a terminal that is gone is said so, to the arm" || bad "tty gone" "$(cat "$DOORS")"
reset
python3 - "$REPLY" "$ME" <<'PY' && good "a live terminal gets the answer on its screen" || bad "live terminal"
import json, os, pty, select, subprocess, sys
reply, me = sys.argv[1:3]
master, slave = pty.openpty()
text = f"[from a person at terminal {os.ttyname(slave)} · {me}] ping"
subprocess.run(["bash", reply, "--turn-end"], input=json.dumps({"session": "p", "answer": "terminal-answer", "messages": [{"id": "1", "text": text}]}),
               text=True, capture_output=True, env={**os.environ, "YMIR_REPLY_PANE": "w1:pB", "YMIR_REPLY_ORIGIN": f"agent B · {me}"})
got = os.read(master, 4000) if select.select([master], [], [], 5)[0] else b""
sys.exit(0 if b"terminal-answer" in got else 1)
PY

# ── a pane that cannot take it is never silent ────────────────────────────────
reset; turn b1 held "[from agent A · herdr pane w1:pA · $ME] q" | BOX_PANE=w1:pA as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ ! -s "$SENTLOG" ] && has "$(cat "$DOORS")" "undelivered answer for pane w1:pA" && good "a busy input box: nothing typed, the arm holder gets it" || bad "box held" "$(cat "$DOORS")"
reset; turn b2 fast "[from agent A · herdr pane w1:pA · $ME] q" | PANE_STATUS=idle as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ "$(wc -l <"$SENTLOG")" = 1 ] && [ ! -s "$DOORS" ] && good "a reply is never typed twice when the sender reads idle" || bad "dup" "$(cat "$SENTLOG" "$DOORS")"

# ── another machine: the fleet-tell road, over a fake ssh ─────────────────────
reset
turn f1 "from here" "[from agent Z · herdr pane w2:pZ · faraway] q" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$DOORS")" "ssh u@far.example" && [ "$(wc -l <"$SENTLOG")" = 1 ] && has "$(cat "$SENTLOG")" "w2:pZ" \
  && [ "$(last)" = "[reply from agent B · herdr pane w1:pB · $ME] from here" ] \
  && good "cross-machine: fleet-tell carries it to machine:pane, once, stamped by the replier" || bad "cross" "$(cat "$DOORS" "$SENTLOG")"

# ── Claude Code's Stop hook reads the turn from its transcript ────────────────
reset
python3 - "$T/t.jsonl" "$ME" <<'PY'
import json, sys
me = sys.argv[2]
s = lambda who, p: f"[from agent {who} · herdr pane {p} · {me}] go"
rows = [{"type": "user", "uuid": "old", "message": {"content": s("Old", "w1:pO")}},
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "old answer"}]}},
        {"type": "user", "uuid": "u1", "message": {"content": '\n<pasted_content id="x">\n' + s("A", "w1:pA")}},
        {"type": "user", "uuid": "u2", "message": {"content": [{"type": "tool_result", "content": "r"}]}},
        {"type": "attachment", "uuid": "u3", "attachment": {"type": "queued_command", "prompt": s("H", "w1:pH")}},
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "the final word"}]}}]
open(sys.argv[1], "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
printf '{"session_id":"c","transcript_path":"%s"}' "$T/t.jsonl" | as w1:pB B bash "$REPLY" --claude-stop >/dev/null 2>&1
[ "$(cut -f1 "$SENTLOG" | sort | tr '\n' ' ')" = "w1:pA w1:pH " ] && has "$(last)" "the final word" && good "the opening prompt and a queued steer are answered; an older turn is not" || bad "claude" "$(cat "$SENTLOG")"
o="$(printf '{"session_id":"c","transcript_path":"%s"}' "$T/t.jsonl" | env YMIR_ROOT="$ROOT" YMIR_REPLY_PANE=w1:pB bash "$ROOT/.claude/hooks/reply-back.sh" 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && [ -z "$o" ] && good "the hook script never blocks and writes nothing on stdout" || bad "hook" "$rc $o"

[ "$fail" = 0 ] || { echo "--- sent:"; cat -A "$SENTLOG" | head; }
# ── a refused stop sends nothing; the stop that ends the turn sends the real answer ──
reset
python3 - "$T/b.jsonl" "$ME" <<'PY'
import json, sys
rows = [{"type": "user", "uuid": "u1", "message": {"content": f"[from agent A · herdr pane w1:pA · {sys.argv[2]}] go"}},
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "unfinished words"}]}}]
open(sys.argv[1], "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
row() { printf '%s\n' "$1" >>"$T/b.jsonl"; }
stop() { printf '{"session_id":"b","transcript_path":"%s"}' "$T/b.jsonl" | env YMIR_ROOT="$ROOT" YMIR_REPLY_PANE=w1:pB YMIR_REPLY_FOREGROUND=0 YMIR_REPLY_SETTLE=20 bash "$ROOT/.claude/hooks/reply-back.sh" >/dev/null 2>&1; }
until_sent() { timeout "$1" bash -c 'until grep -q . "$SENTLOG"; do timeout 0.2 tail -f /dev/null; done'; }
# the live order (measured): the other hook's refusal is already written when this door starts
row '{"type":"attachment","attachment":{"type":"hook_blocking_error","hookEvent":"Stop"}}'
row '{"type":"user","isMeta":true,"message":{"content":"Stop hook feedback:\nwrite your report"}}'
stop
row '{"type":"system","subtype":"stop_hook_summary","preventedContinuation":false}'
until_sent 4
[ ! -s "$SENTLOG" ] && [ -z "$(ls "$XDG_STATE_HOME/ymir/replies/done" 2>/dev/null)" ] && good "blocked stop: nothing sent, nothing marked answered" || bad "blocked" "$(cat "$SENTLOG")"
row '{"type":"assistant","message":{"content":[{"type":"text","text":"the real answer"}]}}'
stop
[ ! -s "$SENTLOG" ] && good "nothing is sent before the harness gives its verdict" || bad "early" "$(cat "$SENTLOG")"
row '{"type":"system","subtype":"stop_hook_summary","preventedContinuation":false}'
until_sent 15
has "$(cat "$SENTLOG")" "the real answer" && ! has "$(cat "$SENTLOG")" "unfinished" && [ "$(wc -l <"$SENTLOG")" = 1 ] && good "the stop that ends the turn sends the real answer, once" || bad "real answer" "$(cat "$SENTLOG" "$XDG_STATE_HOME/ymir/replies/hook.log")"

# ── the arm holder is answered through its wake queue, never its input box ──
reset; turn k1 "for the helm" "[from agent H · herdr pane w1:pH · $ME] q" | HOLDER=w1:pH as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ ! -s "$SENTLOG" ] && has "$(cat "$DOORS")" "arm tell --class report" && has "$(cat "$DOORS")" "[reply from agent B" && good "an answer for the arm holder goes to its queue" || bad "holder" "$(cat "$DOORS" "$SENTLOG")"

# ── an agent's message never reaches the operator ──
reset
for who in "agent Rödd helper · herdr pane w1:pA" "agent telegram-seat · herdr pane w1:pA" "the arm holder · herdr pane w1:pA"; do
  turn "n$who" "quiet" "[from $who · $ME] q" | BOX_PANE=w1:pA as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
done
! grep -qE '^(room|notify) ' "$DOORS" && has "$(cat "$DOORS")" "arm tell" && good "agent-stamped messages: no room, no chat, no notice, even when the pane refuses" || bad "notice" "$(cat "$DOORS")"
o="$(bash "$REPLY" --parse "[from agent A · herdr pane w1:pA · $ME] q"; bash "$REPLY" --parse "$rodd")"
has "$o" '"w1:pA","no"' && has "$o" '"room","yes"' && good "the parser says whether the operator is there" || bad "presence" "$o"

# ── a wake shown to the holder is owed an answer ──
reset
printf '1\t2\tsignal\tk\tagent W · herdr pane w1:pW · %s to the arm holder: done\tclass=report\n1\t3\tsignal\tk2\tagent R · herdr pane w1:pR · %s to the arm holder: [reply from x] y\n1\t4\tsignal\tk3\tRödd (the voice) to the arm holder: hi\n' "$ME" "$ME" | as w1:pB B bash "$REPLY" --owe
printf '{"session":"s","answer":"noted","messages":[]}' | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ "$(cut -f1 "$SENTLOG")" = "w1:pW" ] && good "the holder's turn end answers the wake's sender, no reply and no voice wake" || bad "owed" "$(cat "$SENTLOG")"

# ── a turn the operator began is his: the agents heard in it get a receipt, never his conversation ──
his() {  # <opener> [synthetic 0|1] — an opener, then a steered agent line, answered in words meant for the operator
  python3 -c 'import json,sys; print(json.dumps({"session":"s","answer":"private-words","messages":[{"id":"o","text":sys.argv[1],"synthetic":sys.argv[3]=="1"},{"id":"q","text":sys.argv[2]}]}))' \
    "$1" "[from agent A · herdr pane w1:pA · $ME] q" "${2:-0}"
}
for opener in "how are we doing?" "[from the Allfather · $ME] how?" "[from a person at terminal /dev/pts/9999 · $ME] how?"; do
  reset; his "$opener" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
  has "$(cat "$SENTLOG")" "Receipt:" && ! grep -q private-words "$SENTLOG" \
    && good "his turn: the steering agent gets a receipt only: ${opener%% ·*}" || bad "his turn: $opener" "$(cat "$SENTLOG" "$DOORS")"
done
for opener in "<task-notification>done</task-notification>" $'\xe2\x81\xa3RODD_OP: v1 watcher: wake' "[reply from agent C · herdr pane w1:pC · $ME] ok"; do
  reset; his "$opener" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
  has "$(cat "$SENTLOG")" "private-words" && good "a harness or agent line is not the operator: the sender gets the answer" || bad "injected: $opener" "$(cat "$SENTLOG")"
done
reset; his "a synthetic note" 1 | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$SENTLOG")" "private-words" && good "a synthetic entry is not the operator" || bad "synthetic" "$(cat "$SENTLOG")"
reset
printf '1\t2\tsignal\tk\tagent W · herdr pane w1:pW · %s to the arm holder: done\tclass=report\n' "$ME" | as w1:pB B bash "$REPLY" --owe
turn o1 private-words "what is open?" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ "$(cut -f1 "$SENTLOG")" = w1:pW ] && has "$(cat "$SENTLOG")" "Receipt:" && ! has "$(cat "$SENTLOG")" private-words \
  && good "a wake drained in his turn gets a receipt, not his conversation" || bad "wake receipt" "$(cat "$SENTLOG")"
reset
python3 - "$T/h.jsonl" "$ME" <<'PY'
import json, sys
rows = [{"type": "user", "uuid": "n", "origin": {"kind": "task-notification"}, "message": {"content": "wake text"}},
        {"type": "attachment", "uuid": "q", "attachment": {"type": "queued_command", "origin": {"kind": "human"}, "prompt": f"[from agent A · herdr pane w1:pA · {sys.argv[2]}] q"}},
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "for the agent"}]}}]
open(sys.argv[1], "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
printf '{"session_id":"h","transcript_path":"%s"}' "$T/h.jsonl" | as w1:pB B bash "$REPLY" --claude-stop >/dev/null 2>&1
has "$(cat "$SENTLOG")" "for the agent" && good "Claude's own injected entry is not the operator" || bad "claude injected" "$(cat "$SENTLOG")"

# ── the engine's own prompt.md as a worker's first turn: a steer queued into it gets the answer ──
engine_prompt() {  # <brief> — what the engine writes to prompt.md for it, through the real stamp door
  PYTHONPATH="$ROOT/src" python3 - "$T/engine" "$1" <<'PY'
import sys
from pathlib import Path
from types import SimpleNamespace
from ymir_runtime import proc
from ymir_runtime.seat import Errand, _prompt_for
tmp = Path(sys.argv[1])
roots = SimpleNamespace(root=tmp / "no-doors", data=tmp / "data")
errand = Errand(task_id="e", project_dir=str(tmp))
print(_prompt_for(roots, errand, "e", sys.argv[2], runner=proc.run)[1])
PY
}
for brief in "# Task" "[from agent A · herdr pane w1:pA · $ME] # Task"; do
  reset; prompt="$(engine_prompt "$brief")"
  python3 -c 'import json,sys; print(json.dumps({"session":"s","answer":"steered-answer","messages":[{"id":"o","text":sys.argv[1]},{"id":"q","text":sys.argv[2]}]}))' \
    "$prompt" "[from agent H · herdr pane w1:pH · $ME] steer" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
  [[ "$prompt" == "[from "* ]] && has "$(cat "$SENTLOG")" steered-answer && ! has "$(cat "$SENTLOG")" "Receipt:" \
    && good "engine brief turn plus a queued steer: the answer, not a receipt (${brief%% *})" || bad "engine brief: $brief" "$(head -1 <<<"$prompt"; cat "$SENTLOG" "$DOORS")"
done

# ── answered by hand with eindri-send: the hook stays quiet ──
export FAKE_PANE=w1:pB FAKE_PANE_PID=$$ HERDR_PANE_ID=w1:pB
q="[from agent A · herdr pane w1:pA · $ME] status?"
late() { python3 -c 'import json,sys; print(json.dumps({"session":"s","answer":"hook-copy","messages":[{"id":sys.argv[1],"text":sys.argv[2],"since":1}]}))' "$1" "$q"; }
reset; bash "$SEND" w1:pA "by hand" >/dev/null 2>&1
late e1 | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
[ "$(wc -l <"$SENTLOG")" = 1 ] && ! has "$(cat "$SENTLOG")" hook-copy && good "an eindri-send answer by hand: no second copy" || bad "hand sent" "$(cat "$SENTLOG")"
late e2 | as w1:pC C bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$SENTLOG")" hook-copy && good "another agent's hand-sent line does not silence mine" || bad "per replier" "$(cat "$SENTLOG")"
reset; YMIR_MSG_FROM="script cron · $ME" bash "$SEND" w1:pA "tick" >/dev/null 2>&1
late e3 | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$SENTLOG")" hook-copy && good "a script's line from the same pane is no answer" || bad "script send" "$(cat "$SENTLOG")"
reset; BOX_PANE=w1:pA bash "$SEND" w1:pA "refused" >/dev/null 2>&1
late e4 | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$SENTLOG")" hook-copy && good "a refused hand send is no answer" || bad "refused send" "$(cat "$SENTLOG")"
unset FAKE_PANE FAKE_PANE_PID HERDR_PANE_ID

# ── the REAL doors, driven from a pane: each stamps that pane, and the answer comes back to it ──
export FAKE_PANE=w1:pA FAKE_PANE_PID=$$ HERDR_PANE_ID=w1:pA YMIR_STATE_DIR="$T/state"; mkdir -p "$YMIR_STATE_DIR"
back() {  # <door label> — what the door typed into w1:pB comes back from B's turn into w1:pA
  local q; q="$(grep '^w1:pB' "$SENTLOG" | tail -1 | cut -f2)"; : >"$SENTLOG"
  turn "d-$1" "back-$1" "$q" | as w1:pB B bash "$REPLY" --turn-end >/dev/null 2>&1
  has "$(cat "$SENTLOG")" "back-$1" && [ "$(cut -f1 "$SENTLOG")" = w1:pA ] && good "real door $1: the answer returns to the sender's pane" || bad "door $1" "q=$q sent=$(cat "$SENTLOG")"
}
reset; bash "$SEND" w1:pB "x" >/dev/null 2>&1; back eindri-send
reset; bash "$ROOT/bin/agents/tell.sh" w1:pB "x" >/dev/null 2>&1; back tell
reset; FLEET_TELL_ME="$ME" bash "$ROOT/bin/fleet/fleet-tell.sh" --pane-only --to w1:pB "x" >/dev/null 2>&1; back fleet-tell
reset; VEIL_STATE="$T/veil" bash "$ROOT/bin/agents/veil.sh" steer --to w1:pB "x" >/dev/null 2>&1; back veil-steer
reset; bash "$ROOT/bin/forge/smith-seat.sh" ask w1:pB "x" >/dev/null 2>&1; back smith-seat
reset; PYTHONPATH="$ROOT/bin/seat/backends" python3 -c 'import herdr,sys; print("w1:pB\t"+herdr.stamped("x"))' >>"$SENTLOG"; back backend-prompt
# the wake queue: rodd-arm and arm-send, then the holder drains in its own pane
reset; rm -f "$YMIR_STATE_DIR/.wake-queue" "$YMIR_STATE_DIR/.wake-drained"
export RODD_ARM_LEASE="$YMIR_STATE_DIR/.arm.lease"
printf 'pid=%s starttime=%s gen=1 mode=test session=none heartbeat=%s state=%s\n' "$$" "$(sed 's/.*) //' /proc/$$/stat | awk '{print $20}')" "$(date +%s)" "$YMIR_STATE_DIR" >"$RODD_ARM_LEASE"
bash "$ROOT/bin/voice/rodd-arm.sh" tell --from "agent W" "report one" >/dev/null 2>&1
bash "$ROOT/bin/fleet/arm-send.sh" "$ME" "report two" >/dev/null 2>&1
[ "$(grep -c 'herdr pane w1:pA' "$YMIR_STATE_DIR/.wake-queue" 2>/dev/null)" = 2 ] && good "real doors rodd-arm tell and arm-send record the sender's pane" || bad "wake pane" "$(cat "$YMIR_STATE_DIR/.wake-queue")"
printf 'w1:pH\n' >"$YMIR_STATE_DIR/.arm.pane"
FAKE_PANE=w1:pH HERDR_PANE_ID=w1:pH BROKK_STATE_OVERRIDE="$YMIR_STATE_DIR" YMIR_ACK_ANY=1 bash "$ROOT/bin/time/saga-wake-drain.sh" drain >/dev/null 2>&1
: >"$SENTLOG"; printf '{"session":"h","answer":"holder-answer","messages":[]}' | as w1:pH H bash "$REPLY" --turn-end >/dev/null 2>&1
has "$(cat "$SENTLOG")" "holder-answer" && [ "$(cut -f1 "$SENTLOG")" = w1:pA ] && good "the real drain: the holder's turn end answers the wake's sender, once per sender" || bad "drain" "$(cat "$SENTLOG"; ls -R "$XDG_STATE_HOME/ymir/replies")"
unset FAKE_PANE FAKE_PANE_PID HERDR_PANE_ID

printf '\ntest_reply: %s ok, %s failed\n' "$ok" "$fail"; [ "$fail" = 0 ]
