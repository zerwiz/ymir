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

echo "$ok passed, $fail failed"; [ "$fail" -eq 0 ]
