#!/usr/bin/env bash
# seat-reap.sh — the hand that closes a finished seat.
#
# The fault this door answers (measured 2026-11-10): `einherjar-spawn.sh
# launch_herdr` raises a herdr workspace `eindri-<id>` per errand, and NOTHING
# closed it. The arm's close hook and the review verdict never touched the
# workspace; `eindri-control.sh close` closes a pane and nothing called it on
# completion. A worker exits into a bare shell, herdr restores that shell after a
# restart, and the hall fills with dead `eindri-*` workspaces — nine of them while
# this was written, one of which was this worker's own.
#
# The Allfather's law is that this is figured out AUTOMATICALLY when the seat takes
# the arm — never by an operator remembering to tidy up:
#
#   seat-reap.sh <id>        close THIS errand's seat: the discriminator decides
#                            working (never) / finished (retire) / undecided
#                            (keep with the reason named)
#   seat-reap.sh --sweep     the hall: retire finished-idle agents (S2), close
#                            agentless seats, never touch a working seat
#   seat-reap.sh --list      what --sweep WOULD do, closing nothing
#   seat-reap.sh --close-pane P  close an ORPHAN pane (a bare shell, no errand) —
#                            the ONLY door; the Allfather's word, never a sweep
#   seat-reap.sh --install   seat the sweep on every harness this host runs
#   seat-reap.sh --check     is it seated? (exit 1 when a present harness is not)
#   seat-reap.sh --shell P   close the bare shell standing in worktree P (a dead
#                            seat keeps its tree `in-use` forever otherwise)
#   seat-reap.sh --verify    the two structural faults, reported and never mended
#                            (exit 1 when this seat is broken) — the verb install
#                            and Gróa call from their --check mode
#
# Plan 255 (2026-11-11): a FINISHED worker is still a live process at an idle
# prompt, so the old `agent_in_workspace → keep` could not tell it from real work.
# The sweep now asks the discriminator for a named verdict, and a finished seat is
# RETIRED — the harness's own exit first, a bounded wait, the close doors, and
# only then a TERM to the agent's pid (SIGKILL never first, never silent).
#
# One reader for one question: whether an agent stands in a workspace is asked of
# bin/seat/herdr-agents.py (the ONE reader of `herdr agent list`, plan 189 §18.2),
# never re-parsed here. The close itself reuses the doors that already refuse a
# live seat — bin/seat/seats.sh close and `herdr workspace close` — so this file
# cannot become a second, looser closer.
#
# Refusals are the point. A workspace holding a LIVE agent is never touched; a
# dirty or unpushed WORKTREE is never touched (that is bin/forge/housekeeping.sh's
# judgement, and it is not repeated here — this door closes seats, it does not
# reclaim work).
#
# Env: BROKK_HOME / BROKK_STATE_OVERRIDE (siblings). Exit: 0 ok, 1 error, 2 usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The errand records are written by einherjar-spawn.sh / eindri-arm.sh as
# ${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}. A digest passes the hoard's state
# dir, which on a tree-installed seat is EMPTY — so this door asks every shelf a
# record could be on rather than reading one and calling the errand recordless.
state_dirs() {
  local d seen=""
  for d in "${BROKK_STATE_OVERRIDE:-}" "$BROKK_HOME/state" "$ROOT/state"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"
    printf '%s\n' "$d"
  done
}

# record <id> <suffix> -> the first existing state file on any shelf, or nothing
record() {
  local id=$1 suffix=$2 d
  while IFS= read -r d; do
    [ -e "$d/$id.$suffix" ] && { printf '%s' "$d/$id.$suffix"; return 0; }
  done < <(state_dirs)
  return 1
}

meta_key() { # <id> <key>
  local f; f="$(record "$1" meta)" || return 1
  [ -n "$f" ] || return 1
  awk -F= -v k="$2" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$f" 2>/dev/null
}

# ── the two readers of herdr, and nothing else ────────────────────────────────
HAVE_HERDR=0
command -v herdr >/dev/null 2>&1 && HAVE_HERDR=1

# ws_rows -> workspace_id<TAB>label<TAB>workspace_agent_status
ws_rows() {
  [ "$HAVE_HERDR" = 1 ] || return 1
  herdr workspace list 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
for w in (d.get("result") or {}).get("workspaces") or []:
    print("%s\t%s\t%s" % (w.get("workspace_id") or "", w.get("label") or "", w.get("agent_status") or "unknown"))
' 2>/dev/null
}

# agents_json -> the agent list from the ONE door
agents_json() { python3 "$SCRIPT_DIR/herdr-agents.py" --json 2>/dev/null; }

# agent_in_workspace <ws> <worktree> -> 0 when an agent stands in it. The pane is
# the evidence, not the workspace's own `agent_status` roll-up.
agent_in_workspace() {
  local ws=$1 wt=${2:-} j
  j="$(agents_json)" || return 1
  [ -n "$j" ] || return 1
  # The JSON rides through a FILE: a heredoc owns stdin, so a pipe into it would
  # stream nothing and every seat would read as agentless (the same trap the seat
  # brief records from bin/seat/seats.sh, 2026-11-08).
  local tmp; tmp="$(mktemp 2>/dev/null)" || return 1
  printf '%s' "$j" >"$tmp"
  python3 - "$ws" "$wt" "$tmp" <<'PY' 2>/dev/null
import json,sys
ws, wt = sys.argv[1], (sys.argv[2] or "").rstrip("/")
try:
    agents = json.load(open(sys.argv[3]))
except Exception:
    raise SystemExit(1)
for a in agents or []:
    if (a.get("workspace_id") or "") == ws:
        raise SystemExit(0)
    fg = (a.get("foreground_cwd") or "").rstrip("/")
    cwd = (a.get("cwd") or "").rstrip("/")
    if wt and (fg == wt or cwd == wt):
        raise SystemExit(0)
raise SystemExit(1)
PY
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# ── plan 255 · the discriminator: three verdicts, not two ──────────────────
# An agent that FINISHED is still a live process sitting at an idle prompt, so
# the old `agent_in_workspace → keep` could not tell real work from a finished
# seat. These readers ask the ONE door (herdr-agents.py) for the agent's STATE,
# and the sweep calls discriminate() for a named verdict instead of a blanket keep.
IDLE_GRACE="${SEAT_REAP_IDLE_GRACE:-600}"      # idle-for-grace seconds → RETIRE
EXIT_WAIT="${SEAT_REAP_EXIT_WAIT:-20}"         # bounded wait for the agent to leave

# agent_status <ws> <wt> -> the agent's `agent_status` on stdout; rc 1 when no
# agent stands there at all. The same ONE reader, never re-parsed.
agent_status() {
  local ws=$1 wt=${2:-} j tmp rc st
  j="$(agents_json)" || return 1
  [ -n "$j" ] || return 1
  tmp="$(mktemp 2>/dev/null)" || return 1
  printf '%s' "$j" >"$tmp"
  st="$(python3 - "$ws" "$wt" "$tmp" <<'PY' 2>/dev/null
import json,sys
ws, wt = sys.argv[1], (sys.argv[2] or "").rstrip("/")
try:
    agents = json.load(open(sys.argv[3]))
except Exception:
    raise SystemExit(1)
for a in agents or []:
    if (a.get("workspace_id") or "") == ws:
        print(a.get("agent_status") or "unknown"); raise SystemExit(0)
    fg = (a.get("foreground_cwd") or "").rstrip("/")
    cwd = (a.get("cwd") or "").rstrip("/")
    if wt and (fg == wt or cwd == wt):
        print(a.get("agent_status") or "unknown"); raise SystemExit(0)
raise SystemExit(1)
PY
)"
  rc=$?
  rm -f "$tmp"
  [ "$rc" = 0 ] || return 1
  printf '%s' "${st:-unknown}"
}

# agent_live <ws> <wt> -> 0 when a LIVE agent (working|idle) stands here.
# `done` is not live: its process has exited and the agentless path owns it.
agent_live() {
  local st; st="$(agent_status "$1" "$2" 2>/dev/null || true)"
  case "$st" in working|idle) return 0 ;; *) return 1 ;; esac
}

# agent_kind <ws> <wt> -> the agent's harness kind (pi/claude/...), or empty.
agent_kind() {
  local ws=$1 wt=${2:-} j tmp rc kind
  j="$(agents_json)" || return 1
  [ -n "$j" ] || return 1
  tmp="$(mktemp 2>/dev/null)" || return 1
  printf '%s' "$j" >"$tmp"
  kind="$(python3 - "$ws" "$wt" "$tmp" <<'PY' 2>/dev/null
import json,sys
ws, wt = sys.argv[1], (sys.argv[2] or "").rstrip("/")
try:
    agents = json.load(open(sys.argv[3]))
except Exception:
    raise SystemExit(1)
for a in agents or []:
    if (a.get("workspace_id") or "") == ws:
        print(a.get("agent") or ""); raise SystemExit(0)
    fg = (a.get("foreground_cwd") or "").rstrip("/")
    cwd = (a.get("cwd") or "").rstrip("/")
    if wt and (fg == wt or cwd == wt):
        print(a.get("agent") or ""); raise SystemExit(0)
raise SystemExit(1)
PY
)"
  rc=$?
  rm -f "$tmp"
  [ "$rc" = 0 ] || return 1
  printf '%s' "${kind:-}"
}

# terminal_errand <id> -> 0 when the record reached a word that ENDS the work.
# `needs-decision` is deliberately NOT terminal here: it waits for the Allfather.
terminal_errand() {
  local id=$1 f st verdict
  f="$(record "$id" review)" && [ -n "$f" ] && {
    verdict="$(awk -F= '$1=="verdict"{print $2; exit}' "$f" 2>/dev/null)"
    case "$verdict" in pass|fail) return 0 ;; esac
  }
  f="$(record "$id" close)" && [ -n "$f" ] && return 0
  f="$(record "$id" status)" || return 1
  [ -n "$f" ] || return 1
  st="$(tail -n1 "$f" 2>/dev/null | awk '{print $1}' | tr -d ':')"
  case "$st" in done|failed|accepted|returned|closed) return 0 ;; esac
  return 1
}

needs_decision_errand() {  # <id> -> 0 when the record waits on the Allfather
  local id=$1 f st
  f="$(record "$id" status)" || return 1
  [ -n "$f" ] || return 1
  st="$(tail -n1 "$f" 2>/dev/null | awk '{print $1}' | tr -d ':')"
  [ "$st" = "needs-decision" ]
}

# The idle grace: a finished-idle seat is stamped on first observation, and the
# stamp only counts while the agent KEEPS reporting idle. One `working` sample
# clears it — the grace is continuous, never a single glance.
idle_since() {  # <id> -> epoch on stdout; rc 1 when unstamped
  local id=$1 d stamp
  while IFS= read -r d; do
    [ -r "$d/.$id.idle-since" ] || continue
    stamp="$(head -n1 "$d/.$id.idle-since" 2>/dev/null | tr -dc '0-9')"
    [ -n "$stamp" ] && { printf '%s' "$stamp"; return 0; }
  done < <(state_dirs)
  return 1
}
mark_idle() {  # <id> — stamp this finished-idle seat now
  local id=$1 d
  while IFS= read -r d; do
    mkdir -p "$d" 2>/dev/null || continue
    printf '%s\n' "$(date +%s)" > "$d/.$id.idle-since" 2>/dev/null || true
  done < <(state_dirs)
}
clear_idle() {  # <id> — a working sample, or a retirement, resets the grace
  local id=$1 d
  while IFS= read -r d; do
    rm -f "$d/.$id.idle-since" 2>/dev/null || true
  done < <(state_dirs)
}

# discriminate <id> <ws> <wt> <pane> — set VERDICT/REASON and return:
#   0 KEEP (working | undecided), 1 RETIRE (finished), 2 AGENTLESS (no live agent)
discriminate() {
  local id=$1 ws=$2 wt=$3 st since now age
  VERDICT="undecided"; REASON="no live record"
  st="$(agent_status "$ws" "$wt" 2>/dev/null || true)"
  [ -n "$st" ] || return 2
  case "$st" in
    working)
      VERDICT="working"; REASON="the agent reports working — never touched"
      [ "${SEAT_REAP_DRY:-0}" = 0 ] && clear_idle "$id"
      return 0 ;;
    idle)
      if terminal_errand "$id"; then
        now="$(date +%s)"
        since="$(idle_since "$id" 2>/dev/null || true)"
        if [ -z "$since" ]; then
          [ "${SEAT_REAP_DRY:-0}" = 0 ] && mark_idle "$id"
          VERDICT="undecided"; REASON="finished-idle — grace not yet elapsed (just observed)"
          return 0
        fi
        age=$(( now - since ))
        if [ "$age" -lt "$IDLE_GRACE" ]; then
          VERDICT="undecided"; REASON="finished-idle — grace not yet elapsed (${age}s of ${IDLE_GRACE}s)"
          return 0
        fi
        VERDICT="finished"; REASON="finished-idle for ${age}s — retiring"
        return 1
      fi
      [ "${SEAT_REAP_DRY:-0}" = 0 ] && clear_idle "$id"
      if needs_decision_errand "$id"; then
        VERDICT="undecided"; REASON="needs-decision — waits for the Allfather, never reaped"
      else
        VERDICT="undecided"; REASON="idle but the record is not terminal — left alone"
      fi
      return 0 ;;
    done)
      [ "${SEAT_REAP_DRY:-0}" = 0 ] && clear_idle "$id"
      return 2 ;;
    *)
      VERDICT="undecided"; REASON="unknown agent state (${st}) — left alone"
      return 0 ;;
  esac
}

pane_of() { # <ws> -> the first pane id in that workspace
  [ "$HAVE_HERDR" = 1 ] || return 1
  herdr pane list --workspace "$1" 2>/dev/null \
    | sed -n 's/.*"pane_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# pane_at <abs-path> -> the pane whose shell is STANDING in that worktree and holds
# no agent. This is the second half of the 2026-11-10 fault: a dead Eindri's bare
# shell keeps its worktree `in-use` forever. Closing it is the first step of any
# reclaim, and it is asked of this door so nothing else parses `herdr pane list`.
pane_at() {
  [ "$HAVE_HERDR" = 1 ] || return 1
  local target tmp; target="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  # The JSON rides a FILE: a heredoc owns stdin, so `herdr pane list | python3 - <<PY`
  # streams nothing and every path reads as unheld (the trap bin/seat/seats.sh records).
  tmp="$(mktemp 2>/dev/null)" || return 1
  herdr pane list >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  python3 - "$target" "$tmp" <<'PY' 2>/dev/null
import json,sys
target=sys.argv[1].rstrip("/")
try:
    d=json.load(open(sys.argv[2]))
except Exception:
    raise SystemExit(1)
for p in (d.get("result") or {}).get("panes") or []:
    cwd=(p.get("cwd") or "").rstrip("/")
    if cwd==target or cwd.startswith(target+"/"):
        print(p.get("pane_id") or "")
        raise SystemExit(0)
raise SystemExit(1)
PY
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# ── the errand's own state: live, closed, or recordless ──────────────────────
# closed <id> -> 0 when the errand has reached a terminal word.
closed_errand() {
  local id=$1 f st verdict
  # A review verdict of `return` is NOT a closed errand: the work went back to the
  # worker, and closing its seat would bury a live errand. Only a terminal verdict
  # or a terminal status closes.
  f="$(record "$id" review)" && [ -n "$f" ] && {
    verdict="$(awk -F= '$1=="verdict"{print $2; exit}' "$f" 2>/dev/null)"
    case "$verdict" in pass|fail) return 0 ;; esac
  }
  f="$(record "$id" close)" && [ -n "$f" ] && return 0
  f="$(record "$id" status)" || return 1
  [ -n "$f" ] || return 1
  st="$(tail -n1 "$f" 2>/dev/null | awk '{print $1}' | tr -d ':')"
  case "$st" in done|failed|accepted|returned|closed) return 0 ;; esac
  return 1
}

# stale <id> -> 0 when the record claims work but nobody has breathed in 2 hours
stale_errand() {
  local id=$1 f age now
  f="$(record "$id" status)" || return 1
  [ -n "$f" ] || return 1
  now=$(date +%s)
  age=$(( now - $(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$now") ))
  [ "$age" -gt "${SEAT_REAP_STALE_SECONDS:-7200}" ]
}

# ── the settling grace (the house law, tests/test_eindri_liveness_grace.sh) ───
# A recordless workspace is NOT a dead one: einherjar-spawn.sh raises the herdr
# workspace at launch_herdr and writes the first status only AFTER the seat is
# proved — up to the whole seat-settle wait (60 s) later. A sweep that closed a
# recordless workspace on sight would kill a seat that is still booting, which is
# exactly the false-death the liveness grace was written to stop (2026-11-06).
#
# The age is measured from the launch stamp the spawner writes beside the record
# (state/.<id>.launched), then from the meta's `launched`, then from the
# worktree's own mtime. When NO timestamp can be found the workspace is KEPT and
# said so: an unmeasurable seat is assumed live, because assuming dead is the
# irreversible direction.
grace_seconds() { printf '%s' "${YMIR_SEAT_SETTLE:-60}"; }

recordless_age() { # <id> -> age in seconds on stdout; 1 when no stamp exists
  local id=$1 d stamp launched wt now
  now=$(date +%s)
  while IFS= read -r d; do
    if [ -r "$d/.$id.launched" ]; then
      stamp="$(head -n1 "$d/.$id.launched" 2>/dev/null | tr -dc '0-9')"
      [ -n "$stamp" ] && { printf '%s' "$((now - stamp))"; return 0; }
    fi
  done < <(state_dirs)
  launched="$(meta_key "$id" launched 2>/dev/null || true)"
  case "$launched" in ''|*[!0-9]*) ;; *) printf '%s' "$((now - launched))"; return 0 ;; esac
  wt="$(meta_key "$id" worktree 2>/dev/null || true)"
  [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"
  if [ -d "$wt" ]; then
    stamp=$(stat -c %Y "$wt" 2>/dev/null || stat -f %m "$wt" 2>/dev/null || true)
    case "$stamp" in ''|*[!0-9]*) ;; *) printf '%s' "$((now - stamp))"; return 0 ;; esac
  fi
  return 1
}

# ── plan 255 · S2: the retire verb — end the agent, THEN close the seat ─────
# The escalation, in order, never starting with a kill:
#   (a) the harness's own exit (per .agents/skills/hamr-adapters/);
#   (b) a bounded wait for the pane to become agentless;
#   (c) the close doors (seats.sh close, herdr workspace close) behind the
#       dirty/unpushed worktree guard;
#   (d) only then a TERM to the agent's own pid, recorded.
exit_command() {  # <agent-kind> -> the harness's own exit command
  case "${1:-}" in
    pi|codex) printf '%s' "/quit" ;;
    claude|opencode|cursor|grok|kimi|muse) printf '%s' "/exit" ;;
    *) printf '%s' "/quit" ;;   # unknown: pi's form is the house default
  esac
}

agent_pid() {  # <pane> -> the agent process pid, or empty (the pane's foreground)
  local pane=$1 tmp rc pid
  [ "$HAVE_HERDR" = 1 ] || return 1
  tmp="$(mktemp 2>/dev/null)" || return 1
  herdr pane process-info --pane "$pane" >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  pid="$(python3 - "$tmp" <<'PY' 2>/dev/null
import json,sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
procs = ((d.get("result") or {}).get("process_info") or {}).get("foreground_processes") or []
for p in procs:
    if (p.get("name") or "") in ("pi","claude","opencode","codex","cursor","grok","kimi","muse"):
        print(p.get("pid") or ""); raise SystemExit(0)
raise SystemExit(1)
PY
)"
  rc=$?
  rm -f "$tmp"
  [ "$rc" = 0 ] && [ -n "$pid" ] && { printf '%s' "$pid"; return 0; }
  return 1
}

# worktree_guard <wt> -> 0 clean enough to close; 1 refuse (GUARD_REASON set).
# A dirty or unpushed tree is the operator's work: never closed by a sweep. The
# `.pi/extensions` deletion is the migration's fault (0019), not work.
worktree_guard() {
  local wt=$1 up ahead head dirty
  GUARD_REASON=""
  [ -d "$wt" ] && [ -e "$wt/.git" ] || return 0
  dirty="$(git -C "$wt" status --porcelain 2>/dev/null | grep -vE '^.?D[[:space:]]+\.pi/extensions/')"
  [ -n "$dirty" ] && { GUARD_REASON="dirty worktree"; return 1; }
  up="$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  head="$(git -C "$wt" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$up" ]; then
    ahead="$(git -C "$wt" rev-list --count "${up}..HEAD" 2>/dev/null || echo 0)"
    [ "${ahead:-0}" -gt 0 ] && { GUARD_REASON="unpushed worktree (${ahead} commit(s))"; return 1; }
  elif [ -n "$head" ]; then
    # No upstream: refuse unless a remote branch already holds this exact commit.
    git -C "$wt" branch -r --contains "$head" 2>/dev/null | grep -q . \
      || { GUARD_REASON="unpushed worktree (no upstream, no remote holds this commit)"; return 1; }
  fi
  return 0
}

rune_retire() {  # <id> <pane> <ws> <step> — ONE runes line per retirement
  local id=$1 pane=$2 ws=$3 step=$4
  local runes="$SCRIPT_DIR/../records/runes-append.sh"
  [ -x "$runes" ] || return 0
  "$runes" seat-reap seat-retired \
    --message "id=$id pane=$pane verdict=$VERDICT reason=$REASON escalation=$step" \
    >/dev/null 2>&1 || true
}

retire_seat() {  # <id> <ws> <pane> -> one TOON row; 0 retired, 1 refused/failed
  local id=$1 ws=$2 pane=$3 wt kind exit_cmd step i pid
  wt="$(meta_key "$id" worktree 2>/dev/null || true)"
  [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"

  if ! worktree_guard "$wt"; then
    printf '  "%s","%s","%s","refused: %s"\n' "$id" "$ws" "$pane" "$GUARD_REASON"
    return 1
  fi

  kind="$(agent_kind "$ws" "$wt" 2>/dev/null || true)"
  exit_cmd="$(exit_command "$kind")"
  step="harness-exit ($kind ${exit_cmd:-none})"

  # (a) the harness's own exit, delivered as its verified command
  if [ -n "$pane" ] && [ "$HAVE_HERDR" = 1 ] && [ -n "$exit_cmd" ]; then
    herdr pane send-text "$pane" "$exit_cmd" >/dev/null 2>&1 || true
    herdr pane send-keys "$pane" enter >/dev/null 2>&1 || true
  fi

  # (b) a bounded wait for the pane to become agentless
  for i in $(seq 1 "$EXIT_WAIT"); do
    agent_live "$ws" "$wt" || { step="agent-exited"; break; }
    sleep 1
  done

  # (c) the close doors, behind the worktree guard already passed
  if [ -n "$pane" ] && [ -x "$SCRIPT_DIR/seats.sh" ]; then
    "$SCRIPT_DIR/seats.sh" close "$pane" >/dev/null 2>&1 || true
  fi
  if [ -n "$ws" ] && [ "$HAVE_HERDR" = 1 ] && ! agent_live "$ws" "$wt"; then
    if herdr workspace close "$ws" >/dev/null 2>&1; then
      step="${step}+workspace-closed"
      rune_retire "$id" "$pane" "$ws" "$step"
      printf '  "%s","%s","%s","retired: %s — %s (escalation: %s)"\n' "$id" "$ws" "$pane" "$VERDICT" "$REASON" "$step"
      return 0
    fi
  fi

  # (d) only then a TERM to the agent's own pid, recorded — never silent
  pid="$(agent_pid "$pane" 2>/dev/null || true)"
  if [ -n "$pid" ]; then
    kill -TERM "$pid" 2>/dev/null || true
    step="term-agent-pid-${pid}"
    sleep 2
    if [ -n "$ws" ] && [ "$HAVE_HERDR" = 1 ] && ! agent_live "$ws" "$wt"; then
      herdr workspace close "$ws" >/dev/null 2>&1 && step="${step}+workspace-closed"
    fi
  fi

  rune_retire "$id" "$pane" "$ws" "$step"
  printf '  "%s","%s","%s","retired: %s — %s (escalation: %s)"\n' "$id" "$ws" "$pane" "$VERDICT" "$REASON" "$step"
  return 0
}

# ── one close ────────────────────────────────────────────────────────────────
# close_seat <id> <ws> <pane> <why> -> prints one TOON row; 0 closed, 1 refused/failed
close_seat() {
  local id=$1 ws=$2 pane=$3 why=$4 wt disc_rc
  wt="$(meta_key "$id" worktree 2>/dev/null || true)"
  [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"

  discriminate "$id" "$ws" "$wt" "$pane"
  disc_rc=$?
  case "$disc_rc" in
    0)  # KEEP — a working or undecided seat is never closed by this door
        printf '  "%s","%s","%s","refused: %s — %s"\n' "$id" "$ws" "$pane" "$VERDICT" "$REASON"
        return 1 ;;
    1)  # RETIRE — a finished seat goes through the retire verb (S2)
        retire_seat "$id" "$ws" "$pane"
        return $? ;;
    2)  # AGENTLESS — the close below
        ;;
  esac
  # The pane door refuses a live agent on its own reading — belt and braces,
  # because the agent list is a moment, and a close is forever.
  if [ -n "$pane" ] && [ -x "$SCRIPT_DIR/seats.sh" ]; then
    "$SCRIPT_DIR/seats.sh" close "$pane" >/dev/null 2>&1 || true
  fi
  if [ -n "$ws" ] && [ "$HAVE_HERDR" = 1 ]; then
    # A second liveness read immediately before the irreversible step.
    if agent_live "$ws" "$wt"; then
      printf '  "%s","%s","%s","refused: an agent appeared at the moment of closing"\n' "$id" "$ws" "$pane"
      return 1
    fi
    if herdr workspace close "$ws" >/dev/null 2>&1; then
      printf '  "%s","%s","%s","%s"\n' "$id" "$ws" "$pane" "$why"
      clear_idle "$id"
      local d
      while IFS= read -r d; do
        printf 'closed=%s\nworkspace=%s\nwhy=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ws" "$why" >"$d/$id.seat-closed" 2>/dev/null || true
      done < <(state_dirs)
      return 0
    fi
    printf '  "%s","%s","%s","failed: herdr refused the workspace close"\n' "$id" "$ws" "$pane"
    return 1
  fi
  printf '  "%s","%s","%s","failed: no pane backend answered"\n' "$id" "$ws" "$pane"
  return 1
}

# resolve_workspace <id> -> ws id (recorded first, then by label)
resolve_workspace() {
  local id=$1 ws
  ws="$(meta_key "$id" workspace 2>/dev/null || true)"
  [ -n "$ws" ] && { printf '%s' "$ws"; return 0; }
  ws="$(ws_rows 2>/dev/null | awk -F'\t' -v l="eindri-$id" '$2==l{print $1; exit}')"
  [ -n "$ws" ] && { printf '%s' "$ws"; return 0; }
  return 1
}

reap_one() { # <id> -> prints rows; 0 closed
  local id=$1 ws pane why
  ws="$(resolve_workspace "$id")" || {
    printf '  "%s","","","no herdr workspace carries this errand"\n' "$id"
    return 1
  }
  pane="$(meta_key "$id" seat_pane 2>/dev/null || true)"
  [ -n "$pane" ] || pane="$(meta_key "$id" window 2>/dev/null || true)"
  [ -n "$pane" ] || pane="$(pane_of "$ws" 2>/dev/null || true)"
  why="closed"
  closed_errand "$id" || why="no live record"
  close_seat "$id" "$ws" "$pane" "$why"
}

# ── the sweep ────────────────────────────────────────────────────────────────
sweep() { # <do-it: 0|1>
  local do_it=$1 ws label id pane wt why disc_rc n_closed=0 n_retired=0 n_kept=0 n_ref=0 n_finidle=0 n_working=0
  local row rrow
  local -a closed_rows=() retired_rows=() kept_rows=() refused_rows=()
  SEAT_REAP_DRY=$((1 - do_it))   # --list mutates no idle grace state

  [ "$HAVE_HERDR" = 1 ] || { printf 'seat-reap[1]{state}:\n  "no herdr on this host — no seat to close"\n'; return 0; }

  while IFS=$'\t' read -r ws label _st; do
    [ -n "$ws" ] || continue
    case "$label" in eindri-*) ;; *) continue ;; esac
    id="${label#eindri-}"
    # The main hall is never swept, even if someone names a workspace after it.
    [ -n "$id" ] || continue
    wt="$(meta_key "$id" worktree 2>/dev/null || true)"
    [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"
    pane="$(meta_key "$id" seat_pane 2>/dev/null || true)"
    [ -n "$pane" ] || pane="$(pane_of "$ws" 2>/dev/null || true)"

    discriminate "$id" "$ws" "$wt" "$pane"
    disc_rc=$?
    case "$disc_rc" in
      0)  # KEEP — a working or undecided seat is never swept
          n_kept=$((n_kept + 1))
          case "$REASON" in finished-idle*) n_finidle=$((n_finidle + 1)) ;; esac
          [ "$VERDICT" = working ] && n_working=$((n_working + 1))
          kept_rows+=("$(printf '  "%s","%s","%s","%s — %s"' "$id" "$ws" "$pane" "$VERDICT" "$REASON")")
          continue ;;
      1)  # RETIRE — a finished seat goes through the retire verb (S2)
          if [ "$do_it" = 0 ]; then
            if worktree_guard "$wt"; then
              n_retired=$((n_retired + 1))
              retired_rows+=("$(printf '  "%s","%s","%s","%s — %s"' "$id" "$ws" "$pane" "$VERDICT" "$REASON")")
            else
              n_ref=$((n_ref + 1))
              refused_rows+=("$(printf '  "%s","%s","%s","refused: %s"' "$id" "$ws" "$pane" "$GUARD_REASON")")
            fi
            continue
          fi
          if rrow="$(retire_seat "$id" "$ws" "$pane")"; then
            n_retired=$((n_retired + 1)); retired_rows+=("$rrow")
            clear_idle "$id"
          else
            case "$rrow" in *refused*) n_ref=$((n_ref + 1)); refused_rows+=("$rrow") ;;
                          *) n_kept=$((n_kept + 1)); kept_rows+=("$rrow") ;; esac
          fi
          continue ;;
      2)  # AGENTLESS — the existing close path below
          ;;
    esac
    if needs_decision_errand "$id"; then
      n_kept=$((n_kept + 1))
      kept_rows+=("$(printf '  "%s","%s","%s","needs-decision — waits for the Allfather, never reaped"' "$id" "$ws" "$pane")")
      continue
    fi
    if closed_errand "$id"; then
      why="errand closed, no agent"
    elif [ -z "$(record "$id" status 2>/dev/null || true)" ]; then
      # THE HEARTBEAT IS THE RECORD OF LIFE — but a seat takes time to breathe.
      # Inside the settling grace the workspace is SETTLING and nothing is closed
      # (tests/test_eindri_liveness_grace.sh is the law this honours).
      age="$(recordless_age "$id" 2>/dev/null || true)"
      if [ -z "$age" ]; then
        n_kept=$((n_kept + 1))
        kept_rows+=("$(printf '  "%s","%s","%s","no live record and no timestamp — kept (an unmeasurable seat is assumed live)"' "$id" "$ws" "$pane")")
        continue
      fi
      if [ "$age" -lt "$(grace_seconds)" ]; then
        n_kept=$((n_kept + 1))
        kept_rows+=("$(printf '  "%s","%s","%s","SETTLING — %ss old, inside the %ss grace"' "$id" "$ws" "$pane" "$age" "$(grace_seconds)")")
        continue
      fi
      why="no live record"
    elif stale_errand "$id"; then
      why="record stale, no agent"
    else
      n_kept=$((n_kept + 1))
      kept_rows+=("$(printf '  "%s","%s","%s","record still fresh — left alone"' "$id" "$ws" "$pane")")
      continue
    fi

    if [ "$do_it" = 0 ]; then
      n_closed=$((n_closed + 1))
      closed_rows+=("$(printf '  "%s","%s","%s","%s"' "$id" "$ws" "$pane" "$why")")
      continue
    fi
    local row
    if row="$(close_seat "$id" "$ws" "$pane" "$why")"; then
      n_closed=$((n_closed + 1)); closed_rows+=("$row")
    else
      case "$row" in *refused*) n_ref=$((n_ref + 1)); refused_rows+=("$row") ;;
                    *) n_kept=$((n_kept + 1)); kept_rows+=("$row") ;; esac
    fi
  done < <(ws_rows 2>/dev/null)

  local verb=closed; [ "$do_it" = 0 ] && verb=would-close
  printf 'seat-reap[1]{%s,retired,kept,finished-idle,working,refused}:\n  "%s","%s","%s","%s","%s","%s"\n' \
    "$verb" "$n_closed" "$n_retired" "$n_kept" "$n_finidle" "$n_working" "$n_ref"
  if [ "${#retired_rows[@]}" -gt 0 ]; then
    printf 'retired[%s]{id,workspace,pane,why}:\n' "${#retired_rows[@]}"
    printf '%s\n' "${retired_rows[@]}"
  fi
  if [ "${#closed_rows[@]}" -gt 0 ]; then
    printf '%s[%s]{id,workspace,pane,why}:\n' "$verb" "${#closed_rows[@]}"
    printf '%s\n' "${closed_rows[@]}"
  fi
  if [ "${#refused_rows[@]}" -gt 0 ]; then
    printf 'refused[%s]{id,workspace,pane,why}:\n' "${#refused_rows[@]}"
    printf '%s\n' "${refused_rows[@]}"
  fi
  if [ "${#kept_rows[@]}" -gt 0 ]; then
    printf 'kept[%s]{id,workspace,pane,why}:\n' "${#kept_rows[@]}"
    printf '%s\n' "${kept_rows[@]}"
  fi
  [ "$n_closed" -gt 0 ] && return 0
  return 0
}

# ── the hook, per harness (requirement: pi, opencode and claude alike) ───────
SESSION_DOOR="$ROOT/bin/time/saga-session-start.sh"

# ── verify: report the two structural faults, mend nothing ───────────────────
# `--check` on the installer and on Gróa must not repair an old home; it must NAME
# what is broken. The mend is the migration's (0018) and Eir's.
is_linked_worktree() {  # <path>
  local p=${1:-.} common own
  common="$(git -C "$p" rev-parse --git-common-dir 2>/dev/null)" || return 1
  own="$(git -C "$p" rev-parse --git-dir 2>/dev/null)" || return 1
  [ -n "$common" ] && [ -n "$own" ] || return 1
  [ "$(CDPATH='' cd "$p" && CDPATH='' cd "$common" 2>/dev/null && pwd -P)" \
    = "$(CDPATH='' cd "$p" && CDPATH='' cd "$own" 2>/dev/null && pwd -P)" ] && return 1
  return 0
}
verify() {
  local bad=0 pointer line wt dirty n_bad=0
  pointer="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}/.ymir-root"
  if [ -r "$pointer" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in
        */.yggdrasil/*|*/.yggdrasil)
          printf '  "root-record","broken","%s is a worktree path — a root is a home, a worktree is an errand"\n' "$line"
          bad=$((bad + 1)); continue ;;
      esac
      if [ -d "$line" ] && is_linked_worktree "$line"; then
        printf '  "root-record","broken","%s is a linked worktree — bin/seat/valknut-load.sh must not record it"\n' "$line"
        bad=$((bad + 1))
      fi
    done <"$pointer"
    [ "$bad" = 0 ] && printf '  "root-record","ok","%s"\n' "$pointer"
  else
    printf '  "root-record","absent","%s (nothing recorded yet)"\n' "$pointer"
  fi
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    case "$wt" in */.yggdrasil/*) ;; *) continue ;; esac
    [ -d "$wt" ] || continue
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | grep -c '^\( \{0,1\}\)D  *\.pi/extensions/')"
    [ "${dirty:-0}" = 0 ] && continue
    printf '  "worktree","broken","%s reports %s extension file(s) deleted — sparse-checkout not set"\n' "$wt" "$dirty"
    n_bad=$((n_bad + 1))
  done < <(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
  [ "$n_bad" = 0 ] && printf '  "worktrees","ok","no worktree reports an extension deletion"\n'
  if [ $((bad + n_bad)) -gt 0 ]; then
    printf 'seat-reap: %s fault(s) — mend: bin/engine/ymir-migrate.sh apply (migration 0019)\n' "$((bad + n_bad))" >&2
    return 1
  fi
  return 0
}

claude_settings() { printf '%s' "${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"; }

# The SessionStart hook is MERGED, never rewritten: another tool's keys are the
# operator's, and this door has no business dropping them (the same reason
# bin/pi/arm.sh refuses to mangle a YAML key it did not write).
claude_hook_seated() {
  local f; f="$(claude_settings)"
  [ -r "$f" ] || return 1
  python3 - "$f" "$SESSION_DOOR" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
want=sys.argv[2]
for grp in (d.get("hooks") or {}).get("SessionStart") or []:
    for h in grp.get("hooks") or []:
        if h.get("command") == want:
            raise SystemExit(0)
raise SystemExit(1)
PY
}

claude_hook_seat() {
  local f; f="$(claude_settings)"
  mkdir -p "$(dirname "$f")" || return 1
  [ -r "$f" ] && cp "$f" "$f.seat-reap.bak" 2>/dev/null
  python3 - "$f" "$SESSION_DOOR" <<'PY'
import json,os,sys
f, want = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(f)) if os.path.exists(f) else {}
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
hooks = d.setdefault("hooks", {})
groups = hooks.setdefault("SessionStart", [])
for grp in groups:
    for h in grp.get("hooks") or []:
        if h.get("command") == want:
            print("claude: SessionStart hook already seated")
            raise SystemExit(0)
groups.append({"hooks": [{"type": "command", "command": want, "timeout": 180}]})
tmp = f + ".seat-reap.tmp"
json.dump(d, open(tmp, "w"), indent=2)
open(tmp, "a").write("\n")
os.replace(tmp, f)
print("claude: SessionStart hook seated in %s" % f)
PY
}

seat_hooks() { # <do-it 0|1>
  local do_it=$1 present=0 bad=0
  # pi — the session side is the deployed watch extension (valknut-load seats it).
  if command -v pi >/dev/null 2>&1; then
    present=$((present + 1))
    if ls "$HOME/.pi/agent/extensions"/gna-pi-watch.ts >/dev/null 2>&1 \
       || ls "$ROOT/.pi/extensions"/gna-pi-watch.ts >/dev/null 2>&1; then
      printf '  "pi","seated","the watch extension delivers the digest, and the digest sweeps"\n'
    else
      if [ "$do_it" = 1 ] && [ -x "$SCRIPT_DIR/valknut-load.sh" ]; then
        "$SCRIPT_DIR/valknut-load.sh" --all >/dev/null 2>&1 || true
      fi
      if ls "$HOME/.pi/agent/extensions"/gna-pi-watch.ts >/dev/null 2>&1; then
        printf '  "pi","seated","seated now by bin/seat/valknut-load.sh --all"\n'
      else
        printf '  "pi","NOT SEATED","run: bin/seat/valknut-load.sh --all"\n'; bad=$((bad + 1))
      fi
    fi
  fi
  # opencode — the plugin that arms the watch and relays the digest.
  if command -v opencode >/dev/null 2>&1; then
    present=$((present + 1))
    if ls "$HOME/.config/opencode/plugins"/*syn-watch* "$ROOT/.opencode/plugins"/*syn-watch* >/dev/null 2>&1; then
      printf '  "opencode","seated","the syn-watch plugin arms the session side"\n'
    else
      printf '  "opencode","NOT SEATED","run: bin/engine/ymir-install.sh (opencode-v2-plugin step)"\n'; bad=$((bad + 1))
    fi
  fi
  # claude — a real SessionStart hook, merged into the operator's own settings.
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    present=$((present + 1))
    if claude_hook_seated; then
      printf '  "claude","seated","SessionStart runs the digest, and the digest sweeps"\n'
    elif [ "$do_it" = 1 ] && claude_hook_seat >/dev/null 2>&1 && claude_hook_seated; then
      printf '  "claude","seated","SessionStart hook merged into %s (backup kept)"\n' "$(claude_settings)"
    else
      printf '  "claude","NOT SEATED","run: bin/seat/seat-reap.sh --install (merges %s)"\n' "$(claude_settings)"; bad=$((bad + 1))
    fi
  fi
  if [ "$present" = 0 ]; then
    printf '  "-","skip","no harness on this host — a clean skip, nothing to seat"\n'
  fi
  [ "$bad" = 0 ]
}

# ── plan 255 · S4: the orphan pane — named in the brief, closed ONLY by his word ──
pane_cwd() {  # <pane-id> -> the pane's cwd on stdout; rc 1 when unknown
  local pane=$1 tmp cwd rc
  [ "$HAVE_HERDR" = 1 ] || return 1
  tmp="$(mktemp 2>/dev/null)" || return 1
  herdr pane list >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  cwd="$(python3 - "$pane" "$tmp" <<'PY' 2>/dev/null
import json,sys
pane=sys.argv[1]
try:
    d=json.load(open(sys.argv[2]))
except Exception:
    raise SystemExit(1)
for p in (d.get("result") or {}).get("panes") or []:
    if (p.get("pane_id") or "")==pane:
        print(p.get("cwd") or ""); raise SystemExit(0)
raise SystemExit(1)
PY
)"
  rc=$?
  rm -f "$tmp"
  [ "$rc" = 0 ] && [ -n "$cwd" ] && { printf '%s' "$cwd"; return 0; }
  return 1
}

close_pane() {  # <pane-id> — the ONLY door that closes an orphan (bare) shell
  local pane=$1 cwd
  if python3 "$SCRIPT_DIR/herdr-agents.py" --find --pane "$pane" >/dev/null 2>&1; then
    printf 'seat-reap[1]{pane,state}:\n  "%s","refused: a live agent stands here"\n' "$pane"
    return 1
  fi
  cwd="$(pane_cwd "$pane" 2>/dev/null || true)"
  case "$cwd" in
    "$ROOT/.yggdrasil/"*|"$ROOT/.yggdrasil")
      printf 'seat-reap[1]{pane,state}:\n  "%s","refused: an errand pane — the sweep owns it"\n' "$pane"
      return 1 ;;
  esac
  if "$SCRIPT_DIR/seats.sh" close "$pane" >/dev/null 2>&1; then
    printf 'seat-reap[1]{pane,state}:\n  "%s","closed (bare shell, no errand — his working directory)"\n' "$pane"
    return 0
  fi
  printf 'seat-reap[1]{pane,state}:\n  "%s","refused: the pane did not close"\n' "$pane"
  return 1
}

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  --sweep)   shift; sweep 1 ;;
  --list)    shift; sweep 0 ;;
  --status)  shift; sweep 0 ;;
  --shell)
    # Close the bare shell holding a worktree — refuse a live agent, as everywhere.
    target="${2:-}"
    [ -n "$target" ] || { printf 'error: --shell <worktree path>\n' >&2; exit 2; }
    p="$(pane_at "$target")" || { printf 'seat-reap[1]{path,state}:\n  "%s","no pane stands in it"\n' "$target"; exit 1; }
    if agent_in_workspace "" "$target"; then
      printf 'seat-reap[1]{path,pane,state}:\n  "%s","%s","refused: a live agent stands here"\n' "$target" "$p"; exit 1
    fi
    if "$SCRIPT_DIR/seats.sh" close "$p" >/dev/null 2>&1; then
      printf 'seat-reap[1]{path,pane,state}:\n  "%s","%s","closed (bare shell, no agent)"\n' "$target" "$p"
      exit 0
    fi
    printf 'seat-reap[1]{path,pane,state}:\n  "%s","%s","refused: the pane did not close"\n' "$target" "$p"
    exit 1 ;;
  --close-pane)
    # Close an ORPHAN pane (a bare shell, no errand) — his word, never a sweep.
    target="${2:-}"
    [ -n "$target" ] || { printf 'error: --close-pane <pane-id>\n' >&2; exit 2; }
    close_pane "$target"
    exit $? ;;
  --install)
    printf 'seat-reap[1]{harness,state,detail}:\n'
    seat_hooks 1 || exit 1
    exit 0 ;;
  --check)
    printf 'seat-reap[1]{harness,state,detail}:\n'
    seat_hooks 0 || exit 1
    exit 0 ;;
  --verify)
    printf 'seat-reap[1]{surface,state,detail}:\n'
    verify ;;
  "" ) printf 'error: an errand id or --sweep|--list|--install|--check is required\n' >&2; exit 2 ;;
  -* ) printf 'error: unknown option %s\n' "$1" >&2; exit 2 ;;
  *)
    id=$1
    printf 'seat-reap[1]{id,workspace,pane,why}:\n'
    reap_one "$id" ;;
esac
