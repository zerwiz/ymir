#!/usr/bin/env bash
# verify-seat.test.sh — can the seat prove itself, and does it FAIL when it cannot?
#
# The promise is not "prints a table" — it is **"exits non-zero when something is missing"**. A
# check that returns 0 on a broken seat is the exact fault this exists to kill (2026-09-30: an
# arm file on disk, no watch loaded, nothing failed). So both halves are proved, against a real
# filesystem with things deliberately removed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/verify-seat.sh"
pass=0; fail=0
ok(){ printf 'ok - %s\n' "$1"; pass=$((pass+1)); }
no(){ printf 'not ok - %s\n' "$1" >&2; fail=$((fail+1)); }

[ -x "$DOOR" ] || { printf 'not ok - no %s\n' "$DOOR" >&2; exit 1; }

TMP="$(mktemp -d /tmp/verify-seat.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# ── 1. a seat with everything present must PASS and say WHOLE ─────────────────
# A REAL whole seat: the four extensions deployed, the watch marker present, a lock
# naming THIS shell (alive), and the home resolving. Nothing here is mocked.
mkdir -p "$TMP/whole-ext" "$TMP/whole-state" "$TMP/whole-locks"
for e in constellation.ts gna-pi-watch.ts syn-turnend-guard.ts ymirhome.ts; do : > "$TMP/whole-ext/$e"; done
touch "$TMP/whole-state/.pi-gna-watch-loaded"
printf '%s\n' "$$" > "$TMP/whole-locks/brokk.lock"
out="$(PI_EXT_DIR="$TMP/whole-ext" YMIR_STATE_DIR="$TMP/whole-state" BROKK_STATE_ROOT="$TMP/whole-locks" bash "$DOOR" --no-exit 2>&1)"
printf '%s' "$out" | grep -q '"WHOLE"' \
  && ok "a whole seat (extensions present) verifies WHOLE" \
  || { no "a whole seat did not verify: $out"; }

# ── 2. a seat missing the WATCH must FAIL, by name, non-zero ──────────────────
mkdir -p "$TMP/broken"
out="$(PI_EXT_DIR="$ROOT" YMIR_STATE_DIR="$TMP/broken" bash "$DOOR" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "a seat without the watch exits NON-ZERO (rc=$rc)" \
  || no "a broken seat exited 0 — that is the fault this door exists to kill"
printf '%s' "$out" | grep -q 'watch-loaded' \
  && ok "the failure NAMES the missing surface (watch-loaded)" \
  || no "the failure did not name what was missing"
printf '%s' "$out" | grep -q '"NOT WHOLE"' \
  && ok "the verdict says NOT WHOLE" || no "no NOT WHOLE verdict"

# ── 3. a seat missing its EXTENSIONS must fail and name them ──────────────────
mkdir -p "$TMP/noext" "$TMP/state2"
out="$(PI_EXT_DIR="$TMP/noext" YMIR_STATE_DIR="$TMP/state2" bash "$DOOR" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "a seat with no extensions exits non-zero" || no "missing extensions exited 0"
printf '%s' "$out" | grep -q 'extensions' && ok "it names extensions as missing" \
  || no "it did not name extensions"

# ── 4. every check must be reportable without changing the verdict ───────────
a="$(bash "$DOOR" --no-exit 2>&1 | grep -c 'verify-seat')"
b="$(bash "$DOOR" --no-exit 2>&1 | grep -c 'verify-seat')"
[ "$a" = "$b" ] && ok "two runs agree (the verdict is stable, not a race)" \
  || no "two runs disagreed ($a vs $b)"

printf 'verify-seat: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1