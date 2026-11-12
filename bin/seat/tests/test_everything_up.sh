#!/usr/bin/env bash
# Wards for the "everything-up" errand: a worker seat is never the helm (Stop hook + arm check),
# and a rendered config resolves the hoard through hoard-lib, never as ~/hodd.
set -u
here="${BASH_SOURCE[0]%/*}"; repo="$(realpath "$here/../../..")"
ok=0; fail=0
chk() { if [ "$2" = "$3" ]; then ok=$((ok+1)); echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1 (want '$2' got '$3')"; fi; }
work="$(TMPDIR=/tmp mktemp -d)"; trap 'rm -rf "$work"' EXIT   # /tmp: outside any seat dir, so helm cases are not taken for workers

# 1. The global Stop hook: a worker worktree and a seat dir exit 0 silently, before any arm is read.
mkdir -p "$work/home/.pi/agent/extensions" "$work/fake/bin/pi" "$work/wt/.yggdrasil/x" "$work/home/.local/state/ymir/seats/y"
printf '%s\n' "$work/fake" > "$work/home/.pi/agent/extensions/.ymir-root"
printf '#!/usr/bin/env bash\necho "stale: no live lease"\n' > "$work/fake/bin/pi/syn-watch-arm.sh"; chmod +x "$work/fake/bin/pi/syn-watch-arm.sh"
for d in "$work/wt/.yggdrasil/x" "$work/home/.local/state/ymir/seats/y"; do
  out="$(HOME="$work/home" CLAUDE_PROJECT_DIR="$d" bash "$repo/.claude/hooks/ymir-arm.sh" 2>&1)"; rc=$?
  chk "worker stop is never blocked (${d##*/})" "0|" "$rc|$out"
done
out="$(HOME="$work/home" CLAUDE_PROJECT_DIR="$work/elsewhere" bash "$repo/.claude/hooks/ymir-arm.sh" 2>&1)"; rc=$?
chk "the helm's stop is still blocked when a wake is queued" "2" "$rc"

# 2. claude-stop-arm.sh: a worker root never arms, even when it owns its seat's lock.
mkdir -p "$work/wt/.yggdrasil/z/bin/pi" "$work/wt/.yggdrasil/z/bin/records"
printf '#!/usr/bin/env bash\necho "signal: wake"\n' > "$work/wt/.yggdrasil/z/bin/pi/syn-watch-arm.sh"
printf '#!/usr/bin/env bash\ncase "$*" in *session-pid*) echo 1;; esac; exit 0\n' > "$work/wt/.yggdrasil/z/bin/records/ymir-state.sh"
chmod +x "$work/wt/.yggdrasil/z/bin/pi/syn-watch-arm.sh"
out="$(CLAUDE_PROJECT_DIR="$work/wt/.yggdrasil/z" bash "$repo/bin/gates/checks/claude-stop-arm.sh" </dev/null 2>&1)"; rc=$?
chk "a worker seat is not armed by claude-stop-arm" "0|" "$rc|$out"
mkdir -p "$work/helm/bin/pi" "$work/helm/bin/records"
cp "$work/wt/.yggdrasil/z/bin/pi/syn-watch-arm.sh" "$work/helm/bin/pi/"; cp "$work/wt/.yggdrasil/z/bin/records/ymir-state.sh" "$work/helm/bin/records/"
out="$(CLAUDE_PROJECT_DIR="$work/helm" YMIR_STATE_DIR="$work/st" bash "$repo/bin/gates/checks/claude-stop-arm.sh" </dev/null 2>&1)"; rc=$?
chk "the helm is still woken (rc 2)" "2" "$rc"

# 3. The rendered config resolves the hoard through hoard-lib: __YMIR_HOME__ is the operator's home, not $HOME.
r="$work/root"; mkdir -p "$r/bin/seat" "$r/bin/vault" "$r/.pi" "$r/RULES" "$r/.agents/agents" "$work/h2" "$work/ymirhome"
cp "$repo/bin/seat/valknut-load.sh" "$r/bin/seat/"; cp "$repo/bin/vault/hoard-lib.sh" "$r/bin/vault/"
printf '{"mcpServers":{"engram":{"args":["--db","__YMIR_HOME__/hodd/memory/kaia.engram"]}}}\n' > "$r/.pi/mcp-adapter.json.example"
HOME="$work/h2" YMIR_HOME="$work/ymirhome" bash "$r/bin/seat/valknut-load.sh" --pi >/dev/null 2>&1
got="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['mcpServers']['engram']['args'][1])" "$r/.pi/mcp-adapter.json" 2>&1)"
chk "engram path is the resolved hoard, not ~/hodd" "$work/ymirhome/hodd/memory/kaia.engram" "$got"

# 3b. An unresolved home refuses loudly: no placeholder is written, and the row is not "seeded".
rm -f "$r/.pi/mcp-adapter.json"
mv "$r/bin/vault/hoard-lib.sh" "$r/bin/vault/hoard-lib.off"   # the resolver is unreachable: the home cannot resolve
out="$(HOME="$work/h2" YMIR_HOME= bash "$r/bin/seat/valknut-load.sh" --pi 2>&1)"
mv "$r/bin/vault/hoard-lib.off" "$r/bin/vault/hoard-lib.sh"
chk "an unresolved home is refused, not seeded" "yes" "$(printf '%s' "$out" | grep -q 'ERROR refused: home unresolved' && ! printf '%s' "$out" | grep -q seeded && echo yes || echo no)"
chk "and no placeholder file is written" "no" "$([ -e "$r/.pi/mcp-adapter.json" ] && echo yes || echo no)"

# 4. The finishing step: the shelf and the wake land in the resolved state dir, and a write that
#    did not land fails loudly instead of claiming a file that is not there.
# Run a COPY of the act in a bare tree: no well, no voice, nothing of the real house is touched.
st="$work/state"; mkdir -p "$st" "$work/ac/bin/agents" "$work/ac/bin/vault"
cp "$repo/bin/agents/eindri-acclaim.sh" "$repo/bin/agents/eindri-wake-lib.sh" "$work/ac/bin/agents/"; cp "$repo/bin/vault/hoard-lib.sh" "$work/ac/bin/vault/"
out="$(BROKK_STATE_OVERRIDE="$st" YMIR_AUTO_REVIEW=off bash "$work/ac/bin/agents/eindri-acclaim.sh" tst --terminal done --line "shipped x" 2>&1)"; rc=$?
chk "acclaim files the report shelf in the resolved state" "yes" "$([ -s "$st/eindri-reports/tst.md" ] && echo yes || echo no)"
chk "acclaim queues the wake in the resolved state" "yes" "$(grep -q 'eindri tst ' "$st/.wake-queue" 2>/dev/null && echo yes || echo no)"
chk "acclaim names the absolute shelf, not a relative one" "yes" "$(printf '%s' "$out" | grep -q "$st/eindri-reports/tst.md" && echo yes || echo no)"
bad="$work/notadir"; : > "$bad"
out="$(BROKK_STATE_OVERRIDE="$bad" YMIR_AUTO_REVIEW=off bash "$work/ac/bin/agents/eindri-acclaim.sh" tst2 --terminal done --line "shipped y" 2>&1)"; rc=$?
chk "a report that did not land fails loudly (rc 1)" "1" "$rc"
chk "and says why" "yes" "$(printf '%s' "$out" | grep -q 'did not land' && echo yes || echo no)"

# 5. The brief names the home's state for the queue, not <repo>/state.
bd="$work/bdata"; mkdir -p "$bd"
BROKK_DATA_OVERRIDE="$bd" BROKK_STATE_OVERRIDE="$st" bash "$repo/bin/agents/erindi-brief.sh" tst3 somerepo --mode direct-PR >/dev/null 2>&1
chk "the brief's completion check greps the resolved queue" "yes" "$(grep -q "grep -c \"tst3\" '$st/.wake-queue'" "$bd/tst3/brief.md" 2>/dev/null && echo yes || echo no)"

# 6. The task board has one writer: todos.sh can reopen what the MCP face marks pending again.
th="$work/todohome"; mkdir -p "$th/state"
YMIR_HOME="$th" bash "$repo/bin/records/todos.sh" add "a task" >/dev/null 2>&1
YMIR_HOME="$th" bash "$repo/bin/records/todos.sh" done 0 >/dev/null 2>&1
chk "todos.sh done" "done" "$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))[0]['status'])" "$th/state/todos.json")"
YMIR_HOME="$th" bash "$repo/bin/records/todos.sh" reopen 0 >/dev/null 2>&1
chk "todos.sh reopen" "pending" "$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))[0]['status'])" "$th/state/todos.json")"
# The LIVE face is bin/mcp/ymir-mcp.py (every installed config names it); the decoy bin/seat copy is gone.
chk "the live MCP face keeps no store of its own" "0" "$(grep -c '_todo_save\|_todo_path' "$repo/bin/mcp/ymir-mcp.py")"
chk "the seat copy is only a pointer to the live face" "0" "$(grep -c "_todo\|FastMCP" "$repo/bin/seat/ymir-mcp.py")"
# clear: remove from the tail, tell the truth (three tasks -> none remain, and the answer says 3).
for t in a b c; do YMIR_HOME="$th" bash "$repo/bin/records/todos.sh" add "$t" >/dev/null 2>&1; done
if python3 -c "import mcp" 2>/dev/null; then
  out="$(YMIR_HOME="$th" python3 - "$repo" <<'PY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("face", sys.argv[1] + "/bin/mcp/ymir-mcp.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.todo(action="clear"))
PY
)"
  # a, b, c plus the earlier "a task" = 4 rows
  chk "clear reports the true count" "cleared 4 task(s)" "$out"
  chk "and nothing remains" "0" "$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$th/state/todos.json")"
else
  echo "skip clear (the mcp SDK is not installed here)"
fi

# 7. Gróa's agent records what it found (daily log + Runes + well when the tree moved) and is silent when nothing moved.
gr="$work/groa"; mkdir -p "$gr/repo/bin/records" "$gr/path" "$gr/ymirhome"
for t in daily-log runes-append mimir; do printf '#!/usr/bin/env bash\necho "$(basename "$0") $*" >> "%s/calls"\n' "$gr" > "$gr/repo/bin/records/$t.sh"; chmod +x "$gr/repo/bin/records/$t.sh"; done
printf '#!/usr/bin/env bash\nprintf "%%b\\n" "$FAKE_OUT"\n' > "$gr/path/opencode"; chmod +x "$gr/path/opencode"
GA=(env PATH="$gr/path:$PATH" YMIR_REPO="$gr/repo" YMIR_HOME="$gr/ymirhome" GROA_PROMPT=/dev/null bash "$repo/bin/agents/groa-agent/groa-agent.sh" tick)
FAKE_OUT="BEHIND: omarchy\\nUPDATED: omarchy\\nMIGRATIONS: none" "${GA[@]}" >/dev/null 2>&1
chk "a moved tree is written to the daily log, Runes and the well" "3" "$(cat "$gr/calls" 2>/dev/null | wc -l)"
rm -f "$gr/calls"; rm -f "$gr/ymirhome/hodd/state/groa-agent.pid"
FAKE_OUT="BEHIND: none\\nUPDATED: nothing\\nMIGRATIONS: none" "${GA[@]}" >/dev/null 2>&1
chk "nothing behind, nothing moved: no record, no noise" "0" "$(cat "$gr/calls" 2>/dev/null | wc -l)"

# 8. A shipping errand's done line must carry its pull request; batch, local-only and report-only (scout) errands are exempt.
mkdir -p "$st"
printf 'mode=direct-PR\n' > "$st/ship1.meta"; printf 'mode=batch\n' > "$st/bat1.meta"
BROKK_STATE_OVERRIDE="$st" bash "$work/ac/bin/agents/eindri-acclaim.sh" ship1 --terminal done --line "done: nothing to show" >/dev/null 2>&1; chk "a direct-PR done line with no PR is refused (rc 3)" "3" "$?"
BROKK_STATE_OVERRIDE="$st" bash "$work/ac/bin/agents/eindri-acclaim.sh" ship1 --terminal done --line "done: opened PR https://github.com/o/r/pull/7" >/dev/null 2>&1; chk "with its PR url it passes" "0" "$?"
BROKK_STATE_OVERRIDE="$st" bash "$work/ac/bin/agents/eindri-acclaim.sh" bat1 --terminal done --line "done: committed on the branch" >/dev/null 2>&1; chk "a batch errand needs no PR" "0" "$?"

# a scout record as eindri-dispatch.sh writes it (mode=scout) needs no PR either; review and recon likewise.
for m in scout review recon; do
  printf 'mode=%s\n' "$m" > "$st/d$m.meta"
  BROKK_STATE_OVERRIDE="$st" bash "$work/ac/bin/agents/eindri-acclaim.sh" "d$m" --terminal done --line "done: report filed" >/dev/null 2>&1; chk "a dispatched $m record needs no PR (rc 0)" "0" "$?"
done

echo "$ok passed, $fail failed"; [ "$fail" -eq 0 ]
