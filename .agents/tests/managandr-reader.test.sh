#!/usr/bin/env bash
# managandr-reader.test.sh — Mánagandr, the read calendar: the reader and the shell door.
#
# Offline by construction. Every run feeds a synthetic Google events.list
# fixture (invented titles, synthetic times, no attendee, no location) into a
# temp cache. No test touches the network and no test carries a real token, yet
# the reader is exercised end-to-end: window, normaliser, cache, gate answer.
#
# Proves, per the errand's done-when:
#   · node --check clean; bash -n clean
#   · the window is plus/minus six weeks
#   · the normaliser maps an all-day event, a multi-day span, a timezone-offset
#     event and a cancelled event correctly
#   · with the vault key absent the reader degrades to a NAMED error, never a
#     silent empty
#   · busy -> 10, free -> 0, unknown -> 20 (distinct from both)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
READER="$ROOT/tools/calendar/reader.mjs"
DOOR="$ROOT/bin/calendar-ask.sh"
FIX="$ROOT/.agents/tests/assets/managandr-google-events.json"

fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Europe/Berlin fixes the all-day midnight math; the door never needs the vault.
export MANAGANDR_TZ=Europe/Berlin
export MANAGANDR_NO_VAULT=1
CACHE="$TMP/cache.json"
NOWS=2026-10-13T10:00:00Z
BUSY_AT=2026-10-13T10:00:00Z
FREE_AT=2026-10-20T12:00:00Z

# ── 1. syntax ────────────────────────────────────────────────────────────────
if bash -n "$DOOR" 2>/dev/null; then ok "calendar-ask.sh is bash -n clean"; else bad "bash -n calendar-ask.sh"; fi
if node --check "$READER" 2>/dev/null; then ok "reader.mjs is node --check clean"; else bad "node --check reader.mjs"; fi

# ── 2. the window is plus/minus six weeks ────────────────────────────────────
if "$READER" --fixture "$FIX" --cache "$CACHE" --now "$NOWS" --window 6w --json >"$TMP/out.json" 2>"$TMP/out.err"; then
  if node -e '
const j = require(process.argv[1]);
const now = Date.parse("2026-10-13T10:00:00Z");
const sixw = 42 * 864e5;
const bad = [];
if (j.window.start !== new Date(now - sixw).toISOString()) bad.push("start=" + j.window.start);
if (j.window.end !== new Date(now + sixw).toISOString()) bad.push("end=" + j.window.end);
if (j.window.radius_ms !== sixw) bad.push("radius=" + j.window.radius_ms);
if (bad.length) { console.error(bad.join(" ")); process.exit(1); }
' "$TMP/out.json" 2>"$TMP/win.err"; then
    ok "window is plus/minus six weeks"
  else
    bad "window is plus/minus six weeks ($(cat "$TMP/win.err"))"
  fi
else
  bad "reader failed to run against the fixture ($(cat "$TMP/out.err"))"
fi

# ── 3. the normaliser ────────────────────────────────────────────────────────
if node -e '
const j = require(process.argv[1]);
const ev = Object.fromEntries(j.events.map((e) => [e.id, e]));
const A = (c, m) => { if (!c) { console.error(m); process.exit(1); } };
A(ev["ev-all-day"], "all-day event missing");
A(ev["ev-all-day"].all_day === true, "all-day flag not set");
A(ev["ev-all-day"].start === "2026-10-10", "all-day start date");
A(ev["ev-all-day"].end === "2026-10-11", "all-day end date");
A(ev["ev-all-day"].start_ms === Date.parse("2026-10-10T00:00:00+02:00"), "all-day midnight is the machine zone, not UTC");
A(ev["ev-multiday"].all_day === false, "multi-day wrongly all-day");
A(ev["ev-multiday"].start === "2026-10-12T09:00:00+02:00", "multi-day start");
A(ev["ev-multiday"].end === "2026-10-14T17:00:00+02:00", "multi-day end");
A(ev["ev-multiday"].end_ms - ev["ev-multiday"].start_ms === 56 * 3600 * 1000, "multi-day span is 56h");
A(ev["ev-offset"].start === "2026-10-06T15:30:00-04:00", "offset start keeps its offset");
A(ev["ev-offset"].start_ms === Date.parse("2026-10-06T15:30:00-04:00"), "offset instant");
A(ev["ev-cancelled"].status === "cancelled", "cancelled status");
A(ev["ev-cancelled"].busy === false, "cancelled is not busy");
A(ev["ev-transparent"].busy === false, "transparent is not busy");
' "$TMP/out.json" 2>"$TMP/norm.err"; then
  ok "normaliser maps all-day, multi-day, tz-offset and cancelled"
else
  bad "normaliser ($(cat "$TMP/norm.err"))"
fi

# ── 4. the vault key absent: a NAMED error, never a silent empty ─────────────
rm -f "$TMP/none.json"
rc=0
env -u MANAGANDR_OAUTH_REFRESH_TOKEN -u MANAGANDR_CLIENT_ID -u MANAGANDR_CLIENT_SECRET \
  -u HEIMDALL_OAUTH_CLIENT_ID -u HEIMDALL_OAUTH_CLIENT_SECRET \
  "$READER" --cache "$TMP/none.json" --now "$NOWS" --json >"$TMP/unknown.json" 2>"$TMP/unknown.err" || rc=$?
if [ "$rc" = 20 ]; then ok "reader exits 20 when it cannot prove freshness"; else bad "reader unknown exit was $rc, want 20"; fi
if node -e '
const j = require(process.argv[1]);
const A = (c, m) => { if (!c) { console.error(m); process.exit(1); } };
A(j.status === "unknown", "status=" + j.status);
A(j.reason === "no_oauth_grant", "reason=" + j.reason);
A(String(j.missing || "").includes("MANAGANDR_OAUTH_REFRESH_TOKEN"), "missing does not name the key: " + j.missing);
A(j.events.length === 0, "events not empty");
A(j.as_of === null, "as_of should be null when unknown");
A(j.checked_at, "checked_at must be present on every path");
' "$TMP/unknown.json" 2>"$TMP/unknown-check.err"; then
  ok "the absent grant is a named no_oauth_grant error, not an empty day"
else
  bad "absent-grant result ($(cat "$TMP/unknown-check.err"))"
fi
# UNKNOWN IS NOT EMPTY: the same command WITH a fixture proves data flows, so an
# empty answer above is demonstrably "unknown", not "nothing on the calendar".
node -e 'const j=require(process.argv[1]); if(j.count<1){console.error("fixture produced no events");process.exit(1)}' "$TMP/out.json" 2>/dev/null \
  && ok "a real read yields events, so 'unknown' is not an empty day" \
  || bad "fixture yielded no events"

# ── 5. the shell door's exit vocabulary ──────────────────────────────────────
"$DOOR" busy --fixture "$FIX" --cache "$CACHE" --now "$BUSY_AT" >/dev/null 2>&1
rc=$?; [ "$rc" = 10 ] && ok "busy returns 10" || bad "busy returned $rc, want 10"

"$DOOR" free --fixture "$FIX" --cache "$CACHE" --now "$FREE_AT" >/dev/null 2>&1
rc=$?; [ "$rc" = 0 ] && ok "free returns 0" || bad "free returned $rc, want 0"

env -u MANAGANDR_OAUTH_REFRESH_TOKEN "$DOOR" busy --cache "$TMP/none2.json" --now "$BUSY_AT" >/dev/null 2>&1
rc=$?
if [ "$rc" = 20 ] && [ "$rc" != 0 ] && [ "$rc" != 10 ]; then
  ok "unknown returns 20, distinct from free (0) and busy (10)"
else
  bad "unknown returned $rc, want 20"
fi

# An UNREADABLE cache is also unknown, never a silent empty.
printf '{ this is not json' >"$TMP/corrupt.json"
env -u MANAGANDR_OAUTH_REFRESH_TOKEN "$DOOR" free --cache "$TMP/corrupt.json" --now "$FREE_AT" >/dev/null 2>&1
rc=$?
[ "$rc" = 20 ] && ok "an unreadable cache is unknown, never free" || bad "unreadable cache returned $rc, want 20"

# ── 6. no title, attendee or location leaks from the door ────────────────────
"$DOOR" probe --fixture "$FIX" --cache "$CACHE" --now "$NOWS" >"$TMP/probe.out" 2>&1
grep -q "Invented" "$TMP/probe.out" && bad "probe leaked a title" || ok "probe prints no title by default"
"$DOOR" busy --fixture "$FIX" --cache "$CACHE" --now "$BUSY_AT" >"$TMP/busy.out" 2>&1
grep -q "Invented" "$TMP/busy.out" && bad "busy leaked a title" || ok "busy prints no title"
"$DOOR" probe --titles --fixture "$FIX" --cache "$CACHE" --now "$NOWS" 2>/dev/null \
  | grep -q "Invented All-Day Gathering" && ok "probe --titles prints on explicit request" || bad "probe --titles did not print"

# ── 7. read-only and jq-free, proved from the code ───────────────────────────
if grep -nE 'events\.(insert|update|patch|delete|move)|method:[[:space:]]*"(PUT|PATCH|DELETE)"|(create|update|delete)Event' "$READER" "$DOOR" >/dev/null 2>&1; then
  bad "a write verb exists in the read calendar"
else
  ok "no create/update/delete verb exists"
fi
if grep -vE '^[[:space:]]*#' "$DOOR" | grep -qE '\bjq\b'; then
  bad "the door calls jq"
else
  ok "the door needs no jq"
fi

if [ "$fail" -eq 0 ]; then
  printf 'managandr-reader: all checks passed\n'
  exit 0
fi
printf 'managandr-reader: %s\n' "$fail checks failed" >&2
exit 1
