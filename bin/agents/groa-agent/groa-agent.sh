#!/usr/bin/env bash
# groa-agent.sh — Gróa's body on a schedule: the updater, leashed, one per install.
#
#   groa-agent.sh start   # launch in the background (opencode, free model)
#   groa-agent.sh stop    # stop it
#   groa-agent.sh status  # is it running? last lines of its log
#   groa-agent.sh tick    # one scheduled run: start, wait, stop if it hangs
#   groa-agent.sh check   # same agent, but only looks — changes nothing
#
# The agent is deliberately narrow: exact commands, no commits, no merges, no
# pushes. If a command fails it must stop and say so, not improvise.
set -uo pipefail

REPO="${YMIR_REPO:-$HOME/ymir}"

# Rule 07: the home is resolved, never restated.
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ]; then
  for _lib in "$REPO/bin/vault/hoard-lib.sh" "$HOME/ymir/bin/vault/hoard-lib.sh"; do
    [ -r "$_lib" ] && { . "$_lib"; ymir_home_root HOME_DIR 2>/dev/null; break; }
  done
  unset _lib
fi
[ -n "$HOME_DIR" ] || HOME_DIR="$HOME/.local/state"
STATE_DIR="$HOME_DIR/hodd/state"
LOG="$STATE_DIR/groa-agent.log"
PIDFILE="$STATE_DIR/groa-agent.pid"
MODEL="${GROA_MODEL:-opencode/nemotron-3-ultra-free}"
TIMEOUT="${GROA_TIMEOUT:-900}"

mkdir -p "$STATE_DIR" 2>/dev/null || { STATE_DIR="$HOME/.local/state/groa-agent"; mkdir -p "$STATE_DIR"; LOG="$STATE_DIR/agent.log"; PIDFILE="$STATE_DIR/agent.pid"; }

common_rules="Hard rules: run only the commands listed. Never commit, never merge, never push, never
rebase, never edit a file by hand, never create a branch. If any command fails, stop immediately,
print the exact error, and do nothing else. Finish with a short report of what happened."

PROMPT_FILE="${GROA_PROMPT:-$HOME/.local/share/groa-agent/prompt.md}"
[ -r "$PROMPT_FILE" ] && common_rules="$(cat "$PROMPT_FILE")"

prompt_run="$common_rules

Working directory: $REPO

1. Run: git fetch --all --prune
2. Run: bin/agents/groa-update.sh --check
3. If and only if it reports updates are available, run: bin/agents/groa-update.sh
4. Run: bin/engine/ymir-migrate.sh status
5. Report: which targets were behind, what was updated, whether migrations are
   needed, and any error text."

prompt_check="$common_rules

Working directory: $REPO

1. Run: git fetch --all --prune
2. Run: bin/agents/groa-update.sh --check
3. Run: bin/gates/checks/ymir-update-check.sh --force
4. Report: is the tree behind? is a newer Ymir on npm? Do not change anything."

running(){ [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

# ── the record ───────────────────────────────────────────────────────────────
# Gróa does not only log to a file: what she did is written where the house keeps
# its memory — the daily log always, the Runes ledger when she acted or stopped,
# and the well when the tree actually moved.
record_report(){
  local offset="$1" segment guard behind updated migrations line
  segment="$(tail -c +$((offset+1)) "$LOG" 2>/dev/null || true)"
  guard="$(printf '%s' "$segment" | sed -n 's/.*GUARD: *//p' | head -1)"
  behind="$(printf '%s' "$segment" | sed -n 's/.*BEHIND: *//p' | head -1)"
  updated="$(printf '%s' "$segment" | sed -n 's/.*UPDATED: *//p' | head -1)"
  migrations="$(printf '%s' "$segment" | sed -n 's/.*MIGRATIONS: *//p' | head -1)"

  # nothing was behind and nothing moved: no record, no noise
  [ -z "$guard" ] && { [ -z "$behind" ] || [ "$behind" = "none" ]; } &&     { [ -z "$updated" ] || [ "$updated" = "nothing" ]; } && return 0

  if [ -n "$guard" ]; then
    line="Gróa stopped: $guard"
  else
    line="Gróa — behind: ${behind:-?} · updated: ${updated:-?} · migrations: ${migrations:-?}"
  fi

  [ -x "$REPO/bin/records/daily-log.sh" ] &&     ( cd "$REPO" && YMIR_HOME="$HOME_DIR" bin/records/daily-log.sh add --actor groa "$line" ) >/dev/null 2>&1 || true
  printf '%s\n' "$line" >> "$LOG"

  if [ -n "$guard" ]; then
    [ -x "$REPO/bin/records/runes-append.sh" ] &&       ( cd "$REPO" && YMIR_HOME="$HOME_DIR" bin/records/runes-append.sh groa groa.guard --message "$line" ) >/dev/null 2>&1 || true
  else
    [ -x "$REPO/bin/records/runes-append.sh" ] &&       ( cd "$REPO" && YMIR_HOME="$HOME_DIR" bin/records/runes-append.sh groa groa.update --message "$line" ) >/dev/null 2>&1 || true
    case "${updated:-}" in
      ""|nothing) ;;
      *) [ -x "$REPO/bin/records/mimir.sh" ] &&            ( cd "$REPO" && YMIR_HOME="$HOME_DIR" bin/records/mimir.sh observe "$line" --tags groa,update --source groa-agent ) >/dev/null 2>&1 || true ;;
    esac
  fi
}

# run the agent, then record what it found
run_and_record(){
  local offset
  offset="$(wc -c < "$LOG" 2>/dev/null || echo 0)"
  ( cd "$REPO" && timeout "$TIMEOUT" opencode run -m "$MODEL" "$PROMPT_TEXT" >> "$LOG" 2>&1 )
  record_report "$offset"
}

case "${1:-}" in
  start|tick|check)
    if running; then echo "already running (pid $(cat "$PIDFILE"))"; exit 0; fi
    prompt="$prompt_run"; [ "${1:-}" = check ] && prompt="$prompt_check"
    PROMPT_TEXT="$prompt"
    kind="${1:-start}"
    {
      echo "── $(date -Is) $kind with $MODEL ─────────────────────────"
    } >> "$LOG"
    PROMPT_TEXT="$prompt" run_and_record &
    echo $! > "$PIDFILE"
    if [ "$kind" = tick ]; then
      wait "$(cat "$PIDFILE")" 2>/dev/null
      echo "── $(date -Is) tick finished (rc $?) ─────────────────────" >> "$LOG"
      rm -f "$PIDFILE"
      tail -20 "$LOG"
    else
      echo "started (pid $(cat "$PIDFILE"), model $MODEL, log $LOG)"
    fi
    ;;
  stop)
    if running; then
      pid="$(cat "$PIDFILE")"; kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
      sleep 2; kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
      echo "stopped (pid $pid)" >> "$LOG"; rm -f "$PIDFILE"
      echo "stopped (pid $pid)"
    else
      echo "not running"; rm -f "$PIDFILE"
    fi
    ;;
  status)
    if running; then echo "running (pid $(cat "$PIDFILE"))"; else echo "not running"; fi
    echo "── last lines ──"; tail -15 "$LOG" 2>/dev/null || echo "(no log yet)"
    ;;
  *)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
