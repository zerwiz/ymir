#!/usr/bin/env bash
# test_sessions_index.sh — plan 368: every tool's sessions into one seat index. Fixtures only: a throwaway HOME with a
# transcript for each of Claude, pi, Codex, Hermes and opencode, a throwaway registry and vault, a fake judge model, a
# fake OTLP collector, a fake ssh. No heart, no fleet.json for the main run: this machine is complete alone.
#   bash tests/test_sessions_index.sh
set -u
ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"; X="$ROOT/bin/records/sessions.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/ymir-sessions.XXXXXX")"
trap 'kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null; rm -rf "$T"' EXIT
export HOME="$T/home" YMIR_HOME="$T/ymirhome" YMIR_SEAT=seat-a YMIR_STATE_DIR="$T/state" YMIR_VAULT_MNT="$T/vault"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
mkdir -p "$HOME" "$YMIR_HOME/hodd/identity" "$T/vault/work"
pass=0; fail=0
ok() { if [ "$2" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }
J() { python3 -c "import json,sys;d=json.load(sys.stdin);$1" 2>/dev/null; }

git init -q -b main "$T/alpha"; git -C "$T/alpha" commit -q --allow-empty -m i
git init -q -b main "$T/beta";  git -C "$T/beta" commit -q --allow-empty -m i
cat >"$YMIR_HOME/hodd/identity/projects.yaml" <<E
projects:
- id: alpha
  name: Alpha
  repo: $T/alpha
  handling: {visibility: {value: public}}
- id: beta
  name: Beta
  repo: $T/beta
  handling: {visibility: {value: private}}
E

python3 - "$T" <<'PY'
import json, os, sqlite3, sys
T = sys.argv[1]; H = T + "/home"
def jl(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write("".join(json.dumps(r) + "\n" for r in rows))
SECRET = "sk" + "-" + "abcdefghijklmnopqrstuvwxyz123456"   # built at run time: a fixture is judged like any file
ERR = "tool x is already registered by /home/u/a/ext.ts and /home/u/b/ext.ts (call 42): two copies of one extension both load, so the harness refuses the second"
# Claude: a token and the vault path in an error, an e-mail in a prompt
jl(H + "/.claude/projects/-a/c1.jsonl", [
    {"type": "user", "timestamp": "2026-01-01T00:00:00Z", "cwd": T + "/alpha", "gitBranch": "main", "message": {"content": "mail ada@example.org about it"}},
    {"type": "assistant", "timestamp": "2026-01-01T00:00:01Z", "cwd": T + "/alpha", "message": {"model": "m1", "usage": {"input_tokens": 10, "output_tokens": 5},
        "content": [{"type": "tool_use", "id": "t1", "name": "Bash"}, {"type": "tool_use", "id": "t2", "name": "Read"}]}},
    {"type": "user", "timestamp": "2026-01-01T00:00:02Z", "message": {"content": [{"type": "tool_result", "tool_use_id": "t1", "is_error": True,
        "content": ERR + " token " + SECRET + " in " + T + "/vault/work/n.md"}]}},
    {"type": "user", "timestamp": "2026-01-01T00:00:03Z", "message": {"content": [{"type": "tool_result", "tool_use_id": "t2", "content": "ok"}]}}])
# Claude, confidential: a session whose cwd is inside the vault
jl(H + "/.claude/projects/-v/cv.jsonl", [
    {"type": "assistant", "timestamp": "2026-01-01T00:00:00Z", "cwd": T + "/vault/work", "message": {"model": "m1", "usage": {"input_tokens": 7, "output_tokens": 3}, "content": []}}])
# pi: the same failure as Claude's, in a beta session and three alpha sessions (so it recurs)
def pi(name, cwd):
    jl(H + f"/.pi/agent/sessions/--r--/2026-01-01T00-00-00-000Z_{name}.jsonl", [
        {"type": "session", "id": name, "timestamp": "2026-01-01T00:00:00Z", "cwd": cwd},
        {"type": "message", "timestamp": "2026-01-01T00:00:01Z", "message": {"role": "assistant", "model": "m2", "usage": {"input": 20, "output": 4, "cost": {"total": 0.01}}, "content": []}},
        {"type": "message", "timestamp": "2026-01-01T00:00:02Z", "message": {"role": "toolResult", "toolName": "bash", "isError": True, "content": [{"type": "text", "text": ERR}]}}])
for i in range(3): pi(f"p{i}", T + "/alpha")
pi("pb", T + "/beta")
# Codex
jl(H + "/.codex/sessions/2026/01/01/rollout-2026-01-01T00-00-00-01a20a76-1e5f-7fa2-ad21-814c2dd11b69.jsonl", [
    {"type": "session_meta", "timestamp": "2026-01-01T00:00:00Z", "payload": {"id": "x", "cwd": T + "/alpha", "model_provider": "openai"}},
    {"type": "event_msg", "timestamp": "2026-01-01T00:00:01Z", "payload": {"type": "token_count", "info": {"last_token_usage": {"input_tokens": 9, "output_tokens": 2}}}},
    {"type": "response_item", "timestamp": "2026-01-01T00:00:02Z", "payload": {"type": "function_call", "call_id": "k", "name": "shell"}},
    {"type": "response_item", "timestamp": "2026-01-01T00:00:03Z", "payload": {"type": "function_call_output", "call_id": "k", "output": json.dumps({"output": "boom", "metadata": {"exit_code": 2}})}}])
# Hermes
os.makedirs(H + "/.hermes", exist_ok=True)
h = sqlite3.connect(H + "/.hermes/state.db")
h.executescript("""CREATE TABLE sessions(id TEXT PRIMARY KEY, started_at REAL, last_activity_at REAL, model TEXT, cwd TEXT, git_branch TEXT, title TEXT,
  estimated_cost_usd REAL, input_tokens INT, cache_read_tokens INT, output_tokens INT);
  CREATE TABLE messages(id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT, role TEXT, content TEXT, tool_name TEXT, timestamp REAL);""")
h.execute("INSERT INTO sessions VALUES('h1',1767225600,1767225700,'hm','%s','main','hermes work',0.5,11,100,6)" % (T + "/alpha"))
h.execute("INSERT INTO messages(session_id,role,content,tool_name,timestamp) VALUES('h1','tool','{\"error\": \"boom hermes\", \"exit_code\": 1}','terminal',1767225650)")
h.commit(); h.close()
# opencode
os.makedirs(H + "/.local/share/opencode", exist_ok=True)
o = sqlite3.connect(H + "/.local/share/opencode/opencode.db")
o.executescript("""CREATE TABLE session(id TEXT PRIMARY KEY, directory TEXT, title TEXT);
  CREATE TABLE message(id TEXT PRIMARY KEY, session_id TEXT, time_created INT, time_updated INT, data TEXT);
  CREATE TABLE part(id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INT, time_updated INT, data TEXT);""")
o.execute("INSERT INTO session VALUES('o1','%s','oc work')" % (T + "/alpha"))
o.execute("INSERT INTO message VALUES('m1','o1',1767225600000,1767225600000,?)", (json.dumps({"role": "assistant", "modelID": "om", "tokens": {"input": 30, "output": 3}, "cost": 0}),))
o.execute("INSERT INTO part VALUES('p1','m1','o1',1767225601000,1767225601000,?)", (json.dumps({"type": "tool", "tool": "bash", "state": {"status": "error", "error": "opencode boom"}}),))
o.commit(); o.close()
PY

out="$(bash "$X" scan --since 36500 --json)"
echo "$out" | J "r=d['read'];assert all(r.get(t) for t in ('claude','pi','codex','hermes','opencode')),r"; ok "every adapter read its tool" $?
bash "$X" list --json | J "from collections import Counter;c=Counter(s['tool'] for s in d['sessions']);assert c['claude']==2 and c['pi']==4 and c['codex']==1 and c['hermes']==1 and c['opencode']==1,c"; ok "a session per tool, in one index" $?

# incremental: nothing new reads nothing; one new line reads only that file
bash "$X" scan --json | J "assert d['read']=={},d"; ok "a re-scan with nothing new reads nothing" $?
before=$(bash "$X" list --json | J "print(sum(s['spans'] for s in d['sessions']))")
printf '%s\n' '{"type":"assistant","timestamp":"2026-01-01T00:00:09Z","cwd":"'"$T"'/alpha","message":{"model":"m1","usage":{"input_tokens":1,"output_tokens":1},"content":[]}}' >>"$HOME/.claude/projects/-a/c1.jsonl"
bash "$X" scan --json | J "assert d['read']=={'claude':1},d['read']"; ok "a new line in one session reads only that session" $?
after=$(bash "$X" list --json | J "print(sum(s['spans'] for s in d['sessions']))")
[ "$after" = "$((before+1))" ]; ok "...and adds exactly one span ($before -> $after)" $?

# redaction and confidentiality
db="$T/state/sessions/index.db"
python3 - "$db" "$T" <<'PY'; ok "token, vault path and e-mail are masked before indexing" $?
import sqlite3, sys
c = sqlite3.connect(sys.argv[1]); T = sys.argv[2]
blob = " ".join(str(v) for r in c.execute("SELECT err FROM spans UNION ALL SELECT last_prompt FROM sessions UNION ALL SELECT title FROM sessions") for v in r)
assert "sk-abcdef" not in blob and T + "/vault" not in blob and "ada@example.org" not in blob, blob
assert "[secret]" in blob and "[vault]" in blob and "[email]" in blob, blob
PY
python3 - "$db" <<'PY'; ok "a vault session is indexed by count only" $?
import sqlite3, sys
c = sqlite3.connect(sys.argv[1]); c.row_factory = sqlite3.Row
r = c.execute("SELECT * FROM sessions WHERE confidential=1").fetchone()
assert r and r["tokens_in"] == 7 and r["spans"] == 1 and r["cwd"] == "" and r["project"] == "" and r["title"] == "", dict(r)
assert c.execute("SELECT COUNT(*) FROM spans WHERE session=?", (r["id"],)).fetchone()[0] == 0
PY

# project join through plan 367's resolver
bash "$X" list --json | J "p={s['id']:s['project'] for s in d['sessions']};assert p['claude:c1']=='alpha' and p['pi:pb']=='beta' and p['hermes:h1']=='alpha' and p['opencode:o1']=='alpha',p"; ok "sessions join their project by cwd" $?
bash "$ROOT/bin/records/projects-status.sh" --json --no-net --local | J "a=[p for p in d['projects'] if p['id']=='alpha'][0];s=a['sessions'];assert s['by_tool'].get('claude') and s['by_tool'].get('pi') and s['updates'],s"; ok "the Projects panel's row carries sessions by tool and next updates" $?

# the failure across tools shows once, with every session it hit (the pi-extension conflict class)
bash "$X" decisions --json | J "g=[x for x in d['decisions'] if 'already registered' in x['signature']];assert len(g)==1 and set(g[0]['tools'])=={'claude','pi'} and len(g[0]['sessions'])==5,g"; ok "one failure, every tool, every session" $?
bash "$X" updates --project alpha --json | J "u=d['updates'];assert any(x['action']=='open an errand' and x['session'] for x in u),u"; ok "solo, no model: a next update names its source session" $?

# privacy of the shared view
bash "$X" list --public-view --json | J "assert d['sessions'] and all(s['project']=='alpha' for s in d['sessions']),d"; ok "a shared view drops private and confidential sessions" $?

# alerts and brief run without a model
bash "$X" alerts --json | J "assert 'alerts' in d"; ok "alerts compute" $?
bash "$X" brief | grep -q "alpha"; ok "the brief has what-to-update lines" $?

# the judge: off with no profile; on with a fake model
bash "$X" judge | grep -q "judge=off"; ok "no judge profile: judge is off, nothing breaks" $?
cat >"$T/fakejudge.py" <<'PY'
import http.server, json, os, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.dumps({"choices": [{"message": {"content": json.dumps({"outcome": "partial", "summary": "stopped at the registry clash",
            "open_threads": ["remove the duplicate extension"], "next_updates": [{"action": "open an errand", "text": "drop the copy in the worktree"}]})}}]}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H); open(sys.argv[1], "w").write(str(s.server_address[1])); s.serve_forever()
PY
python3 "$T/fakejudge.py" "$T/judge.port" & echo $! >"$T/judge.pid"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$T/judge.port" ] && break; sleep 0.3; done
YMIR_JUDGE_BASE_URL="http://127.0.0.1:$(cat "$T/judge.port")" YMIR_JUDGE_MODEL=free-judge bash "$X" judge --limit 5 --json | J "assert d['judged']>=1,d"; ok "the judge pass uses the machine's own profile" $?
bash "$X" updates --project alpha --json | J "assert any(x['text']=='drop the copy in the worktree' for x in d['updates'])"; ok "a judged session adds a concrete next update" $?
bash "$X" list --project alpha --json | J "assert any(s['outcome']=='partial' and 'registry' in s['summary'] for s in d['sessions'])"; ok "outcome and summary are stored" $?

# optional OTLP export: off without a URL; to a local collector in the GenAI shape
bash "$X" export >/dev/null 2>&1 && r=1 || r=0; ok "export is off unless a collector is named" $r
cat >"$T/collector.py" <<'PY'
import http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        open(sys.argv[2], "wb").write(self.path.encode() + b"\n" + self.rfile.read(int(self.headers.get("Content-Length", 0))))
        self.send_response(200); self.end_headers(); self.wfile.write(b"{}")
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H); open(sys.argv[1], "w").write(str(s.server_address[1])); s.serve_forever()
PY
python3 "$T/collector.py" "$T/col.port" "$T/col.out" & echo $! >"$T/col.pid"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$T/col.port" ] && break; sleep 0.3; done
bash "$X" export --otlp "http://127.0.0.1:$(cat "$T/col.port")" | grep -q "HTTP 200"; ok "export posts to the collector" $?
head -1 "$T/col.out" | grep -q "/v1/traces" && tail -n +2 "$T/col.out" | grep -q "gen_ai.operation.name" && tail -n +2 "$T/col.out" | grep -q "1.37.0"; ok "spans carry the GenAI attributes and the pinned convention" $?

# fleet only adds: this machine asks, and names the source seat; with no fleet.json nothing is asked
mkdir -p "$YMIR_HOME/hodd/data"
echo '{"hosts":{"seat-b":{"user":"u","tailnet":"seat-b.example"}}}' >"$YMIR_HOME/hodd/data/fleet.json"
cat >"$T/ssh" <<'E'
#!/usr/bin/env bash
echo '{"seat":"seat-b","sessions":[{"id":"claude:far","tool":"claude","project":"alpha","last":1,"spans":1,"errors":0,"title":"far"}],"decisions":[]}'
E
chmod +x "$T/ssh"
SESSIONS_SSH="$T/ssh" bash "$X" list --fleet --json | J "r=[s for s in d['sessions'] if s['id']=='claude:far'];assert r and r[0]['source_seat']=='seat-b'"; ok "fleet: the other seat's row names its source seat" $?
SESSIONS_SSH="$T/ssh" bash "$X" list --json | J "assert not any(s['id']=='claude:far' for s in d['sessions'])"; ok "fleet is opt-in: the default never asks" $?

echo "sessions-index: $pass passed, $fail failed"; [ "$fail" = 0 ]
