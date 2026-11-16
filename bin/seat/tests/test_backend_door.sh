#!/usr/bin/env bash
# test_backend_door.sh — six verbs, one resolver, and a recovery that shows before it discards.
#
# Why this test exists: Hermes is a second backend behind the herdr verbs (plan 303 §14), so a
# caller must not learn a new tool to reach a session — and a paused session must be REFUSED,
# never replayed, with its lost input printed before anything is discarded. Everything here is
# stubbed: `herdr` on PATH, `hermes` through HERMES_BIN, and the store through
# AGENT_READY_HERMES_DB pointed at a fixture of the runtime's own table.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../backend.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_backend_door"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

mkdir -p "$tmp/bin" "$tmp/stub"
export HOME="$tmp/home"; mkdir -p "$HOME"

# herdr: one idle agent in a pane, and one blocked pane
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = agent ] || exit 0
case "${2:-}" in
  list) printf '{"result":{"agents":[{"agent":"claude","agent_status":"idle","interactive_ready":true,"pane_id":"w1:p1","name":"a-claude"}]}}\n' ;;
  get)
    case "${3:-}" in
      w1:p1) printf '{"result":{"agent":{"agent":"claude","agent_status":"idle","interactive_ready":true}}}\n' ;;
      w1:p2) printf '{"result":{"agent":{"agent":"claude","agent_status":"blocked"}}}\n' ;;
      *) printf '{"error":{"code":"agent_not_found"}}\n'; exit 1 ;;
    esac ;;
  explain) printf 'agent: claude\nstate: blocked\nrule: live_permission_form\nevidence: " allow this?"\n' ;;
  prompt) printf 'prompt\t%s\n' "${3:-}" >>"$STUB_DIR/wakes"; printf '{"result":{"type":"agent_prompted"}}\n' ;;
  read) printf 'a pane tail\n' ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmp/bin/herdr"
export HDR_BIN="$tmp/bin/herdr"
export PATH="$tmp/bin:$PATH"
export STUB_DIR="$tmp/stub"

# hermes: the table, plus chat/discard we can see in the log
cat >"$tmp/bin/hermes" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  sessions)
    case "${2:-}" in
      list)
        printf 'Title                        Workspace          Last Active   ID\n'
        printf '──────────────────────────────────────────────────────────────────\n'
        printf 'A paused session             example-org        just now      local-aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66\n'
        printf 'A live session               example-org        just now      local-11ff22ee33dd44cc55bb66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66ee\n'
        ;;
      export) printf '{"message":{"role":"user","content":"the turn that was lost"}}\n' ;;
      discard) printf 'discard %s\n' "${3:-}" >>"$STUB_DIR/wakes" ;;
    esac ;;
  chat) printf 'chat %s\n' "$*" >>"$STUB_DIR/wakes" ;;
esac
exit 0
SH
chmod +x "$tmp/bin/hermes"
export HERMES_BIN="$tmp/bin/hermes"

# the runtime's own table: one session paused by an unknown admission, one live
export AGENT_READY_HERMES_DB="$tmp/state.db"
python3 - "$AGENT_READY_HERMES_DB" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.executescript("""
CREATE TABLE sessions (id TEXT PRIMARY KEY, ended_at REAL);
CREATE TABLE session_admissions (seq INTEGER PRIMARY KEY AUTOINCREMENT,
  target_session_id TEXT NOT NULL, status TEXT NOT NULL);
""")
paused = "local-aa11bb22cc33dd44ee55ff66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66"
live = "local-11ff22ee33dd44cc55bb66aa77bb88cc99dd00ee11ff22aa33bb44cc55dd66ee"
for s in (paused, live):
    con.execute("INSERT INTO sessions VALUES (?,NULL)", (s,))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (paused, "unknown"))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (live, "terminal"))
con.commit()
PY

# 1 · the six verbs answer for a herdr pane, and a bare target IS herdr
out="$("$door" get w1:p1 2>&1)"; [ "$out" = ready ] && ok "a bare target is herdr and is ready" || bad "bare target: $out"
out="$("$door" get herdr:w1:p1 2>&1)"; [ "$out" = ready ] && ok "herdr:<pane> is the same target" || bad "herdr target: $out"
out="$("$door" get herdr:w1:p2 2>&1)"; [ "$out" = "blocked: prompt (permission)" ] && ok "a blocked pane names its dialog" || bad "blocked: $out"
out="$("$door" get herdr:w9:p9 2>&1)"; [ "$out" = dead ] && ok "a pane with no agent is dead" || bad "dead: $out"

# 2 · the resolver turns a session prefix into the real id, and the state comes from the table
out="$("$door" get hermes:aa11bb22 2>&1)"
[ "$out" = "blocked: lost turn, run recover" ] && ok "a paused session is blocked with the recovery named" || bad "paused: $out"
out="$("$door" get hermes:11ff22ee 2>&1)"
[ "$out" = ready ] && ok "a settled session is ready" || bad "settled: $out"
out="$("$door" get "hermes:A live" 2>&1)"
[ "$out" = ready ] && ok "a title resolves to its session" || bad "title: $out"

# 3 · a paused session is REFUSED by prompt, and the chat road is never taken
: >"$tmp/stub/wakes"
"$door" prompt hermes:aa11bb22 "hello" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "a paused session refuses a prompt (exit 2)" || bad "paused prompt exited $rc"
grep -q "^chat" "$tmp/stub/wakes" && bad "a paused session was sent a turn" || ok "a paused session is never replayed"

# 4 · a ready session takes the turn through its own road
"$door" prompt hermes:11ff22ee "hello there" >/dev/null 2>&1
grep -q "^chat .*--resume" "$tmp/stub/wakes" && grep -q "hello there" "$tmp/stub/wakes" \
  && ok "a ready session takes the turn by chat --resume" || bad "no chat: $(cat "$tmp/stub/wakes")"

# 5 · recover SHOWS the lost input and discards nothing until it is told to
: >"$tmp/stub/wakes"
out="$("$door" recover hermes:aa11bb22 2>&1)"
printf '%s' "$out" | grep -q "the turn that was lost" && ok "recover prints the lost input first" || bad "recover: $out"
grep -q "^discard" "$tmp/stub/wakes" && bad "recover discarded without being told to" || ok "recover discards nothing without --yes"
printf '%s' "$out" | grep -q -- "--yes" && ok "recover says how to acknowledge the lost turn" || bad "no acknowledgement line: $out"

# 6 · and with --yes it discards, once the input has been shown
out="$("$door" recover hermes:aa11bb22 --yes 2>&1)"
grep -q "^discard" "$tmp/stub/wakes" && ok "recover --yes discards the lost turn" || bad "no discard: $(cat "$tmp/stub/wakes")"
printf '%s' "$out" | grep -q "the turn that was lost" && ok "the input is shown even when discarding" || bad "discard hid the input"

# 7 · list names both backends, in one vocabulary
out="$("$door" list 2>&1)"
printf '%s' "$out" | grep -q '"herdr:w1:p1"\|w1:p1' && ok "list carries a herdr pane" || bad "list: $out"
printf '%s' "$out" | grep -q 'herems\|hermes' && ok "list carries a Hermes session" || bad "list has no hermes row: $out"

# 8 · explain gives the reason AND the exact recovery
out="$("$door" explain hermes:aa11bb22 2>&1)"
printf '%s' "$out" | grep -q "hermes sessions discard" && ok "explain names the exact recovery command" || bad "explain: $out"

# 9 · an unknown verb is a usage error, not a silent success
"$door" frobnicate >/dev/null 2>&1; [ $? = 64 ] && ok "an unknown verb exits 64" || bad "unknown verb exited $?"

printf '\ntest_backend_door: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
