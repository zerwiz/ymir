#!/usr/bin/env bash
# snotra-iscall.test.sh — a mic grab is not a meeting.
#
# The fault this test pins (heimdall, 2026-09-28): the watch armed and recorded on
# a seat where nobody was in a call, because an idle Chromium mic hold looks
# exactly like a call to anything that only asks "does an app hold the mic?".
# Production bar: a call is a stream CARRYING a call role (`media.role`), never a
# bare mic grab, and never one of the house's own audio tools.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ISCALL="$ROOT/bin/time/snotra/snotra-iscall.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/state"

# fixture <file> <json>
fixture() { printf '%s\n' "$2" >"$1"; }

# run_verdict <fixture|-> [extra env…] -> prints "rc<TAB>reason"
run_verdict() {
  local fx="$1"; shift
  local out rc
  out="$(SNOTRA_ISCALL_FIXTURE="$fx" YMIR_STATE_DIR="$TMP/state" "$ISCALL" --why "$@" 2>/dev/null)"
  rc=$?
  printf '%s\t%s\n' "$rc" "$out"
}

expect() {  # <label> <want-rc> <got-rc> <reason>
  if [ "$3" = "$2" ]; then ok "$1  [rc=$3: $4]"
  else bad "$1 — wanted rc=$2, got rc=$3 ($4)"; fi
}

# ── 1. no streams at all ─────────────────────────────────────────────────────
fixture "$TMP/none.json" '[]'
r="$(run_verdict "$TMP/none.json")"
expect "no streams -> not a call" 1 "${r%%	*}" "${r#*	}"

# ── 2. THE FAULT: a bare mic grab with no media.role (idle Chromium) ─────────
fixture "$TMP/bare.json" '[{"index":76809,"properties":{"application.name":"Chromium input","application.process.binary":"chromium"}}]'
r="$(run_verdict "$TMP/bare.json")"
expect "bare mic grab (no media.role) -> NOT a call" 1 "${r%%	*}" "${r#*	}"

# ── 3. a real call: the same app, now carrying the call role ─────────────────
fixture "$TMP/phone.json" '[{"index":1,"properties":{"application.name":"Chromium input","application.process.binary":"chromium","media.role":"phone"}}]'
r="$(run_verdict "$TMP/phone.json")"
expect "chromium + media.role=phone -> call" 0 "${r%%	*}" "${r#*	}"

fixture "$TMP/comm.json" '[{"index":1,"properties":{"application.name":"Firefox","application.process.binary":"firefox","media.role":"Communication"}}]'
r="$(run_verdict "$TMP/comm.json")"
expect "firefox + media.role=Communication -> call" 0 "${r%%	*}" "${r#*	}"

# ── 4. the house's own tools are never a caller ──────────────────────────────
fixture "$TMP/parec.json" '[{"index":1,"properties":{"application.name":"parec","application.process.binary":"pacat","media.role":"phone"}}]'
r="$(run_verdict "$TMP/parec.json")"
expect "house tool (pacat/parec) with a call role -> NOT a call" 1 "${r%%	*}" "${r#*	}"

fixture "$TMP/ffmpeg.json" '[{"index":1,"properties":{"application.name":"Lavf63","application.process.binary":"ffmpeg","media.role":"Communication"}}]'
r="$(run_verdict "$TMP/ffmpeg.json")"
expect "the ear's own capture (ffmpeg) -> NOT a call" 1 "${r%%	*}" "${r#*	}"

# ── 5. a mixed seat: an ignored tool AND a real call on one machine ──────────
fixture "$TMP/mixed.json" '[{"index":1,"properties":{"application.process.binary":"ffmpeg","media.role":"Communication"}},{"index":2,"properties":{"application.name":"Zoom","application.process.binary":"zoom","media.role":"phone"}}]'
r="$(run_verdict "$TMP/mixed.json")"
expect "ffmpeg ignored, zoom still counts -> call" 0 "${r%%	*}" "${r#*	}"

# ── 6. the explicit arm outranks the heuristic (the Thing door / a hand) ─────
: >"$TMP/state/.snotra-arm"
r="$(run_verdict "$TMP/none.json")"
expect "explicit arm marker -> call" 0 "${r%%	*}" "${r#*	}"
rm -f "$TMP/state/.snotra-arm"

# ── 7. an operator-supplied ignore list is honoured ──────────────────────────
fixture "$TMP/vlc.json" '[{"index":1,"properties":{"application.process.binary":"vlc","media.role":"phone"}}]'
r="$(SNOTRA_IGNORE_BINARIES="vlc" SNOTRA_ISCALL_FIXTURE="$TMP/vlc.json" YMIR_STATE_DIR="$TMP/state" "$ISCALL" --why 2>/dev/null; printf '\t%s' "$?")"
rc="${r##*	}"
expect "SNOTRA_IGNORE_BINARIES=vlc -> NOT a call" 1 "$rc" "ignored"

# ── 8. malformed input fails SAFE (no capture, no crash) ─────────────────────
fixture "$TMP/bad.json" 'not json at all'
r="$(run_verdict "$TMP/bad.json")"
expect "malformed sound-server JSON -> NOT a call (fails safe)" 1 "${r%%	*}" "${r#*	}"

# ── 9. missing fixture file fails safe ───────────────────────────────────────
r="$(run_verdict "$TMP/does-not-exist.json")"
expect "unreadable fixture -> NOT a call (fails safe)" 1 "${r%%	*}" "${r#*	}"

# ── 10. --json is machine-readable ───────────────────────────────────────────
j="$(SNOTRA_ISCALL_FIXTURE="$TMP/phone.json" YMIR_STATE_DIR="$TMP/state" "$ISCALL" --json 2>/dev/null)"
case "$j" in
  *'"call": true'*|*'"call":true'*) ok "--json reports the verdict" ;;
  *) bad "--json unreadable: $j" ;;
esac

if [ "$fail" = 0 ]; then printf '\nall snotra-iscall tests passed\n'; else printf '\nsnotra-iscall tests FAILED\n' >&2; fi
exit "$fail"
