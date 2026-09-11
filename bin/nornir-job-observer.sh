#!/usr/bin/env bash
# nornir-job-observer.sh - Huginn, the raven of observation.
#
# Read-only observation of the Ymir runtime into Runes. This job touches nothing
# outside Ymir; every source below lives inside the repo (or the external worktree
# root, which is read-only):
#   docs/masterplan.md               open forge orders
#   .agents/agents/*.md              the agent roster
#   .agents/memory/well/             the well (episodes)
#   workspace/memory/runes_audit.md  the ledger
#   smidja/smidja_data/smidja.db     Smíðja runs (read-only SQLite URI)
#   ~/.treehouse                     external worktrees (read-only)
#
# CONTRACT: this job NEVER writes anywhere but state/observer.log and the Runes
# ledger. It only reads manifests, SQLite databases in read-only mode, and small
# state files. Every observation is carved as a Runes line and echoed to
# state/observer.log. When a source is absent the job still carves an ABSENT
# line — silence is never mistaken for health.
#
# Environment:
#   BROKK_YGGDRASIL_ROOT  external worktree root to observe (default ~/.treehouse)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
# shellcheck source=bin/runes-append.sh
. "$SCRIPT_DIR/runes-append.sh"

WORKTREE_ROOT="${BROKK_YGGDRASIL_ROOT:-$HOME/.treehouse}"
SMIDJA_DB="$ROOT/smidja/smidja_data/smidja.db"
MASTERPLAN="$ROOT/docs/masterplan.md"
WELL_DIR="$ROOT/.agents/memory/well"
AGENTS_DIR="$ROOT/.agents/agents"
RUNES_LEDGER="$ROOT/workspace/memory/runes_audit.md"
OBS_LOG="$STATE/observer.log"
OBS_LAST="$STATE/observer.last"

mkdir -p "$STATE"
LOG_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

observe() {  # <source> <message>
  local source=$1 message=$2
  printf '%s observer %s: %s\n' "$LOG_TS" "$source" "$message" >>"$OBS_LOG"
  runes_append "huginn" "observer.$source" --message "$message" >/dev/null 2>&1 || true
}

printf 'OBSERVER - %s\n' "$LOG_TS"
printf 'root=%s worktrees=%s\n' "$ROOT" "$WORKTREE_ROOT"

# ---- ymir: forge orders (masterplan) -------------------------------------
if [ -r "$MASTERPLAN" ]; then
  open=$(grep -cE '^- Status: ADDED' "$MASTERPLAN" 2>/dev/null | tr -d '[:space:]')
  working=$(grep -cE '^- Status:.*WORKING' "$MASTERPLAN" 2>/dev/null | tr -d '[:space:]')
  done=$(grep -cE '\. \+ <[0-9]{4}' "$MASTERPLAN" 2>/dev/null | tr -d '[:space:]')
  msg="masterplan readable; open=${open:-0} working=${working:-0} completed_notes=${done:-0}"
  printf 'ymir.orders open=%s working=%s\n' "${open:-0}" "${working:-0}"
else
  msg="masterplan ABSENT at $MASTERPLAN"
  printf 'ymir.orders ABSENT\n'
fi
observe "ymir.orders" "$msg"

# ---- ymir: agent roster ---------------------------------------------------
if [ -d "$AGENTS_DIR" ]; then
  n=$(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
  msg="agent roster readable; agents=${n:-0}"
  printf 'ymir.agents count=%s\n' "${n:-0}"
else
  msg="agent roster ABSENT at $AGENTS_DIR"
  printf 'ymir.agents ABSENT\n'
fi
observe "ymir.agents" "$msg"

# ---- ymir: the well (episodes) -------------------------------------------
if [ -d "$WELL_DIR" ]; then
  episodes=0
  for f in "$WELL_DIR"/*.jsonl; do
    [ -r "$f" ] || continue
    c=$(wc -l <"$f" 2>/dev/null | tr -d '[:space:]')
    episodes=$((episodes + ${c:-0}))
  done
  msg="well readable; episodes=${episodes}"
  printf 'ymir.well episodes=%s\n' "$episodes"
else
  msg="well ABSENT at $WELL_DIR"
  printf 'ymir.well ABSENT\n'
fi
observe "ymir.well" "$msg"

# ---- ymir: the ledger -----------------------------------------------------
if [ -r "$RUNES_LEDGER" ]; then
  lines=$(wc -l <"$RUNES_LEDGER" 2>/dev/null | tr -d '[:space:]')
  msg="runes ledger readable; lines=${lines:-0}"
  printf 'ymir.runes lines=%s\n' "${lines:-0}"
else
  msg="runes ledger ABSENT at $RUNES_LEDGER"
  printf 'ymir.runes ABSENT\n'
fi
observe "ymir.runes" "$msg"

# ---- smidja: runs (smidja.db, read-only) ---------------------------------
if [ -r "$SMIDJA_DB" ] && command -v python3 >/dev/null 2>&1; then
  smidja_summary=$(python3 - "$SMIDJA_DB" 2>/dev/null <<'PY'
import sqlite3, sys
db = sys.argv[1]
try:
    c = sqlite3.connect('file:' + db + '?mode=ro', uri=True, timeout=3)
except Exception as e:
    print("open_failed=%s" % e)
    sys.exit(0)
def q(sql, default=None):
    try:
        return c.execute(sql).fetchone()[0]
    except Exception:
        return default
sessions = q("select count(*) from sessions", 0)
phases = q("select count(*) from phases", 0)
gates = q("select count(*) from gate_results", 0)
gate_fail = q("select count(*) from gate_results where passed=0", 0)
print("sessions=%s phases=%s gates=%s gate_fail=%s" % (sessions, phases, gates, gate_fail))
try:
    rows = c.execute("select smidja_id,status from sessions order by rowid desc limit 3").fetchall()
    print("recent=" + ",".join("%s:%s" % (r[0], r[1]) for r in rows))
except Exception as e:
    print("recent=unavailable(%s)" % e)
try:
    rows = c.execute("select status,count(*) from phases group by status order by 2 desc limit 5").fetchall()
    print("phase_status=" + ",".join("%s:%s" % (r[0], r[1]) for r in rows))
except Exception as e:
    print("phase_status=unavailable(%s)" % e)
c.close()
PY
)
  first_line=$(printf '%s' "$smidja_summary" | head -n 1)
  msg="smidja.db read-only: ${first_line:-unreadable}"
  printf 'smidja.runs %s\n' "$msg"
  printf '%s\n' "$smidja_summary" | tail -n +2 | sed 's/^/  /'
else
  if [ ! -r "$SMIDJA_DB" ]; then
    msg="smidja.db ABSENT at $SMIDJA_DB"
  else
    msg="smidja.db present but python3 unavailable for read-only query"
  fi
  printf 'smidja.runs ABSENT/UNREADABLE\n'
fi
observe "smidja.runs" "$msg"

# ---- worktrees (external, read-only) -------------------------------------
if [ -d "$WORKTREE_ROOT" ]; then
  wt_count=$(find "$WORKTREE_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')
  state_files=$(find "$WORKTREE_ROOT" -mindepth 2 -maxdepth 2 -name 'treehouse-state.json' 2>/dev/null | wc -l | tr -d '[:space:]')
  msg="worktrees=${wt_count:-0} state_files=${state_files:-0}"
  printf 'yggdrasil.worktrees trees=%s state_files=%s\n' "${wt_count:-0}" "${state_files:-0}"
else
  msg="worktree root ABSENT at $WORKTREE_ROOT"
  printf 'yggdrasil.worktrees ABSENT\n'
fi
observe "yggdrasil.worktrees" "$msg"

printf '%s\n' "observer summary written: $LOG_TS" >"$OBS_LAST"
printf 'observer: observations carved (log=%s)\n' "$OBS_LOG"
