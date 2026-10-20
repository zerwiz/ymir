#!/usr/bin/env bash
# logretta.test.sh — the council's laws, proved with a STUB pi (no model, no money).
#
# What is under test is the orchestration, not a model's opinion:
#   1. a seat is spawned READ-ONLY (--tools read,grep,find,ls) and with --no-extensions
#   2. N seats run, one child each, and the debate round shows each seat the others
#   3. the arbiter's answer becomes the verdict, and a failed seat is reported, not hidden
#   4. an invalid stack fails LOUDLY (unknown key, bad rail, too few slots);
#      a missing stack fails loudly rather than inventing a roster
#   5. the budget line stops the council instead of letting it spend
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT="$ROOT/.pi/extensions/logretta"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── the stub pi: records argv+stdin, answers in pi's --mode json line shape ────
mkdir -p "$TMP/bin"
cat >"$TMP/bin/pi" <<'STUB'
#!/usr/bin/env bash
set -u
n=$(( $(cat "$STUB_DIR/count" 2>/dev/null || echo 0) + 1 ))
echo "$n" >"$STUB_DIR/count"
{
  printf 'ARGV:'; printf ' [%s]' "$@"; printf '\n'
  printf 'STDIN:\n'; cat
  printf '\n---\n'
} >>"$STUB_DIR/calls"
model=""; prev=""
for a in "$@"; do [ "$prev" = "--model" ] && model="$a"; prev="$a"; done
case "$model" in
  *broken*) printf '{"type":"error","message":"model unavailable"}\n' >&2; exit 1 ;;
esac
# a verdict for the arbiter, an opinion otherwise (the prompt says which)
prompt="$(cat)"
if grep -q "You are the arbiter" <<<"$prompt"; then
  text="VERDICT: follow the architect; the skeptic's objection is recorded."
elif grep -q "Your first answer is below" <<<"$prompt"; then
  text="CHANGE: the other seat is right about the seam."
else
  text="OPINION for $model"
fi
python3 - "$text" <<'PY'
import json,sys
print(json.dumps({"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":sys.argv[1]}}))
PY
STUB
chmod +x "$TMP/bin/pi"

export STUB_DIR="$TMP"
export PATH="$TMP/bin:$PATH"
export LOGRETTA_PI="$TMP/bin/pi"

# ── a stack and a driver that calls the tools the way pi does ─────────────────
cat >"$TMP/stack.yaml" <<'YAML'
name: test-council
arbiter: architect
rounds: 2
timeout_seconds: 20
max_total_chars: 60000
slots:
  - name: architect
    model: test/architect-1
    lens: architect
    rail: local
  - name: skeptic
    model: test/skeptic-1
    lens: skeptic
    rail: hosted
YAML
export LOGRETTA_STACK="$TMP/stack.yaml"

cat >"$TMP/drive.mjs" <<'JS'
import { pathToFileURL } from "node:url";
const ext = process.argv[2];
const tool = process.argv[3];
const args = JSON.parse(process.argv[4] ?? "{}");
const mod = await import(pathToFileURL(ext).href);
const tools = new Map();
mod.default({ registerTool: (t) => tools.set(t.name, t) });
if (!tools.has(tool)) { console.error("missing tool " + tool); process.exit(3); }
const r = await tools.get(tool).execute("t", args, undefined, undefined, { cwd: process.cwd() });
console.log(JSON.stringify({ text: r.content?.[0]?.text ?? "", isError: !!r.isError }));
JS

run_tool() { node "$TMP/drive.mjs" "$EXT/index.ts" "$1" "${2:-{\}}" 2>&1; }

# ── 1+2: a full sitting ───────────────────────────────────────────────────────
res="$(run_tool logretta_sit '{"topic":"should the council seat five models?"}')"
if grep -q "VERDICT" <<<"$res"; then ok "a sitting produces a verdict"; else bad "no verdict: $res"; fi
if [ "$(cat "$TMP/count")" = "5" ]; then ok "two seats × (opinion + debate) + one verdict = 5 children"; else bad "expected 5 children, got $(cat "$TMP/count")"; fi
if grep -q -- "--no-extensions" "$TMP/calls"; then ok "seats run with --no-extensions (no recursion)"; else bad "missing --no-extensions"; fi
if grep -q -- "\[read,grep,find,ls\]" "$TMP/calls"; then ok "seats are read-only (no bash/edit/write)"; else bad "seats are not read-only"; fi
if grep -q -- "\[test/skeptic-1\]" "$TMP/calls"; then ok "each seat gets its OWN model"; else bad "seat model not passed"; fi
if grep -q "untrusted_context" "$TMP/calls"; then ok "the debate round delimits other agents' answers as untrusted"; else bad "no untrusted delimiting"; fi
if grep -q "YOUR STANDING RULES" "$TMP/calls"; then ok "every seat receives the council charter"; else bad "no charter in the prompts"; fi
if grep -q "POSITION: one sentence" "$TMP/calls"; then ok "the opinion round carries a production output contract"; else bad "opinion contract missing"; fi
if grep -q "HOLD: or CHANGE:" "$TMP/calls"; then ok "the debate round carries a hold/change contract"; else bad "debate contract missing"; fi
if grep -q "You are the ARBITER" "$TMP/calls"; then ok "the arbiter is briefed as arbiter, not as another opinion"; else bad "no arbiter brief"; fi
if grep -q "DECISION: what to do" "$TMP/calls"; then ok "the verdict carries a decision contract (risks, next actions, confidence)"; else bad "verdict contract missing"; fi
if grep -q "You are the SKEPTIC" "$TMP/calls"; then ok "each seat gets its own full lens brief"; else bad "lens brief missing"; fi

# ── 3: a failed seat is reported, and the council still converges ─────────────
sed -i 's|test/skeptic-1|test/broken-1|' "$TMP/stack.yaml"
: >"$TMP/calls"
res="$(run_tool logretta_sit '{"topic":"does one dead seat sink the council?"}')"
if grep -q "FAILED" <<<"$res"; then ok "a failed seat is named, not hidden"; else bad "silent failure"; fi
if grep -q "VERDICT" <<<"$res"; then ok "the council still reaches a verdict with one seat down"; else bad "no verdict with one seat down"; fi
sed -i 's|test/broken-1|test/skeptic-1|' "$TMP/stack.yaml"

# ── 4: invalid stacks fail loudly ────────────────────────────────────────────
bad_stack() {
  printf '%s\n' "$2" >"$TMP/bad.yaml"
  local out; out="$(LOGRETTA_STACK="$TMP/bad.yaml" node "$TMP/drive.mjs" "$EXT/index.ts" logretta_stack '{}' 2>&1)"
  if grep -qi "$1" <<<"$out"; then ok "stack refuses: $1"; else bad "expected '$1', got: $out"; fi
}
bad_stack "unknown key" 'slots:
  - name: a
    model: x/y
    lens: architect
    rail: local
  - name: b
    model: x/z
    lens: skeptic
    rail: local
bogus: 1'
bad_stack "rail must be" 'slots:
  - name: a
    model: x/y
    lens: architect
    rail: cloud
  - name: b
    model: x/z
    lens: skeptic
    rail: local'
bad_stack "needs 2" 'slots:
  - name: a
    model: x/y
    lens: architect
    rail: local'
bad_stack "fully-qualified" 'slots:
  - name: a
    model: qwen-35b
    lens: architect
    rail: local
  - name: b
    model: x/z
    lens: skeptic
    rail: local'

out="$(LOGRETTA_STACK="$TMP/nope.yaml" node "$TMP/drive.mjs" "$EXT/index.ts" logretta_stack '{}' 2>&1)"
if grep -qi "no stack at" <<<"$out"; then ok "a missing stack is a loud skip, never an invented roster"; else bad "missing stack not reported: $out"; fi

# ── 5: the budget stops the council ──────────────────────────────────────────
sed -i 's/max_total_chars: 60000/max_total_chars: 2000/' "$TMP/stack.yaml"
cat >"$TMP/bin/pi" <<'STUB'
#!/usr/bin/env bash
python3 - <<'PY'
import json
print(json.dumps({"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"X"*1500}}))
PY
STUB
chmod +x "$TMP/bin/pi"
res="$(run_tool logretta_sit '{"topic":"spend everything"}')"
if grep -q "BUDGET" <<<"$res"; then ok "the budget line stops the council loudly"; else bad "budget not enforced"; fi

[ "$fail" = 0 ] && printf '\nlogretta: all laws hold\n'
exit "$fail"
