#!/usr/bin/env bash
# nornir-job-asken-handoff.sh — the rollover, on the schedule.
#
# The handoff is automatic at the moment a surface calls it (the OpenCode plugin,
# the Zed task). This job is the backstop: once a day every repository that carries
# a .asken state is handed off regardless of measured pressure, so a session that
# died without a reporter still leaves a fresh HANDOFF.md behind. Stateless:
# trigger, record a rune, exit. Best-effort: a missing asken is a skip, never a
# failure, and the job always exits 0 so one absent tool cannot fail the schedule.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ASKEN_BIN="${ASKEN_BIN:-$(command -v asken 2>/dev/null || true)}"
if [ -z "$ASKEN_BIN" ] || [ ! -x "$ASKEN_BIN" ]; then
  printf 'nornir-job-asken-handoff[1]{state}:\n  "skip","asken is not on PATH"\n'
  exit 0
fi

# A colon- or space-separated list, defaulting to this repository alone.
repos="${ASKEN_REPOS:-$ROOT}"
repos="${repos//:/ }"

count=0
acted=0
rows=""
for repo in $repos; do
  [ -n "$repo" ] || continue
  # Only a repository that has been initialised carries a handoff to refresh;
  # ASKEN_INIT_ALL opts every listed repository in regardless.
  [ -d "$repo/.asken" ] || [ -n "${ASKEN_INIT_ALL:-}" ] || continue
  count=$((count + 1))
  # --force so the refresh is unconditional, and no --no-anchor: the Anchor sync
  # is time-bounded inside asken and skipped when Anchor is down, so a scheduled
  # roll is mirrored to the memory plane and the job still never blocks.
  verdict="$("$ASKEN_BIN" trigger --force --repo "$repo" --quiet 2>&1)"
  head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || printf '?')"
  if printf '%s' "$verdict" | grep -q '"acted": true'; then
    acted=$((acted + 1))
    rows="${rows}  \"$(basename "$repo")\",\"$head\",true\n"
  else
    rows="${rows}  \"$(basename "$repo")\",\"$head\",false\n"
  fi
done

if [ "$count" -eq 0 ]; then
  printf 'nornir-job-asken-handoff[1]{state}:\n  "skip","no repository carries .asken"\n'
  exit 0
fi

printf 'nornir-job-asken-handoff[%s]{repo,head,acted}:\n' "$count"
printf '%b' "$rows"

if [ -r "$ROOT/bin/runes-append.sh" ]; then
  # shellcheck source=bin/runes-append.sh
  . "$ROOT/bin/runes-append.sh"
  runes_append "nornir" "asken.handoff" --message "Rolled $acted of $count repository handoff(s)" >/dev/null \
    || printf 'nornir-job-asken-handoff: rune append failed (non-fatal)\n'
fi
exit 0
