#!/usr/bin/env bash
# load-agents-md.sh — Claude Code SessionStart: inject the project's AGENTS.md into context.
#
# Claude Code auto-loads CLAUDE.md and never a project's AGENTS.md, so a repo whose contract
# lives in AGENTS.md (this one does) is invisible to it. This hook closes the gap: it prints
# $CLAUDE_PROJECT_DIR/AGENTS.md as `additionalContext`.
#
# It SKIPS (prints nothing) when there is no AGENTS.md, or when CLAUDE.md already carries it —
# CLAUDE.md is a link to AGENTS.md, or imports it with an `@AGENTS.md` line — so the contract
# is never loaded twice.
#
# Seated by bin/seat/harness-extensions-install.sh into ~/.claude/hooks/, and wired there as ONE
# named SessionStart entry in ~/.claude/settings.json (never a blind merge). Always exits 0: a
# SessionStart hook that fails must never block a session from opening.
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
f="$dir/AGENTS.md"
[ -f "$f" ] || exit 0
c="$dir/CLAUDE.md"
if [ -e "$c" ]; then
  [ "$(readlink -f "$c")" = "$(readlink -f "$f")" ] && exit 0
  grep -qE '^@(\./)?AGENTS\.md' "$c" && exit 0
fi
if command -v jq >/dev/null 2>&1; then
  jq -n --arg p "$f" --rawfile body "$f" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:("Contents of " + $p + " (project instructions, auto-loaded by SessionStart hook):\n\n" + $body)}}'
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$f" <<'PY'
import json, sys
p = sys.argv[1]
body = open(p, encoding="utf-8", errors="replace").read()
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
      "additionalContext": f"Contents of {p} (project instructions, auto-loaded by SessionStart hook):\n\n{body}"}}))
PY
fi
exit 0
