#!/usr/bin/env bash
# claude-pretool.sh — Claude Code's PreToolUse seam onto the house's pre-tool checks (plan 239 P2).
#
# Claude hands the hook a JSON payload on stdin ({"tool_name":"Bash","tool_input":{"command":…}});
# the house's checks take `--command <text>`. This adapter reads the one, calls the others —
# the same two Pi's tool_call seam calls (.pi/extensions/syn-turnend-guard.ts) — and passes a
# refusal through as Claude's block: exit 2 with the reason on stderr.
#
# Inert for any tool but Bash and for an empty command. Never blocks on its own failure: a
# malformed payload or a missing check exits 0 (a broken seatbelt must not stop the hall).
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
payload="$(cat)"
cmd="$(printf '%s' "$payload" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
if d.get("tool_name")!="Bash": sys.exit(0)
print((d.get("tool_input") or {}).get("command") or "", end="")' 2>/dev/null)"
[ -n "$cmd" ] || exit 0
for check in syn-arm-pretool-check.sh syn-cd-pretool-check.sh; do
  script="$ROOT/bin/gates/checks/$check"
  [ -x "$script" ] || continue
  err="$("$script" --command "$cmd" 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" = 2 ]; then printf '%s\n' "${err:-denied by $check}" >&2; exit 2; fi
done
exit 0
