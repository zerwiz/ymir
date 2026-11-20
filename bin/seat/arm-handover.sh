#!/usr/bin/env bash
# arm-handover.sh — the arm changing hands is a RECORDED, ANNOUNCED event.
#
# At the Allfather's word, 2026-11-20: "we need to fix so the arm cant randomly lose".
# Measured the night before: the helm changed hands four times in ninety minutes —
# pi 2243828 → claude 1074973 at 00:34 → pi 2354925 at 01:05 → claude 2425137 at
# 01:06 — and `state/` held no line anywhere saying the arm had moved. A hand that
# loses the helm without being told cannot know it is read-only, so the room went
# quiet while three sessions each believed they were the helm.
#
# `src/ymir_runtime/state/lock.py` writes the record (`.lock-journal`, and
# `.arm.handover` for the last change of hands). This door READS it and is the one
# place that speaks it:
#
#   arm-handover.sh                  the last change of hands, one readable row
#   arm-handover.sh --journal [n]    the last n records (default 20), oldest first
#   arm-handover.sh --prior-helm     the last recorded helm: role, pid, pane,
#                                    whether that process is still alive, and whether
#                                    it is a helm-capable harness (or only a holder)
#   arm-handover.sh --pane <pid>     the PROVED herdr pane of a pid, written to
#                                    .arm.pane (or cleared — never a ghost)
#   arm-handover.sh --announce       speak the last record into both panes
#
# THE PANE IS PROVED, NEVER INHERITED. `state/.arm.pane` named `w39:p23` for four
# days after that pane died, so every door that aims a line at the helm aimed at a
# ghost. A pane is written only when herdr can be shown to hold it and to host the
# holder (its shell, or a foreground process, in the holder's ancestry). When no
# pane can be proved the file is REMOVED and the record says `pane=none`: an absent
# pane makes a door fall back; a ghost makes it lie.
#
# Env (all optional):
#   YMIR_STATE_DIR   the state root (default: the home's, via hoard-lib.sh)
#   EINDRI_SEND      the send door (default: bin/agents/eindri-send.sh) — a test
#                    points this at a recorder
#   YMIR_HERDR_CMD   the herdr binary (default: `herdr`) — a test points this at a stub
#
# Exit: 0 ran · 1 nothing to say / the door failed · 2 usage.
set -u

VERSION="1.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)}"
STATE_DOOR="$ROOT/bin/records/ymir-state.sh"
OWNER_FILE=".arm.pane"

usage() { awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit "${1:-0}"; }

_RA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -r "$_RA_DIR/../time/sol-lib.sh" ]; then . "$_RA_DIR/../time/sol-lib.sh"; else sol_line() { date '+%Y-%m-%d %H:%M %Z'; }; fi
die() { printf '%s — arm-handover: %s\n' "$(sol_line)" "$*" >&2; exit 1; }

STATE=""
resolve_state() {
  [ -n "$STATE" ] && return 0
  if [ -n "${YMIR_STATE_DIR:-}" ]; then STATE="$YMIR_STATE_DIR"; return 0; fi
  local hl="$ROOT/bin/vault/hoard-lib.sh" hs=""
  if [ -r "$hl" ]; then
    # shellcheck source=../vault/hoard-lib.sh
    . "$hl"
    hoard_state_dir hs 2>/dev/null || hs=""
  fi
  STATE="${hs:-${BROKK_STATE_OVERRIDE:-${BROKK_HOME:-$ROOT}/state}}"
}

# The last change of hands: `.arm.handover` (written by the lock module for exactly
# this question), and the journal as the fallback for a seat that predates it.
last_record() {  # prints the newest event=acquire|release|reap line
  if [ -r "$STATE/.arm.handover" ]; then
    head -1 "$STATE/.arm.handover" | grep -q 'event=' && { head -1 "$STATE/.arm.handover"; return 0; }
  fi
  local f="$STATE/.lock-journal"
  [ -r "$f" ] || return 1
  awk '/ event=(acquire|release|reap) /{ line=$0 } END{ if (line != "") print line; else exit 1 }' "$f"
}

field() {  # <line> <key>
  printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1
}

# ── the pane, proved against herdr ───────────────────────────────────────────
_herdr() { timeout 8 ${YMIR_HERDR_CMD:-herdr} "$@" 2>/dev/null; }

ancestors() {  # <pid> — the process and its ancestors, one per line
  python3 - "$1" <<'PY' 2>/dev/null
import sys
pid = sys.argv[1]
seen = []
for _ in range(64):
    try:
        with open("/proc/%s/stat" % pid) as fh:
            ppid = fh.read().rsplit(")", 1)[1].split()[1]
    except (OSError, IndexError):
        break
    seen.append(pid)
    if ppid in ("0", "1") or ppid == pid or ppid in seen:
        break
    pid = ppid
print("\n".join(seen))
PY
}

pane_pids() {  # <pane> — the pane's shell and foreground processes
  _herdr pane process-info --pane "$1" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
pi=(d.get("result") or {}).get("process_info") or {}
out=[]
if pi.get("shell_pid"): out.append(str(pi["shell_pid"]))
for p in pi.get("foreground_processes") or []:
    if p.get("pid"): out.append(str(p["pid"]))
print("\n".join(out))'
}

pane_exists() {  # <pane> — 0 when herdr still holds it
  _herdr pane list | P="$1" python3 -c 'import json,os,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(1)
for p in (d.get("result") or {}).get("panes") or []:
    if p.get("pane_id")==os.environ["P"]: raise SystemExit(0)
raise SystemExit(1)'
}

pane_hosts() {  # <pane> <pid> — 0 when that pane demonstrably hosts that process
  local pane="$1" pid="$2" have pid_i
  # `process-info` on a pane herdr no longer holds answers nothing, so this one
  # question proves both "herdr still holds the pane" and "it hosts the process".
  have="$(ancestors "$pid")"
  [ -n "$have" ] || return 1
  for pid_i in $(pane_pids "$pane"); do
    printf '%s\n' "$have" | grep -qx "$pid_i" && return 0
  done
  return 1
}

resolve_pane() {  # <pid> — print the proved pane, or nothing
  # ONE QUESTION, AND IT IS CHEAP. A harness herdr launched carries HERDR_PANE_ID in
  # its own environment, so the pane is read from the holder and then PROVED against
  # herdr's process table. A process without it was not launched in a pane (a plain
  # terminal, a cron, a supervisor), and no pane can be PROVED for it — the door says
  # so and writes nothing. Sweeping every pane of the machine to guess would put ~40
  # herdr calls in front of every turn end and would still be a guess.
  #
  # The honest limit: a Claude session started in a plain terminal is ADOPTED by
  # herdr's agent table (by session id), but that id is not in the process environment
  # and the session file is not held open, so the holder cannot be proved into a pane.
  # Measured 2026-11-20: the live helm is exactly such a session, and this door
  # answered "none" rather than name a pane it could not prove.
  local pid="$1" cand=""
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  cand="$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^HERDR_PANE_ID=//p' | head -1)"
  [ -n "$cand" ] || return 0
  pane_hosts "$cand" "$pid" && printf '%s' "$cand"
  return 0
}

write_pane() {  # <pane|""> — write atomically, or clear a ghost
  local pane="$1"
  if [ -n "$pane" ]; then
    if printf '%s\n' "$pane" >"$STATE/$OWNER_FILE.new" 2>/dev/null; then
      mv -f "$STATE/$OWNER_FILE.new" "$STATE/$OWNER_FILE" 2>/dev/null || true
    fi
  else
    rm -f "$STATE/$OWNER_FILE" 2>/dev/null || true
  fi
}

# ── the verbs ────────────────────────────────────────────────────────────────
cmd_show() {
  resolve_state
  local line; line="$(last_record)" || { printf 'arm-handover: no change of hands is on the record\n'; return 1; }
  # A pane already on file that herdr no longer holds is a GHOST: clear it.
  local pane; pane="$(head -1 "$STATE/$OWNER_FILE" 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$pane" ] && ! pane_exists "$pane"; then
    write_pane ""
    printf 'arm-handover: cleared a ghost pane (%s — herdr does not hold it)\n' "$pane" >&2
  fi
  printf 'arm-handover[1]{at,event,holder,from,to,why,role,harness,pane}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$(printf '%s' "$line" | cut -d' ' -f1)" "$(field "$line" event)" "$(field "$line" pid)" \
    "$(field "$line" from_pid)" "$(field "$line" to_pid)" "$(field "$line" why)" \
    "$(field "$line" role)" "$(field "$line" harness)" "${pane:-none}"
  return 0
}

cmd_journal() {
  resolve_state
  local n="${1:-20}" f="$STATE/.lock-journal"
  case "$n" in ''|*[!0-9]*) die "journal takes a count, not '$n'" ;; esac
  [ -r "$f" ] || { printf 'arm-handover: no journal at %s\n' "$f"; return 1; }
  awk '/ event=(acquire|release|reap) /' "$f" | tail -n "$n"
  return 0
}

cmd_prior_helm() {
  resolve_state
  local line event pid role alive=no why harness
  if ! line="$(last_record)"; then
    printf 'prior-helm[1]{role,pid,pane,alive,why,harness}:\n  "none","none","none","no","no change of hands is on the record","no"\n'
    return 1
  fi
  event="$(field "$line" event)"
  role="$(field "$line" role)"
  pid="$(field "$line" pid)"
  why="$(field "$line" why)"
  harness="$(field "$line" harness)"; [ -n "$harness" ] || harness=no
  case "$event" in
    release) pid="" ; why="released by its own word" ;;
    reap)    pid="" ; why="reaped: $(field "$line" reason)" ;;
  esac
  if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    case "$(tr -d '[:space:]' <"/proc/$pid/stat" 2>/dev/null | sed 's/.*) //' | awk '{print $1}')" in
      Z*|X*) : ;;
      *)     alive=yes ;;
    esac
  fi
  local pane; pane="$(head -1 "$STATE/$OWNER_FILE" 2>/dev/null | tr -d '[:space:]')"
  printf 'prior-helm[1]{role,pid,pane,alive,why,harness}:\n'
  printf '  "%s","%s","%s","%s","%s","%s"\n' \
    "${role:-unknown}" "${pid:-none}" "${pane:-none}" "$alive" "${why:-unknown}" "$harness"
  return 0
}

cmd_pane() {
  resolve_state
  local pid="${1:-}"
  case "$pid" in ''|*[!0-9]*) die "pane takes a pid" ;; esac
  local pane; pane="$(resolve_pane "$pid")"
  write_pane "$pane"
  if [ -n "$pane" ]; then
    printf 'arm-handover-pane[1]{pid,pane,proved}:\n  "%s","%s","yes"\n' "$pid" "$pane"
  else
    printf 'arm-handover-pane[1]{pid,pane,proved}:\n  "%s","none","no — nothing was invented"\n' "$pid"
  fi
  return 0
}

# One line into one pane, through the house's send door. Never fatal, never a loop:
# the pane this door itself stands in is skipped (a session is not told what it did).
_speak() {  # <pane> <text>
  local pane="$1" text="$2" send="${EINDRI_SEND:-$ROOT/bin/agents/eindri-send.sh}"
  [ -n "$pane" ] || return 0
  [ "$pane" = "${HERDR_PANE_ID:-}" ] && return 0
  [ -x "$send" ] || return 0
  timeout 20 "$send" --from "script arm-handover" "$pane" "$text" >/dev/null 2>&1 || true
  return 0
}

cmd_announce() {
  resolve_state
  local line; line="$(last_record)" || return 0
  local event role pid from to why old_pane new_pane who
  event="$(field "$line" event)"; role="$(field "$line" role)"
  pid="$(field "$line" pid)"; from="$(field "$line" from_pid)"
  to="$(field "$line" to_pid)"; why="$(field "$line" why)"

  # The pane of the CURRENT holder is refreshed at every change of hands — proved,
  # or cleared. This is the whole of the drift fix: the file names the holder's
  # real pane, and never one herdr has dropped.
  old_pane="$(head -1 "$STATE/$OWNER_FILE" 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$to" ] && [ "$to" != none ]; then
    new_pane="$(resolve_pane "$to")"
    write_pane "$new_pane"
  else
    new_pane=""
    write_pane ""
  fi

  case "$event" in
    acquire) who="${from:-none}"; ;;
    release) who="$pid"; ;;
    reap)    who="$from"; ;;
  esac
  # The hand that lost it is told; the hand that took it is told unless it IS the
  # pane this door stands in. A pane herdr no longer holds is never spoken to.
  if [ -n "$old_pane" ] && [ "$old_pane" != "$new_pane" ]; then
    _speak "$old_pane" "the helm moved: ${role:-unknown} (pid ${to:-none}) holds the arm now, and it was yours until $event ($why). This session is read-only for spawn, steer, merge and drain until you take it back — bin/voice/rodd-arm.sh hold."
  fi
  if [ -n "$new_pane" ]; then
    _speak "$new_pane" "you hold the helm now: role ${role:-unknown} (pid ${to:-none}), mode $event ($why). The record is $STATE/.lock-journal."
  fi
  return 0
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage 0 ;;
  --announce) shift; cmd_announce ;;
  --journal) shift; cmd_journal "${1:-20}" ;;
  --prior-helm) shift; cmd_prior_helm ;;
  --pane) shift; cmd_pane "${1:-}" ;;
  --show|show) shift; cmd_show ;;
  *) printf 'error: unknown verb %s\nhelp: arm-handover.sh [--show|--journal [n]|--prior-helm|--pane <pid>|--announce]\n' "$1" >&2; exit 2 ;;
esac
