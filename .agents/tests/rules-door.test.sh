#!/usr/bin/env bash
# rules-door.test.sh — does the law answer, and does it answer HONESTLY?
#
# The promise is not "prints something" — it is:
#   1 a topic that a law covers returns that law, quoted
#   2 a topic NO law covers says so, and hands over the whole (small) law rather than inventing one
#   3 the gate list is read from ci-verify.sh, not asserted
#   4 it registers only its OWN tools (one door, one registration — register §12)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/.pi/shared/extensions/rules.ts"
pass=0; fail=0
ok(){ printf 'ok - %s\n' "$1"; pass=$((pass+1)); }
no(){ printf 'not ok - %s\n' "$1" >&2; fail=$((fail+1)); }

H="$(mktemp /tmp/rules-door.XXXXXX.mjs)"; trap 'rm -f "$H"' EXIT
cat > "$H" <<'MJS'
const mod = await import(process.argv[2]);
const tools = [];
mod.default({ registerTool: (t) => tools.push(t), on: () => {} });
const call = async (n, a) => (await tools.find((t) => t.name === n).handler(a)).output;
const mode = process.argv[3];
if (mode === 'names') console.log(tools.map((t) => t.name).join(','));
if (mode === 'rule')  console.log(await call('ymir_rule', { topic: process.argv[4] }));
if (mode === 'gates') console.log(await call('ymir_gates', {}));
MJS

[ -r "$SRC" ] || { no "no extension source at $SRC"; exit 1; }

names="$(node --experimental-strip-types "$H" "$SRC" names 2>/dev/null)"
[ "$names" = "ymir_rule,ymir_gates" ] \
  && ok "the rules door registers exactly its OWN two tools (no tool belongs to two doors)" \
  || no "unexpected tool set: $names"

out="$(node --experimental-strip-types "$H" "$SRC" rule "delete" 2>/dev/null)"
printf '%s' "$out" | grep -q "11-never-delete-only-move.md" \
  && ok "a covered topic returns the law that covers it, by name" \
  || no "the law about deleting was not returned: $out"
printf '%s' "$out" | grep -q "quoted from RULES/" \
  && ok "it says WHERE the law came from" || no "no provenance in the answer"

out="$(node --experimental-strip-types "$H" "$SRC" rule "xylophone" 2>/dev/null)"
printf '%s' "$out" | grep -qi "no law in RULES/ mentions" \
  && ok "a topic NO law covers says so plainly — and does not invent one" \
  || no "it answered something for a topic no law covers: $out"
printf '%s' "$out" | grep -q "the whole law" \
  && ok "and hands over the whole law, which is small enough to read" \
  || no "no fallback to the whole law"

out="$(node --experimental-strip-types "$H" "$SRC" gates 2>/dev/null)"
printf '%s' "$out" | grep -q 'ci-verify\[' \
  && ok "the gate list is READ from ci-verify.sh, not asserted" || no "no gate list"
printf '%s' "$out" | grep -q "silently absent" \
  && ok "it carries the law it is quoting (a gate that runs nowhere)" \
  || no "the gate surface lost its warning"

printf 'rules-door: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1