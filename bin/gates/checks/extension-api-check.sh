#!/usr/bin/env bash
# extension-api-check.sh — a Ymir extension must speak Pi's ACTUAL tool API.
#
# WHY (2026-10-03): every Ymir tool in the hall died at once with
# `definition.execute is not a function`. All 15 extensions registered tools with `handler:`;
# Pi 1.0's ToolDefinition has NO `handler` field — the body is `execute`. Pi accepted the
# registration, advertised the tool to the model, and then failed at call time. Three
# different tools, one cause: one bug wearing three hats.
#
# Nothing caught it, because every check that ran said yes:
#   · it PARSED       — `handler:` is valid object syntax
#   · it REGISTERED   — Pi advertises the definition happily
#   · a smoke test called `tool.handler(args)` — with the SAME wrong key the code used, so the
#     test proved the bug rather than the tool
#
# So this gate checks the SEAM — the shape Pi calls through — and not the file's syntax.
# Reference: the operator vault, hodd/docs/developer-setup/pi-extension-api.md
#            https://pi.dev/docs/latest/extensions
#            ~/.npm-global/.../pi-coding-agent/examples/extensions/hello.ts
#
#   bin/extension-api-check.sh           # check every source extension
#   bin/extension-api-check.sh --quiet   # exit code only, for CI
#
# It checks the SOURCE shelf (.pi/shared/extensions). The seat copies it; verify-seat proves the
# copy parses. Copying the mistake faithfully is not a new mistake.
set -uo pipefail

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" || exit 2
SRC="$ROOT/.pi/shared/extensions"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

[ -d "$SRC" ] || { echo "extension-api-check: no $SRC" >&2; exit 1; }

bad=0
found=0

for f in "$SRC"/*.ts; do
  [ -f "$f" ] || continue
  found=1
  name="$(basename "$f")"
  rel=".pi/shared/extensions/$name"

  # 1. THE key — but ONLY inside registerTool. `pi.registerCommand` and `pi.on(...)` handlers
  #    legitimately take a `handler` key, and flagging those would be the gate crying wolf.
  _tool_handler="$(python3 - "$f" <<'PYBLOCK'
import re, sys
s = open(sys.argv[1]).read()
for m in re.finditer(r'pi\.registerTool\(\{', s):
    i, depth, j = m.end(), 1, m.end()
    while j < len(s) and depth:
        if s[j] == '{': depth += 1
        elif s[j] == '}': depth -= 1
        j += 1
    blk = s[i:j]
    for ln in blk.splitlines():
        if re.match(r'\s*handler:', ln):
            print(ln.strip()[:72])
PYBLOCK
)"
  if [ -n "$_tool_handler" ]; then
    printf 'extension_api[1]{file,why,fix}: "%s","registers handler: — Pi calls definition.execute(...), and ToolDefinition has no handler field, so every call fails with definition.execute is not a function","rename the key to execute: and use the harness signature execute(toolCallId, params, signal, onUpdate, ctx)"\n' "$rel"
    printf '%s\n' "$_tool_handler" | head -3 | sed 's/^/    /'
    bad=$((bad + 1))
  fi

  # 2. THE first argument. A renamed handler keeps `async (args)` and would silently receive
  #    the TOOL CALL ID (a string) where it expects the params object. That is a tool which
  #    runs and answers wrongly — worse than one that throws.
  if grep -nE 'execute:[[:space:]]*async[[:space:]]*\([[:space:]]*args\b' "$f" >/dev/null 2>&1; then
    printf 'extension_api[1]{file,why,fix}: "%s","execute() first parameter is the toolCallId; naming it args means the body gets a STRING where it expects the params object — a silent wrong answer","use async (_toolCallId, params, _signal, _onUpdate, _ctx)"\n' "$rel"
    grep -nE 'execute:[[:space:]]*async[[:space:]]*\([[:space:]]*args\b' "$f" | head -3 | sed 's/^/    /'
    bad=$((bad + 1))
  fi

  # 3. THE result. `{ output: ... }` is not what the harness reads; it needs `content`. And
  #    returning an object does NOT mark a tool as failed — only throwing does.
  if grep -qE 'return[[:space:]]*\{[[:space:]]*output:' "$f"; then
    printf 'extension_api[1]{file,why,fix}: "%s","returns { output: … }; the harness reads content:[{type:\"text\",text}] and details. An {output} result reaches the model as an empty success","return { content: [{ type: \"text\", text }], details: undefined } — and THROW to report a failure, because returning an object does not mark it as an error"\n' "$rel"
    grep -nE 'return[[:space:]]*\{[[:space:]]*output:' "$f" | head -2 | sed 's/^/    /'
    bad=$((bad + 1))
  fi
done

[ "$found" = 1 ] || { echo "extension-api-check: no extensions found" >&2; exit 1; }

if [ "$bad" -eq 0 ]; then
  [ "$QUIET" = 1 ] || printf 'extension_api[2]{extensions,bad}: "%s","0"\n' "$(ls "$SRC"/*.ts | wc -l | tr -d ' ')"
  exit 0
fi

cat >&2 <<MSG
extension-api-check: $bad extension(s) do not speak Pi's tool API.

  Pi 1.0 registers a tool with execute(toolCallId, params, signal, onUpdate, ctx) and reads
  { content, details } back. A tool registered any other way is ADVERTISED to the model and
  then fails on first use — which is what happened to every Ymir door on 2026-10-03.

  The whole reference, quoted from the installed package:
    the operator vault: hodd/docs/developer-setup/pi-extension-api.md
    https://pi.dev/docs/latest/extensions
    ~/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/hello.ts
MSG
exit 1
