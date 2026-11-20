#!/usr/bin/env bash
# nornir-job-snotra-mail.sh — Snotra listens for the answers.
#
# The letters ask the participants to confirm or correct the record by a date. Until 2026-10-23 nothing read the
# mailboxes: the register could ask forever and never be answered, because an unread inbox is silence wearing the
# word "no reply yet".
#
# WHAT IT DOES (read-only on the mailbox; it never sends, never marks read, never replies)
#   1. finds every meeting folder on every meetings shelf (through snotra_paths.py);
#   2. for each one that has letters.json, reads the replies to the letters it sent;
#   3. appends what it saw to that meeting's replies.jsonl and carves ONE rune for the run;
#   4. prints the register view: every decision beside the reply that answers it.
#
# Role: @heart? No — the mailbox belongs to the operator's seat, so this job belongs to the SEAT that holds the
# letters, gated @dev. Two seats on one box must not both read it (the 2026-09-28 N-sessions fault).
#
# Exit 0 always if nothing failed; 1 if a meeting could not be read (the rune still records the attempt).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'nornir-snotra-mail: the hoard is unresolved\n' >&2; exit 1; }
DAYS="${SNOTRA_MAIL_DAYS:-30}"
rc=0; seen=0; recorded=0
while IFS= read -r M; do
  [ -n "$M" ] || continue
  [ -f "$M/letters.json" ] || continue
  seen=$((seen + 1))
  if out="$("$ROOT/systems/snotra/services/mail-watch/snotra-mail-watch.sh" record "$M" 2>&1)"; then
    n="$(printf '%s' "$out" | sed -n 's/.*replies:\([0-9]*\).*/\1/p')"
    recorded=$((recorded + ${n:-0}))
    printf '  %s — %s\n' "$(basename "$M")" "$(printf '%s' "$out" | tail -1)"
  else
    printf '  %s — FAILED: %s\n' "$(basename "$M")" "$(printf '%s' "$out" | tail -1)"
    rc=1
  fi
done < <(YMIR_HOME="$HOME_R" python3 "$ROOT/systems/snotra/services/record/snotra_paths.py" --recent "$DAYS" 2>/dev/null)

printf 'snotra-mail: %d meeting(s) with letters · %d reply(ies) recorded · %d failure(s)\n' "$seen" "$recorded" "$rc"
if [ -x "$ROOT/bin/records/runes-append.sh" ] && [ "$seen" -gt 0 ]; then
  "$ROOT/bin/records/runes-append.sh" brokk nornir-snotra-mail --message \
    "Snotra mail watch: ${seen} meeting(s), ${recorded} reply(ies) recorded, rc=${rc}" >/dev/null 2>&1 || true
fi
exit "$rc"
