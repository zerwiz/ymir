#!/usr/bin/env bash
# context-left.test.sh — the test that proves the number MOVES.
#
# WHY THIS EXISTS (2026-11-09): only Rödd, the voice, could see its own context
# budget. A pi seat — the counsellor, every Eindri — had no such tool, so work ran
# into the window unwarned and two errands died at the ceiling that night. The fix
# is `.pi/extensions/context-left/`: one counter, owned by the harness's own state,
# published so the voice repeats it instead of keeping a second one.
#
# The three claims this test refuses to take on faith:
#   1. a session that spends more tokens reports a SMALLER remainder (it moves);
#   2. a window that is unknown is REFUSED with the reason — never guessed;
#   3. the voice keeps NO counter of its own: it repeats the published reading, and
#      says plainly when there is none (one source of truth, not two).
#
# Hermetic: a fake pi object drives the real factory, a temp home receives the real
# publication, and no model, network or herdr is touched.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT="$ROOT/.pi/extensions/context-left"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

command -v node >/dev/null 2>&1 || { printf '1..0 # skip node is absent\n'; exit 0; }
command -v python3 >/dev/null 2>&1 || { printf '1..0 # skip python3 is absent\n'; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME_R="$TMP/home"
mkdir -p "$HOME_R/hodd/state"

# ── 1. shape: Rule 13 — a directory with an index.ts, and the logic beside it ──
[ -f "$EXT/index.ts" ] && ok "the extension is a directory with an index.ts" \
  || bad "the extension is a directory with an index.ts"
[ -f "$EXT/reading.ts" ] && ok "the arithmetic lives in its own module (testable without a harness)" \
  || bad "reading.ts exists"
grep -q 'name: "context_left"' "$EXT/index.ts" \
  && ok "it registers the tool every seat can call: context_left" \
  || bad "it registers a tool named context_left"
grep -q 'pi.on("turn_end"' "$EXT/index.ts" \
  && ok "it republishes at turn end (a reader never repeats a three-turn-old number)" \
  || bad "it republishes at turn end"
grep -q 'getContextUsage' "$EXT/index.ts" \
  && ok "the token count comes from the harness (ctx.getContextUsage) — no invented counter" \
  || bad "the token count comes from ctx.getContextUsage"
grep -rq 'contextWindow *[:=] *[0-9]' "$EXT" \
  && bad "a window size is hardcoded (RULES/07)" \
  || ok "no window size is hardcoded — it is resolved from the catalogue (RULES/07)"

# ── 2–3. drive the REAL factory with a fake pi, publish into a temp home ───────
cat > "$TMP/harness.mjs" <<'JS'
import { pathToFileURL } from "node:url";
const ext = await import(pathToFileURL(process.argv[2]).href);

const factory = ext.default;
const tools = [];
const handlers = [];
factory({ registerTool: (def) => tools.push(def), on: (name, fn) => handlers.push({ name, fn }) });

const tool = tools.find((t) => t.name === "context_left");
if (!tool) { console.log(JSON.stringify({ fatal: "no context_left tool registered" })); process.exit(0); }

function ctx(tokens, contextWindow, userTurns, inputTokens) {
  const entries = [];
  for (let i = 0; i < userTurns; i += 1) {
    entries.push({ type: "message", message: { role: "user" } });
    entries.push({
      type: "message",
      message: { role: "assistant", usage: { input: inputTokens + i } },
    });
  }
  return {
    cwd: process.cwd(),
    model: { id: "test/model-a", contextWindow },
    getContextUsage: () => ({ tokens, contextWindow, percent: contextWindow ? (tokens / contextWindow) * 100 : null }),
    sessionManager: {
      getSessionId: () => "session-under-test",
      getSessionFile: () => process.env.TEST_SESSION_FILE || "",
      getEntries: () => entries,
    },
  };
}

const runs = {};
for (const [label, tokens] of [["early", 20000], ["later", 90000]]) {
  const res = await tool.execute("call-1", {}, undefined, undefined, ctx(tokens, 200000, 6, 15000));
  runs[label] = res.content[0].text;
}
const refused = await tool.execute("call-2", {}, undefined, undefined, ctx(5000, null, 2, 1000));
runs.window_unknown = refused.content[0].text;
const unmeasured = await tool.execute("call-3", {}, undefined, undefined, ctx(null, 200000, 2, 1000));
runs.tokens_unknown = unmeasured.content[0].text;
// A good reading published LAST, so the reader's freshest record is a live one.
const final = await tool.execute("call-4", {}, undefined, undefined, ctx(120000, 200000, 8, 15000));
runs.final = final.content[0].text;
runs.turn_end_publishes = handlers.some((h) => h.name === "turn_end");
console.log(JSON.stringify(runs));
// A publisher that has already exited is history, not a live budget: the door checks the
// pid. `HOLD_MS` keeps this process standing so the live-reading path can be proved.
const hold = Number(process.env.HOLD_MS || 0);
if (hold > 0) await new Promise((r) => setTimeout(r, hold));
JS

printf 'session under test\n' > "$TMP/session-under-test.jsonl"
OUT="$(cd "$TMP" && TEST_SESSION_FILE="$TMP/session-under-test.jsonl" YMIR_HOME="$HOME_R" YMIR_ROOT="$ROOT" HOME="$TMP" \
  node "$TMP/harness.mjs" "$EXT/index.ts" 2>"$TMP/err")"
if [ -z "$OUT" ]; then
  bad "the extension loads and answers (node said: $(head -3 "$TMP/err" | tr '\n' ' '))"
else
  ok "the extension loads and answers"
  python3 - "$OUT" <<'PY'
import json, re, sys
runs = json.loads(sys.argv[1])
def num(text, key):
    m = re.search(r'"%s"\s*:\s*"([^"]*)"' % re.escape(key), text)
    return m.group(1) if m else None
def row(text):
    m = re.search(r'context_left\[9\]\{[^}]+\}:\n\s*"([^\n]*)', text)
    return [c.strip().strip('"') for c in m.group(1).split(",")] if m else []
def fail(msg):
    print("not ok - " + msg); sys.exit(1)
early, later = row(runs["early"]), row(runs["later"])
if len(early) != 9 or len(later) != 9:
    fail("the answer carries the nine facts (window, tokens, remainder, turns left)")
rem_early, rem_later = int(early[4]), int(later[4])
if not rem_later < rem_early:
    fail("a session that spends tokens reports a SMALLER remainder (%d then %d)" % (rem_early, rem_later))
print("ok - the number moves: remainder %d -> %d as the session spends tokens" % (rem_early, rem_later))
tl_early = early[7]
if not tl_early.isdigit():
    fail("turns-left is derived from the session's own tokens-per-turn, not guessed")
print("ok - turns until compaction is derived from the session's own spending (%s)" % tl_early)
if "window is unknown" not in runs["window_unknown"]:
    fail("an unknown window is REFUSED, naming the window")
print("ok - an unknown window is refused with the reason (never a guess)")
if "no measured context" not in runs["tokens_unknown"]:
    fail("an unmeasured token count is REFUSED, naming the reason")
print("ok - an unmeasured token count is refused with the reason")
PY
  [ $? -eq 0 ] || fail=1
fi

# ── 4. the publication is real, and one file per session ───────────────────────
PUB="$HOME_R/hodd/state/context-left/session-under-test.json"
if [ -f "$PUB" ]; then
  ok "the reading is published at hodd/state/context-left/<session>.json"
  python3 - "$PUB" <<'PY'
import json, sys
rec = json.load(open(sys.argv[1]))
assert rec.get("ok") is True, "the publication carries a failed reading"
assert isinstance(rec.get("tokens"), int), "no token count published"
assert isinstance(rec.get("remaining"), int), "no remainder published"
assert rec.get("rendered"), "no rendered answer to repeat"
assert isinstance(rec.get("pid"), int), "no pid — a reader cannot tell live from history"
print("ok - the published record carries the facts, the rendered answer, and the pid")
PY
  [ $? -eq 0 ] || fail=1
else
  bad "the reading is published at hodd/state/context-left/<session>.json"
fi

# ── 4b. the house's own context door prefers the live reading ────────────────
DOOR="$ROOT/bin/seat/context.sh"
if [ -x "$DOOR" ]; then
  ( cd "$TMP" && TEST_SESSION_FILE="$TMP/session-under-test.jsonl" HOLD_MS=20000 YMIR_HOME="$HOME_R" YMIR_ROOT="$ROOT" HOME="$TMP" \
      node "$TMP/harness.mjs" "$EXT/index.ts" >/dev/null 2>&1 & echo $! > "$TMP/holder.pid" )
  i=0; while [ "$i" -lt 60 ] && [ ! -s "$HOME_R/hodd/state/context-left/session-under-test.json" ]; do i=$((i+1)); sleep 0.1; done
  LIVE="$(YMIR_HOME="$HOME_R" bash "$DOOR" --session "$TMP/session-under-test.jsonl" --json 2>&1)"
  case "$LIVE" in
    *"live harness reading (pi extension)"*) ok "bin/seat/context.sh prints the live extension reading, not a second count" ;;
    *) bad "bin/seat/context.sh prefers the live reading (got: $(printf '%s' "$LIVE" | head -2 | tr '\n' ' '))" ;;
  esac
  case "$LIVE" in
    *'"tokens": 120000'*) ok "the door's numbers are the extension's own" ;;
    *) bad "the door's numbers are the extension's own (got: $(printf '%s' "$LIVE" | head -2 | tr '\n' ' '))" ;;
  esac
  kill "$(cat "$TMP/holder.pid" 2>/dev/null)" 2>/dev/null || true
  rm -f "$HOME_R/hodd/state/context-left/"*.json
  FALLBACK="$(YMIR_HOME="$HOME_R" bash "$DOOR" --session "$TMP/session-under-test.jsonl" --json 2>&1)"
  case "$FALLBACK" in
    *"live harness reading"*) bad "with no published reading the door must not claim a live one" ;;
    *) ok "with no published reading the door falls back and makes no live claim" ;;
  esac
else
  printf '# skip: bin/seat/context.sh is absent\n'
fi

# ── 5. one source of truth: the voice repeats it, and keeps no counter ────────
VT="$ROOT/bin/voice/voice_tools.py"
grep -q 'hodd/state/context-left\|"context-left"' "$VT" 2>/dev/null \
  && ok "the voice tool reads the published reading" \
  || bad "the voice tool reads the published reading"
python3 - "$VT" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
start = src.find('if name == "context_left":')
end = src.find('if name == "', start + 10)
block = src[start:end if end > start else start + 4000]
if "Token usage" in block or "host.log" in block:
    print("not ok - the context_left block still scrapes a token count of its own (two counters)")
    sys.exit(1)
print("ok - the context_left block keeps no counter of its own; it repeats the publication")
PY
[ $? -eq 0 ] || fail=1

OUT2="$(cd "$TMP" && TEST_SESSION_FILE="$TMP/session-under-test.jsonl" YMIR_HOME="$HOME_R" YMIR_ROOT="$ROOT" HOME="$TMP" \
  node "$TMP/harness.mjs" "$EXT/index.ts" 2>/dev/null)"
VOICE_OUT="$(YMIR_HOME="$HOME_R" python3 - "$VT" <<'PY' 2>&1
import asyncio, importlib.util, sys, pathlib
spec = importlib.util.spec_from_file_location("voice_tools", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
out = asyncio.run(mod._execute("context_left", {}))
print(out.get("output") if isinstance(out, dict) else str(out))
PY
)"
case "$VOICE_OUT" in
  *"context_left[9]"*) ok "the voice repeats the extension's own rendered reading" ;;
  *) bad "the voice repeats the extension's reading (got: $(printf '%s' "$VOICE_OUT" | head -2 | tr '\n' ' '))" ;;
esac

rm -f "$HOME_R/hodd/state/context-left/"*.json
VOICE_NONE="$(YMIR_HOME="$HOME_R" python3 - "$VT" <<'PY' 2>&1
import asyncio, importlib.util, sys
spec = importlib.util.spec_from_file_location("voice_tools", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
out = asyncio.run(mod._execute("context_left", {}))
print(out.get("output") if isinstance(out, dict) else str(out))
PY
)"
case "$VOICE_NONE" in
  *"cannot answer"*) ok "with no published reading the voice refuses and says why (never an estimate)" ;;
  *) bad "with no published reading the voice refuses and says why (got: $(printf '%s' "$VOICE_NONE" | head -2 | tr '\n' ' '))" ;;
esac

[ "$fail" -eq 0 ] && printf '1..1 # all claims proved\n'
exit "$fail"
