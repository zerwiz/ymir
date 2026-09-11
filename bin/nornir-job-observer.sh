#!/usr/bin/env bash
# nornir-job-observer.sh - Huginn, the raven of observation.
#
# Read-only bridge from the Ymir runtime into the two external systems that
# already exist on this machine:
#   /home/zerwiz/command     FEATURES.md registry, .compliance/ gates,
#                            smidja runs (smidja.db), Kaia engram
#   /home/zerwiz/brokk   crew sessions, worktree state, outcomes
#
# CONTRACT: this job NEVER writes into either tree. It only reads manifests,
# SQLite databases in read-only mode, and small state files. Every observation
# is carved as a Runes line and echoed to state/observer.log. When a source is
# absent the job still carves an ABSENT line — silence is never mistaken for
# health.
#
# Environment:
#   BROKK_COMMAND_ROOT, BROKK_FIRSTMATE_ROOT     source roots (defaults below)
#   BROKK_YGGDRASIL_ROOT  external worktree root to observe (default ~/.treehouse)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
# shellcheck source=bin/runes-append.sh
. "$SCRIPT_DIR/runes-append.sh"

COMMAND_ROOT="${BROKK_COMMAND_ROOT:-/home/zerwiz/command}"
FIRSTMATE_ROOT="${BROKK_FIRSTMATE_ROOT:-/home/zerwiz/brokk}"
WORKTREE_ROOT="${BROKK_YGGDRASIL_ROOT:-$HOME/.treehouse}"
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
printf 'command=%s brokk=%s\n' "$COMMAND_ROOT" "$FIRSTMATE_ROOT"

# ---- command: FEATURES.md registry ---------------------------------------
if [ -r "$COMMAND_ROOT/FEATURES.md" ]; then
  projects=$(grep -cE '^\| `' "$COMMAND_ROOT/FEATURES.md" 2>/dev/null || printf 0)
  msg="FEATURES.md registry readable; projects=${projects:-0}"
  printf 'command.features projects=%s\n' "${projects:-0}"
else
  msg="FEATURES.md ABSENT at $COMMAND_ROOT/FEATURES.md"
  printf 'command.features ABSENT\n'
fi
observe "command.features" "$msg"

# ---- command: .compliance gates ------------------------------------------
if [ -d "$COMMAND_ROOT/.compliance" ]; then
  gates_dir="$COMMAND_ROOT/.compliance/gates"
  gate_count=0
  gate_names=""
  if [ -d "$gates_dir" ]; then
    gate_count=$(find "$gates_dir" -maxdepth 1 -name 'check_*.sh' 2>/dev/null | wc -l | tr -d '[:space:]')
    gate_names=$(find "$gates_dir" -maxdepth 1 -name 'check_*.sh' -printf '%f ' 2>/dev/null | sed 's/ $//')
  fi
  config_ok="absent"
  [ -r "$COMMAND_ROOT/.compliance/config/core_four.yaml" ] && config_ok="present"
  msg=".compliance present; gates=${gate_count:-0} [${gate_names}] core_four=${config_ok}"
  printf 'command.compliance gates=%s core_four=%s\n' "${gate_count:-0}" "$config_ok"
else
  msg=".compliance ABSENT under $COMMAND_ROOT"
  printf 'command.compliance ABSENT\n'
fi
observe "command.compliance" "$msg"

# ---- command: smidja runs (smidja.db, read-only) -----------------------
SMIDJA_DB="$COMMAND_ROOT/smidja/smidja_data/smidja.db"
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
  printf 'command.smidja %s\n' "$msg"
  printf '%s\n' "$smidja_summary" | tail -n +2 | sed 's/^/  /'
else
  if [ ! -r "$SMIDJA_DB" ]; then
    msg="smidja.db ABSENT at $SMIDJA_DB"
  else
    msg="smidja.db present but python3 unavailable for read-only query"
  fi
  printf 'command.smidja ABSENT/UNREADABLE\n'
fi
observe "command.smidja" "$msg"

# ---- command: Kaia engram ------------------------------------------------
ENGRAM="$COMMAND_ROOT/smidja/smidja_data/kaia.engram"
if [ -r "$ENGRAM" ]; then
  size=$(stat -c '%s' "$ENGRAM" 2>/dev/null || printf 0)
  mtime=$(stat -c '%y' "$ENGRAM" 2>/dev/null | cut -d'.' -f1)
  wal="absent"
  [ -e "$ENGRAM-wal" ] && wal="present"
  msg="kaia.engram size=${size}B wal=${wal} mtime=${mtime}"
  printf 'command.engram size=%s wal=%s mtime=%s\n' "$size" "$wal" "$mtime"
else
  msg="kaia.engram ABSENT at $ENGRAM"
  printf 'command.engram ABSENT\n'
fi
observe "command.engram" "$msg"

# ---- brokk: crew sessions --------------------------------------------
if [ -r "$FIRSTMATE_ROOT/state/home-summary.json" ]; then
  active=$(grep -m1 '"active_children":' "$FIRSTMATE_ROOT/state/home-summary.json" 2>/dev/null | sed -E 's/[^0-9]//g')
  open_dec=$(grep -m1 '"decisions_open":' "$FIRSTMATE_ROOT/state/home-summary.json" 2>/dev/null | sed -E 's/[^0-9]//g')
  valid=$(grep -m1 '"valid":' "$FIRSTMATE_ROOT/state/home-summary.json" 2>/dev/null | sed -E 's/.*"valid":[[:space:]]*(true|false).*/\1/')
  metas=$(find "$FIRSTMATE_ROOT/state" -maxdepth 1 -name '*.meta' 2>/dev/null | wc -l | tr -d '[:space:]')
  msg="crew sessions: active_children=${active:-0} decisions_open=${open_dec:-0} valid=${valid:-unknown} session_meta=${metas:-0}"
  printf 'brokk.sessions active=%s decisions=%s valid=%s\n' "${active:-0}" "${open_dec:-0}" "${valid:-unknown}"
else
  msg="home-summary.json ABSENT under $FIRSTMATE_ROOT/state"
  printf 'brokk.sessions ABSENT\n'
fi
observe "brokk.sessions" "$msg"

# ---- brokk: branch outcomes ------------------------------------------
OUTCOMES="$FIRSTMATE_ROOT/state/branch-outcomes.jsonl"
if [ -r "$OUTCOMES" ]; then
  n=$(wc -l <"$OUTCOMES" 2>/dev/null | tr -d '[:space:]')
  task=$(tail -n 1 "$OUTCOMES" 2>/dev/null | sed -n 's/.*"task":"\([^"]*\)".*/\1/p')
  recorded=no
  tail -n 1 "$OUTCOMES" 2>/dev/null | grep -q '"verdict"' && recorded=yes
  msg="branch outcomes=${n:-0}; latest task=${task:-unknown} outcome_recorded=${recorded}"
  printf 'brokk.outcomes count=%s latest_task=%s outcome_recorded=%s\n' "${n:-0}" "${task:-unknown}" "$recorded"
else
  msg="branch-outcomes.jsonl ABSENT under $FIRSTMATE_ROOT/state"
  printf 'brokk.outcomes ABSENT\n'
fi
observe "brokk.outcomes" "$msg"

# ---- worktree state (external, read-only) ------------------------------------------
if [ -d "$WORKTREE_ROOT" ]; then
  wt_count=$(find "$WORKTREE_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')
  state_files=$(find "$WORKTREE_ROOT" -mindepth 2 -maxdepth 2 -name 'treehouse-state.json' 2>/dev/null | wc -l | tr -d '[:space:]')
  msg="worktrees=${wt_count:-0} state_files=${state_files:-0}"
  printf 'brokk.worktrees trees=%s state_files=%s\n' "${wt_count:-0}" "${state_files:-0}"
else
  msg="worktree root ABSENT at $WORKTREE_ROOT"
  printf 'brokk.worktrees ABSENT\n'
fi
observe "brokk.worktrees" "$msg"

printf '%s\n' "observer summary written: $LOG_TS" >"$OBS_LAST"
printf 'observer: observations carved (log=%s)\n' "$OBS_LOG"
