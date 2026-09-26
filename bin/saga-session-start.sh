#!/usr/bin/env bash
# saga-session-start.sh - the one-command Brokk session start.
#
# Sága ("the seeress", who sees all that happens) collapses the Brokk runtime's
# session start into ONE ordered digest, so a harness opens in one or two turns
# instead of many reads. Ported from the upstream agent-distro reference for plan 29
# (memory/plans/core/29-brokk-distro-runtime.md).
#
# Stages, in order:
#   1. lock            acquire the per-home session lock first
#   2. bootstrap       detect-only diagnostics (tool floors, realm env)
#   3. wake queue      present durable wakes (Ratatoskr inbox + approvals)
#   4. supervision     the operating block for the detected harness
#   5. fleet digest    Eindri tasks / open forge orders / state metadata
#   6. context digest  realm, operator, projects, learnings, hood (ABSENT explicit)
#   7. cron start      ensure the scheduled jobs are running (idempotent)
#   8. next step       closing pointer
#
# Read-once: the digest is this turn's startup input. Do not re-read the sources
# it just printed unless one was reported absent or corrupt.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The operator's records live in the HOME they chose, never in the code tree
# (Rule 04). Resolve every shelf through bin/hoard-lib.sh, exactly as the shell
# tools do — the digest once defaulted DATA to $BROKK_HOME/data (the TREE), so it
# printed "operator: ABSENT, projects: ABSENT, learnings: ABSENT" at every session
# while the real files sat in $YMIR_HOME/hodd/data/ (2026-09-23). A digest that
# cannot see its own records is worse than no digest.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
hoard_state_dir  _HS 2>/dev/null; hoard_data_dir  _HD 2>/dev/null; hoard_settings_dir _HC 2>/dev/null
STATE="${BROKK_STATE_OVERRIDE:-${_HS:-$BROKK_HOME/state}}"
DATA="${BROKK_DATA_OVERRIDE:-${_HD:-$BROKK_HOME/data}}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-${_HC:-$BROKK_HOME/config}}"
unset _HS _HD _HC
# shellcheck source=bin/gleipnir-lock-lib.sh
. "$SCRIPT_DIR/gleipnir-lock-lib.sh"
gleipnir_lock_reap

REALM="${BROKK_REALM:-}"
if [ -z "$REALM" ] && [ -r "$DATA/realm.md" ]; then
  REALM=$(head -n 1 "$DATA/realm.md" 2>/dev/null | tr -d '[:space:]')
fi
REALM="${REALM:-}"
# Never assume the company's slug: resolve the operator's realm neutrally.
if [ -z "$REALM" ]; then . "$SCRIPT_DIR/realm-lib.sh"; ymir_active_realm "$ROOT" REALM; fi

section() { printf '\n== %s ==\n' "$1"; }

LOCKED=0
owner=""
if gleipnir_lock_acquire; then
  LOCKED=1
else
  gleipnir_lock_owner owner
fi

# A SEAT MARKER for the opt-in gate (plan 58 Phase 0c). The nine Ymir extensions
# deploy GLOBALLY, so every `pi` session on the machine loads them and resolves
# the same machine lock; on 2026-09-25 an unrelated session could reclaim a lock
# the primary had lost. Only a session SEATED here may reclaim it. The marker
# records the pid the lock was acquired for; the extensions prove ownership by
# ancestry against it.
if [ "$LOCKED" = "1" ]; then
  gleipnir_session_pid _seat_pid 2>/dev/null || _seat_pid=""
  mkdir -p "$STATE" 2>/dev/null || true
  printf '%s\n' "${_seat_pid:-${BROKK_SESSION_PID:-$$}}" >"$STATE/.seated" 2>/dev/null || true
  unset _seat_pid
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
# The well: keep the Mimirsbrunn (engram) bridge alive so recall never fires dry.
if [ -x "$SCRIPT_DIR/mimir-bridge.sh" ]; then
  if "$SCRIPT_DIR/mimir-bridge.sh" --start >/dev/null 2>&1; then
    printf 'well bridge: up\n'
  else
    printf 'well bridge: not up (see state/mimir-bridge.log)\n'
  fi
fi
# The operator's home: env -> the recorded choice -> the ONE documented default
# (Rule 07; the default lives in bin/hoard-lib.sh, never in a script).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _ymir_yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _ymir_yc in "$_ymir_yr/hoard-lib.sh" "$(dirname "$_ymir_yr")/bin/hoard-lib.sh"; do
    [ -r "$_ymir_yc" ] && { . "$_ymir_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _ymir_yr _ymir_yc
fi
ymir_home_root YMIR_HOME
if [ -r "${YMIR_HOME}/svartalfaheim/$REALM/.env.realm" ]; then
  printf 'realm env: present\n'
elif [ -r "$ROOT/svartalfaheim/$REALM/.env.realm" ]; then
  printf 'realm env: present\n'
else
  printf 'realm env: ABSENT (%s)\n' "svartalfaheim/$REALM/.env.realm"
fi

section "WAKE QUEUE"
# The handoff failsafe runs BEFORE the drain: it sweeps the report/question
# shelves for anything not yet delivered to Brokk and puts it in the wake queue.
# The fast road is the when-adapter; this is the slow road that cannot be missed
# (the runner may be down, or a spec may have been written into a worktree).
# Without it, a finished Eindri's work sits on the shelf unseen.
if [ -x "$SCRIPT_DIR/eindri-handoff.sh" ]; then
  BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/eindri-handoff.sh" sweep 2>/dev/null || true
fi
if [ -x "$SCRIPT_DIR/saga-wake-drain.sh" ]; then
  BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/saga-wake-drain.sh" || true
else
  printf 'wake queue: 0 pending (drain not installed)\n'
fi

section "SUPERVISION"
printf 'harness next step: arm supervision via the installed harness adapter; never run bin/syn-watch-arm.sh by hand.\n'

section "UPDATE"
# Does a newer Ymir stand on npm? The CLI told the USER; the RUNTIME had no such
# sense, so a session could run for days on an old tree and never know a fix had
# shipped (2026-09-23). One cached lookup a day; silence when there is no news.
if [ -x "$SCRIPT_DIR/ymir-update-check.sh" ]; then
  out="$(BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/ymir-update-check.sh" 2>/dev/null)"; rc=$?
  if [ "$rc" = "3" ]; then printf '%s\n' "$out"
  else printf 'current — no newer Ymir on npm\n'; fi
else
  printf 'check not installed\n'
fi

section "FLEET DIGEST"
if [ -d "$STATE" ]; then
  metas=$(find "$STATE" -maxdepth 1 -name '*.meta' 2>/dev/null | wc -l | tr -d '[:space:]')
  printf 'task metadata records: %s\n' "${metas:-0}"
else
  printf 'task metadata records: 0\n'
fi
MP="${BROKK_MASTERPLAN:-${YMIR_HOME}/hodd/docs/masterplan.md}"
if [ -r "$MP" ]; then
  open=$(grep -c '^- Status: ADDED' "$MP" 2>/dev/null || echo 0)
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
# The hood: the map of the Allfather's private + company holdings. Printed
# whole from the realm seat so a session opens knowing the lay of the land.
HOOD_FILE="$ROOT/svartalfaheim/$REALM/HOOD.md"
[ -r "${YMIR_HOME}/svartalfaheim/$REALM/HOOD.md" ] && HOOD_FILE="${YMIR_HOME}/svartalfaheim/$REALM/HOOD.md"
emit_context "$HOOD_FILE" "hood"

section "TODAY"
# The day's work, so a session opens knowing what was already forged. Written by
# bin/daily-log.sh into the hoard shelf the contract names
# ($YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md) — the record a random document in
# hodd/docs is not.
if [ -x "$SCRIPT_DIR/daily-log.sh" ]; then
  BROKK_HOME="$BROKK_HOME" "$SCRIPT_DIR/daily-log.sh" today 2>/dev/null | head -24 || printf 'no entries yet\n'
else
  printf 'daily-log.sh not installed\n'
fi

section "ASSET ROUTING"
# Load the owning asset BEFORE editing a governed path. A code change not
# reflected in its asset is an incomplete change. Router: galdr/SKILL.md.
printf 'governed[6]{path,load_first}:\n'
printf '  "bin/ymir-install.sh",".agents/skills/galdr-ymirsystem/assets/installation.md"\n'
printf '  "apps/hlidskjalf/**",".agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md"\n'
printf '  "bin/mimir*",".agents/skills/galdr-ymirsystem/assets/memory-well.md"\n'
printf '  "bin/nornir-* | config/cron.yaml",".agents/skills/galdr-ymirsystem/assets/nornir-jobs.md"\n'
printf '  "bin/valknut-load.sh | .pi/**",".agents/skills/galdr-ymirsystem/assets/harness-integration/README.md"\n'
printf '  "bin/smidja* | .agents/skills/smidja-factory/**",".agents/skills/galdr-ymirsystem/assets/smidja.md"\n'
printf 'rule: load the asset, then change the code, then update the asset in the same change.\n'

section "TOOL SURFACE"
# The Allfather's own handles into this machine. Know them; name them when he
# would reach for one.
printf 'tools[4]{handle,what}:\n'
printf '  "/edit <path>","open a file in his own editor (ctrl+shift+e for the picker)"\n'
printf '  "bin/ymir-say.sh","Ymir speaks on the desktop (done/alarm/fail/note)"\n'
printf '  "bin/omarchy-plugins.sh","the suggested Omarchy shell plugins; add/list"\n'
printf '  "bin/herdr-run.sh","seat an Eindri in a herdr tab, or a disposable space"\n'

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
