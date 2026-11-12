#!/usr/bin/env bash
# verdict-watch.sh — EVERY report is delivered, because the ARTEFACT is watched, not the agent.
#
# WHY (the Allfather, 2026-11-07: "THIS MUST ALLWAYS FUCKING HAPPEND"): the seats are *told* to call
# `notify` when they finish, and that is a promise an LLM can forget — measured twice: the queue
# stayed at 25 entries after both a judge and a smith were asked to speak. An obligation that depends
# on a model remembering is not a guarantee.
#
# So delivery hangs off the file. Every review/errand report under
# `<home>/state/eindri-reports/` is fingerprinted; a NEW or CHANGED report is delivered through the
# one hotline (Runes + the arm's wake queue + Telegram when the human road is configured). A seat may
# therefore say nothing at all and its verdict still reaches the operator.
#
#   bin/forge/verdict-watch.sh            # deliver anything new or changed since the last pass
#   bin/forge/verdict-watch.sh --status   # what has been delivered, and when
#
# Exit: 0 ran (delivered N) · 1 a delivery failed loudly · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
_h=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root _h 2>/dev/null
STATE="${_h:-$HOME/Documents/ymirhome}/state"
REPORTS="$STATE/eindri-reports"
SEEN="$STATE/.reviewed/delivered"
NOTIFY="$ROOT/bin/notify/send.sh"

mkdir -p "$SEEN" 2>/dev/null || true

if [ "${1-}" = "--status" ]; then
  n=0; printf 'delivered[3]{report,fingerprint,when}:\n'
  for f in "$SEEN"/*; do
    [ -f "$f" ] || continue
    printf '  "%s","%s","%s"\n' "$(basename "$f" .seen)" "$(cut -c1-12 "$f" 2>/dev/null)" "$(date -r "$f" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || printf '  "none","","nothing delivered yet"\n'
  exit 0
fi
[ "${1-}" = "" ] || { printf 'verdict-watch: usage: verdict-watch.sh [--status]\n' >&2; exit 2; }

[ -d "$REPORTS" ] || { printf 'verdict-watch: no reports directory at %s — nothing to watch\n' "$REPORTS" >&2; exit 0; }
[ -x "$NOTIFY" ] || { printf 'verdict-watch: the hotline is missing at %s — CANNOT deliver\n' "$NOTIFY" >&2; exit 1; }

delivered=0; failed=0
for f in "$REPORTS"/*.md; do   # every report, not only pr-*-review: a smith's finding is news too
  [ -r "$f" ] || continue
  base="$(basename "$f" .md)"
  fp="$(sha256sum "$f" 2>/dev/null | cut -c1-32)"
  [ -n "$fp" ] || continue
  marker="$SEEN/$base.seen"
  [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$fp" ] && continue

  first="$(head -1 "$f" 2>/dev/null | tr -d '\r')"
  # THE MESSAGE MUST CARRY THE FINDING, not a title. A one-line "ready for the forge" is a mouth that
  # says nothing (the Allfather, 2026-11-07: "your not delivering enough info"). So the digest is the
  # report's first three non-empty content lines, flattened, after the verdict line.
  # The digest is the FINDING: metadata (pr:, head:, ruleset:, judged_*) is skipped, and markdown
  # headings are dropped, so the line the operator reads is the reason, not the bookkeeping.
  digest="$(sed -n '2,60p' "$f" 2>/dev/null | tr -d '\r' \
    | grep -viE '^(pr|repo|head|ruleset|judged_by|judged_at)[[:space:]]*:' \
    | sed 's/^[[:space:]#-]*//' | grep -v '^$' | head -3 | paste -sd '|' -)"
  case "$first" in
    REFUSE*|NEEDS-REWORK*) sev=HIGH ;;
    PASS*)                 sev=INFO ;;
    *)                     sev=MEDIUM ;;
  esac
  pr="$(printf '%s' "$base" | sed -n 's/^pr-\([0-9]*\)-review$/\1/p')"
  line="$(grep -m1 -E '^(head|pr):' "$f" 2>/dev/null | tr -d '\r')"
  [ -n "$line" ] && digest="${digest:+$digest · }$line"
  msg="report $base — ${first:-no verdict line}${digest:+ - $digest}"
  # ONE LINE, always: the queue is append-only line-per-entry, so a newline in the message would cut
  # the finding in half at the reader. Flatten and bound before it is handed over.
  msg="$(printf '%s' "$msg" | tr '\n\t' '  ' | tr -s ' ' | cut -c1-600)"

  # "DELIVERED" MUST MEAN DELIVERED. notify exits 0 for a send AND for a deliberate suppression
  # (duplicate within the hour, or a collapsed channel), so its decision is read from its own row:
  # only `"send"` counts, and only then is the fingerprint marked as delivered.
  nout="$(bash "$NOTIFY" --source review --severity "$sev" --key "report:$base.$fp" --message "$msg" 2>&1)" \
    || { printf 'verdict-watch: notify itself failed for %s\n' "$base" >&2; }
  case "$nout" in
    *'"send"'*)
      printf '%s' "$fp" >"$marker" 2>/dev/null || true
      delivered=$((delivered + 1))
      printf 'verdict-watch: delivered %s (%s)\n' "$base" "$sev" >&2 ;;
    *'"duplicate"'*|*'"collapse"'*)
      # Suppressed by design: say WHICH, and do not mark it delivered — the file has not reached the
      # operator, and a marker here would hide it forever.
      printf 'verdict-watch: NOT delivered %s — notify suppressed it as %s\n' "$base" \
        "$(printf '%s' "$nout" | grep -o '"duplicate"\|"collapse"' | head -1 | tr -d '"')" >&2
      failed=$((failed + 1)) ;;
    *)
      printf 'verdict-watch: NOT delivered %s — notify said: %s\n' "$base" "$(printf '%s' "$nout" | head -c 120)" >&2
      failed=$((failed + 1)) ;;
  esac

done

printf 'verdict-watch[3]{watched,delivered,failed}:\n  "%s","%s","%s"\n' "$(ls "$REPORTS"/*.md 2>/dev/null | wc -l | tr -d ' ')" "$delivered" "$failed"
[ "$failed" = 0 ] || exit 1
exit 0
