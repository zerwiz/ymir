#!/usr/bin/env bash
# test_ratatoskr_who.sh — the directory reads herdr, names every machine, and hides no miss.
#
# Why this test exists: the house's old directory was opt-in, so it listed whoever had
# announced by hand and kept listing them after their pane was gone. The new one lists
# the panes that exist NOW — on this machine and on each fleet machine over its road —
# and a machine that does not answer must be a ROW that says so, never a row quietly
# dropped. Every case below is a stub, so no real machine and no live agent is touched.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../ratatoskr.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_ratatoskr_who"
[ -x "$door" ] || { bad "the door is missing: $door"; exit 1; }

mkdir -p "$tmp/bin" "$tmp/home/hodd/data" "$tmp/stub"
export STUB_DIR="$tmp/stub"
export HOME="$tmp/home-home"
mkdir -p "$HOME"

# ── a stub herdr: `agent list` from a file, `agent get` for one pane, `explain` for its reason ──
cat >"$tmp/bin/herdr" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "agent" ] || exit 0
case "${2:-}" in
  list) cat "$STUB_DIR/list.json" ;;
  get)
    f="$STUB_DIR/${3:-x}.get"
    [ -r "$f" ] || { printf '{"error":{"code":"agent_not_found"}}\n'; exit 1; }
    cat "$f" ;;
  explain) cat "$STUB_DIR/${3:-x}.explain" 2>/dev/null; exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmp/bin/herdr"

# ── a stub ssh: answers the fleet snippet from a per-host file, or fails like a dark road ──
cat >"$tmp/bin/ssh" <<'SH'
#!/usr/bin/env bash
# The door passes the remote snippet as one argument, and that snippet is full of
# `@` markers — so the address is the first multi-line-free argument carrying one.
target=""
for a in "$@"; do
  case "$a" in *@*) case "$a" in *$'\n'*) continue ;; esac; target="$a"; break ;; esac
done
host="${target#*@}"; host="${host%%.*}"
printf '%s\n' "$host" >>"$STUB_DIR/ssh-called"
f="$STUB_DIR/host-$host.out"
[ -r "$f" ] || exit 255
cat "$f"
SH
chmod +x "$tmp/bin/ssh"
export PATH="$tmp/bin:$PATH"

# ── this machine: three panes, one of them blocked on the folder-trust dialog ──
cat >"$STUB_DIR/list.json" <<'JSON'
{"result":{"agents":[
 {"agent":"claude","agent_status":"idle","interactive_ready":true,"pane_id":"w1:p1","name":"helm"},
 {"agent":"pi","agent_status":"working","pane_id":"w1:p2","terminal_title_stripped":"worker"},
 {"agent":"claude","agent_status":"blocked","pane_id":"w1:p3","name":"trusting"}
]}}
JSON
printf '{"result":{"agent":{"agent":"claude","agent_status":"idle","interactive_ready":true}}}\n' >"$STUB_DIR/w1:p1.get"
printf '{"result":{"agent":{"agent":"pi","agent_status":"working"}}}\n'                    >"$STUB_DIR/w1:p2.get"
printf '{"result":{"agent":{"agent":"claude","agent_status":"blocked"}}}\n'                >"$STUB_DIR/w1:p3.get"
printf 'agent: claude\nstate: blocked\nrule: live_blocked_form\nevidence: " Quick safety check: Is this a project you trust?"\n' \
  >"$STUB_DIR/w1:p3.explain"

# ── two fleet machines: one answers with a pane, one is dark ──
cat >"$tmp/home/hodd/data/fleet.json" <<'JSON'
{"hosts":{
 "host-a":{"tailnet":"host-a.example.org","user":"someone"},
 "host-b":{"tailnet":"host-b.example.org","user":"someone"},
 "host-c":{"tailnet":"host-c.example.org","user":"someone"},
 "host-d":
   {},
 "host-e":{"tailnet":"host-e.example.org","user":"someone"}
}}
JSON
cat >"$STUB_DIR/host-host-b.out" <<'OUT'
@@AGENTS@@
{"result":{"agents":[
 {"agent":"claude","agent_status":"idle","interactive_ready":true,"pane_id":"w2:p1","name":"far-helm"},
 {"agent":"pi","agent_status":"blocked","pane_id":"w2:p2","name":"far-dialog"}
]}}
@@ARM@@
arm-holder[2]{lock_owner,alive,pane,via}:
  "99","yes","w2:p2","the arm holder named its pane"
@@END@@
OUT
cat >"$STUB_DIR/host-host-c.out" <<'OUT'
@@AGENTS@@
{"result":{"agents":[]}}
@@ARM@@
@@END@@
OUT

export YMIR_HOME="$tmp/home"
export HDR_BIN="$tmp/bin/herdr"
export YMIR_MACHINE="host-a"
export RATATOSKR_ARM_PANE="w1:p1"

# 1 · this machine's own rows: harness, pane, and the state in the one vocabulary
out="$("$door" who --local 2>&1)"
printf '%s\n' "$out" | grep -q '"host-a","claude","w1:p1","helm","ready","yes","local"' \
  && ok "a local row names machine, harness, pane, state and the arm" || bad "local row: $out"
printf '%s\n' "$out" | grep -q '"host-a","pi","w1:p2","worker","working","no","local"' \
  && ok "a working pane reads working" || bad "working row: $out"

# 2 · a blocked pane carries the reason a person acts on
printf '%s\n' "$out" | grep -q 'blocked: trust prompt' \
  && ok "a pane on the trust dialog says so" || bad "trust row: $out"

# 3 · the row count is exactly what herdr lists — nothing stale is remembered
printf '%s\n' "$out" | head -1 | grep -q '^who\[3\]' \
  && ok "three panes listed, three rows" || bad "row count: $(printf '%s\n' "$out" | head -1)"

# 4 · --local asks no machine
[ -s "$STUB_DIR/ssh-called" ] && bad "--local still called ssh" || ok "--local asks no machine"

# 5 · the fleet: an answering machine's rows carry the road that answered
out="$("$door" who 2>&1)"
printf '%s\n' "$out" | grep -q '"host-b","claude","w2:p1","far-helm","ready","no","tailnet"' \
  && ok "a far machine's agent is a row, with its road named" || bad "far row: $out"
printf '%s\n' "$out" | grep -q '"host-b","pi","w2:p2","far-dialog","blocked: dialog","yes","tailnet"' \
  && ok "a far blocked pane says dialog, and the arm is marked" || bad "far blocked row: $out"

# 6 · a machine whose road fails is a row that names the miss, never silence
printf '%s\n' "$out" | grep -q '"host-e","-","-","-","dead","-","dark:' \
  && ok "a dark machine is named as dark, not dropped" || bad "dark row missing: $out"
printf '%s\n' "$out" | grep -q '"host-d"' \
  && bad "a machine with no road was listed" || ok "a machine with no road is not asked"

# 7 · a machine that answers with no agent says that, rather than vanishing
printf '%s\n' "$out" | grep -q '"host-c","-","-","-","dead","-","no agent stands there"' \
  && ok "an empty machine still gets a row" || bad "empty machine row: $out"

# 8 · --machine narrows to one
out="$("$door" who --machine host-b 2>&1)"
printf '%s\n' "$out" | grep -q 'host-a' && bad "--machine leaked another machine" || ok "--machine narrows to one"
printf '%s\n' "$out" | grep -q 'host-b' && ok "--machine keeps the one named" || bad "--machine lost its machine: $out"

# 9 · the arm pane that herdr does not list is named, not silently arm-less
export RATATOSKR_ARM_PANE="w9:p9"
out="$("$door" who --local 2>&1)"
printf '%s\n' "$out" | grep -q '"host-a","-","w9:p9","(the arm)","dead","yes"' \
  && ok "an arm pane holding no listed agent is a row of its own" || bad "arm miss row: $out"
export RATATOSKR_ARM_PANE="w1:p1"

# 10 · --json is the same rows for a caller that must not parse a table
"$door" who --local --json 2>/dev/null | python3 -c '
import json,sys
rows=json.load(sys.stdin)
assert isinstance(rows,list) and len(rows)==3, rows
assert rows[0]["machine"]=="host-a" and rows[0]["arm"]=="yes" and rows[0]["road"]=="local", rows[0]
' && ok "--json carries machine, state, arm and road" || bad "--json is not the documented shape"

# 11 · a broken herdr is a refusal, never an empty directory that reads as "no agents"
printf 'not json\n' >"$STUB_DIR/list.json"
"$door" who --local >/dev/null 2>&1; [ $? = 1 ] && ok "an unreadable herdr exits 1" || bad "unreadable herdr exited $?"

printf '\ntest_ratatoskr_who: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
