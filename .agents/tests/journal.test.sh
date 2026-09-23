#!/usr/bin/env bash
# journal.test.sh — the outbox: append offline, queue when detached, push when attached.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPEND="$ROOT/bin/journal-append.sh"
RECON="$ROOT/bin/journal-reconcile.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export BROKK_STATE_OVERRIDE="$TMP/state" YMIR_HOST=testbox
J="$TMP/state/journal/testbox.jsonl"

# 1. append works with no network at all
k1="$(bash "$APPEND" --op note --data '{"a":1}' 2>/dev/null)"
k2="$(bash "$APPEND" --op note --data '{"a":2}' 2>/dev/null)"
[ "$(wc -l <"$J" | tr -d '[:space:]')" = "2" ] && ok "two entries appended offline" || bad "append: $(cat "$J" 2>/dev/null)"
[ "$k1" != "$k2" ] && ok "entries carry distinct idempotency keys" || bad "keys equal: $k1"
python3 - "$J" <<'PY' && ok "each line is valid JSON with a key" || bad "journal lines are not valid JSON"
import json,sys
for line in open(sys.argv[1]):
    d=json.loads(line)
    assert "key" in d and "op" in d and "data" in d, d
PY

# 2. detached: the journal queues and is NOT lost
out="$(YMIR_HEART=none bash "$RECON" 2>/dev/null)"
printf '%s' "$out" | grep -q 'queued' && ok "detached: journal queued, exit 0" || bad "detached: $out"
[ -f "$J" ] && ok "detached: journal still present" || bad "detached: journal vanished"

# 3. attached with a fake push: the journal is pushed and moved to sent/
mkdir -p "$TMP/heart"
out="$(YMIR_HEART=127.0.0.1 YMIR_LINK_TIMEOUT=1 YMIR_JOURNAL_PUSH='cp "$1" '"$TMP"'/heart/' bash "$RECON" 2>/dev/null)"
printf '%s' "$out" | grep -q 'pushed 1' && ok "attached: journal pushed" || bad "attached: $out"
[ -f "$TMP/heart/testbox.jsonl" ] && ok "heart received the journal" || bad "heart inbox empty"
[ -f "$J" ] && bad "journal not moved after push" || ok "journal moved to sent/ after push"

# 4. nothing pending now
out="$(YMIR_HEART=none bash "$RECON" 2>/dev/null)"
printf '%s' "$out" | grep -q 'nothing to reconcile' && ok "empty queue reports clean" || bad "empty: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
