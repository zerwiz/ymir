#!/usr/bin/env bash
# ymir-style.sh — the cloth of the terminal halls.
#
# Ymir had no design for its own command line: correct output, no experience.
# This is the cloth — cut from the same stone as the halls
# (midgard/design-system/tokens.css): bone for words, bronze for what acts,
# steel for what stands, blood for what is wrong, and the forge's marks for the
# states a plan can be in.
#
# The rules it obeys (cli-guidelines, clig.dev, Monospace TUI):
#   · colour, marks and motion only when a human is present — never in a pipe,
#     never when NO_COLOR is set, never on a dumb terminal, never for --no-color
#   · data goes to stdout, the human's rendering goes to stderr, so a pipeline
#     never has to parse a decoration
#   · a reaction for every action, and a next step for every ending
#   · density first: no banner bigger than four lines, no rule longer than the text
#
# Source-safe; functions only. Nothing here writes a byte of data.
set -u

# The progress primitives (appended below, "the work in progress"):
#   style_step [--data] "<what>" -- <command…>   one command: rune spinner, one ending line
#   style_steps <n>                              the next n steps are counted [1/n] … [n/n]
#   style_download "<what>" <url> <dest>         a byte bar when the size is known, else a spinner
#   style_bar <done> <total> [label]             the bar itself, for a caller that counts its own work
# On a human's terminal they move; in a pipe, under NO_COLOR, on a dumb terminal or in CI they
# print ONE plain line per step and never a control byte. They never swallow an exit code.

# --- the palette, from the tokens (truecolor → 256 → none) ------------------
style_init() {
  STYLE_ON=0
  # A human must be present: stderr is a terminal and nobody said no.
  # CI is never a human at a window, even when a runner hands it a pty.
  if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ "${YMIR_NO_COLOR:-0}" != 1 ]; then
    STYLE_ON=1
  fi
  if [ "$STYLE_ON" = 1 ] && { [ "${COLORTERM:-}" = truecolor ] || [ "${COLORTERM:-}" = 24bit ]; }; then
    C_BONE=$'\033[38;2;207;195;169m'; C_BRONZE=$'\033[38;2;201;151;79m'
    C_STEEL=$'\033[38;2;150;160;168m'; C_BLOOD=$'\033[38;2;194;88;74m'
    C_FAINT=$'\033[38;2;107;98;80m'; C_BOLD=$'\033[1m'
  elif [ "$STYLE_ON" = 1 ]; then
    C_BONE=$'\033[38;5;187m'; C_BRONZE=$'\033[38;5;179m'
    C_STEEL=$'\033[38;5;109m'; C_BLOOD=$'\033[38;5;167m'
    C_FAINT=$'\033[38;5;101m'; C_BOLD=$'\033[1m'
  else
    C_BONE=""; C_BRONZE=""; C_STEEL=""; C_BLOOD=""; C_FAINT=""; C_BOLD=""
  fi
  C_OFF=""
  [ "$STYLE_ON" = 1 ] && C_OFF=$'\033[0m'
  # A sourced library must never end a function on a FAILING test: callers run
  # under `set -e` (scripts/start.sh does), and the last command's status becomes
  # the function's — so a caller raised the whole hall and died at the cloth.
  return 0
}

# The forge's marks, one per state a thing can be in.
style_mark() {  # <state> → a glyph
  case "${1:-}" in
    DO|do)             printf '%s' '◆' ;;
    SKIP|skip|already) printf '%s' '·' ;;
    INFO|info)         printf '%s' '—' ;;
    BLOCKED|blocked)   printf '%s' '✕' ;;
    CONSENT|consent)   printf '%s' '?' ;;
    unconfigured)      printf '%s' '?' ;;
    OK|ok)             printf '%s' '✓' ;;
    WARN|warn)         printf '%s' '·' ;;
    FAIL|fail)         printf '%s' '✕' ;;
    *)                 printf '%s' '·' ;;
  esac
}

style_colour() {  # <state> → the colour for it
  case "${1:-}" in
    DO|CONSENT|WARN|warn|do|consent) printf '%s' "$C_BRONZE" ;;
    unconfigured)                    printf '%s' "$C_BRONZE" ;;
    OK|SKIP|INFO|ok|skip|info)       printf '%s' "$C_STEEL" ;;
    FAIL|BLOCKED|fail|blocked)       printf '%s' "$C_BLOOD" ;;
    *)                               printf '%s' "$C_FAINT" ;;
  esac
}

# --- preferences: a user must be able to say "not again", once --------------
# The store is the operator's settings (see bin/engine/ymir-config.sh); absent means on.
notice_state() {  # <key> → on|off
  local key="$1" store line
  if [ -n "${YMIR_SETTINGS_DIR:-}" ]; then store="$YMIR_SETTINGS_DIR/notices.conf"
# The operator's home: env -> the recorded choice -> the ONE documented default
# (Rule 07; the default lives in bin/vault/hoard-lib.sh, never in a script).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _ymir_yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _ymir_yc in "$_ymir_yr/hoard-lib.sh" "$_ymir_yr/../vault/hoard-lib.sh" "$_ymir_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_ymir_yc" ] && { . "$_ymir_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _ymir_yr _ymir_yc
fi
ymir_home_root YMIR_HOME
  else store="${YMIR_HOME}/config/notices.conf"; fi
  [ -r "$store" ] || { printf 'on'; return 0; }
  line="$(grep -m1 "^${key}=" "$store" 2>/dev/null || true)"
  [ -n "$line" ] && printf '%s' "${line#*=}" || printf 'on'
}
notice_wanted() { [ "$(notice_state "${1-}")" != off ]; }
notice_hint() {  # <key> — said once, and never when the hints are silenced
  [ "$(notice_state hints)" = off ] && return 0
  printf '%s
' "${C_FAINT}      (not again: ymir config notice ${1-} off)${C_OFF}" >&2
}

# --- the pieces -------------------------------------------------------------

# The mark: four lines at most. The WORDS show even in a pipe — only the colour
# is conditional, because colour is decoration and the name is information.
style_title() {  # <name> <claim>
  printf '%s\n' "${C_BRONZE}   ᛉ  ${C_BOLD}${1}${C_OFF}" >&2
  printf '%s\n' "${C_FAINT}      ${2}${C_OFF}" >&2
  printf '\n' >&2
}

style_rule() {  # a hairline, no wider than the words it separates
  local width="${1:-52}"
  [ "$STYLE_ON" = 1 ] || return 0
  local line=""; local i=0
  while [ "$i" -lt "$width" ]; do line="$line─"; i=$((i+1)); done
  printf '%s\n' "${C_FAINT}${line}${C_OFF}" >&2
}

style_say()  { printf '%s\n' "${C_BONE}$*${C_OFF}" >&2; }
style_hint() { printf '%s\n' "${C_FAINT}$*${C_OFF}" >&2; }

style_line() {  # <state> <name> <detail> — the one line per thing
  local state="$1" name="$2" detail="${3:-}"
  printf '  %s%s%s %-12s %s%s\n' \
    "$(style_colour "$state")" "$(style_mark "$state")" "$C_OFF" \
    "$name" "$(style_colour "$state")" "$detail" >&2
  printf '%s' "$C_OFF" >/dev/null
}

style_heading() { printf '\n%s%s%s\n' "$C_BRONZE" "$1" "$C_OFF" >&2; }

# For a long hour: say what is happening and why it takes a while. A user who
# knows the halls are being set right waits; a user watching a silent cursor
# wonders whether it has broken.
style_patience() {  # [what is being set right]
  notice_wanted patience || return 0
  local what="${1:-the halls are being set right}"
  printf '\n' >&2
  style_line DO "much moves" "$what"
  style_hint "      this hour is long, and nothing of yours is lost in it —"
  style_hint "      roots come home, shapes are re-cut, names are set true again."
  style_hint "      Your patience is noted, and it is earned."
  notice_hint patience
  printf '\n' >&2
}

# The ending: what stands, then exactly what to type next. Every CLI deserves
# to leave the operator with the next step and nothing else to guess.
style_next() {  # one command per line, as "verb — what it does"
  notice_wanted next || return 0
  printf '\n%s\n' "${C_BOLD}Where to go from here${C_OFF}" >&2
  while [ $# -gt 0 ]; do
    local cmd="${1%% — *}" what="${1#* — }"
    printf '  %s%-22s%s %s\n' "$C_BRONZE" "$cmd" "$C_OFF" "$(printf '%s' "$what" | sed "s/^/$C_FAINT/;s/$/$C_OFF/")" >&2
    shift
  done
  printf '\n' >&2
}


# ═══ the work in progress ═════════════════════════════════════════════════════
# A download, a clone, an install or a build is the long hour of a command line, and
# npm's and git's own noise says nothing of it in Ymir's voice. These primitives give
# every such hour the same shape: a bronze rune turning while it runs, and ONE line when
# it ends — ✓ steel with the time, or ✕ blood with the log's tail and where the log lives.
# The command's own output is kept in a log (state/log), never thrown away.
#
# Contract (tests: bin/desktop/tests/test_style_progress.sh):
#   · the exit code of the command is the exit code of the step — always
#   · motion and colour only on a TTY with a human behind it (STYLE_ON=1); otherwise
#     exactly one plain line per step, no \r, no escape bytes
#   · the command runs in a subshell: a shell function works, its variables do not persist
#   · decoration goes to stderr; with --data the command's stdout is replayed on stdout
#     after the ending line (pass or fail), so a script's data contract survives being wrapped
#
# Env: YMIR_LOG_DIR (default ${YMIR_STATE_DIR:-$XDG_STATE_HOME or ~/.local/state/ymir}/log),
#      YMIR_STEP_KEEP=1 keeps the log of a step that passed too, YMIR_STEP_TAIL (default 15).

STYLE_RUNES="ᛉ ᚠ ᚢ ᚦ ᚨ ᚱ"
STYLE_STEP_I=0
STYLE_STEP_N=0

style_steps() {  # <n> — count the next n steps as [1/n] … [n/n]; 0 clears
  STYLE_STEP_I=0; STYLE_STEP_N="${1:-0}"
  return 0
}

_style_ready() { [ -n "${STYLE_ON+x}" ] || style_init; return 0; }

_style_elapsed() {  # <seconds> → 4s · 1m04s
  local s="${1:-0}"
  if [ "$s" -lt 1 ]; then printf '<1s'
  elif [ "$s" -lt 60 ]; then printf '%ss' "$s"
  else printf '%sm%02ds' "$((s/60))" "$((s%60))"; fi
}

_style_bytes() {  # <bytes> → 812 KB · 6.8 MB
  awk -v b="${1:-0}" 'BEGIN{ if (b<1024) printf "%d B", b; else if (b<1048576) printf "%.0f KB", b/1024; else if (b<1073741824) printf "%.1f MB", b/1048576; else printf "%.2f GB", b/1073741824 }'
}

_style_logfile() {  # <what> → a fresh log path
  local dir slug
  dir="${YMIR_LOG_DIR:-${YMIR_STATE_DIR:-${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/ymir}/log}"
  mkdir -p "$dir" 2>/dev/null || dir="${TMPDIR:-/tmp}"
  slug="$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '-' | sed 's/--*/-/g;s/^-//;s/-$//' | cut -c1-40)"
  printf '%s/%s-%s-%s.log' "$dir" "${slug:-step}" "$(date +%Y%m%d-%H%M%S)" "$$"
}

# Sets STYLE_PREFIX ("[i/n] " when a count is set). Not a $(…) call: a subshell would lose the increment.
_style_prefix() {
  STYLE_PREFIX=""
  if [ "${STYLE_STEP_N:-0}" -gt 0 ]; then
    STYLE_STEP_I=$((STYLE_STEP_I+1))
    STYLE_PREFIX="[$STYLE_STEP_I/$STYLE_STEP_N] "
  fi
}

_style_spin_clear() { [ "$STYLE_ON" = 1 ] && printf '\r\033[K' >&2; return 0; }

# The ending of a step, shared by style_step and style_download.
_style_end() {  # <rc> <label> <seconds> <log>
  local rc="$1" label="$2" secs="$3" log="$4" t
  t="$(_style_elapsed "$secs")"
  if [ "$rc" -eq 0 ]; then
    printf '  %s%s%s %s %s%s%s\n' "$C_STEEL" "$(style_mark ok)" "$C_OFF" "$label" "$C_FAINT" "$t" "$C_OFF" >&2
    [ "${YMIR_STEP_KEEP:-0}" = 1 ] || rm -f "$log" 2>/dev/null
  else
    printf '  %s%s%s %s %s%s (exit %s)%s\n' "$C_BLOOD" "$(style_mark fail)" "$C_OFF" "$label" "$C_BLOOD" "$t" "$rc" "$C_OFF" >&2
    if [ -s "$log" ]; then
      tail -n "${YMIR_STEP_TAIL:-15}" "$log" 2>/dev/null | sed "s/^/      ${C_FAINT}/;s/\$/${C_OFF}/" >&2
    fi
    printf '      %slog: %s%s\n' "$C_FAINT" "$log" "$C_OFF" >&2
  fi
}

style_step() {  # [--data] <what> -- <command…>
  _style_ready
  local data=0
  [ "${1:-}" = --data ] && { data=1; shift; }
  local what="${1:-working}"; shift
  [ "${1:-}" = -- ] && shift
  [ "$#" -gt 0 ] || { printf 'style_step: no command given for "%s"\n' "$what" >&2; return 2; }
  local label log out="" pid rc t0 i=0 runes saved_int saved_term
  _style_prefix; label="$STYLE_PREFIX$what"
  log="$(_style_logfile "$what")"
  [ "$data" = 1 ] && out="$log.out"
  t0=$SECONDS
  if [ "$data" = 1 ]; then "$@" >"$out" 2>"$log" </dev/null & else "$@" >"$log" 2>&1 </dev/null & fi
  pid=$!
  if [ "$STYLE_ON" = 1 ]; then
    saved_int="$(trap -p INT)"; saved_term="$(trap -p TERM)"
    trap 'kill "$pid" 2>/dev/null; printf "\r\033[K\033[?25h" >&2; exit 130' INT TERM
    printf '\033[?25l' >&2
    # shellcheck disable=SC2206
    runes=($STYLE_RUNES)
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r\033[K  %s%s%s %s %s%s%s' "$C_BRONZE" "${runes[$((i % ${#runes[@]}))]}" "$C_OFF" "$label" "$C_FAINT" "$(_style_elapsed $((SECONDS-t0)))" "$C_OFF" >&2
      i=$((i+1)); sleep 0.12 2>/dev/null || sleep 1
    done
  fi
  wait "$pid"; rc=$?
  if [ "$STYLE_ON" = 1 ]; then
    printf '\r\033[K\033[?25h' >&2
    trap - INT TERM
    [ -n "$saved_int" ] && eval "$saved_int"; [ -n "$saved_term" ] && eval "$saved_term"
  fi
  _style_end "$rc" "$label" $((SECONDS-t0)) "$log"
  if [ -n "$out" ]; then
    cat "$out"     # on a failure too: a caller may parse the rows a failed run still printed
    rm -f "$out"
  fi
  return "$rc"
}

# The bar: a caller that counts its own work (bytes, files, items) draws it here.
style_bar() {  # <done> <total> [label] — redraws in place on a TTY; silent otherwise
  _style_ready
  [ "$STYLE_ON" = 1 ] || return 0
  local done="${1:-0}" total="${2:-0}" label="${3:-}" width=24 fill pct bar="" i=0
  [ "$total" -gt 0 ] 2>/dev/null || return 0
  [ "$done" -gt "$total" ] && done="$total"
  pct=$((done*100/total)); fill=$((done*width/total))
  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$fill" ]; then bar="$bar█"; else bar="$bar░"; fi
    i=$((i+1))
  done
  printf '\r\033[K  %s%s%s %s%3s%%%s %s%s%s' "$C_BRONZE" "$bar" "$C_OFF" "$C_BONE" "$pct" "$C_OFF" "$C_FAINT" "$label" "$C_OFF" >&2
}

style_download() {  # <what> <url> <dest> — a byte bar when the size is known, else the spinner
  _style_ready
  local what="$1" url="$2" dest="$3" size="" label log pid rc t0 have
  command -v curl >/dev/null 2>&1 || { printf 'style_download: curl is not on this machine\n' >&2; return 127; }
  _style_prefix; label="$STYLE_PREFIX$what"
  size="$(curl -fsSIL --max-time 15 "$url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{n=$2} END{print n}')"
  case "$size" in ''|*[!0-9]*|0) size="" ;; esac
  if [ "$STYLE_ON" != 1 ] || [ -z "$size" ]; then
    # unknown size, or nobody to watch a bar: the spinner (or the plain line) tells the truth
    local keep_n="$STYLE_STEP_N"; STYLE_STEP_N=0
    style_step "$label" -- curl -fsSL -o "$dest" "$url"; rc=$?
    STYLE_STEP_N="$keep_n"
    return "$rc"
  fi
  log="$(_style_logfile "$what")"; t0=$SECONDS
  curl -fsSL -o "$dest" "$url" >"$log" 2>&1 </dev/null & pid=$!
  printf '\033[?25l' >&2
  while kill -0 "$pid" 2>/dev/null; do
    have=0; [ -f "$dest" ] && have="$(wc -c <"$dest" | tr -d ' ')"
    style_bar "$have" "$size" "$what  $(_style_bytes "$have") / $(_style_bytes "$size")"
    sleep 0.15 2>/dev/null || sleep 1
  done
  wait "$pid"; rc=$?
  printf '\r\033[K\033[?25h' >&2
  _style_end "$rc" "$label ($(_style_bytes "$size"))" $((SECONDS-t0)) "$log"
  return "$rc"
}
