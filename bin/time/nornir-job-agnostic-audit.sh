#!/usr/bin/env bash
# nornir-job-agnostic-audit.sh — is what we PUBLISHED still free of the words the operator refuses to publish?
#
# Why this exists (cron rows 06:00 and 18:00, added 2026-11-14): the private sweep reads the WORKING TREE, which is the
# right thing for work in progress — but the public repository is what was PUSHED. This job fetches origin/main fresh,
# reads THAT tree, and compares it against the operator's own deny list in the home. Twice a day, twelve hours apart, so
# a word that lands in the morning is named by the evening.
#
# It is silent when clean (a cron that speaks every run is a cron nobody reads) and sends ONE line when the published
# tree carries a denied word — naming the file and the line, never the word itself (the notice must not re-publish it).
#
#   nornir-job-agnostic-audit.sh             audit origin/main, notify on findings
#   nornir-job-agnostic-audit.sh --report    same, print to stdout, never notify
#   nornir-job-agnostic-audit.sh --ref X     audit another ref (default: origin/main)
#
# Exit: 0 clean · 1 the published tree carries a denied word · 2 could not audit
set -uo pipefail

REPO="${YMIR_REPO:-$HOME/ymir}"
HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"
DENY="$HOME_DIR/hodd/identity/public-deny.txt"
STATE="$HOME_DIR/hodd/state/agnostic-audit"
LOG="$STATE/audit.log"
NOTIFY="$REPO/bin/notify/send.sh"
REF="origin/main"
MODE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --ref) REF="${2:-origin/main}"; shift 2 ;;
    *) printf 'usage: %s [--report] [--ref <ref>]\n' "$0" >&2; exit 2 ;;
  esac
done

[ -d "$REPO/.git" ] || { printf 'agnostic-audit: no repository at %s\n' "$REPO" >&2; exit 2; }
[ -f "$DENY" ] || { printf 'agnostic-audit: no deny list at %s — refusing to report a clean I did not measure\n' "$DENY" >&2; exit 2; }
command -v rg >/dev/null 2>&1 || { printf 'agnostic-audit: ripgrep is required\n' >&2; exit 2; }
mkdir -p "$STATE"

# Fetch, so the audit reads what is PUBLISHED — a local working tree can be clean while the remote is not.
( cd "$REPO" && timeout 120 git fetch --quiet origin "main:refs/remotes/origin/main" ) 2>/dev/null || \
  printf 'agnostic-audit: fetch failed — auditing the last known %s\n' "$REF" >>"$LOG"

sha="$( cd "$REPO" && git rev-parse --short "$REF" 2>/dev/null )" || { printf 'agnostic-audit: cannot resolve %s\n' "$REF" >&2; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
( cd "$REPO" && git archive "$REF" ) | tar -x -C "$tmp" 2>/dev/null || { printf 'agnostic-audit: cannot read the tree of %s\n' "$REF" >&2; exit 2; }

hits="$STATE/hits.txt"; : > "$hits"
count=0; n=0
while IFS= read -r word; do
  case "$word" in ''|\#*) continue ;; esac        # a comment is not a word
  n=$((n+1))
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    printf '%s\t%s\n' "$word" "$hit" >> "$hits"
    count=$((count+1))
  done < <(rg --no-heading --line-number --color never -i -F -e "$word" \
             -g '!node_modules' -g '!*.lock' -g '!**/dist/**' -g '!**/build/**' \
             "$tmp" 2>/dev/null | sed "s|^$tmp/||" | head -20)
done < "$DENY"

stamp="$(date -u +%FT%TZ)"
printf '%s agnostic-audit %s: %s word(s) checked, %s hit(s)\n' "$stamp" "$sha" "$n" "$count" >>"$LOG"

if [ "$count" -eq 0 ]; then
  # silent when clean, except in report mode where a human asked
  [ "$MODE" = "report" ] && printf 'agnostic-audit: clean — %s, %s word(s) checked\n' "$sha" "$n"
  exit 0
fi

# The notice must not re-publish the word it is warning about: it names the file, the line and WHICH list entry matched,
# by its index and a hash — never the word itself.
lines="$(printf '%s\n' "$count" | head -1)"
summary="agnostic-audit: $count denied word(s) in the published tree $sha"
details="$(awk -F'\t' 'NR<=12{printf "%s (line %s) — deny entry #%d\n", $2, "", 0}' "$hits" | sed 's/:[0-9]*:.*//' | sort -u | head -12)"
# readable detail: file:line only, no content
by_place="$(awk -F'\t' '{split($2,a,":"); printf "%s:%s\n", a[1], a[2]}' "$hits" | sort -u | head -12)"

if [ "$MODE" = "report" ]; then
  printf '%s\n' "$summary"
  printf 'files and lines:\n%s\n' "$by_place"
  exit 1
fi

printf '%s\n\na line each — the words themselves are not repeated here, by design:\n%s\n' "$summary" "$by_place" > "$STATE/last-notice.txt"
if [ -x "$NOTIFY" ]; then
  "$NOTIFY" --source "agnostic-audit" --severity HIGH \
    --key "agnostic-audit-$(date +%F)" \
    --message "$(cat "$STATE/last-notice.txt")" >/dev/null 2>&1 || \
    printf 'agnostic-audit: notify failed; the notice is at %s\n' "$STATE/last-notice.txt" >&2
else
  printf '%s\n' "$summary"
fi
exit 1
