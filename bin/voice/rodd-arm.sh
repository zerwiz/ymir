#!/usr/bin/env bash
# rodd-arm.sh — Rödd knocks on the arm, and hears the answer.
#
# Rödd (the voice, apps/rodd) drives its OWN pi session, so it can act in the world but cannot
# reach the session that HOLDS THE ARM — the one that drains wakes, dispatches errands and
# answers. This is the door for both halves of that conversation (plan 223):
#
#   who           resolve the arm lease: holder pid, gen, mode, state dir, heartbeat age
#   tell [--from <name>] <text>   append a wake of kind `signal` into the state dir the LEASE names
#   hear [n]      read the arm's replies from <state>/rodd/room.jsonl, and advance the cursor
#
# THE LEASE IS THE AUTHORITY, NEVER A PATH. Two state shelves exist on some seats, and only the
# one named in `.arm.lease` (`state=`) is drained by the arm. So every verb resolves the lease
# first, and a missing, dead or stale lease makes the door say `no arm is held` and exit 3 —
# a voice that hands a message to nobody and says "sent" is the false green this house keeps
# paying for (2026-11-05, plan 188 §14-16).
#
# ONE WRITER PER FILE. The door appends to the wake queue (the house's own durable wire, written
# under its own lock) and to its own cursor file; it NEVER writes the room. The arm writes
# `<state>/rodd/room.jsonl` — one JSON object per line, `{"ts","from","text"}` — and Rödd only
# reads it. Reading advances a byte cursor; the room is never truncated, so a reply is never
# destroyed by being heard.
#
# Usage:
#   rodd-arm.sh who                 who holds the arm, and is the heartbeat fresh
#   rodd-arm.sh tell <text>         hand the arm holder a message (refuses with no arm held)
#   rodd-arm.sh hear [n]            print unread replies (default 20, `all` for every one)
#   rodd-arm.sh room                where the room is, and how many replies it holds
#   rodd-arm.sh --check             the one-line verdict, for a health surface
#   rodd-arm.sh --self-test         prove the door against a synthetic lease in a temp state
#
# Env (all optional):
#   RODD_ARM_LEASE                   the lease file (default: <state>/.arm.lease)
#   YMIR_STATE_DIR                   the state root (default: <home>/state, via hoard-lib.sh)
#   BROKK_WATCH_HEARTBEAT_STALE_SECONDS  heartbeat age that means "not held" (default 60,
#                                    the watcher's own threshold — one number, not two)
#
# Exit: 0 ran · 3 no arm is held · 2 usage · 1 the door itself failed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

STATE_DOOR="$ROOT/bin/records/ymir-state.sh"
HOARD_LIB="$ROOT/bin/vault/hoard-lib.sh"
STALE_AFTER="${BROKK_WATCH_HEARTBEAT_STALE_SECONDS:-60}"
DEFAULT_SHOW=20

usage() { sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die()   { printf 'rodd-arm: %s\n' "$*" >&2; exit 1; }
refuse(){ printf 'rodd-arm: %s\n' "$*" >&2; exit 3; }
now()   { date +%s; }
# one readable line: the queue is tab-separated, so a tab or a newline in a spoken
# message would break the record. Flatten, then squeeze, then trim — never mangle words.
flatten(){ printf '%s' "$1" | tr '\t\r\n' '   ' | tr -s ' ' | sed 's/^ *//; s/ *$//'; }

# The two roots are the home's business (Rule 07): asked of the one resolver, never restated.
resolve_roots() {
  [ -r "$HOARD_LIB" ] || die "the home resolver is missing ($HOARD_LIB) — no state dir can be named"
  # shellcheck source=../vault/hoard-lib.sh
  . "$HOARD_LIB"
  hoard_state_dir STATE_ROOT || die "the home resolver could not name a state dir"
  LEASE="${RODD_ARM_LEASE:-$STATE_ROOT/.arm.lease}"
}

lease_field() {  # <file> <field>
  sed -n "s/.*\b$2=\([^ ]*\).*/\1/p" "$1" 2>/dev/null | head -1
}

# /proc field 22 (starttime) — the identity that makes PID reuse a mismatch. Empty where
# /proc does not answer (a non-Linux seat): the probe then falls back to the pid alone.
pid_starttime() {  # <pid>
  [ -r "/proc/$1/stat" ] || return 0
  sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | awk '{print $20}'
}

# arm_probe — resolve the lease and decide whether an arm is HELD.
# Sets: LEASE PID GEN MODE SESSION LIVESTATE HEARTBEAT AGE QUEUE ROOM; ARM_WHY on failure.
# Returns 0 held · 1 not held.
arm_probe() {
  ARM_WHY=""
  PID=""; GEN=""; MODE=""; SESSION=""; LIVESTATE=""; HEARTBEAT=""; AGE=""; QUEUE=""; ROOM=""
  resolve_roots
  if [ ! -r "$LEASE" ]; then
    ARM_WHY="there is no arm lease at $LEASE — nobody is holding the arm"
    return 1
  fi
  PID="$(lease_field "$LEASE" pid)"
  GEN="$(lease_field "$LEASE" gen)"
  MODE="$(lease_field "$LEASE" mode)"
  SESSION="$(lease_field "$LEASE" session)"
  HEARTBEAT="$(lease_field "$LEASE" heartbeat)"
  LIVESTATE="$(lease_field "$LEASE" state)"

  case "$PID" in
    ''|*[!0-9]*) ARM_WHY="the lease names no pid — a lease without a holder is not an arm"; return 1 ;;
  esac
  kill -0 "$PID" 2>/dev/null || {
    ARM_WHY="the lease names pid $PID, which is not a live process"; return 1; }

  local recorded cur
  recorded="$(lease_field "$LEASE" starttime)"
  cur="$(pid_starttime "$PID")"
  if [ -n "$recorded" ] && [ -n "$cur" ] && [ "$cur" != "$recorded" ]; then
    ARM_WHY="pid $PID is live but it is a DIFFERENT process (starttime $cur, lease says $recorded) — the lease is a leftover"
    return 1
  fi

  case "$HEARTBEAT" in
    ''|*[!0-9]*) ARM_WHY="the lease carries no heartbeat — freshness cannot be proved"; return 1 ;;
  esac
  local t; t="$(now)"
  AGE=$(( t - HEARTBEAT ))
  [ "$AGE" -ge 0 ] || AGE=0
  if [ "$AGE" -gt "$STALE_AFTER" ]; then
    ARM_WHY="the lease's heartbeat is ${AGE}s old (over ${STALE_AFTER}s) — the arm has stopped beating"
    return 1
  fi

  # NEVER invent the state dir: it is the lease's own `state=`, and it must exist.
  if [ -z "$LIVESTATE" ] || [ ! -d "$LIVESTATE" ]; then
    ARM_WHY="the lease names state '$LIVESTATE', which is not a directory — the queue path cannot be resolved from it"
    return 1
  fi
  QUEUE="$LIVESTATE/.wake-queue"
  ROOM="$LIVESTATE/rodd/room.jsonl"
  return 0
}

held_or_refuse() {
  arm_probe && return 0
  refuse "no arm is held — $ARM_WHY. Nothing was handed over and nothing was written."
}

# ── who ────────────────────────────────────────────────────────────────────────
cmd_who() {
  if ! arm_probe; then
    printf 'no arm is held\n'
    printf 'rodd-arm: %s\n' "$ARM_WHY" >&2
    return 3
  fi
  printf 'rodd-arm[1]{verb,holder_pid,gen,mode,session,state_dir,heartbeat_age_s,stale_after_s,queue,room}:\n'
  printf '  "who","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$PID" "${GEN:-unknown}" "${MODE:-unknown}" "${SESSION:-none}" \
    "$LIVESTATE" "$AGE" "$STALE_AFTER" "$QUEUE" "$ROOM"
  return 0
}

# ── tell ───────────────────────────────────────────────────────────────────────
# The key is `rodd-<epoch>`; a second message inside the same second must not reuse it, so
# the queued keys are read through the SAME door that writes them and a suffix is added.
unique_key() {  # <epoch>
  local base="rodd-$1" keys k n=1
  keys="$("$STATE_DOOR" queue keys signal --queue "$QUEUE" 2>/dev/null)" || keys=""
  case "$(printf '%s\n' "$keys" | grep -Fx "$base" | head -1)" in
    "$base") : ;;
    *) printf '%s' "$base"; return 0 ;;
  esac
  while :; do
    n=$((n + 1))
    k="$base-$n"
    printf '%s\n' "$keys" | grep -Fxq "$k" || { printf '%s' "$k"; return 0; }
  done
}

cmd_tell() {
  # --from <name> names the sender (an Eindri, another seat); the default stays Rödd, the voice.
  # RODD_FROM does the same from the environment. 2026-11-11: nine agents' roll-call knocks all
  # arrived signed "Rödd (the voice)", and the arm holder could not tell them apart.
  local from="${RODD_FROM:-Rödd (the voice)}"
  if [ "${1:-}" = "--from" ]; then
    [ -n "${2:-}" ] || die 'tell --from needs a name: rodd-arm.sh tell --from w4F-p1 "..."'
    from="$2"; shift 2
  fi
  case "$from" in *$'\e'*) die 'refusing a sender name carrying an escape sequence' ;; esac
  local text="$*"
  [ -n "${text//[[:space:]]/}" ] || die 'tell needs a message: rodd-arm.sh tell "the window is too wide"'
  case "$text" in *$'\e'*) die 'refusing a message carrying an escape sequence — one plain line only' ;; esac
  held_or_refuse
  [ -x "$STATE_DOOR" ] || die "the queue door is missing ($STATE_DOOR) — the message was NOT handed over"

  # tabs and newlines are the queue's field separators: the door flattens them, so a
  # multi-line message arrives as ONE readable line rather than as a broken record.
  local epoch key payload
  epoch="$(now)"
  key="$(unique_key "$epoch")"
  payload="$(flatten "$from") to the arm holder: $(flatten "$text")"
  "$STATE_DOOR" queue append signal "$key" "$payload" --queue "$QUEUE" --epoch "$epoch" >/dev/null 2>&1 \
    || die "the queue write to $QUEUE failed — nothing was handed over, and nothing claims it was"
  printf 'rodd-arm-tell[1]{verb,delivered,key,state_dir,queue,epoch,chars}:\n'
  printf '  "tell","yes","%s","%s","%s","%s","%s"\n' \
    "$key" "$LIVESTATE" "$QUEUE" "$epoch" "${#payload}"
  return 0
}

# ── hear ───────────────────────────────────────────────────────────────────────
cmd_hear() {
  local want="${1:-$DEFAULT_SHOW}"
  case "$want" in
    ''|*[!0-9]*)
      case "$want" in all|ALL) want=all ;; *) die "hear takes a count or 'all', not '$want'" ;; esac ;;
  esac
  held_or_refuse
  local cursor="$LIVESTATE/rodd/.cursor"
  mkdir -p "$LIVESTATE/rodd" || die "cannot create the room's shelf $LIVESTATE/rodd"
  python3 - "$ROOM" "$cursor" "$want" <<'PY' || die "the room could not be read"
import json, os, sys, tempfile

room, cursor, want = sys.argv[1], sys.argv[2], sys.argv[3]
limit = None if want.isdigit() is False else int(want)

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

raw = b""
try:
    with open(room, "rb") as fh:
        raw = fh.read()
except OSError:
    raw = b""

start = 0
try:
    start = int(open(cursor).read().strip() or 0)
except (OSError, ValueError):
    start = 0
if start < 0 or start > len(raw):
    start = 0

chunk = raw[start:]
# Only COMPLETE lines are consumed: a reply written mid-read is read whole on the next
# turn, never half-printed and never skipped.
cut = chunk.rfind(b"\n") + 1
consumed, tail = chunk[:cut], chunk[cut:]

rows = []
for line in consumed.decode("utf-8", "replace").splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except ValueError:
        obj = {"text": line}
    if not isinstance(obj, dict):
        obj = {"text": str(obj)}
    rows.append((
        str(obj.get("ts") or obj.get("at") or ""),
        str(obj.get("from") or obj.get("speaker") or "arm"),
        str(obj.get("text") or ""),
    ))

unread = len(rows)
shown = rows if limit is None else rows[:limit]
# A limited read stops at the first UNPRINTED reply: nothing is consumed unheard.
new_cursor = start + len(consumed)
if limit is not None and limit < unread:
    kept = consumed.split(b"\n")[:limit]
    new_cursor = start + sum(len(part) + 1 for part in kept)

print(f"rodd-arm-hear[1]{{verb,state_dir,room,unread,shown,cursor}}:")
print(f"  {q('hear')},{q(os.path.dirname(os.path.dirname(room)))},{q(room)},{q(unread)},{q(len(shown))},{q(new_cursor)}")
if shown:
    print("replies[%d]{at,from,text}:" % len(shown))
    for at, sender, text in shown:
        flat = " ".join(text.split())
        print(f"  {q(at)},{q(sender)},{q(flat)}")
else:
    print("replies[0]{at,from,text}:")

try:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(cursor) or ".", prefix=".cursor-")
    with os.fdopen(fd, "w") as fh:
        fh.write(f"{new_cursor}\n")
    os.replace(tmp, cursor)
except OSError as exc:
    print(f"rodd-arm: the cursor could not be advanced ({exc}) — replies were shown, not consumed",
          file=sys.stderr)
    sys.exit(1)
if len(tail):
    print(f"rodd-arm: a reply is still being written ({len(tail)} bytes) — it will be read whole next time",
          file=sys.stderr)
PY
}

# ── room ───────────────────────────────────────────────────────────────────────
cmd_room() {
  held_or_refuse
  local lines=0
  [ -r "$ROOM" ] && lines="$(awk 'END{print NR}' "$ROOM")"
  printf 'rodd-arm-room[1]{verb,state_dir,room,lines,writer,reader}:\n'
  printf '  "room","%s","%s","%s","the arm holder","Rödd (a byte cursor, never a truncation)"\n' \
    "$LIVESTATE" "$ROOM" "$lines"
}

# ── check ──────────────────────────────────────────────────────────────────────
cmd_check() {
  if arm_probe; then
    printf 'rodd-arm[1]{verdict,holder_pid,state_dir,heartbeat_age_s}:\n  "held","%s","%s","%s"\n' \
      "$PID" "$LIVESTATE" "$AGE"
    return 0
  fi
  printf 'rodd-arm[1]{verdict,why}:\n  "no arm is held","%s"\n' "$ARM_WHY"
  return 3
}

# ── self-test ──────────────────────────────────────────────────────────────────
# A synthetic seat: a temp state dir, a live pid (this shell), and a lease that names it.
# Nothing touches the real arm: RODD_ARM_LEASE and YMIR_STATE_DIR point the door elsewhere.
self_test() {
  local rc pass=0 fail=0 out err
  T="$(mktemp -d)"   # global on purpose: the EXIT trap outlives this function
  trap 'rm -rf "$T"' EXIT
  export YMIR_STATE_DIR="$T/state"
  export RODD_ARM_LEASE="$T/state/.arm.lease"
  mkdir -p "$T/state"
  export RODD_ARM_SELF_TEST_PID=$$

  ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
  bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; printf '       %s\n' "${2:-}"; }
  run() { out="$("$0" "$@" 2>"$T/err")"; rc=$?; err="$(cat "$T/err")"; }
  want_rc() {  # <rc> <why>
    if [ "$rc" = "$1" ]; then ok "$2"; else bad "$2" "expected rc=$1 got rc=$rc · out=$(printf '%s' "$out" | head -2 | tr '\n' ' ') · err=$(printf '%s' "$err" | head -1)"; fi
  }
  has() {  # <needle> <why>
    case "$out" in *"$1"*) ok "$2" ;; *) bad "$2" "out=$(printf '%s' "$out" | head -3 | tr '\n' ' ')" ;; esac
  }
  # a TOON row's column, by position (the header names them; the row carries them)
  col() {  # <row-line> <column>
    printf '%s\n' "$out" | sed -n "${1}p" | sed 's/^  //' \
      | awk -F'","' -v c="$2" '{v=$c; gsub(/^"|"$/,"",v); print v}'
  }

  printf 'rodd-arm self-test\n'

  # 1 · no lease at all: nothing is held, and nothing is pretended
  run who
  want_rc 3 "who with no lease exits 3"
  has "no arm is held" "who with no lease says so"

  run tell "should not land"
  want_rc 3 "tell REFUSES with no lease"
  [ ! -s "$T/state/.wake-queue" ] && ok "tell with no lease wrote nothing" \
    || bad "tell with no lease wrote nothing" "the queue exists and is non-empty"

  # 2 · a lease naming a dead pid
  printf 'pid=999999 starttime=1 gen=4 mode=test session=none heartbeat=%s state=%s\n' \
    "$(now)" "$T/state" >"$RODD_ARM_LEASE"
  run who
  want_rc 3 "who with a dead pid exits 3"

  # 3 · a live lease, written exactly as the watcher writes it
  printf 'pid=%s starttime=%s gen=7 mode=self-test session=none heartbeat=%s state=%s\n' \
    "$$" "$(pid_starttime $$)" "$(now)" "$T/state" >"$RODD_ARM_LEASE"
  run who
  want_rc 0 "who with a live lease exits 0"
  has "\"$$\"" "who names the holder pid"
  has '"7"' "who names the generation"
  has "$T/state" "who names the lease's state dir, not a hardcoded one"
  case "$out" in *heartbeat_age_s*) ok "who reports the heartbeat's age" ;; *) bad "who reports the heartbeat's age" "$out" ;; esac

  run --check
  want_rc 0 "--check agrees the arm is held"

  # 4 · tell lands in the LEASE's queue, one line, tabs and newlines flattened
  run tell "the Rödd window is too wide"
  want_rc 0 "tell with a held arm exits 0"
  [ "$(col 2 2)" = yes ] && ok "tell says delivered only because the door returned it" \
    || bad "tell says delivered only because the door returned it" "delivered=$(col 2 2)"
  [ -s "$T/state/.wake-queue" ] && ok "the wake landed in the lease's queue" \
    || bad "the wake landed in the lease's queue" "the queue is empty or absent"
  if [ -s "$T/state/.wake-queue" ]; then
    local qline; qline="$(cat "$T/state/.wake-queue")"
    [ "$(printf '%s\n' "$qline" | wc -l | tr -d ' ')" = 1 ] && ok "one wake is one line" || bad "one wake is one line" "$qline"
    case "$(printf '%s' "$qline" | cut -f3)" in signal) ok "the wake's kind is signal" ;; *) bad "the wake's kind is signal" "$qline" ;; esac
    case "$(printf '%s' "$qline" | cut -f4)" in rodd-*) ok "the wake's key is rodd-<epoch>" ;; *) bad "the wake's key is rodd-<epoch>" "$qline" ;; esac
    case "$(printf '%s' "$qline" | cut -f5)" in *"Rödd"*) ok "the wake names Rödd" ;; *) bad "the wake names Rödd" "$qline" ;; esac
    case "$(printf '%s' "$qline" | cut -f5)" in *"too wide"*) ok "the wake carries the text" ;; *) bad "the wake carries the text" "$qline" ;; esac
    [ "$(printf '%s' "$qline" | awk -F'\t' '{print NF}')" = 5 ] && ok "no field separator was smuggled in" \
      || bad "no field separator was smuggled in" "$(printf '%s' "$qline" | cat -A | head -1)"
  fi

  run tell "$(printf 'two\nlines\twith a tab')"
  want_rc 0 "a multi-line tell is accepted"
  [ "$(awk 'END{print NR}' "$T/state/.wake-queue")" = 2 ] && ok "a second tell does not overwrite the first" \
    || bad "a second tell does not overwrite the first" "$(cat "$T/state/.wake-queue")"
  [ "$(awk -F'\t' '{print $4}' "$T/state/.wake-queue" | sort -u | wc -l | tr -d ' ')" = 2 ] \
    && ok "the two wakes carry distinct keys" || bad "the two wakes carry distinct keys" "$(cat "$T/state/.wake-queue")"

  run tell "$(printf 'two\nlines')"
  [ "$(awk 'END{print NR}' "$T/state/.wake-queue")" = 3 ] && ok "a third tell inside the same second still lands" \
    || bad "a third tell inside the same second still lands" "$(cat "$T/state/.wake-queue")"

  # 5 · hear: nothing yet, then a reply the ARM wrote, then the cursor
  run hear
  want_rc 0 "hear with no room yet exits 0"
  [ "$(col 2 4)" = 0 ] && ok "hear with no room yet reports nothing unread" \
    || bad "hear with no room yet reports nothing unread" "unread=$(col 2 4)"

  mkdir -p "$T/state/rodd"
  printf '%s\n' '{"ts":"2026-11-08T21:10:00Z","from":"hoenir","text":"try the narrower window"}' \
    >"$T/state/rodd/room.jsonl"
  local before; before="$(cksum <"$T/state/rodd/room.jsonl")"
  run hear
  want_rc 0 "hear reads a reply the arm wrote"
  [ "$(col 2 4)" = 1 ] && ok "hear counts it unread" \
    || bad "hear counts it unread" "unread=$(col 2 4)"
  has "try the narrower window" "hear prints the reply's text"
  has "hoenir" "hear names who answered"
  [ "$(cksum <"$T/state/rodd/room.jsonl")" = "$before" ] && ok "reading did not touch the room" \
    || bad "reading did not touch the room" "the room changed while being read"

  run hear
  [ "$(col 2 4)" = 0 ] && ok "a second hear reports nothing new (the cursor advanced, and nothing was deleted)" \
    || bad "a second hear reports nothing new (the cursor advanced, and nothing was deleted)" "unread=$(col 2 4)"
  [ "$(wc -l <"$T/state/rodd/room.jsonl" | tr -d ' ')" = 1 ] && ok "the reply is still in the room after being read" \
    || bad "the reply is still in the room after being read" "the room lost its line"

  printf '%s\n' '{"ts":"2026-11-08T21:12:00Z","from":"hoenir","text":"and the second answer"}' >>"$T/state/rodd/room.jsonl"
  run hear
  has "and the second answer" "a new reply is read, and the old one is not repeated"

  # 6 · a stale heartbeat is not an arm
  printf 'pid=%s starttime=%s gen=7 mode=self-test session=none heartbeat=%s state=%s\n' \
    "$$" "$(pid_starttime $$)" "$(( $(now) - 3600 ))" "$T/state" >"$RODD_ARM_LEASE"
  run who
  want_rc 3 "a stale heartbeat means no arm is held"
  has "no arm is held" "a stale lease says so"

  # 7 · the lease names a state dir that does not exist: never invent one
  printf 'pid=%s starttime=%s gen=7 mode=self-test session=none heartbeat=%s state=%s\n' \
    "$$" "$(pid_starttime $$)" "$(now)" "$T/no-such-state" >"$RODD_ARM_LEASE"
  run tell "nowhere"
  want_rc 3 "an absent state dir is refused, never invented"
  [ ! -d "$T/no-such-state" ] && ok "the door did not create the dir it was not given" \
    || bad "the door did not create the dir it was not given" "$T/no-such-state exists"

  printf 'rodd-arm self-test: %s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}

# ── main ───────────────────────────────────────────────────────────────────────
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage 0 ;;
  who) shift; cmd_who ;;
  tell) shift; cmd_tell "$@" ;;
  hear) shift; cmd_hear "${1:-$DEFAULT_SHOW}" ;;
  room) shift; cmd_room ;;
  --check|check) shift; cmd_check ;;
  --self-test|self-test) shift; self_test ;;
  *) printf 'error: unknown verb %s\nhelp: rodd-arm.sh [who|tell <text>|hear [n]|room|--check|--self-test]\n' "$1" >&2; exit 2 ;;
esac
