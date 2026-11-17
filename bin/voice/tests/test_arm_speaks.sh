#!/usr/bin/env bash
# test_arm_speaks.sh — "a session that can speak" is ONE definition, and it refuses a
# watcher by name (plan 310 §1.1).
#
# THE LAW THIS PROVES. On 2026-11-17 the heart's arm read `held` all morning while every pi
# on that machine was dead: the holder was `ymir_runtime watch run`, a supervisor with no
# model behind it, and a tell handed to it went nowhere. So the house now has one answer to
# "can this session speak", in `bin/voice/arm-speak-lib.sh`, and these are its cases:
#
#   1 · a process that is not a harness          → refused, and the refusal SAYS why
#   2 · a harness with a live transcript         → accepted, and the proof is named
#   3 · a harness whose transcript is stale      → refused (a corpse is not a session)
#   4 · a harness with no known transcript shelf  → refused, naming the row to add
#   5 · the claimant is resolved the way the lock door resolves it (BROKK_SESSION_PID, then
#       the ancestry), so the arm, the lock and this lib never disagree
#   6 · the door's own `speaks` verb answers the same question, and `hold` refuses a
#       non-agent with the same words
#
# Every stand-in harness is a copy of a real binary NAMED as the harness, in its own working
# directory: /proc/<pid>/comm is the executable name, so the lib sees what it would see on a
# real seat. Nothing here touches the live arm, the live lock or the live lease table.
#
# Usage: test_arm_speaks.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
LIB="$ROOT/bin/voice/arm-speak-lib.sh"
DOOR="$ROOT/bin/voice/rodd-arm.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
t()   { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1" "${3:-}"; fi; }

TMP=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/harness/bin" "$TMP/speakhome"
export YMIR_SPEAK_HOME="$TMP/speakhome"

# ── the stand-ins ─────────────────────────────────────────────────────────────
fake_harness() {  # <comm> — starts a stand-in harness; sets FAKE_PID (never echoes it:
                  # a command substitution would take the process down with its subshell)
  local name="$1" work="$TMP/harness/work-$1"
  mkdir -p "$work"
  cp "$(command -v sleep)" "$TMP/harness/bin/$name"
  ( cd "$work" && exec "$TMP/harness/bin/$name" 600 ) &
  FAKE_PID=$!
  sleep 0.2
}
shelf_dir() {  # <comm> <cwd> — where that harness would keep this session's transcript
  local comm="$1" work="$2" slug
  case "$comm" in
    pi)     slug="--$(printf '%s' "$work" | sed 's#^/##; s#/#-#g')--" ;;
    claude) slug="-$(printf '%s' "$work" | sed 's#^/##; s#/#-#g')" ;;
    *)      slug="--$(printf '%s' "$work" | sed 's#^/##; s#/#-#g')--" ;;
  esac
  printf '%s/.pi/agent/sessions/%s' "$YMIR_SPEAK_HOME" "$slug"
}
write_transcript() {  # <comm> <cwd> [touch-epoch]
  local dir; dir="$(shelf_dir "$1" "$2")"
  mkdir -p "$dir"
  printf '{"turn":1}\n' >"$dir/session.jsonl"
  [ -n "${3:-}" ] && touch -d "@$3" "$dir/session.jsonl"
  printf '%s' "$dir/session.jsonl"
}

ask() {  # <pid> — run the lib's probe in a clean shell, print the row and the rc
  local pid="$1"
  YMIR_SPEAK_MAX_AGE="${YMIR_SPEAK_MAX_AGE:-1800}" bash -c '
    set -u
    . "'"$LIB"'"
    speaks_probe "'"$pid"'"
    rc=$?
    speaks_line
    exit "$rc"
  ' 2>&1
}

printf 'test_arm_speaks\n'

# ── 1 · a process that is not a harness is refused, by name ───────────────────
python3 -c 'import time; time.sleep(600)' &
PY=$!
sleep 0.2
sleep 0.3
out="$(ask "$PY")"; rc=$?
[ "$rc" != 0 ] && ok "a python3 watcher cannot speak" || bad "a python3 watcher cannot speak" "$out"
case "$out" in *"a watcher is not a speaker"*) ok "the refusal says a watcher is not a speaker" ;; *) bad "the refusal says a watcher is not a speaker" "$out" ;; esac
case "$out" in *'"no"'*) ok "the verdict row says no" ;; *) bad "the verdict row says no" "$out" ;; esac
out="$(ask "$$")"; rc=$?
[ "$rc" != 0 ] && ok "this shell (bash) cannot speak either" || bad "this shell (bash) cannot speak either" "$out"
out="$(ask 999999)"; rc=$?
[ "$rc" != 0 ] && ok "a dead pid cannot speak" || bad "a dead pid cannot speak" "$out"
case "$out" in *"not a live process"*) ok "a dead pid is named as dead" ;; *) bad "a dead pid is named as dead" "$out" ;; esac

# ── 2 · a harness with a live transcript is accepted, and the proof is named ──
fake_harness pi; PI="$FAKE_PID"
t "the stand-in harness is named pi as the kernel sees it" '[ "$(cat /proc/'"$PI"'/comm)" = pi ]' "$(cat /proc/$PI/comm 2>/dev/null)"
out="$(ask "$PI")"; rc=$?
[ "$rc" != 0 ] && ok "a harness with NO transcript yet is refused" || bad "a harness with NO transcript yet is refused" "$out"
case "$out" in *"no transcript for pi"*) ok "the refusal names the missing transcript" ;; *) bad "the refusal names the missing transcript" "$out" ;; esac
write_transcript pi "$TMP/harness/work-pi" >/dev/null
out="$(ask "$PI")"; rc=$?
[ "$rc" = 0 ] && ok "a harness with a fresh transcript CAN speak" || bad "a harness with a fresh transcript CAN speak" "$out"
case "$out" in *'"yes","pi","'"$PI"'"'*) ok "the row names the harness and its pid" ;; *) bad "the row names the harness and its pid" "$out" ;; esac
case "$out" in *"transcript:cwd"*) ok "the proof is the session's OWN transcript (transcript:cwd)" ;; *) bad "the proof is the session's OWN transcript (transcript:cwd)" "$out" ;; esac

# ── 3 · a stale transcript is a dead model ───────────────────────────────────
old=$(( $(date +%s) - 7200 ))
write_transcript pi "$TMP/harness/work-pi" "$old" >/dev/null
out="$(ask "$PI")"; rc=$?
[ "$rc" != 0 ] && ok "a stale transcript means the model stopped speaking" || bad "a stale transcript means the model stopped speaking" "$out"
case "$out" in *"stopped speaking"*) ok "the refusal says the model has stopped speaking" ;; *) bad "the refusal says the model has stopped speaking" "$out" ;; esac
# …and the window is ONE number, honoured from the environment
write_transcript pi "$TMP/harness/work-pi" >/dev/null
old_touch=$(( $(date +%s) - 120 ))
touch -d "@$old_touch" "$(shelf_dir pi "$TMP/harness/work-pi")/session.jsonl"
out="$(YMIR_SPEAK_MAX_AGE=60 ask "$PI")"; rc=$?
[ "$rc" != 0 ] && ok "a tighter window (YMIR_SPEAK_MAX_AGE=60) refuses a 120s old transcript" || bad "a tighter window refuses a 120s old transcript" "$out"
out="$(YMIR_SPEAK_MAX_AGE=600 ask "$PI")"; rc=$?
[ "$rc" = 0 ] && ok "the same transcript passes a wider window — the window is the only difference" || bad "the same transcript passes a wider window" "$out"

# ── 4 · a harness with no known transcript shelf is refused, naming the row ──
fake_harness muse; MUSE="$FAKE_PID"
out="$(ask "$MUSE")"; rc=$?
[ "$rc" != 0 ] && ok "a harness with no known shelf cannot prove a heartbeat" || bad "a harness with no known shelf cannot prove a heartbeat" "$out"
case "$out" in *"no known transcript shelf"*) ok "the refusal names the missing shelf row" ;; *) bad "the refusal names the missing shelf row" "$out" ;; esac
case "$out" in *"speak_shelf"*) ok "the refusal says where the row goes" ;; *) bad "the refusal says where the row goes" "$out" ;; esac

# ── 5 · the claimant is resolved the way the lock door resolves it ───────────
out="$(BROKK_SESSION_PID="$PI" bash -c 'set -u; . "'"$LIB"'"; speaks_claimant_pid C; printf "%s" "$C"')"
[ "$out" = "$PI" ] && ok "BROKK_SESSION_PID names the session (the harness's own word wins)" || bad "BROKK_SESSION_PID names the session" "got $out, want $PI"
out="$(bash -c 'set -u; . "'"$LIB"'"; speaks_claimant_pid C; printf "%s" "$C"')"
[ -n "$out" ] && ok "with no explicit pid, the ancestry is walked to a session" || bad "the ancestry is walked to a session" "empty"

# ── 6 · the door says the same, and `hold` refuses a non-agent in the same words ──
out="$(bash "$DOOR" speaks "$PI" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "rodd-arm.sh speaks accepts the speaking harness" || bad "rodd-arm.sh speaks accepts the speaking harness" "$out"
out="$(bash "$DOOR" speaks "$PY" 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "rodd-arm.sh speaks refuses the watcher (rc 1)" || bad "rodd-arm.sh speaks refuses the watcher (rc 1)" "$out"
STATE="$TMP/state"; mkdir -p "$STATE"
out="$(env YMIR_STATE_DIR="$STATE" RODD_ARM_LEASE="$STATE/.arm.lease" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
        BROKK_SESSION_PID="$$" bash "$DOOR" hold 2>&1)"; rc=$?
[ "$rc" = 3 ] && ok "hold from a non-agent process is REFUSED (exit 3)" || bad "hold from a non-agent process is REFUSED (exit 3)" "$out"
case "$out" in *"ONLY A SESSION THAT CAN SPEAK MAY HOLD AN ARM"*) ok "the refusal names the law" ;; *) bad "the refusal names the law" "$out" ;; esac
case "$out" in *"a watcher is not a speaker"*) ok "the refusal names the reason" ;; *) bad "the refusal names the reason" "$out" ;; esac
[ ! -e "$TMP/machine/brokk.lock" ] && ok "a refused hold never took the lock" || bad "a refused hold never took the lock" "a lock appeared"

printf 'test_arm_speaks: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
