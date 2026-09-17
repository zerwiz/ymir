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

# --- the palette, from the tokens (truecolor → 256 → none) ------------------
style_init() {
  STYLE_ON=0
  # A human must be present: stderr is a terminal and nobody said no.
  if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ "${YMIR_NO_COLOR:-0}" != 1 ]; then
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
}

# The forge's marks, one per state a thing can be in.
style_mark() {  # <state> → a glyph
  case "${1:-}" in
    DO|do)             printf '%s' '◆' ;;
    SKIP|skip|already) printf '%s' '·' ;;
    INFO|info)         printf '%s' '—' ;;
    BLOCKED|blocked)   printf '%s' '✕' ;;
    CONSENT|consent)   printf '%s' '?' ;;
    OK|ok)             printf '%s' '✓' ;;
    WARN|warn)         printf '%s' '·' ;;
    FAIL|fail)         printf '%s' '✕' ;;
    *)                 printf '%s' '·' ;;
  esac
}

style_colour() {  # <state> → the colour for it
  case "${1:-}" in
    DO|CONSENT|WARN|warn|do|consent) printf '%s' "$C_BRONZE" ;;
    OK|SKIP|INFO|ok|skip|info)       printf '%s' "$C_STEEL" ;;
    FAIL|BLOCKED|fail|blocked)       printf '%s' "$C_BLOOD" ;;
    *)                               printf '%s' "$C_FAINT" ;;
  esac
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
  local what="${1:-the halls are being set right}"
  printf '\n' >&2
  style_line DO "much moves" "$what"
  style_hint "      this hour is long, and nothing of yours is lost in it —"
  style_hint "      roots come home, shapes are re-cut, names are set true again."
  style_hint "      Your patience is noted, and it is earned."
  printf '\n' >&2
}

# The ending: what stands, then exactly what to type next. Every CLI deserves
# to leave the operator with the next step and nothing else to guess.
style_next() {  # one command per line, as "verb — what it does"
  printf '\n%s\n' "${C_BOLD}Where to go from here${C_OFF}" >&2
  while [ $# -gt 0 ]; do
    local cmd="${1%% — *}" what="${1#* — }"
    printf '  %s%-22s%s %s\n' "$C_BRONZE" "$cmd" "$C_OFF" "$(printf '%s' "$what" | sed "s/^/$C_FAINT/;s/$/$C_OFF/")" >&2
    shift
  done
  printf '\n' >&2
}
