#!/usr/bin/env bash
# saga-session-start.sh — Sága: the SHORT HEAD at session start, everything else on demand.
#
# The fault this door answers (plan 275, item 28, measured 2026-11-14): the digest
# pre-loaded 19 sections — 55–57 KB, 696 lines, ~14,000 tokens — three times at every
# compaction, and under 40 of those lines were the ones a session can act on. The
# practice is the opposite: the smallest set of high-signal tokens, and detail fetched
# just in time when the task needs it.
#
# So the digest is now TWO things:
#
#   THE HEAD (default, ≤ 60 lines) — the fixed core every worker must know, who holds
#     the helm, what needs the Allfather, the live errands (a finished one is reported
#     ONCE then folded away, an unreadable pane is reaped once), and the next step. It
#     is what a session start AND a compaction inject.
#   THE SECTIONS (on demand) — every other fact, by name, when the task needs it. The
#     head names them in one line; nothing pre-loads them.
#
# Usage:
#   saga-session-start.sh                     # the session start: stages, then the head
#   saga-session-start.sh --head              # the head only, NO side effects (compaction)
#   saga-session-start.sh --page              # a PAGE reads the head: read-only, holds nothing
#   saga-session-start.sh --section <name>    # one section, on demand (default: read-only)
#   saga-session-start.sh --list              # the sections, one line each
#   saga-session-start.sh --check             # measure the head; exit 1 over budget
#   saga-session-start.sh --full              # a human wants the whole truth: head + all
#
# The stages (lock, bridges, the well, the handoff sweep, the hall sweep, cron) are
# MUTATING and run ONLY at a session start, and the hall sweep ONLY when this session
# holds the lock — a session that does not hold the arm is read-only for spawn, steer,
# merge and drain (the seat law), and a worker's session start must not tidy the hall.
#
# Read-once: the head IS this turn's startup input. Do not re-read the sources it
# names unless one was reported absent or broken.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The operator's records live in the HOME they chose, never in the code tree (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
ymir_home_root YMIR_HOME 2>/dev/null || YMIR_HOME="${YMIR_HOME:-}"
hoard_state_dir  _HS 2>/dev/null; hoard_data_dir  _HD 2>/dev/null; hoard_settings_dir _HC 2>/dev/null
# THE HOUSE'S RECORD SHELF, deliberately not `${BROKK_STATE_OVERRIDE}`: inside a seat
# pane that variable points at the harness's own continuity dir (`…/ymir/seats/<id>`),
# which holds no meta and no status — honouring it made the head report "no errand claims
# life" while 163 records sat on the house's shelf (the fault eindri-liveness documents).
# The errand, wake and marker files are the HOUSE's; SAGA_STATE_DIR is the seam a test uses.
HOUSE_STATE="${SAGA_STATE_DIR:-${_HS:-$BROKK_HOME/state}}"
STATE="$HOUSE_STATE"
DATA="${BROKK_DATA_OVERRIDE:-${_HD:-$BROKK_HOME/data}}"
CONFIG="${BROKK_CONFIG_OVERRIDE:-${_HC:-$BROKK_HOME/config}}"
unset _HS _HD _HC
# shellcheck source=bin/vault/gleipnir-lock-lib.sh
# The lock door is loaded ON DEMAND (see the door, below): a read-only mode that needs no
# lock — --list, --check on a machine with no session — must not pay 0.4s to a python door
# it never asks a question of.
load_lock_lib() {
  [ -n "${_GLEIPNIR_LOADED:-}" ] && return 0
  # shellcheck source=bin/vault/gleipnir-lock-lib.sh
  . "$SCRIPT_DIR/../vault/gleipnir-lock-lib.sh" && _GLEIPNIR_LOADED=1
}
# shellcheck source=bin/time/saga-head-lib.sh
. "$SCRIPT_DIR/saga-head-lib.sh"

HEAD_CORE="$SCRIPT_DIR/saga-head-core.md"
HEAD_MAX_LINES="${YMIR_SAGA_HEAD_LINES:-60}"
HEAD_MAX_BYTES="${YMIR_SAGA_HEAD_BYTES:-8192}"

REALM="${BROKK_REALM:-}"
if [ -z "$REALM" ] && [ -r "$DATA/realm.md" ]; then
  REALM=$(head -n 1 "$DATA/realm.md" 2>/dev/null | tr -d '[:space:]')
fi
REALM="${REALM:-}"
if [ -z "$REALM" ]; then . "$SCRIPT_DIR/../skuld/realm-lib.sh"; ymir_active_realm "$ROOT" REALM; fi

# The clock comes through its own door (bin/time/sol.sh) when it is there, so every
# session and every log line wears the same instant — and falls back to `date`.
sol_now() {  # <fmt> — sol.sh when installed, the shell's clock otherwise
  if [ -x "$SCRIPT_DIR/sol.sh" ]; then
    bash "$SCRIPT_DIR/sol.sh" "$1" --plain 2>/dev/null && return 0
  fi
  case "$1" in
    utc) date -u +%Y-%m-%dT%H:%M:%SZ ;;
    *)   date +%s ;;
  esac
}

section() { printf '\n== %s ==\n' "$1"; }

# ── the lock: taken once, at a session start, and never inferred ─────────────
LOCKED=0        # this session HOLDS the lock
LOCK_OWNER=""  # a live pid holds it, and it is not us
LOCK_KNOWN=0
lock_take() {
  load_lock_lib
  if gleipnir_lock_acquire; then LOCKED=1
  else gleipnir_lock_owner owner; LOCK_OWNER="${owner:-}"; fi
  LOCK_KNOWN=1
}
lock_probe() {  # read-only: who holds it, and is it this session
  load_lock_lib
  owner=""; gleipnir_lock_owner owner 2>/dev/null || true
  LOCKED=0; LOCK_OWNER=""; LOCK_KNOWN=1
  [ -n "${owner:-}" ] || return 0
  [ -d "/proc/$owner" ] || return 0
  if [ -n "${BROKK_SESSION_PID:-}" ] && [ "$owner" = "$BROKK_SESSION_PID" ]; then LOCKED=1; else LOCK_OWNER="$owner"; fi
}

# ══ THE STAGES (mutating; a session start only) ══════════════════════════════
stage_bootstrap() {
  missing=""
  for tool in git bash node; do command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"; done
  if [ -n "$missing" ]; then printf 'MISSING:%s\n' "$missing"; else printf 'tool floors OK\n'; fi
  # Model bridge: keep Pi's opencode-go endpoint alive so a session never 401s.
  if [ -x "$SCRIPT_DIR/../bridge/bifrost-bridge.sh" ]; then
    if BROKK_ENV_FILE="$BROKK_HOME/.env.local" "$SCRIPT_DIR/../bridge/bifrost-bridge.sh" --start >/dev/null 2>&1; then
      printf 'model bridge: up\n'
    else
      printf 'model bridge: not up (see state/model-bridge.log)\n'
    fi
  fi
  # The well: keep the Mimirsbrunn (engram) bridge alive so recall never fires dry.
  if [ -x "$SCRIPT_DIR/../bridge/mimir-bridge.sh" ]; then
    if "$SCRIPT_DIR/../bridge/mimir-bridge.sh" --start >/dev/null 2>&1; then
      printf 'well bridge: up\n'
    else
      printf 'well bridge: not up (see state/mimir-bridge.log)\n'
    fi
  fi
  if [ -r "${YMIR_HOME:-}/svartalfaheim/$REALM/.env.realm" ] || [ -r "$ROOT/svartalfaheim/$REALM/.env.realm" ]; then
    printf 'realm env: present\n'
  else
    printf 'realm env: ABSENT (%s)\n' "svartalfaheim/$REALM/.env.realm"
  fi
}

stage_handoff() {
  # The slow road that cannot be missed: a finished Eindri's report sweeps into the
  # wake queue even when the fast runner is down. The caller has already decided this
  # session holds the house; a seat's start leaves the queue to the helm.
  if [ -x "$SCRIPT_DIR/../agents/eindri-handoff.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/../agents/eindri-handoff.sh" sweep 2>/dev/null || true
  fi
}

stage_sweep() {
  # TAKING THE ARM SWEEPS THE HALL (the Allfather, 2026-11-10): a finished seat is
  # closed automatically. The caller has already decided this session holds the house.
  if [ -x "$ROOT/bin/seat/seat-reap.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" \
      bash "$ROOT/bin/seat/seat-reap.sh" --sweep 2>/dev/null \
      || printf 'sweep: the seat door did not answer (bin/seat/seat-reap.sh --list says why)\n'
  fi
  if [ -x "$ROOT/bin/seat/seat-adopt.sh" ]; then
    adopt_out="$(BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" \
      bash "$ROOT/bin/seat/seat-adopt.sh" --all 2>/dev/null || true)"
    case "$adopt_out" in *adopted:*) printf '%s\n' "$adopt_out" ;; esac
  fi
}

# Is this session a SEAT (a worker home) rather than the house's own hand? A seat takes its
# own lock, so "the lock is held" alone does not make a session the primary (herdr-run.sh
# gives every seat its own BROKK_MACHINE_STATE_DIR under …/ymir/seats/<id>).
is_seat() { case "${BROKK_MACHINE_STATE_DIR:-}" in */ymir/seats/*) return 0 ;; esac; return 1; }

stage_prepare() {
  load_lock_lib
  gleipnir_lock_reap
  lock_take
  stage_bootstrap >/dev/null 2>&1 || true
  # THE STAGES THAT MUTATE THE HALL ARE THE HELM'S (the seat law: a session that does not
  # hold the arm is read-only for spawn, steer, merge and drain). A worker's session start
  # must not sweep the hall or write the wake queue; it announces only what went WRONG.
  if [ "$LOCKED" = 1 ] && ! is_seat; then
    _stages="$( { stage_handoff; stage_sweep; } 2>&1 )"
    printf '%s\n' "$_stages" | grep -E 'adopted:|fail|error|did not answer|refused' | head -3 || true
    unset _stages
  fi
  # Cron is idempotent and one loop per machine: the helm raises it, a seat leaves it.
  if [ "$LOCKED" = 1 ] && ! is_seat && [ -x "$SCRIPT_DIR/nornir-cron-start.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/nornir-cron-start.sh" >/dev/null 2>&1 || true
  fi
  # The skill index is cached and quiet; refresh it off the clock.
  if [ -x "$SCRIPT_DIR/../agents/skill-index.sh" ]; then
    YMIR_HOME="${YMIR_HOME:-}" "$SCRIPT_DIR/../agents/skill-index.sh" >/dev/null 2>&1 || true
  fi
}

# ══ THE SECTIONS (on demand) ════════════════════════════════════════════════
SEC_LOCK() {
  # A PAGE IS NOT A SESSION (plan 275 item 36b). The Runtime page runs this door to DRAW the
  # digest; a page load is not a hand on the helm. So it takes nothing, refreshes nothing, and
  # never reports the lock as its own — it names the real holder from the arm lease.
  if [ "${PAGE:-0}" = 1 ]; then
    printf 'lock: read-only — this run takes nothing, refreshes nothing and holds nothing\n'
    if [ -x "$SCRIPT_DIR/../seat/helm-identity.sh" ]; then
      bash "$SCRIPT_DIR/../seat/helm-identity.sh" --line 2>/dev/null || printf 'helm: no arm is held (no lease on this machine)\n'
    else
      printf 'helm: bin/seat/helm-identity.sh is not installed — the lease cannot be read\n'
    fi
    return 0
  fi
  [ "$LOCK_KNOWN" = 1 ] || lock_probe
  if [ "$LOCKED" = 1 ]; then
    printf 'lock: held by this session (pid %s)\n' "${BROKK_SESSION_PID:-$$}"
  elif [ -n "$LOCK_OWNER" ]; then
    printf 'READ-ONLY: the session lock is held by pid %s - no spawn, steer, merge, drain, or repair this session\n' "$LOCK_OWNER"
  else
    printf 'lock: free - no live session holds it; a session started here may take it\n'
  fi
  if [ -x "$SCRIPT_DIR/../seat/helm-identity.sh" ]; then
    bash "$SCRIPT_DIR/../seat/helm-identity.sh" --line 2>/dev/null || printf 'helm: no arm is held\n'
  fi
}

SEC_BOOTSTRAP() { stage_bootstrap; }

SEC_WAKE() {
  if [ -x "$SCRIPT_DIR/saga-wake-drain.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/saga-wake-drain.sh" || true
  else
    printf 'wake queue: 0 pending (drain not installed)\n'
  fi
}

SEC_SEATS() {
  if [ -x "$ROOT/bin/seat/seat-reap.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" \
      bash "$ROOT/bin/seat/seat-reap.sh" --list 2>/dev/null \
      || printf 'sweep: the seat door did not answer (bin/seat/seat-reap.sh --list says why)\n'
  else
    printf 'sweep: bin/seat/seat-reap.sh absent — dead Eindri workspaces are not closed\n'
  fi
}

SEC_SUPERVISION() {
  printf 'harness next step: arm supervision via the installed harness adapter; never run bin/pi/syn-watch-arm.sh by hand.\n'
  if [ -x "$ROOT/bin/pi/arm-pin.sh" ]; then "$ROOT/bin/pi/arm-pin.sh" status 2>/dev/null || true; fi
}

SEC_TODOS() {
  if [ -x "$SCRIPT_DIR/../voice/todos.sh" ]; then
    bash "$SCRIPT_DIR/../voice/todos.sh" --digest 2>/dev/null || printf 'todos: unreadable\n'
  else
    printf 'todos: door not installed (bin/voice/todos.sh)\n'
  fi
}

SEC_AGENTS() {
  if [ -x "$SCRIPT_DIR/../agents/agent-census.sh" ]; then
    bash "$SCRIPT_DIR/../agents/agent-census.sh" --digest 2>/dev/null || printf 'census: failed\n'
  else
    printf 'census: door not installed (bin/agents/agent-census.sh)\n'
  fi
}

SEC_UPDATE() {
  if [ -x "$SCRIPT_DIR/../gates/checks/ymir-update-check.sh" ]; then
    out="$(BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/../gates/checks/ymir-update-check.sh" 2>/dev/null)"; rc=$?
    if [ "$rc" = "3" ]; then printf '%s\n' "$out"; else printf 'current — no newer Ymir on npm\n'; fi
  else
    printf 'check not installed\n'
  fi
}

SEC_FLEET() {
  if [ -d "$STATE" ]; then
    metas=$(find "$STATE" -maxdepth 1 -name '*.meta' 2>/dev/null | wc -l | tr -d '[:space:]')
    printf 'task metadata records: %s\n' "${metas:-0}"
  else
    printf 'task metadata records: 0\n'
  fi
  MP="${BROKK_MASTERPLAN:-${YMIR_HOME:-}/hodd/docs/masterplan.md}"
  if [ -r "$MP" ]; then
    open=$(grep -c '^- Status: ADDED' "$MP" 2>/dev/null || echo 0)
    printf 'open forge orders: %s\n' "${open:-0}"
  fi
}

SEC_LANDING() {
  # Plan 293 part 3 (2026-11-14): the audit of 36 panes found 22 branches pushed and clean, four
  # merged, and nothing anywhere in the session start said the rest were still waiting — while one
  # machine's local main held 19 commits on no remote at all. A branch with no PR is work nobody will
  # review; a commit on no remote is work one disk away from being lost. Read-only and time-bounded.
  if [ -x "$SCRIPT_DIR/saga-land-warnings.sh" ]; then
    bash "$SCRIPT_DIR/saga-land-warnings.sh" 2>/dev/null \
      || printf 'landing: the warning door did not answer (bin/time/saga-land-warnings.sh --check says why)\n'
  else
    printf 'landing: bin/time/saga-land-warnings.sh absent — branches with no PR and commits on no remote are unseen\n'
  fi
}

SEC_CONTEXT() {
  emit_context() {  # <path> <label>
    printf -- '--- %s ---\n' "$2"
    if [ -r "$1" ]; then cat "$1"; else printf 'ABSENT: %s\n' "$1"; fi
  }
  printf -- '--- realm ---\n%s\n' "$REALM"
  emit_context "$DATA/operator.md" "operator"
  emit_context "$DATA/projects.md" "projects"
  emit_context "$DATA/learnings.md" "learnings"
  HOOD_FILE="$ROOT/svartalfaheim/$REALM/HOOD.md"
  [ -r "${YMIR_HOME:-}/svartalfaheim/$REALM/HOOD.md" ] && HOOD_FILE="${YMIR_HOME}/svartalfaheim/$REALM/HOOD.md"
  emit_context "$HOOD_FILE" "hood"
}

SEC_CLOCK() {
  if [ -x "$SCRIPT_DIR/sol.sh" ]; then
    bash "$SCRIPT_DIR/sol.sh" context 2>/dev/null || printf 'no clock\n'
  else
    printf 'no clock (bin/time/sol.sh absent)\n'
  fi
}

SEC_TODAY() {
  if [ -x "$SCRIPT_DIR/../records/daily-log.sh" ]; then
    _today="$(BROKK_HOME="$BROKK_HOME" "$SCRIPT_DIR/../records/daily-log.sh" today 2>/dev/null || true)"
    if [ -z "$_today" ]; then printf 'no entries yet\n'; else
      _n="$(printf '%s\n' "$_today" | wc -l | tr -d ' ')"
      [ "$_n" -gt 40 ] && printf '(%s earlier lines today — daily-log.sh today shows all)\n' "$((_n - 40))"
      printf '%s\n' "$_today" | tail -40
    fi
  else
    printf 'daily-log.sh not installed\n'
  fi
}

SEC_RECALL() {
  if [ -x "$SCRIPT_DIR/../records/mimir-recall-today.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" \
      "$SCRIPT_DIR/../records/mimir-recall-today.sh" 2>/dev/null | head -12 || printf 'recall: the well door did not answer\n'
  else
    printf 'recall: bin/records/mimir-recall-today.sh absent — the well was not asked\n'
  fi
}

SEC_SKILLS() {
  if [ -x "$SCRIPT_DIR/../agents/skill-index.sh" ]; then
    SKILL_IDX="$(YMIR_HOME="${YMIR_HOME:-}" "$SCRIPT_DIR/../agents/skill-index.sh" --print 2>/dev/null | head -1)"
    SKILL_TOT="$(grep -m1 '^total:' "$SKILL_IDX" 2>/dev/null | sed 's/^total:[[:space:]]*//')"
    printf 'index: %s (%s skills across 4 shelves)\n' "$SKILL_IDX" "${SKILL_TOT:-?}"
    printf 'read the index, or ask: bin/agents/skill-find.sh "<words>" | --where <name> | --list\n'
    printf 'a stale index fails loudly: bin/agents/skill-index.sh --check\n'
  else
    printf 'skill-index: not installed\n'
  fi
}

SEC_MODELS() {
  cat_models="$("$ROOT/bin/model/catalog.sh" --providers 2>/dev/null | sed -n '2,20p' | tr -d '"' || true)"
  if [ -n "$cat_models" ]; then
    printf 'the catalogue is the truth: bin/model/catalog.sh  (pi own list — never a table in a doc)\n'
    printf '%s\n' "$cat_models"
    printf 'a model the catalogue lists is pi to serve; bin/model/catalog.sh --has <provider/model> answers before dispatch\n'
  else
    printf 'the catalogue cannot be read — bin/model/catalog.sh --check says why; do not dispatch on a guess\n'
  fi
}

SEC_ASSETS() {
  printf 'governed[6]{path,load_first}:\n'
  printf '  "bin/engine/ymir-install.sh",".agents/skills/galdr-ymirsystem/assets/installation.md"\n'
  printf '  "apps/hlidskjalf/**",".agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md"\n'
  printf '  "bin/mimir*",".agents/skills/galdr-ymirsystem/assets/memory-well.md"\n'
  printf '  "bin/nornir-* | config/cron.yaml",".agents/skills/galdr-ymirsystem/assets/nornir-jobs.md"\n'
  printf '  "bin/seat/valknut-load.sh | .pi/**",".agents/skills/galdr-ymirsystem/assets/harness-integration/README.md"\n'
  printf '  "bin/smidja* | .agents/skills/smidja-factory/**",".agents/skills/galdr-ymirsystem/assets/smidja.md"\n'
  printf 'rule: load the asset, then change the code, then update the asset in the same change.\n'
}

SEC_TOOLS() {
  printf 'tools[4]{handle,what}:\n'
  printf '  "/edit <path>","open a file in his own editor (ctrl+shift+e for the picker)"\n'
  printf '  "systems/snotra/services/tts-lease/ymir-say.sh","Ymir speaks on the desktop (done/alarm/fail/note)"\n'
  printf '  "bin/host/omarchy-plugins.sh","the suggested Omarchy shell plugins; add/list"\n'
  printf '  "bin/seat/herdr-run.sh","seat an Eindri in a herdr tab, or a disposable space"\n'
}

SEC_CRON() {
  if [ -x "$SCRIPT_DIR/nornir-cron-start.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/nornir-cron-start.sh" --status 2>/dev/null \
      || printf 'cron: --status did not answer; bin/time/nornir-cron-start.sh raises it\n'
  else
    printf 'cron: not installed (bin/time/nornir-cron-start.sh absent)\n'
  fi
}

SEC_LIVENESS() {
  # The full judgement, on demand: is the pane still a worker? (expensive; never in the head)
  if [ -x "$SCRIPT_DIR/../agents/eindri-liveness.sh" ]; then
    bash "$SCRIPT_DIR/../agents/eindri-liveness.sh" check 2>/dev/null || true
  else
    printf 'liveness: bin/agents/eindri-liveness.sh absent\n'
  fi
}

SEC_NEXT() {
  printf 'Ascend Hlidskjalf as Brokk. Address the Allfather. Read once; act.\n'
}

SECTIONS="lock bootstrap wake seats supervision todos agents update fleet landing context clock today recall skills models assets tools cron liveness next"

SEC_NAME() {  # <name> -> the function
  case "$1" in
    lock) SEC_LOCK ;; bootstrap) SEC_BOOTSTRAP ;; wake) SEC_WAKE ;; seats) SEC_SEATS ;; landing) SEC_LANDING ;;
    supervision) SEC_SUPERVISION ;; todos) SEC_TODOS ;; agents) SEC_AGENTS ;; update) SEC_UPDATE ;;
    fleet) SEC_FLEET ;; context) SEC_CONTEXT ;; clock) SEC_CLOCK ;; today) SEC_TODAY ;;
    recall) SEC_RECALL ;; skills) SEC_SKILLS ;; models) SEC_MODELS ;; assets) SEC_ASSETS ;;
    tools) SEC_TOOLS ;; cron) SEC_CRON ;; liveness) SEC_LIVENESS ;; next) SEC_NEXT ;;
    *) return 1 ;;
  esac
}

SEC_DESCR() {  # <name> -> one line: what it answers
  case "$1" in
    lock)        printf 'who holds the session lock and the helm (the arm lease, one line)' ;;
    bootstrap)   printf 'tool floors, the model bridge, the well, the realm env (re-probes; no-op when up)' ;;
    wake)        printf 'the wake queue in full — every durable wake, and the open work' ;;
    seats)       printf 'the hall sweep as a dry run: which seats it WOULD close, and why' ;;
    supervision) printf 'how the harness arms supervision, and the age of the pinned runtime' ;;
    todos)       printf "the Allfather's task ledger — every open item, with due dates" ;;
    agents)      printf 'every agent process on this machine, every herdr pane, every stale errand pane' ;;
    update)      printf 'whether a newer Ymir stands on npm (one cached lookup a day)' ;;
    fleet)       printf 'Eindri task records, open forge orders, fleet metadata' ;;
    context)     printf 'the operator contract, the project registry, the learnings, the HOOD map (the long read)' ;;
    clock)       printf 'now, in the house zone and UTC, with the stamp the logs use' ;;
    today)       printf "today's log — the work already forged this day" ;;
    recall)      printf "the well's answer for the day's topic (drink before you act)" ;;
    skills)      printf 'the skill index: where it is, how many, and how to search it' ;;
    models)      printf 'the model catalogue — the one table of what this machine can serve' ;;
    assets)      printf 'which Galdr asset owns which governed path (load before you edit)' ;;
    tools)       printf "the Allfather's own handles into this machine" ;;
    cron)        printf 'the Nornir scheduler: is it alive (read-only status)' ;;
    liveness)    printf 'the full seat judgement — every record, its pane, its verdict (expensive)' ;;
    next)        printf 'the closing pointer' ;;
    *) return 1 ;;
  esac
}

# ══ THE HEAD ════════════════════════════════════════════════════════════════
head_arm() {  # who holds the Gná arm, in one line, read from the arm's own record
  local row seat role host pid hb
  [ -x "$SCRIPT_DIR/../voice/rodd-arm.sh" ] || { printf 'the arm: bin/voice/rodd-arm.sh not installed\n'; return 0; }
  row="$(timeout 3 bash "$SCRIPT_DIR/../voice/rodd-arm.sh" who 2>/dev/null | sed -n '2p')"
  if [ -z "$row" ]; then printf 'the arm is VACANT here — bin/voice/rodd-arm.sh hold takes a vacant one\n'; return 0; fi
  seat="$(printf '%s' "$row" | cut -d'"' -f2)"; role="$(printf '%s' "$row" | cut -d'"' -f4)"
  host="$(printf '%s' "$row" | cut -d'"' -f8)";  pid="$(printf '%s' "$row" | cut -d'"' -f20)"
  hb="$(printf '%s' "$row" | cut -d'"' -f22)"
  printf 'held by %s (%s) on %s · arm pid %s · heartbeat %ss · tell it: bin/voice/rodd-arm.sh tell --from <you> "…"\n' \
    "${seat:-unnamed}" "${role:-?}" "${host:-?}" "${pid:-?}" "${hb:-?}"
}

head_needs() {  # what needs the Allfather: counts first, then the newsiest lines
  local wq="$STATE/.wake-queue" fmq="$SCRIPT_DIR/../../state/procevent/.wake-queue"
  local wakes=0 decisions=0 questions=0 todos_line="" newest_wake="" nq
  if [ -s "$wq" ]; then nq="$(awk 'END{print NR}' "$wq" 2>/dev/null)"; wakes=$((wakes + ${nq:-0})); fi
  if [ -s "$fmq" ]; then nq="$(awk 'END{print NR}' "$fmq" 2>/dev/null)"; wakes=$((wakes + ${nq:-0})); fi
  decisions=$(find "$STATE" -maxdepth 1 -name '*.decision' 2>/dev/null | wc -l | tr -d '[:space:]')
  questions=$(find "$STATE/eindri-questions" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
  if [ -x "$SCRIPT_DIR/../voice/todos.sh" ]; then
    todos_line="$(timeout 5 bash "$SCRIPT_DIR/../voice/todos.sh" --digest 2>/dev/null | head -1 | sed 's/ — ledger.*//')"
  fi
  printf 'wakes %s · decisions %s · questions %s · %s\n' \
    "${wakes:-0}" "${decisions:-0}" "${questions:-0}" "$(printf '%s' "${todos_line:-todos: unreadable}" | sed 's/^open: /todos: /')"
  if [ "$wakes" -gt 0 ] 2>/dev/null; then
    newest_wake="$([ -s "$wq" ] && tail -n1 "$wq" 2>/dev/null || tail -n1 "$fmq" 2>/dev/null)"
    [ -n "$newest_wake" ] && printf '  newest wake: %s\n' "$(printf '%s' "$newest_wake" | tr '\t' ' ' | cut -c1-150)"
    printf '  the arm drains and acks them: --section wake\n'
  fi
  [ "$questions" -gt 0 ] 2>/dev/null && printf '  questions filed for the helm: %s — %s\n' "$questions" "$(ls "$STATE/eindri-questions" 2>/dev/null | head -3 | tr '\n' ' ')"
  return 0
}

print_head() {
  printf 'Sága · the short head%s · %s · home=%s · realm=%s\n' \
    "$([ "${PAGE:-0}" = 1 ] && printf ' (read-only page)' || true)" "$(sol_now utc)" "$BROKK_HOME" "$REALM"
  section "FIXED CORE (every worker knows this)"
  if [ -r "$HEAD_CORE" ]; then saga_head_core_text "$HEAD_CORE"; else printf 'ABSENT: %s — the core is missing from this tree\n' "$HEAD_CORE"; fi
  section "HELM"
  SEC_LOCK
  printf 'arm: %s\n' "$(head_arm)"
  section "NEEDS THE ALLFATHER"
  head_needs
  section "LIVE ERRANDS"
  saga_head_errand_block "$STATE" 6 3
  section "LANDING"
  SEC_LANDING
  section "NEXT STEP"
  printf 'Ascend Hlidskjalf as Brokk. Address the Allfather. Read once; act.\n'
  printf 'on demand: %s --section <name>  (%s)\n' "$(basename "$0")" "$(printf '%s' "$SECTIONS" | tr ' ' ' ')"
  printf 'the whole truth: %s --full\n' "$(basename "$0")"
}

head_measure() {  # -> "lines bytes" — a DRY measurement; it never consumes the news
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/saga-head.XXXXXX")" || return 1
  SAGA_HEAD_DRY=1 print_head >"$tmp" 2>/dev/null
  printf '%s %s\n' "$(awk 'END{print NR}' "$tmp")" "$(wc -c <"$tmp" | tr -d ' ')"
  rm -f "$tmp"
}
is_section() { case " $SECTIONS " in *" $1 "*) return 0 ;; esac; return 1; }

# ══ the door ════════════════════════════════════════════════════════════════
MODE="start"; SECTION=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --head|head) MODE=head; shift ;;
    --page|page) MODE=page; shift ;;
    --full|--all|full) MODE=full; shift ;;
    --list|list) MODE=list; shift ;;
    --check|check) MODE=check; shift ;;
    --section) SECTION="${2-}"; MODE=section; [ $# -ge 2 ] && shift 2 || shift ;;
    --section=*) SECTION="${1#--section=}"; MODE=section; shift ;;
    *) printf 'error: unknown argument %s\nhelp: saga-session-start.sh [--head|--page|--section <name>|--list|--check|--full]\n' "$1" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  list)
    printf 'sections[%s]{name,answers}:\n' "$(printf '%s\n' $SECTIONS | wc -l | tr -d ' ')"
    for s in $SECTIONS; do printf '  "%s","%s"\n' "$s" "$(SEC_DESCR "$s")"; done
    printf 'read one: %s --section <name>  ·  all: --full\n' "$(basename "$0")"
    ;;
  head)
    # NO side effects: this is the compaction path. The lock is only READ.
    print_head
    ;;
  page)
    # NO side effects and no lock AT ALL: a page load is not a session start.
    PAGE=1
    print_head
    ;;
  section)
    [ -n "$SECTION" ] || { printf 'error: --section needs a name\nhelp: %s --list\n' "$0" >&2; exit 2; }
    is_section "$SECTION" || { printf 'error: unknown section %s\nhelp: %s --list\n' "$SECTION" "$0" >&2; exit 2; }
    section "$(printf '%s' "$SECTION" | tr '[:lower:]' '[:upper:]')"
    SEC_NAME "$SECTION"
    ;;
  check)
    read -r lines bytes <<<"$(head_measure)"
    printf 'saga_head[3]{lines,budget_lines,bytes}:\n  "%s","%s","%s"\n' "$lines" "$HEAD_MAX_LINES" "$bytes"
    if [ "${lines:-0}" -gt "$HEAD_MAX_LINES" ] || [ "${bytes:-0}" -gt "$HEAD_MAX_BYTES" ]; then
      printf 'FAIL: the head is over budget (%s lines > %s, or %s bytes > %s)\n' "$lines" "$HEAD_MAX_LINES" "$bytes" "$HEAD_MAX_BYTES" >&2
      printf 'help: move a block from the head to a section (--section <name>), never grow the head\n' >&2
      exit 1
    fi
    printf 'PASS: the head fits (%s lines ≤ %s, %s bytes ≤ %s)\n' "$lines" "$HEAD_MAX_LINES" "$bytes" "$HEAD_MAX_BYTES"
    ;;
  full)
    stage_prepare
    print_head
    for s in $SECTIONS; do section "$(printf '%s' "$s" | tr '[:lower:]' '[:upper:]')"; SEC_NAME "$s" || true; done
    ;;
  start|*)
    stage_prepare
    print_head
    # A head that outgrows its budget says so in the head itself, where the reader is.
    read -r lines bytes <<<"$(head_measure)"
    if [ "${lines:-0}" -gt "$HEAD_MAX_LINES" ] || [ "${bytes:-0}" -gt "$HEAD_MAX_BYTES" ]; then
      printf 'WARNING: this head is over budget (%s lines/%s bytes > %s/%s) — --section <name>, never a longer head\n' \
        "$lines" "$bytes" "$HEAD_MAX_LINES" "$HEAD_MAX_BYTES"
    fi
    ;;
esac
exit 0
