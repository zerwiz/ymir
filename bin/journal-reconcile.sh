#!/usr/bin/env bash
# journal-reconcile.sh — push this machine's outbox to the heart, when it answers.
#
# Plan 51 (multi-machine operations), Phase 2b. Runs on a heartbeat.
#   * heart unreachable (detached/offline) → the journal stays queued, exit 0.
#     Being offline is FINE, never a failure.
#   * heart answers (attached) → each pending journal is pushed, then moved to
#     journal/sent/ so a machine offline for days reconciles in ONE pass with no
#     double-send. The heart is the only writer of the canonical record (Law 7).
#
#   journal-reconcile.sh            # push pending; move to sent/ on success
#   journal-reconcile.sh --dry-run  # report what would be pushed; change nothing
#   journal-reconcile.sh --status   # the local queue, as TOON
#   journal-reconcile.sh --version
#
# The push is pluggable so it can be tested without a heart:
#   YMIR_JOURNAL_PUSH   a command run with the journal file path as $1.
# The default ssh's the file to the heart's inbox:
#   ssh <heart> 'cat >> ~/.ymir-inbox/<host>.jsonl'
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

MODE="push"
case "${1-}" in --dry-run) MODE="dry" ;; --status) MODE="status" ;; ""|push) ;; *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE=""
if command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE 2>/dev/null; fi
STATE="${BROKK_STATE_OVERRIDE:-${STATE:-${YMIR_STATE_DIR:-${YMIR_HOME:-$HOME/Documents/ymirhome}/state}}}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
HOST="${HOST:-unknown}"

JDIR="$STATE/journal"
SENT="$JDIR/sent"

pending_files() { find "$JDIR" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | sort; }
pending_count() { pending_files | wc -l | tr -d '[:space:]'; }

if [ "$MODE" = status ]; then
  printf 'journal_queue[2]{host,pending}:\n'
  printf '  "%s","%s file(s)"\n' "$HOST" "$(pending_count)"
  p="$(pending_files | head -1)"
  [ -n "$p" ] && printf '  "oldest","%s entries in %s"\n' "$(wc -l <"$p" | tr -d '[:space:]')" "${p##*/}"
  exit 0
fi

# link: attached | detached | offline | standalone — from the topology resolver
LINK="standalone"; HEART=""
if [ -x "$SCRIPT_DIR/topology.sh" ]; then
  _topo="$(bash "$SCRIPT_DIR/topology.sh" --json 2>/dev/null || true)"
  if [ -n "$_topo" ]; then
    read -r LINK HEART < <(printf '%s' "$_topo" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
except Exception:
  print("standalone "); raise SystemExit
print(f"{d.get(\"link\",\"standalone\")} {d.get(\"heart\") or \"\"}")' 2>/dev/null)
  fi
fi
LINK="${LINK:-standalone}"

if [ "$(pending_count)" = "0" ]; then
  printf 'journal: nothing to reconcile (link=%s)\n' "$LINK"
  exit 0
fi

if [ "$LINK" != "attached" ]; then
  printf 'journal: %s file(s) queued (link=%s) — will sync when the heart answers\n' "$(pending_count)" "$LINK"
  exit 0
fi

default_push() {  # <file>
  local f="$1"
  [ -n "$HEART" ] || return 1
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$HEART" 'mkdir -p ~/.ymir-inbox' 2>/dev/null || return 1
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$HEART" "cat >> ~/.ymir-inbox/${HOST}.jsonl" <"$f"
}

push_one() {  # <file>
  local f="$1"
  if [ -n "${YMIR_JOURNAL_PUSH:-}" ]; then
    # shellcheck disable=SC2086
    eval "$YMIR_JOURNAL_PUSH" '"$f"'
  else
    default_push "$f"
  fi
}

if [ "$MODE" = dry ]; then
  printf 'journal: would push %s file(s) to the heart (%s)\n' "$(pending_count)" "${HEART:-none}"
  pending_files | while IFS= read -r f; do printf '  %s (%s entries)\n' "${f##*/}" "$(wc -l <"$f" | tr -d '[:space:]')"; done
  exit 0
fi

mkdir -p "$SENT"
pushed=0; failed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if push_one "$f"; then
    mv -f "$f" "$SENT/${f##*/}.$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || mv -f "$f" "$SENT/" 2>/dev/null || true
    pushed=$((pushed + 1))
  else
    failed=$((failed + 1))
  fi
done < <(pending_files)

printf 'journal: pushed %s, failed %s (link=%s)\n' "$pushed" "$failed" "$LINK"
[ "$failed" = 0 ] || exit 1
exit 0
