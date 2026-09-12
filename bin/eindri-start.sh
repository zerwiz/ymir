#!/usr/bin/env bash
# eindri-start.sh — start an Eindri as the Allfather asks. One command.
#
#   ensure backend -> classify the role -> seat the smith -> record -> report
#
# A seat is attempted on herdr (the Þjazi backend); when the herdr CLI cannot
# seat (no `hdr`, or a herdr without `agent start`), it falls back to tmux — the
# verified sibling — so an agent always starts. Galdr-style TOON.
#
# Usage:
#   eindri-start.sh "<request>" [--role <name>] [--pane|--tab|--space] [--kind pi|opencode]
#   eindri-start.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE="${BROKK_STATE_OVERRIDE:-$ROOT/state}"
SEATS="$STATE/herdr-seats"
SESSION="${YMIR_HERDR_SESSION:-brokk}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

REQ=""; ROLE=""; SEAT=""; MODEL=""; KIND="${YMIR_HERDR_KIND:-pi}"
while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE=${2-}; shift 2 ;;
    --kind) KIND=${2-}; shift 2 ;;
    --model) MODEL=${2-}; shift 2 ;;
    --space) SEAT="--space"; shift ;;
    --tab) SEAT="--tab"; shift ;;
    --pane) SEAT="--pane"; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/eindri-start.sh "<request>" [--role <name>] [--pane|--tab|--space] [--kind pi|opencode]\n' "$1" >&2; exit 2 ;;
    *) [ -z "$REQ" ] && REQ="$1" || REQ="$REQ $1"; shift ;;
  esac
done
[ -n "$REQ" ] || { printf 'error: eindri-start needs a request\nhelp: bin/eindri-start.sh "build the login page"\n' >&2; exit 2; }

# 1. Backend: ensure herdr (or a usable backend) exists.
[ -x "$SCRIPT_DIR/herdr-ensure.sh" ] && "$SCRIPT_DIR/herdr-ensure.sh" ensure --install >/dev/null 2>&1 || true

# 2. The right smith for the request.
if [ -z "$ROLE" ] && [ -x "$SCRIPT_DIR/eindri-role.sh" ]; then
  ROLE="$("$SCRIPT_DIR/eindri-role.sh" choose "$REQ" 2>/dev/null | sed -n '2p' | sed -E 's/^ *"([^"]+)".*/\1/')"
fi
ROLE="${ROLE:-eindri}"
SLUG="$(printf '%s' "$REQ" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed -E 's/^-|-$//g' | cut -c1-24)"
LABEL="${ROLE}-${SLUG:-task}"

mkdir -p "$STATE"

# 3. Seat: herdr first, tmux fallback — always produce a seat.
#    rc 3 from herdr-run means "not worth a smith" — report it, do NOT fake a seat.
seat="none"; refuse=0; rc=0
if [ -x "$SCRIPT_DIR/herdr-run.sh" ]; then
  "$SCRIPT_DIR/herdr-run.sh" eindri $SEAT ${MODEL:+--model "$MODEL"} "$ROLE" -- "$REQ" >/dev/null 2>&1 || rc=$?
fi
if [ "$rc" = 0 ]; then
  seat="herdr"
elif [ "$rc" = 3 ]; then
  seat="none"; refuse=1
else
  command -v tmux >/dev/null 2>&1 || { printf 'eindri-start[1]{role,seat,request}:\n  "%s","none","%s"\n' "$ROLE" "$REQ"; printf 'error: no seat — herdr cannot seat and tmux is absent\n' >&2; exit 1; }
  tmux has-session -t "$SESSION" 2>/dev/null || tmux new-session -d -s "$SESSION" -n shell
  tmux new-window -t "$SESSION" -n "$LABEL" "bash -lc 'printf \"\\n  %s — Eindri of Ymir\\n  request: %s\\n\\n\"; case \"$KIND\" in pi) exec pi \"$REQ\" ;; *) exec \"$KIND\" ;; esac'" 2>/dev/null \
    && seat="tmux:$SESSION:$LABEL"
fi
[ "$refuse" = 1 ] && { printf 'eindri-start[1]{role,seat,verdict}:\n  "%s","none","too brief — answer it in hand"\n' "$ROLE"; exit 0; }
[ "$seat" != "none" ] || { printf 'error: could not seat %s\n' "$ROLE" >&2; exit 1; }

# 4. Serve the Eindri over A2A (best effort): its tasks are delivered by
#    injection into the seated agent's chat; reachable at A2A_URL.
A2A_URL=""
if [ "$seat" = herdr ] && [ -f "$SCRIPT_DIR/a2a-serve.py" ]; then
  PORT=$((7800 + (RANDOM % 100)))
  mkdir -p "$STATE"
  nohup python3 "$SCRIPT_DIR/a2a-serve.py" "$ROLE" "$ROLE" "$PORT" >"$STATE/a2a-$ROLE.log" 2>&1 &
  A2A_URL="http://127.0.0.1:$PORT/"
fi

# 5. Record + report.
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROLE" "$seat" "$REQ" >>"$SEATS"
printf 'eindri-start[1]{role,seat,a2a,request,label}:\n'
printf '  "%s","%s","%s","%s","%s"\n' "$ROLE" "$seat" "${A2A_URL:-none}" "$REQ" "$LABEL"
