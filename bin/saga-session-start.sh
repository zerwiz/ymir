#!/usr/bin/env bash
# saga-session-start.sh - the one-command Brokk session start.
#
# Sága ("the seeress", who sees all that happens) collapses the Brokk runtime's
# session start into ONE ordered digest, so a harness opens in one or two turns
# instead of many reads. Ported from the upstream agent-distro reference for plan 29
# (docs/plans/29-brokk-distro-runtime.md).
#
# Stages, in order:
#   1. lock            acquire the per-home session lock first
#   2. bootstrap       detect-only diagnostics (tool floors, realm env)
#   3. wake queue      present durable wakes (Ratatoskr inbox + approvals)
#   4. supervision     the operating block for the detected harness
#   5. fleet digest    Eindri tasks / open forge orders / state metadata
#   6. context digest  realm, operator, projects, learnings (ABSENT explicit)
#   7. cron start      ensure the scheduled jobs are running (idempotent)
#   8. next step       closing pointer
#
# Read-once: the digest is this turn's startup input. Do not re-read the sources
# it just printed unless one was reported absent or corrupt.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-$BROKK_HOME/config}"
# shellcheck source=bin/gleipnir-lock-lib.sh
. "$SCRIPT_DIR/gleipnir-lock-lib.sh"

REALM="${BROKK_REALM:-}"
if [ -z "$REALM" ] && [ -r "$DATA/realm.md" ]; then
  REALM=$(head -n 1 "$DATA/realm.md" 2>/dev/null | tr -d '[:space:]')
fi
REALM="${REALM:-way-of}"

section() { printf '\n== %s ==\n' "$1"; }

LOCKED=0
owner=""
if gleipnir_lock_acquire; then
  LOCKED=1
else
  gleipnir_lock_owner owner
fi

printf 'BROKK SESSION START - %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'home=%s realm=%s\n' "$BROKK_HOME" "$REALM"

section "LOCK"
if [ "$LOCKED" = "1" ]; then
  printf 'session lock held (pid %s)\n' "${BROKK_SESSION_PID:-$$}"
else
  printf 'READ-ONLY: session lock held by pid %s - no spawn, steer, merge, drain, or repair this session\n' "${owner:-unknown}"
fi

section "BOOTSTRAP"
missing=""
for tool in git bash node; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  printf 'MISSING:%s\n' "$missing"
else
  printf 'tool floors OK\n'
fi
# Model bridge: keep Pi's opencode-go endpoint alive so a session never 401s.
if [ -x "$SCRIPT_DIR/bifrost-bridge.sh" ]; then
  if BROKK_ENV_FILE="$BROKK_HOME/.env.local" "$SCRIPT_DIR/bifrost-bridge.sh" --start >/dev/null 2>&1; then
    printf 'model bridge: up\n'
  else
    printf 'model bridge: not up (see state/model-bridge.log)\n'
  fi
fi
if [ -r "$BROKK_HOME/svartalfaheim/$REALM/.env.realm" ]; then
  printf 'realm env: present\n'
elif [ -r "$ROOT/svartalfaheim/$REALM/.env.realm" ]; then
  printf 'realm env: present\n'
else
  printf 'realm env: ABSENT (%s)\n' "svartalfaheim/$REALM/.env.realm"
fi

section "WAKE QUEUE"
if [ -x "$SCRIPT_DIR/saga-wake-drain.sh" ]; then
  BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/saga-wake-drain.sh" || true
else
  printf 'wake queue: 0 pending (drain not installed)\n'
fi

section "SUPERVISION"
printf 'harness next step: arm supervision via the installed harness adapter; never run bin/syn-watch-arm.sh by hand.\n'

section "FLEET DIGEST"
if [ -d "$STATE" ]; then
  metas=$(find "$STATE" -maxdepth 1 -name '*.meta' 2>/dev/null | wc -l | tr -d '[:space:]')
  printf 'task metadata records: %s\n' "${metas:-0}"
else
  printf 'task metadata records: 0\n'
fi
if [ -r "$ROOT/docs/masterplan.md" ]; then
  open=$(grep -c '^- Status: ADDED' "$ROOT/docs/masterplan.md" 2>/dev/null || echo 0)
  printf 'open forge orders: %s\n' "${open:-0}"
fi

section "CONTEXT DIGEST"
emit_context() {  # <path> <label>
  local path=$1 label=$2
  printf -- '--- %s ---\n' "$label"
  if [ -r "$path" ]; then
    cat "$path"
  else
    printf 'ABSENT: %s\n' "$path"
  fi
}
printf -- '--- realm ---\n%s\n' "$REALM"
emit_context "$DATA/operator.md" "operator"
emit_context "$DATA/projects.md" "projects"
emit_context "$DATA/learnings.md" "learnings"

section "CRON START"
if [ -x "$SCRIPT_DIR/nornir-cron-start.sh" ]; then
  BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/nornir-cron-start.sh" || printf 'cron: start reported a failure (see above)\n'
else
  printf 'cron: not installed (bin/nornir-cron-start.sh absent)\n'
fi

section "NEXT STEP"
printf 'Ascend Hlidskjalf as Brokk. Address the Allfather. Read once; act.\n'

if [ "$LOCKED" = "1" ]; then
  # The lock is held for the life of this script's session; the harness owns
  # continuance. Release only if we are the lock owner and no session is live.
  :
fi
