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
  *) exit 1 ;;
esac
S
cat >"$T/bin/ssh" <<'S'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in *@*) printf 'ssh %s\n' "$a" >>"$DOORS" ;; esac; done
eval "${@: -1}"
S
for d in room arm notify tell; do
  printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >>"$DOORS"\nexit "${%s_RC:-0}"\n' "$d" "${d^^}" >"$T/doors/$d"
done
chmod +x "$T/bin"/* "$T/doors"/*; export PATH="$T/bin:$PATH"
export YMIR_REPLY_ROOM="$T/doors/room" YMIR_REPLY_ARM="$T/doors/arm" YMIR_REPLY_NOTIFY="$T/doors/notify" YMIR_REPLY_TELL="$T/doors/tell"
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
printf '\ntest_reply: %s ok, %s failed\n' "$ok" "$fail"; [ "$fail" = 0 ]
