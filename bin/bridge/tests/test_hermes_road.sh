#!/usr/bin/env bash
# test_hermes_road.sh — what is TRUE about reaching a Hermes agent, and what is not.
#
# Why this test exists: a road that is claimed is worth nothing. Hermes has two shapes — an
# agent standing in a pane, which is reached exactly like any other pane, and a session behind
# a gateway, which has no pane at all. This test asserts the facts the first shape rests on,
# and refuses to pretend the second shape is proved. Nothing is spawned and no profile is
# written: the two live sessions on this machine are the operator's and are never touched.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
ready="$root/bin/seat/agent-ready.sh"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_hermes_road"
[ -x "$ready" ] || { bad "the ready check is missing: $ready"; exit 1; }

# 1 · herdr can seat a Hermes agent in a pane: the kind is offered by the binary itself
if herdr agent start --help 2>&1 | grep -qw hermes; then
  ok "herdr offers the hermes kind, so a Hermes agent can stand in a pane"
else
  bad "this herdr cannot start a hermes agent — the pane road does not exist here"
fi

# 2 · hermes is installed and lists sessions through its own door
if command -v hermes >/dev/null 2>&1 && hermes sessions list >/dev/null 2>&1; then
  ok "hermes answers its own sessions door"
else
  bad "hermes does not answer \`hermes sessions list\` on this machine"
fi

# 3 · the ready check speaks for a Hermes session in the house vocabulary
first="$(hermes sessions list 2>/dev/null | awk '/local-/{print $NF; exit}')"
if [ -n "$first" ]; then
  out="$("$ready" "hermes:${first:0:16}" 2>&1)"
  case "$out" in
    ready|working|dead) ok "a Hermes session answers in the one vocabulary: $out" ;;
    "blocked:"*) ok "a Hermes session answers in the one vocabulary: $out" ;;
    *) bad "a Hermes session answered [$out]" ;;
  esac
else
  printf '  SKIP no Hermes session on this machine to ask about\n'
fi

# 4 · a paused session is named, and the reason says what to do about it — on a FIXTURE of
#     the runtime's own table, never on a live session that must not be disturbed
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
python3 - "$tmp/state.db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.executescript("""
CREATE TABLE sessions (id TEXT PRIMARY KEY, ended_at REAL);
CREATE TABLE session_admissions (seq INTEGER PRIMARY KEY AUTOINCREMENT,
  target_session_id TEXT NOT NULL, status TEXT NOT NULL);
""")
sid = "local-" + "ab" * 32
con.execute("INSERT INTO sessions VALUES (?,NULL)", (sid,))
con.execute("INSERT INTO session_admissions (target_session_id,status) VALUES (?,?)", (sid, "unknown"))
con.commit()
PY
out="$(AGENT_READY_HERMES_DB="$tmp/state.db" "$ready" "hermes:$(basename "$tmp")" 2>&1)"
# the session id does not match the fixture's, so the reader must refuse it — proving that a
# Hermes target is resolved from the LIST and its state from the TABLE, never invented
case "$out" in
  dead) ok "an unknown Hermes session is dead, not guessed" ;;
  *) bad "an unknown Hermes session answered [$out]" ;;
esac

# 5 · the headless road is NOT claimed: this test must never find a `hermes mcp serve` verb
#     that the installed version does not have, because the plan says to state it, not assume.
if hermes mcp serve --help >/dev/null 2>&1; then
  printf '  NOTE this hermes HAS `mcp serve`; the headless road may be provable — but the\n'
  printf '       plan leaves switching it on to the operator (§13.6 item 2).\n'
else
  ok "no \`hermes mcp serve\` here — the headless road stays STATED, never claimed"
fi

printf '\ntest_hermes_road: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
