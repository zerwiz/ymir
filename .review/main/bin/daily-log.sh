#!/usr/bin/env bash
# daily-log.sh — the day's work, recorded where the contract says it lives.
#
# The hoard contract names the shelf — `$YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md`
# — but nothing wrote there, so a session's work scattered into one-off documents
# under `hodd/docs/`. A random document is not a record; a dated log is, and it
# can be read back a week later to answer "what did we actually do?".
#
#   daily-log.sh add "<what>" [--tag T]...   # append one dated entry (default actor: brokk)
#   daily-log.sh add --actor bragi "<what>"
#   daily-log.sh today                       # print today's log
#   daily-log.sh show [YYYY-MM-DD]           # print a day
#   daily-log.sh list                        # which days have a log
#
# The log is APPEND-ONLY and dated (Rule 06): a correction is a new entry, never
# an edit. Each day is one file; each entry is a timestamped block under an actor.
#
# Exit: 0 ok, 1 error, 2 usage.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/hoard-lib.sh" ]; then . "$_yh/bin/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
hoard_root HOARD                    # the contract path is <hoard>/memory/daily
DIR="${DAILY_LOG_DIR:-$HOARD/memory/daily}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-today}"; shift || true

today() { date -u +%Y-%m-%d; }
stamp() { date -u +%H:%M; }

case "$ACTION" in
  add)
    ACTOR="brokk"; TAGS=""; TEXT=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --actor) ACTOR="${2:-brokk}"; shift 2 ;;
        --actor=*) ACTOR="${1#--actor=}"; shift ;;
        --tag) TAGS="${TAGS:+$TAGS, }${2:-}"; shift 2 ;;
        --tag=*) TAGS="${TAGS:+$TAGS, }${1#--tag=}"; shift ;;
        -*) shift ;;
        *) TEXT="${TEXT:+$TEXT }$1"; shift ;;
      esac
    done
    [ -n "$TEXT" ] || { printf 'error: usage: bin/daily-log.sh add "<what>" [--actor NAME] [--tag T]\n' >&2; exit 2; }

    mkdir -p "$DIR" 2>/dev/null || { printf 'error: cannot create %s\n' "$DIR" >&2; exit 1; }
    f="$DIR/$(today).md"
    # Seed the day once; then append. Never rewrite an existing line.
    if [ ! -f "$f" ]; then
      printf '# %s — the day'"'"'s work\n\n' "$(today)" >"$f"
    fi
    {
      printf '## %s — %s\n' "$(stamp)" "$ACTOR"
      printf -- '- %s\n' "$TEXT"
      [ -n "$TAGS" ] && printf -- '- tags: %s\n' "$TAGS"
      printf '\n'
    } >>"$f"
    printf 'daily-log[1]{action,date,actor,path}:\n  "add","%s","%s","%s"\n' "$(today)" "$ACTOR" "$f"
    ;;

  today)  f="$DIR/$(today).md"
          [ -r "$f" ] || { printf 'daily-log[1]{date,state}:\n  "%s","no entries yet"\n' "$(today)"; exit 0; }
          cat "$f" ;;

  show)   d="${1:-$(today)}"
          f="$DIR/$d.md"
          [ -r "$f" ] || { printf 'error: no log for %s\n' "$d" >&2; exit 1; }
          cat "$f" ;;

  list)   [ -d "$DIR" ] || { printf 'daily-log[1]{days}:\n  "0","none"\n'; exit 0; }
          n=$(ls "$DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
          printf 'daily-log[%s]{date,path}:\n' "$n"
          for f in "$DIR"/*.md; do
            [ -f "$f" ] || continue
            printf '  "%s","%s"\n' "$(basename "$f" .md)" "$f"
          done ;;

  *) printf 'error: unknown action %s (add|today|show|list)\n' "$ACTION" >&2; exit 2 ;;
esac
