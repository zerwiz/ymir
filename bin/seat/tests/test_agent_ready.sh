#!/usr/bin/env bash
# test_agent_ready.sh — the ready-check answers in ONE vocabulary, for both backends.
#
# Why this test exists: a relay that wakes an agent must know whether the agent can
# take a turn. The two backends answer in two vocabularies, and a pane standing on a
# dialog swallows whatever is typed into it. So every case below is a stub answer —
# this test says exactly what the reader does with each, and the real machine is
# never touched. `HOME`, `HERMES_HOME` and `PATH` are all under the temporary dir.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../agent-ready.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_agent_ready"
[ -x "$door" ] || { bad "the door is missing or not executable: $door"; exit 1; }

# ── a stub herdr: `agent get <pane>` and `agent explain <pane>` answer from files ──
mkdir -p "$tmp/bin" "$tmp/stub" "$tmp/home" "$tmp/hermes"
export STUB_DIR="$tmp/stub"
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
# agent get <pane>   → $STUB_DIR/<pane>.get   (exit 1 for a missing agent, like herdr)
# agent explain <p>  → $STUB_DIR/<pane>.explain
[ "${1:-}" = "agent" ] || exit 0
case "${2:-}" in
  get)
    f="$STUB_DIR/${3:-x}.get"
    [ -r "$f" ] || { printf '{"error":{"code":"agent_not_found","message":"no agent"}}\n'; exit 1; }
    cat "$f" ;;
  explain)
    f="$STUB_DIR/${3:-x}.explain"
    [ -r "$f" ] && cat "$f"
    exit 0 ;;
  list)
    cat "$STUB_DIR/list.json" 2>/dev/null || printf '{"result":{"agents":[]}}\n' ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmp/bin/herdr"

# ── a stub hermes: `sessions list` prints the table; the store is a real sqlite file ──
cat >"$tmp/bin/hermes" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "sessions" ] && [ "${2:-}" = "list" ] || exit 0
printf 'Title                        Workspace          Last Active   ID\n'
printf '──────────────────────────────────────────────────────────────────\n'
printf 'Audit Receipt Hunter spec    Inmost-ControlTo   just now      local-fd2ee4d0939d080e51b8c178ea9d6229d805a1fe966f0df808f4293cf6a722ac\n'
printf 'Audit vaults tech stack      heimdall           just now      local-9e11172e0e979d40aca0c1ab41c408a6dd5a30240b845186d21e7b0b2ccfbe62\n'
printf 'Ok                           ymir               21h ago       local-59087a9fe825d3c31cd9c3c49d1f2f79592ce98560e695cf064610ff7de1de71\n'
SH
chmod +x "$tmp/bin/hermes"
export PATH="$tmp/bin:$PATH"

# the Hermes store: three sessions, one paused by an unknown admission, one working,
# one settled. This is the runtime's OWN table shape (v0.22.6).
export HERMES_HOME="$tmp/hermes"
python3 - "$HERMES_HOME/state.db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.executescript("""
CREATE TABLE sessions (id TEXT PRIMARY KEY, ended_at REAL);
CREATE TABLE session_admissions (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  target_session_id TEXT NOT NULL,
  status TEXT NOT NULL);
""")
ids = {
 "fd": "local-fd2ee4d0939d080e51b8c178ea9d6229d805a1fe966f0df808f4293cf6a722ac",
 "9e": "local-9e11172e0e979d40aca0c1ab41c408a6dd5a30240b845186d21e7b0b2ccfbe62",
 "59": "local-59087a9fe825d3c31cd9c3c49d1f2f79592ce98560e695cf064610ff7de1de71",
}
for i in ids.values():
    con.execute("INSERT INTO sessions VALUES (?,NULL)", (i,))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (ids["fd"], "unknown"))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (ids["9e"], "terminal"))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (ids["9e"], "started"))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (ids["59"], "terminal"))
con.commit()
PY

row() { printf '{"result":{"agent":{"agent":"%s","agent_status":"%s"%s}}}\n' "$1" "$2" "$3" >"$STUB_DIR/p.get"; }
explain() { printf 'agent: claude\nstate: blocked\nrule: %s\nevidence: "%s"\n' "$1" "$2" >"$STUB_DIR/p.explain"; }
answer() { "$door" "$@" 2>/dev/null; }

# 1 · an idle agent at its prompt is ready
row claude idle ',"interactive_ready":true'
[ "$(answer p)" = ready ] && ok "idle at a prompt → ready" || bad "idle at a prompt answered $(answer p)"

# 2 · a working agent is working, not dead and not ready
row pi working ''
[ "$(answer p)" = working ] && ok "working → working" || bad "working answered $(answer p)"
"$door" p >/dev/null 2>&1; [ $? = 1 ] && ok "working exits 1" || bad "working exited $?"

# 3 · the folder-trust prompt is named, not hidden behind a retry
row claude blocked ',"launch_pending":true'
explain live_blocked_form ' Accessing workspace:\n\n Quick safety check: Is this a project you created or one you trust?'
[ "$(answer p)" = "blocked: trust prompt" ] && ok "trust prompt → blocked: trust prompt" \
  || bad "trust prompt answered $(answer p)"
"$door" p >/dev/null 2>&1; [ $? = 2 ] && ok "blocked exits 2" || bad "blocked exited $?"

# 4 · any other dialog is named by herdr's own rule, so a person still knows what to act on
explain live_permission_form ' Allow this command?'
case "$(answer p)" in "blocked: prompt (permission)") ok "a permission dialog is named by its rule" ;;
  *) bad "permission dialog answered $(answer p)" ;; esac

# 5 · a pane holding no agent is dead — never "ready" and never "blocked"
rm -f "$STUB_DIR/p.get"
[ "$(answer p)" = dead ] && ok "no agent → dead" || bad "no agent answered $(answer p)"
"$door" p >/dev/null 2>&1; [ $? = 3 ] && ok "dead exits 3" || bad "dead exited $?"

# 6 · an idle agent whose prompt box is NOT drawn is blocked, not ready (plan 291 row 5)
row claude idle ',"interactive_ready":false'
[ "$(answer p)" = "blocked: not at an input prompt" ] && ok "idle without a prompt box → blocked" \
  || bad "idle/unready answered $(answer p)"

# 7 · a Hermes session paused by an unknown admission says what to do about it
[ "$(answer hermes:fd2ee4d0)" = "blocked: lost turn, run recover" ] \
  && ok "a paused Hermes session → blocked: lost turn, run recover" \
  || bad "a paused Hermes session answered $(answer hermes:fd2ee4d0)"

# 8 · a Hermes session with a turn in flight is working
[ "$(answer hermes:9e11172e)" = working ] && ok "a Hermes turn in flight → working" \
  || bad "a Hermes turn in flight answered $(answer hermes:9e11172e)"

# 9 · a settled session is ready: `chat --resume` still takes a turn
[ "$(answer hermes:59)" = ready ] && ok "a settled Hermes session → ready" \
  || bad "a settled Hermes session answered $(answer hermes:59)"

# 10 · the title resolves too, and a missing session is dead by name
case "$(answer "hermes:Audit vaults")" in working) ok "a title resolves to its session" ;;
  *) bad "a title answered $(answer "hermes:Audit vaults")" ;; esac
case "$(answer "hermes:Audit")" in
  "blocked: ambiguous:"*) ok "an ambiguous title is a block that names the candidates" ;;
  *) bad "an ambiguous title answered $(answer "hermes:Audit")" ;; esac

# 11 · a bare target is herdr, so nothing that works today changes shape
row claude idle ',"interactive_ready":true'
[ "$(answer herdr:p)" = ready ] && ok "herdr:<pane> and a bare pane agree" || bad "herdr: prefix answered $(answer herdr:p)"

# 12 · several targets answer with the worst one — the one a person must act on
printf '{"result":{"agents":[{"pane_id":"p","agent":"claude","agent_status":"idle","interactive_ready":true}]}}\n' >"$STUB_DIR/list.json"
out="$("$door" p hermes:fd2ee4d0 2>/dev/null)"; rc=$?
printf '%s\n' "$out" | grep -q "^p	ready$" && printf '%s\n' "$out" | grep -q "^hermes:fd2ee4d0	blocked: lost turn, run recover$" \
  && [ "$rc" = 2 ] && ok "two targets, one blocked, exit 2" || bad "two targets answered [$out] rc=$rc"

# 13 · --all names both backends
out="$("$door" --all 2>/dev/null)"
printf '%s' "$out" | grep -q '^herdr:p' && printf '%s' "$out" | grep -q '^hermes:local-' \
  && ok "--all lists a herdr pane and a Hermes session" || bad "--all answered [$out]"

# 14 · --json is a list of rows a caller can read
"$door" hermes:fd2ee4d0 --json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d[0]["backend"]=="hermes" and d[0]["state"]==2 and d[0]["word"]=="blocked: lost turn, run recover", d
' && ok "--json carries backend, state and the word" || bad "--json is not the documented shape"

# 15 · no arguments is a usage error, not a silent "ready"
"$door" >/dev/null 2>&1; [ $? = 64 ] && ok "no target exits 64" || bad "no target exited $?"

printf '\ntest_agent_ready: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
