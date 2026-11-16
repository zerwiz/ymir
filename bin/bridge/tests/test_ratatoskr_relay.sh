#!/usr/bin/env bash
# test_ratatoskr_relay.sh — the wake, the confirm, the one retry, the miss, and the return.
#
# Why this test exists: a task on a shelf is not a conversation. The relay is the piece
# that makes an agent answer without polling — and the piece that can fail silently, by
# typing into a dialog or into a pane that never moves. Every case below is a stub
# `herdr`, so this test says exactly what the relay does with each answer, and a real pane
# is never typed into.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../ratatoskr-relay.sh"
qdoor="$here/../ratatoskr.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_ratatoskr_relay"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

mkdir -p "$tmp/bin" "$tmp/stub" "$tmp/home"
export HOME="$tmp/home"
export STUB_DIR="$tmp/stub"
export RATATOSKR_QUEUE="$tmp/queue"
export YMIR_MACHINE="host-a"
# the sender is a pane, not this worker's own session: the return must go where the asker sits
export HERDR_PANE_ID="w1:p1"

# ── a stub herdr: `agent get` reads the pane's state file; a prompt flips it when told to ──
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
d="$STUB_DIR"
case "${1:-}" in
  agent)
    case "${2:-}" in
      --help)
        # the 0.9.1 shape has `agent prompt`; the 0.7.4 shape does not
        printf 'herdr agent commands:\n  herdr agent list\n'
        [ -r "$d/has-prompt" ] && printf '  herdr agent prompt <target> <text>\n'
        exit 0 ;;
      get)
        f="$d/state-${3:-x}"
        [ -r "$f" ] || { printf '{"error":{"code":"agent_not_found"}}\n'; exit 1; }
        st="$(cat "$f")"
        extra=""
        [ "$st" = idle ] && extra=',"interactive_ready":true'
        printf '{"result":{"agent":{"agent":"pi","agent_status":"%s"%s}}}\n' "$st" "$extra" ;;
      explain)
        printf 'agent: pi\nstate: blocked\nrule: live_permission_form\nevidence: "a dialog"\n' ;;
      prompt)
        printf 'prompt\t%s\t%s\n' "${3:-}" "${4:-}" >>"$d/wakes.log"
        [ -r "$d/move-${3:-x}" ] && printf 'working\n' >"$d/state-${3:-x}"
        printf '{"id":"cli:agent:prompt","result":{"type":"agent_prompted"}}\n' ;;
      send)
        printf 'send\t%s\t%s\n' "${3:-}" "${4:-}" >>"$d/wakes.log"
        printf '{"id":"cli:agent:send","result":{"type":"ok"}}\n' ;;
      list) printf '{"result":{"agents":[]}}\n' ;;
      *) exit 0 ;;
    esac ;;
  pane)
    [ "${2:-}" = send-keys ] && printf 'keys\t%s\t%s\n' "${3:-}" "${4:-}" >>"$d/wakes.log"
    exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmp/bin/herdr"
export HDR_BIN="$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH"
touch "$tmp/stub/has-prompt"

q() { "$qdoor" "$@" 2>&1; }
send() { q send "$@" | tail -1; }

# ── 1 · a ready target is woken, and the wake names the task and the queue ──
printf 'idle\n' >"$tmp/stub/state-w1:p1"
id1="$(send herdr:w1:p1 "answer with 1")"
out="$("$door" --once --confirm 0 2>&1)"; rc=$?
grep -q "^prompt	w1:p1" "$tmp/stub/wakes.log" && ok "a ready pane is woken" || bad "no prompt: $(cat "$tmp/stub/wakes.log" 2>/dev/null)"
grep -q "$id1" "$tmp/stub/wakes.log" && ok "the wake names the task id" || bad "the wake does not name the task"
grep -q "$RATATOSKR_QUEUE" "$tmp/stub/wakes.log" && ok "the wake names the queue, so the agent needs no environment" || bad "the wake omits the queue"
[ "$rc" = 0 ] && ok "a clean pass exits 0" || bad "a clean pass exited $rc"

# ── 2 · a pane that never moves is woken ONCE more, then recorded as a miss by name ──
"$door" --once --confirm 0 >/dev/null 2>&1
n="$(grep -c "^prompt	w1:p1" "$tmp/stub/wakes.log")"
[ "$n" = 2 ] && ok "a wake that did not move the agent is retried exactly once" || bad "the pane was woken $n times"
out="$("$door" --once --confirm 0 2>&1)"; rc=$?
grep -q "did not move" "$tmp/stub/../stub/../queue/relay/misses.log" 2>/dev/null \
  && ok "the miss is written to the relay's own log" || bad "no miss recorded: $out"
grep -q "miss: $id1" <<<"$out" && ok "the miss names the task and the pane" || bad "miss line: $out"

# ── 3 · a blocked pane is never typed into, and says why it was not ──
printf 'blocked\n' >"$tmp/stub/state-w1:p2"
id2="$(send herdr:w1:p2 "answer with 2")"
out="$("$door" --once --confirm 0 2>&1)"
grep -q "^prompt	w1:p2" "$tmp/stub/wakes.log" && bad "a blocked pane was typed into" || ok "a blocked pane is never typed into"
grep -q "miss: $id2 w1:p2 blocked: prompt (permission)" <<<"$out" && ok "the miss names the reason a person acts on" || bad "blocked miss: $out"

# ── 4 · a pane holding no agent is a miss, never a wake into a shell ──
id3="$(send herdr:w9:p9 "answer with 3")"
out="$("$door" --once --confirm 0 2>&1)"
grep -q "^prompt	w9:p9" "$tmp/stub/wakes.log" && bad "a dead pane was typed into" || ok "a dead pane is never typed into"
grep -q "miss: $id3" <<<"$out" && ok "a dead pane is a miss" || bad "dead miss: $out"

# ── 5 · a task addressed to another machine is not this relay's ──
id4="$(send other-machine/w7:p1 "answer with 4")"
before="$(wc -l <"$tmp/stub/wakes.log" 2>/dev/null || echo 0)"
"$door" --once --confirm 0 >/dev/null 2>&1
after="$(wc -l <"$tmp/stub/wakes.log" 2>/dev/null || echo 0)"
[ "$before" = "$after" ] && ok "another machine's task is left for its own relay" || bad "a foreign task was woken"

# ── 6 · the answer goes back to the ASKER's pane, under the header, exactly once ──
printf 'idle\n' >"$tmp/stub/state-w1:p3"
printf 'idle\n' >"$tmp/stub/state-w1:p1"
id5="$(q send herdr:w1:p1 "the question" | tail -1)"
printf 'idle\n' >"$tmp/stub/state-w1:p3"
q claim "$id5" --by w1:p3 >/dev/null
q reply "$id5" "the answer" >/dev/null
: >"$tmp/stub/wakes.log"
"$door" --once --confirm 0 >/dev/null 2>&1
grep -q "^prompt	w1:p1	\[ratatoskr · from w1:p3 · re $id5\] the answer" "$tmp/stub/wakes.log" \
  && ok "the answer returns to the asker under the header" || bad "return: $(cat "$tmp/stub/wakes.log")"
"$door" --once --confirm 0 >/dev/null 2>&1
n="$(grep -c "re $id5" "$tmp/stub/wakes.log")"
[ "$n" = 1 ] && ok "the answer is returned exactly once" || bad "the answer was returned $n times"

# ── 7 · the 0.7.4 road: no `agent prompt`, so `agent send` + Enter carries the wake ──
rm -f "$tmp/stub/has-prompt"
printf 'idle\n' >"$tmp/stub/state-w2:p1"
id6="$(send herdr:w2:p1 "a task for an older herdr")"
: >"$tmp/stub/wakes.log"
"$door" --once --confirm 0 >/dev/null 2>&1
grep -q "^send	w2:p1" "$tmp/stub/wakes.log" && grep -q "^keys	w2:p1	Enter" "$tmp/stub/wakes.log" \
  && ok "where prompt does not exist, send + Enter carries the wake" || bad "older road: $(cat "$tmp/stub/wakes.log")"
grep -q "$id6" "$tmp/stub/wakes.log" && ok "the older road still names the task" || bad "the older road lost the task"
touch "$tmp/stub/has-prompt"

# ── 8 · the exit code says whether anything was missed ──
printf 'blocked\n' >"$tmp/stub/state-w8:p1"
send herdr:w8:p1 "a task nobody can take" >/dev/null
"$door" --once --confirm 0 >/dev/null 2>&1; [ $? = 1 ] && ok "a pass with a miss exits 1" || bad "a missy pass exited $?"

# ── 9 · status is the record, and it names the misses ──
out="$("$door" status 2>&1)"
printf '%s\n' "$out" | grep -q '^relay\[4\]' && ok "status counts what the relay did" || bad "status: $out"
printf '%s\n' "$out" | grep -q 'miss:' && ok "status prints the last misses" || bad "status hides the misses"

printf '\ntest_ratatoskr_relay: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
