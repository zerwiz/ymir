#!/usr/bin/env bash
# journal-fold.test.sh — the heart folds bodies' journals, idempotently.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPEND="$ROOT/bin/records/journal-append.sh"
RECEIVE="$ROOT/bin/records/journal-receive.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export BROKK_STATE_OVERRIDE="$TMP/state" YMIR_JOURNAL_INBOX="$TMP/inbox" YMIR_HOST=body1
mkdir -p "$TMP/inbox"

# the body writes two entries (the operator's own), one company-namespaced, then
# pushes its file to the heart's inbox
bash "$APPEND" --op note --data '{"a":1}' >/dev/null 2>&1
bash "$APPEND" --op note --data '{"a":2}' >/dev/null 2>&1
bash "$APPEND" --op note --namespace company-y --data '{"a":3}' >/dev/null 2>&1
SRC="$TMP/state/journal/body1.jsonl"
cp "$SRC" "$TMP/inbox/body1.jsonl"

# fold
out="$(bash "$RECEIVE" 2>/dev/null)"
printf '%s' "$out" | grep -q 'folded 3 new' && ok "three entries folded" || bad "fold: $out"
FOLDED="$TMP/state/journal/folded/body1.jsonl"
SCOPED="$TMP/state/journal/folded/company-y/body1.jsonl"
[ "$(wc -l <"$FOLDED" | tr -d '[:space:]')" = "2" ] && ok "own log holds only the two unscoped entries" || bad "own folded log: $(cat "$FOLDED" 2>/dev/null)"
[ "$(wc -l <"$SCOPED" | tr -d '[:space:]')" = "1" ] && ok "the company entry folds into its namespace only" || bad "scoped log: $(cat "$SCOPED" 2>/dev/null)"
[ -f "$TMP/inbox/body1.jsonl" ] && bad "inbox file not archived" || ok "inbox file archived after fold"

# replay the SAME entries: idempotent, no duplicates
cp "$SRC" "$TMP/inbox/body1.jsonl"
out="$(bash "$RECEIVE" 2>/dev/null)"
printf '%s' "$out" | grep -q 'folded 0 new' && ok "replayed keys are a no-op" || bad "replay: $out"
[ "$(wc -l <"$FOLDED" | tr -d '[:space:]')" = "2" ] && ok "own log still has 2 entries" || bad "duplicates: $(cat "$FOLDED")"
[ "$(wc -l <"$SCOPED" | tr -d '[:space:]')" = "1" ] && ok "scoped log still has 1 entry" || bad "scoped duplicates: $(cat "$SCOPED")"

# status names the namespace it folded
out="$(bash "$RECEIVE" --status 2>/dev/null)"
printf '%s' "$out" | grep -q 'journal_inbox' && ok "status reports" || bad "status: $out"
printf '%s' "$out" | grep -q 'company-y' && ok "status names the folded namespace" || bad "status namespaces: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
