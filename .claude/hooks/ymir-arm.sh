#!/usr/bin/env bash
# ymir-arm.sh — Claude Code Stop hook (asyncRewake): the Gná arm reaches a Claude
# seat in ANY project, not only a session started in the Ymir house.
#
# The house's project-scope `.claude/settings.json` arms a session that is already
# inside ~/ymir. A Claude seat opened in any other repository has no such file, so
# it would never take a wake — the fleet would have a blind seat. This hook is the
# global answer: it resolves the house from pi's own root record
# (~/.pi/agent/extensions/.ymir-root), so it reaches every Claude session on the
# machine. Inside the house it exits immediately (the project hook is the one arm).
#
# Seated by bin/seat/harness-extensions-install.sh as ONE named asyncRewake Stop
# entry in ~/.claude/settings.json; mended by bin/agents/groa-update.sh (which runs
# that installer) and checked by bin/agents/eir-doctor.sh.
#
# One helm only: a session whose helm is held by another live session exits quietly
# (bin/pi/syn-watch-arm.sh's own contract), and an older client of the same session
# is retired by a new one so a signal cannot rewake the seat more than once.
[ -z "${GROK_AGENT:-}${GROK_HOOK_EVENT:-}" ] || exit 0
root=""
while IFS= read -r r; do
  [ -x "$r/bin/pi/syn-watch-arm.sh" ] && { root="$r"; break; }
done < "$HOME/.pi/agent/extensions/.ymir-root" 2>/dev/null
[ -n "$root" ] || exit 0
# inside the house the project's own .claude/settings.json already arms it
[ "$(readlink -f "${CLAUDE_PROJECT_DIR:-.}")" = "$(readlink -f "$root")" ] && exit 0
out=$("$root/bin/pi/syn-watch-arm.sh" --restart); rc=$?
case "$out" in *signal:*|*stale:*|*check:*|*heartbeat:*) printf '%s\n' "$out" >&2; exit 2;; esac
exit $rc
