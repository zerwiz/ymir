#!/usr/bin/env bash
# arm-speak-lib.sh — THE definition of "a session that can speak" (plan 310 §1).
#
# WHY THIS FILE EXISTS, AND WHY IT IS THE ONLY ONE. On 2026-11-17 the heart's arm read
# `held` all morning while every pi on that machine was dead: the holder was
# `ymir_runtime watch run`, a supervisor with no model behind it. A tell was handed to it
# and nothing answered. The fault was not the arm — it was that nothing in the house said
# what "can speak" MEANS. Two doors (the machine arm's `hold`, and the heart's own guard)
# need that answer, so it is defined ONCE, here, and every other door CALLS it:
#
#   speaks_probe <pid>          can this pid speak?  0 yes · 1 no
#   speaks_line                 the one TOON row, from the last probe
#   speaks_claimant_pid         whose session a caller is: <session pid> in SPEAK_CLAIMANT
#
# WHAT "CAN SPEAK" IS. A live harness session whose model is behind it — proved, not
# assumed:
#
#   1. THE CLAIMANT IS A HARNESS. The named pid is a live process whose comm one of the
#      harnesses the lock door already knows (`src/ymir_runtime/state/lock.py`
#      HARNESS_COMMS: pi, opencode, claude, cursor, codex, grok, kimi, muse, hermes). A
#      watcher — python3, bash, `ymir_runtime watch run` — is refused by name: A WATCHER IS
#      NOT A SPEAKER. (The pid asked about IS the session: `speaks_claimant_pid` is the one
#      place that walks a caller's ancestry to find it, exactly as the lock door does.)
#   2. IT HAS SPOKEN RECENTLY. The harness writes its own session transcript, and the
#      freshest one for that session is younger than `YMIR_SPEAK_MAX_AGE` seconds
#      (default 1800). This is the live model heartbeat: a supervisor can beat without a
#      mind, but only a model writes a turn.
#
# THE PROOF IS NAMED, NEVER GUESSED (RULES/25: a borrowed capability says so). Where the
# harness keys its transcripts by the session's own working directory (`pi`, `claude`) the
# proof is `transcript:cwd` — that session's own file. Where the harness does not key by
# path (`codex`, `opencode`) the freshest transcript for THAT HARNESS is taken and the
# proof says `transcript:harness` — borrowed, and it says so. A harness with no known
# transcript shelf is REFUSED, naming the row to add: a heartbeat that cannot be proved is
# not a heartbeat.
#
# NOT A PERMISSION. This answers "is there a mind behind this pid". Who may act on an arm
# or a lease is `bin/voice/arm-lease-lib.sh`; what a read-only agent may still do (ASK the
# holder — `bin/seat/lock-ask.sh`) is unchanged by anything here.
#
# Env (optional, one default each — Rule 07):
#   YMIR_SPEAK_MAX_AGE   how old a transcript may be and still prove a live model (1800)
#   YMIR_SPEAK_HOME      the home whose harness shelves are read (default: $HOME)
#
# Source-safe: defines functions and constants only; it runs nothing at source time.
set -u

# One number, one place: the age at which a transcript stops proving a live model.
SPEAK_MAX_AGE="${YMIR_SPEAK_MAX_AGE:-1800}"
SPEAK_ANCESTRY_LIMIT=10
# The harnesses, in the lock door's own list. A new harness is added THERE and here —
# two lists is the drift this house keeps paying for, so the lock lib is asked first when
# it is present, and this line is the fallback for a bare caller.
SPEAK_HARNESSES_DEFAULT="pi opencode claude cursor codex grok kimi muse hermes"
SPEAK_HARNESSES="${SPEAK_HARNESSES:-$SPEAK_HARNESSES_DEFAULT}"

# The standing result of the last probe. Read by callers, never by guessing.
SPEAKS=""; SPEAK_HARNESS=""; SPEAK_PID=""; SPEAK_PROOF=""; SPEAK_AGE=""; SPEAK_WHY=""

speak_home() { printf '%s' "${YMIR_SPEAK_HOME:-${HOME:-}}"; }

speak_comm() {  # <pid> — the executable name, /proc where it exists, ps where it does not
  local c=""
  c="$(cat "/proc/$1/comm" 2>/dev/null || true)"
  [ -n "$c" ] || c="$(ps -o comm= -p "$1" 2>/dev/null | sed 's#.*/##' | tr -d '[:space:]' || true)"
  printf '%s' "$c"
}

speak_ppid() {  # <pid>
  [ -r "/proc/$1/stat" ] || { printf ''; return 0; }
  sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | awk '{print $2}'
}

speak_alive() {  # <pid>
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null
}

speak_is_harness() {  # <comm>
  local want="$1" one
  for one in $SPEAK_HARNESSES; do [ "$one" = "$want" ] && return 0; done
  return 1
}

# speak_harness_of <pid> — the nearest live harness in the pid's ancestry (itself first).
# Prints "<pid> <comm>" and returns 0; prints nothing and returns 1 when there is none.
speak_harness_of() {
  local pid="${1:-}" comm hops=0
  while [ -n "$pid" ] && [ "$pid" != 0 ] && [ "$hops" -lt "$SPEAK_ANCESTRY_LIMIT" ]; do
    case "$pid" in ''|*[!0-9]*) break ;; esac
    comm="$(speak_comm "$pid")"
    if [ -n "$comm" ] && speak_is_harness "$comm" && speak_alive "$pid"; then
      printf '%s %s' "$pid" "$comm"; return 0
    fi
    pid="$(speak_ppid "$pid")"
    hops=$((hops + 1))
  done
  return 1
}

# speak_shelf <comm> — the harness's own transcript shelf.
#   echoes "<root>\t<cwd-keyed:yes|no>"; returns 1 when this harness has no known shelf.
speak_shelf() {
  local home; home="$(speak_home)"
  case "${1:-}" in
    pi)       printf '%s\t%s' "$home/.pi/agent/sessions" yes ;;
    claude)   printf '%s\t%s' "$home/.claude/projects" yes ;;
    codex)    printf '%s\t%s' "$home/.codex/sessions" no ;;
    opencode) printf '%s\t%s' "$home/.local/state/opencode" no ;;
    hermes)   printf '%s\t%s' "$home/.hermes" no ;;
    *) return 1 ;;
  esac
}

# speak_slug <comm> <cwd> — how that harness names a session's shelf directory.
speak_slug() {
  local cwd="$1"
  case "${2:-}" in
    pi)     printf '%s' "--$(printf '%s' "$cwd" | sed 's#^/##; s#/#-#g')--" ;;
    claude) printf '%s' "-$(printf '%s' "$cwd" | sed 's#^/##; s#/#-#g')" ;;
    *) return 1 ;;
  esac
}

# speak_newest <dir> — the freshest *.jsonl under this shelf (recursive), as its mtime.
speak_newest() {
  [ -d "$1" ] || return 1
  find "$1" -maxdepth 3 -type f -name '*.jsonl' -printf '%T@\n' 2>/dev/null \
    | sort -n | tail -1
}

speaks_line() {  # the standing answer as one TOON row
  printf 'speaks[1]{verdict,harness,pid,proof,age_s,max_age_s,why}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s"\n' \
    "${SPEAKS:-no}" "${SPEAK_HARNESS:-none}" "${SPEAK_PID:-none}" "${SPEAK_PROOF:-none}" \
    "${SPEAK_AGE:-none}" "$SPEAK_MAX_AGE" "${SPEAK_WHY:-}"
}

# ── speaks_probe <pid> ────────────────────────────────────────────────────────
# The one function. 0 = this pid can speak; 1 = it cannot, and SPEAK_WHY says why.
#
# THE PID ITSELF MUST BE THE HARNESS — not a process that happens to have one above it.
# Everything started from a pi pane has pi in its ancestry, so an ancestry test would call
# a `python3` watcher a speaker. The caller names the SESSION (`speaks_claimant_pid` walks
# the ancestry the way the lock door does, and hands back the harness pid); this function
# judges that pid and nothing else.
speaks_probe() {
  local ask="${1:-}" found hp hc comm shelf keyed cwd root newest age slug
  SPEAKS=no; SPEAK_HARNESS=""; SPEAK_PID=""; SPEAK_PROOF=none; SPEAK_AGE=""; SPEAK_WHY=""

  case "$ask" in
    ''|*[!0-9]*)
      SPEAK_WHY="no pid was named, so there is no session to prove"
      return 1 ;;
  esac
  if ! speak_alive "$ask"; then
    SPEAK_WHY="pid $ask is not a live process"
    return 1
  fi

  hc="$(speak_comm "$ask")"
  if ! speak_is_harness "$hc"; then
    SPEAK_WHY="pid $ask is '${hc:-unknown}', not a harness session ($(printf '%s' "$SPEAK_HARNESSES" | sed 's/ /, /g')) — a watcher is not a speaker"
    return 1
  fi
  hp="$ask"

  if ! shelf="$(speak_shelf "$hc")"; then
    SPEAK_HARNESS="$hc"; SPEAK_PID="$hp"
    SPEAK_WHY="harness '$hc' has no known transcript shelf, so its heartbeat cannot be proved — add its row to speak_shelf (bin/voice/arm-speak-lib.sh)"
    return 1
  fi
  root="${shelf%%$'\t'*}"; keyed="${shelf##*$'\t'}"

  if [ "$keyed" = yes ]; then
    cwd="$(readlink -f "/proc/$hp/cwd" 2>/dev/null || true)"
    if [ -z "$cwd" ] || ! slug="$(speak_slug "$cwd" "$hc")"; then
      SPEAK_HARNESS="$hc"; SPEAK_PID="$hp"
      SPEAK_WHY="harness '$hc' keys its transcripts by session directory and pid $hp's directory cannot be read, so this session's own transcript cannot be found"
      return 1
    fi
    root="$root/$slug"
    SPEAK_PROOF="transcript:cwd"
  else
    SPEAK_PROOF="transcript:harness"
  fi

  newest="$(speak_newest "$root")"
  if [ -z "$newest" ]; then
    SPEAK_HARNESS="$hc"; SPEAK_PID="$hp"
    SPEAK_WHY="no transcript for $hc at $root — nothing proves a model ever spoke in this session"
    return 1
  fi
  age="$(( $(date +%s) - ${newest%%.*} ))"
  [ "$age" -ge 0 ] || age=0
  SPEAK_HARNESS="$hc"; SPEAK_PID="$hp"; SPEAK_AGE="$age"
  if [ "$age" -gt "$SPEAK_MAX_AGE" ]; then
    SPEAK_WHY="the newest $hc transcript is ${age}s old (over ${SPEAK_MAX_AGE}s) — the model has stopped speaking"
    return 1
  fi
  SPEAKS=yes
  SPEAK_WHY="a live $hc session (pid $hp) whose transcript was written ${age}s ago"
  return 0
}

# ── speaks_claimant ───────────────────────────────────────────────────────────
# WHOSE session a caller is. A harness names its own pid (BROKK_SESSION_PID). With none
# named, the ancestry of this shell decides — the same walk the lock door makes
# (src/ymir_runtime/state/lock.py session_pid), so the arm, the lock and this lib never
# disagree about which session is speaking. A caller with no harness anywhere above it
# gets its own pid back, and `speaks_probe` will refuse it by name.
speaks_claimant_pid() {  # <result-var> [shell-pid]
  local var="${1:-}" start="${2:-$PPID}" pid_text found
  [ -n "$var" ] || return 2
  if [ -n "${BROKK_SESSION_PID:-}" ]; then
    printf -v "$var" '%s' "$BROKK_SESSION_PID"
    return 0
  fi
  found="$(speak_harness_of "$start" || true)"
  if [ -n "$found" ]; then pid_text="${found%% *}"; else pid_text="$start"; fi
  printf -v "$var" '%s' "$pid_text"
  return 0
}
