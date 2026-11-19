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
# An Eindri worker (a Yggdrasil worktree or a seat directory) never takes the arm — one helm.
# Without this the hook printed "stale: no live lease" in every worker pane and blocked each stop, a loop.
case "$(readlink -f "${CLAUDE_PROJECT_DIR:-$PWD}")" in */.yggdrasil/*|*/.local/state/ymir/seats/*) exit 0 ;; esac
root=""
while IFS= read -r r; do
  [ -x "$r/bin/pi/syn-watch-arm.sh" ] && { root="$r"; break; }
done < "$HOME/.pi/agent/extensions/.ymir-root" 2>/dev/null
[ -n "$root" ] || exit 0
# inside the house the project's own .claude/settings.json already arms it
[ "$(readlink -f "${CLAUDE_PROJECT_DIR:-.}")" = "$(readlink -f "$root")" ] && exit 0
# ATTACH ONLY (2026-11-19, measured): a Claude session that does NOT already hold the helm
# must never take it. The client enters a VACANT helm by design, and a Stop hook runs at every
# turn end — so any Claude seat quietly became the primary whenever it found no owner, and took
# the lock from the seat that held it (measured: 2243828 → 1557290 at 03:02 with 2243828 alive).
# Taking the helm is a deliberate act: bin/voice/rodd-arm.sh hold. Here we only attach — the
# owner test below guards an older pin whose client predates `--attach-only`.
if [ -r "$root/bin/vault/gleipnir-lock-lib.sh" ]; then
  . "$root/bin/vault/gleipnir-lock-lib.sh" 2>/dev/null || exit 0
  gleipnir_session_pid _sess 2>/dev/null || true
  _mine="${_sess:-$$}"
  _owner=""; gleipnir_lock_owner _owner 2>/dev/null || true
  [ -n "$_owner" ] && [ "$_owner" = "$_mine" ] || exit 0
fi

# plan 257 H6: the arm client this hook runs is the PIN's, never the tree's — a session
# must not carry its own branch into the supervisor. The tree's client hands over too, so
# an older pin with no lib still lands on one road.
client=""
[ -r "$root/bin/pi/arm-pin-lib.sh" ] && . "$root/bin/pi/arm-pin-lib.sh" && arm_pin_client client
out=$("${client:-$root/bin/pi/syn-watch-arm.sh}" --restart --attach-only); rc=$?
case "$out" in *signal:*|*stale:*|*check:*|*heartbeat:*) printf '%s\n' "$out" >&2; exit 2;; esac
exit $rc
