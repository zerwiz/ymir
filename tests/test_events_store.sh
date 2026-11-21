#!/usr/bin/env bash
# test_events_store.sh — the events store, its one writer and its first two sources (plan 333 phase 1).
#
# Everything is fenced in one temp dir. Nothing real is written, and nothing is sent:
#   · validation   a bad row is refused with exit 1 and writes nothing
#   · dedupe       the same key on the same day is written once
#   · tail/search  read the day files back, with filters
#   · cron source  a failing scheduled job lands as one HIGH row (fixture root: no hotline, no Telegram)
#   · garmr source a judged finding lands as one row (the door, the rune and the voice are stubbed)
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "$HERE")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-events.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export YMIR_EVENTS_DIR="$TMP/events"
unset YMIR_STATE_DIR
APPEND="$ROOT/bin/records/events-append.sh"
TAIL="$ROOT/bin/records/events-tail.sh"
SEARCH="$ROOT/bin/records/events-search.sh"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
count() { cat "$YMIR_EVENTS_DIR"/*.jsonl 2>/dev/null | grep -c . ; }

# ── validation ────────────────────────────────────────────────────────────────
for case in \
  "--source Bad --kind a --subject x" \
  "--source s --kind 'bad kind' --subject x" \
  "--source s --kind a" \
  "--source s --kind a --subject x --severity LOUD" \
  "--source s --kind a --subject x --ts yesterday"; do
  eval "bash '$APPEND' $case" >/dev/null 2>&1; rc=$?
  [ "$rc" = 1 ] && ok "refused (exit 1): $case" || bad "expected exit 1, got $rc: $case"
done
[ "$(count)" = 0 ] && ok "refused rows wrote nothing" || bad "a refused row was written"

long="$(printf 'x%.0s' $(seq 1 201))"
bash "$APPEND" --source s --kind a --subject "$long" >/dev/null 2>&1; [ $? = 1 ] && ok "over-long subject refused" || bad "long subject accepted"

out="$(bash "$APPEND" --source test --kind note --subject "first" --severity high --key k-one --body "detail one" 2>&1)"
[ "$out" = "written k-one" ] && ok "a valid row is written (severity upper-cased)" || bad "valid row: $out"
f="$(ls "$YMIR_EVENTS_DIR"/*.jsonl)"
[[ "$f" =~ /[0-9]{4}-[0-9]{2}-[0-9]{2}\.jsonl$ ]] && ok "day file is YYYY-MM-DD.jsonl" || bad "day file name: $f"
python3 - "$f" <<'PY' && ok "row carries exactly the seven fields" || bad "row shape wrong"
import json, sys
row = json.loads(open(sys.argv[1]).readline())
assert sorted(row) == sorted("ts source kind subject severity key body".split()), row
assert row["severity"] == "HIGH" and row["key"] == "k-one" and row["body"] == "detail one"
PY

# ── dedupe ────────────────────────────────────────────────────────────────────
out="$(bash "$APPEND" --source test --kind note --subject "again" --key k-one 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "duplicate k-one" ] && [ "$(count)" = 1 ] && ok "same key, same day: written once" || bad "dedupe: rc=$rc out=$out n=$(count)"
bash "$APPEND" --source test --kind note --subject "other day" --key k-one --ts 2020-01-02T03:04:05+00:00 >/dev/null 2>&1
[ "$(count)" = 2 ] && [ -f "$YMIR_EVENTS_DIR/2020-01-02.jsonl" ] && ok "same key on another day is a new row, in that day's file" || bad "cross-day key"
a="$(bash "$APPEND" --source test --kind auto --subject "no key" 2>&1)"
b="$(bash "$APPEND" --source test --kind auto --subject "no key" 2>&1)"
[[ "$a" == written\ auto:* ]] && [[ "$b" == duplicate\ auto:* ]] && ok "a missing key is derived, so an identical row still dedupes" || bad "derived key: $a / $b"

# ── tail and search ───────────────────────────────────────────────────────────
bash "$APPEND" --source other --kind alarm --subject "disk nearly full" --severity CRITICAL --key k-disk >/dev/null
[ "$(bash "$TAIL" -n 1 | grep -c 'disk nearly full')" = 1 ] && ok "tail -n 1 returns the newest row" || bad "tail newest"
[ "$(bash "$TAIL" --source other | grep -c .)" = 1 ] && ok "tail --source filters" || bad "tail --source"
[ "$(bash "$TAIL" --min-severity HIGH | grep -c .)" = 2 ] && ok "tail --min-severity keeps HIGH and above" || bad "tail --min-severity"
[ "$(bash "$SEARCH" "DISK" | grep -c 'disk nearly full')" = 1 ] && ok "search is case-insensitive over every field" || bad "search"
[ "$(bash "$SEARCH" "detail one" | grep -c .)" = 1 ] && ok "search reads the body" || bad "search body"
[ "$(bash "$SEARCH" "other day" | grep -c .)" = 0 ] && ok "search --days 7 skips an old day file" || bad "search window"
[ "$(bash "$SEARCH" "other day" --days 100000 | grep -c .)" = 1 ] && ok "search --days widens the window" || bad "search wide"

# ── source 1: Nornir cron failures ────────────────────────────────────────────
# A fixture root carries ONLY the events door, so the scheduler finds no hotline to ring.
mkdir -p "$TMP/root/bin" "$TMP/state" "$TMP/conf" "$TMP/home"
ln -s "$ROOT/bin/records" "$TMP/root/bin/records"
printf '@every:1 echo boom-from-fixture >&2; exit 7\n' >"$TMP/conf/cron.yaml"
export YMIR_EVENTS_DIR="$TMP/cron-events"
BROKK_ROOT_OVERRIDE="$TMP/root" BROKK_HOME="$TMP/home" BROKK_STATE_OVERRIDE="$TMP/state" \
BROKK_CONFIG_OVERRIDE="$TMP/conf" BROKK_NORNIR_PERSIST=1 BROKK_CRON_ONCE=1 BROKK_ROLES=dev \
  bash "$ROOT/bin/time/nornir-cron-start.sh" >/dev/null 2>&1
for _ in $(seq 1 50); do [ "$(count)" -ge 1 ] && break; sleep 0.2; done
if [ "$(count)" = 1 ]; then
  python3 - "$YMIR_EVENTS_DIR" <<'PY' && ok "cron: a failing job is one HIGH row naming the exit code" || bad "cron row wrong"
import glob, json, sys
row = json.loads(open(glob.glob(sys.argv[1] + "/*.jsonl")[0]).readline())
assert row["source"] == "cron" and row["kind"] == "job-failed" and row["severity"] == "HIGH", row
assert "rc=7" in row["subject"] and row["key"].startswith("cron-fail:"), row
PY
else bad "cron: expected 1 row, found $(count)"; fi
kill "$(cat "$TMP/state/cron.pid" 2>/dev/null)" 2>/dev/null

# ── source 2: Garmr findings ──────────────────────────────────────────────────
export YMIR_EVENTS_DIR="$TMP/garmr-events"
python3 -I - "$ROOT" <<'PY' && ok "garmr: a judged finding is one row; INFO is not recorded; a repeat dedupes" || bad "garmr source"
import glob, json, os, sys
root = sys.argv[1]
sys.path.insert(0, os.path.join(root, "bin", "ward", "garmr"))
os.environ["YMIR_HOME"] = os.environ["YMIR_EVENTS_DIR"]  # never the real home
import brain, rules
brain._door = lambda *a, **k: {"said": "stub"}   # no hotline, no Telegram
brain._rune = lambda *a, **k: None
brain._speak = lambda *a, **k: None
finding = {"ts": "2026-11-21T10:00:00+0000", "sense": "ss", "kind": "listener", "pid": 4242,
           "comm": "nc", "addr": "0.0.0.0:4444"}
rows = brain.judge([finding, finding], {}, escalate_ok=False)
loud = [r for r in rows if r["severity"] != "INFO"]
files = glob.glob(os.environ["YMIR_EVENTS_DIR"] + "/*.jsonl")
events = [json.loads(l) for f in files for l in open(f)]
assert loud, "fixture finding must judge above INFO, got " + repr([r["severity"] for r in rows])
assert len(events) == 1, events                  # two identical findings, one row
e = events[0]
assert e["source"] == "garmr" and e["kind"] == "finding" and e["severity"] == loud[0]["severity"], e
assert e["key"].startswith("garmr:") and "4242" in e["key"] and "0.0.0.0:4444" in e["body"], e
PY

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'events store: every case held' || echo 'events store: a case failed')"
exit "$fail"
