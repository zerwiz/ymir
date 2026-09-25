#!/usr/bin/env bash
# journal-receive.sh — the HEART folds the bodies' journals into one record.
#
# Plan 51 (multi-machine operations), Phase 2b (heart side). Bodies push their
# outbox to the heart's inbox (`~/.ymir-inbox/<host>.jsonl`, see
# bin/journal-reconcile.sh). This is the ONLY writer that folds them in:
#   * entries are deduped by their idempotency key, so a replay is a no-op;
#   * new entries append to `$STATE/journal/folded/<host>.jsonl` (one canonical
#     log per machine) — the fork that happened once cannot recur (Law 7);
#   * a fully-folded inbox file is archived to the inbox's `folded/`.
#
#   journal-receive.sh            # fold everything waiting
#   journal-receive.sh --dry-run  # report what would fold; change nothing
#   journal-receive.sh --status   # what is waiting / folded
#   journal-receive.sh --version
#
# Env: YMIR_JOURNAL_INBOX (default ~/.ymir-inbox), YMIR_STATE_OVERRIDE.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE=fold
case "${1-}" in --dry-run) MODE=dry ;; --status) MODE=status ;; ""|fold) ;; *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE=""
if command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE 2>/dev/null; fi
STATE="${BROKK_STATE_OVERRIDE:-${STATE:-${YMIR_STATE_DIR:-${YMIR_HOME}/state}}}"
INBOX="${YMIR_JOURNAL_INBOX:-$HOME/.ymir-inbox}"
FOLDED="$STATE/journal/folded"
ARCHIVE="$INBOX/folded"

inbox_files() { find "$INBOX" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | sort; }

if [ "$MODE" = status ]; then
  printf 'journal_inbox[3]{inbox,waiting,folded}:\n'
  printf '  "%s","%s file(s)","%s host log(s)"\n' "$INBOX" "$(inbox_files | wc -l | tr -d '[:space:]')" "$(find "$FOLDED" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
  exit 0
fi

[ -d "$INBOX" ] || { printf 'journal: nothing waiting (%s absent)\n' "$INBOX"; exit 0; }
[ "$(inbox_files | wc -l | tr -d '[:space:]')" = "0" ] && { printf 'journal: nothing waiting\n'; exit 0; }

mkdir -p "$FOLDED" "$ARCHIVE"
folded_total=0; files=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  host="$(basename "$f" .jsonl)"
  dest="$FOLDED/$host.jsonl"
  if [ "$MODE" = dry ]; then
    printf 'journal: would fold %s -> %s (%s entries)\n' "$f" "$dest" "$(wc -l <"$f" | tr -d '[:space:]')"
    continue
  fi
  n="$(python3 - "$f" "$dest" <<'PY'
import json, os, sys
src, dest = sys.argv[1], sys.argv[2]
have = set()
if os.path.exists(dest):
    for line in open(dest):
        try: have.add(json.loads(line)["key"])
        except Exception: pass
added = 0
with open(dest, "a") as out:
    for line in open(src):
        line = line.rstrip("\n")
        if not line: continue
        try: k = json.loads(line)["key"]
        except Exception: continue
        if k in have: continue      # idempotent: a replayed key is a no-op
        have.add(k); out.write(line + "\n"); added += 1
print(added)
PY
)"
  folded_total=$((folded_total + n)); files=$((files + 1))
  mv -f "$f" "$ARCHIVE/${host}.jsonl.$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || rm -f "$f"
done < <(inbox_files)

if [ "$MODE" = dry ]; then exit 0; fi
printf 'journal: folded %s new entr(y/ies) from %s file(s)\n' "$folded_total" "$files"
exit 0
