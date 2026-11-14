#!/usr/bin/env bash
# saga-session.sh — Claude Code SessionStart: Sága's ONE session-start digest.
#
# The fault this replaces (measured 2026-11-14, plan 275 item 28): the user-scope
# ~/.claude/settings.json carried THREE SessionStart entries, each a hardcoded
# absolute path to a different home (the checkout, a worktree under .yggdrasil/,
# and the pin), so every session start AND every compaction injected three full
# ~56 KB digests — about 125,000 tokens in one session.
#
# Now there is ONE entry and it resolves the home that is CURRENT, at the moment the
# session opens:
#
#   1. $BROKK_ROOT_OVERRIDE — a door that means a specific tree says so;
#   2. the session's own project ($CLAUDE_PROJECT_DIR, else $PWD) when it is a Ymir home;
#   3. the pin ~/ymir-runtime — what this machine actually runs;
#   4. ~/ymir — the source, last.
#
# The payload on stdin (which carries Claude's `source`) is handed to that home's own
# runner, so a `startup` runs the stages and the head, and a `compact` re-injects the
# head alone. This hook ALWAYS exits 0: a failed session start must never block a
# session from opening.
set -u

is_ymir_home() {  # <dir>
  [ -n "${1:-}" ] && [ -d "$1/.pi" ] && [ -d "$1/RULES" ] \
    && [ -x "$1/bin/time/saga-sessionstart-run.sh" ]
}

root_of() {  # <dir> — walk up for a Ymir home
  local d="${1:-}"
  [ -n "$d" ] && [ -d "$d" ] || return 1
  d="$(cd "$d" 2>/dev/null && pwd)" || return 1
  while [ "$d" != "/" ]; do
    is_ymir_home "$d" && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

home=""
for cand in "${BROKK_ROOT_OVERRIDE:-}" "${CLAUDE_PROJECT_DIR:-}" "${PWD:-}"; do
  [ -n "$cand" ] || continue
  if r="$(root_of "$cand")"; then home="$r"; break; fi
done
if [ -z "$home" ]; then
  pin="$HOME/ymir-runtime"
  [ -e "$pin" ] && pin="$(readlink -f "$pin" 2>/dev/null || printf '%s' "$pin")"
  is_ymir_home "$pin" && home="$pin"
fi
if [ -z "$home" ]; then
  is_ymir_home "$HOME/ymir" && home="$HOME/ymir"
fi
[ -n "$home" ] || exit 0   # no Ymir on this machine: nothing to say, never a refusal

exec "$home/bin/time/saga-sessionstart-run.sh"
