#!/usr/bin/env bash
# meeting-record-guard.sh — a meeting record is a record: if one is missing, put it back.
#
#   meeting-record-guard.sh check   # what is tracked under hodd/life/meetings and missing on disk
#   meeting-record-guard.sh fix     # restore the missing ones from git, and carve a rune for each
#
# WHY (2026-10-23): a tracked transcript — `hodd/life/meetings/2026-10-23-ping-reygan-craig-mic.transcript.md` —
# was found DELETED on disk; the commit guard refused the deletion (Rule 11) and it was restored by hand.
# The cause was not provable from the logs, and this door exists because "who deleted it" is the wrong first
# question: the record must not be able to go missing while a meeting is being processed.
#
# It only ever ADDS: `git checkout -- <path>` restores a tracked file, and nothing here deletes.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root H 2>/dev/null || true
[ -n "${H:-}" ] || { printf 'meeting-record-guard: the hoard is unresolved\n' >&2; exit 2; }
ACTION="${1:-check}"
[ -d "$H/.git" ] || { printf 'meeting-record-guard: %s is not a git repo — nothing to compare\n' "$H" >&2; exit 3; }
cd "$H" || exit 3

TRACKED="$(git ls-files 'hodd/life/meetings/**' 2>/dev/null | grep -E '\.(md|txt|json|jsonl)$' || true)"
[ -n "$TRACKED" ] || { printf 'meeting_record_guard[1]{tracked,missing}: "0","0"\n'; exit 0; }
TOTAL=$(printf '%s\n' "$TRACKED" | wc -l)
MISSING=""
for f in $TRACKED; do
  [ -e "$f" ] || MISSING="${MISSING}${f}
"
done
COUNT=$(printf '%s' "$MISSING" | grep -c . || true)
printf 'meeting_record_guard[1]{tracked,missing}: "%s","%s"\n' "$TOTAL" "${COUNT:-0}"
if [ "${COUNT:-0}" -eq 0 ]; then exit 0; fi
printf '%s' "$MISSING" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ "$ACTION" = "fix" ]; then
    if git checkout -- "$f" 2>/dev/null && [ -e "$f" ]; then
      printf '  restored  %s\n' "$f"
      bash "$ROOT/bin/records/runes-append.sh" brokk retention \
        --message "meeting record restored from git (found missing on disk): $f" >/dev/null 2>&1 || true
    else
      printf '  FAILED    %s\n' "$f" >&2
    fi
  else
    printf '  missing   %s\n' "$f"
  fi
done
[ "$ACTION" = "fix" ] || exit 1
