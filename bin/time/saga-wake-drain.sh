#!/usr/bin/env bash
# saga-wake-drain.sh - present durable Brokk wakes, or acknowledge them.
#
# Sága sees the queue. `drain` (default) prints each durable wake; `ack` drops
# the queues once the wakes have been handled. Ported/trimmed from the upstream
# wake-drain contract for plan 29.
#
# Usage: saga-wake-drain.sh [drain [--full]|ack|start|classes]
#   start    the session start's drain: present, write the ledger, ack, report what was owed
#   --full   every line, uncollapsed (still in class order) — how a collapsed report is opened
#   classes  one machine row, `voice=N ask=N report=N`, read-only (the arm extension asks it)
#
# PEOPLE FIRST (plan 328). The queue is presented by CLASS, not by arrival: `voice` (Rödd,
# the mail desk, Telegram, the operator), then `ask` (an errand's question), then `report`
# (done / report filed / progress) — FIFO inside a class. The first line names the shape,
# `voice n · ask n · report n`, and routine errand reports collapse to one counted line with
# their ids. Collapsing is presentation only: the ack still consumes exactly the presented
# lines (a multiset diff), so every collapsed report stays individually ackable.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The queue lives in the OPERATOR's state, never the code tree (Rule 04). Resolve
# it exactly as every shell tool does, so a standalone drain sees the same queue
# the watcher fills. It once defaulted to $BROKK_HOME/state (the TREE) and
# reported "0 pending" while the hoard queue held unhandled wakes (2026-09-23).
if [ -z "${BROKK_STATE_OVERRIDE:-}" ]; then
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
    unset _c
  fi
  hoard_state_dir _HS 2>/dev/null && BROKK_STATE_OVERRIDE="$_HS"
  unset _HS
fi
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"

mkdir -p "$STATE"
QUEUE="$STATE/.wake-queue"
# The FM runner's own durable queue (its published check-wakes) lives under the
# .agents home, not the main state. The watcher hollers on BOTH doors; a drain
# that reads only one lets strikes hide in the other. Combine them here.
. "$SCRIPT_DIR/sol-lib.sh"
FMQ="$SCRIPT_DIR/../../state/procevent/.wake-queue"

# ── the classes (plan 328) ───────────────────────────────────────────────────────
# One reader for every line shape the queue holds: a trailing `class=<c>` field written by
# the door that knows its source wins; an older, unmarked line is classed by its source —
# the mail desk, a tell from a person, the operator's own word are voice; a QUESTION or a
# needs-decision is ask; everything else is machinery, a report.
# Input: queue lines on stdin. WAKE_ORDER_MODE=present prints records `<tag>\t<text>`:
#   S  the summary   ·  W  one line to present (class tail stripped)   ·  R  the collapsed reports
# WAKE_ORDER_MODE=classes prints `voice=N ask=N report=N`. WAKE_ORDER_FULL=1 collapses nothing.
WAKE_ORDER_PY='
import os, re, sys
CLASS_TAIL = re.compile(r"\tclass=(voice|ask|report)\s*$")
STAMP = re.compile(r"^\d{4}-\d\d-\d\d \d\d:\d\d[^—]*—\s*")
AGENT = re.compile(r"^(agent|eindri|Eindri|seat)\s|^w[A-Za-z0-9]*[-:]p\d")
ASK = re.compile(r"\bQUESTION\b|needs-decision|\bblocked:")
def body_of(line):
    f = line.split("\t")
    if len(f) >= 5 and f[0].isdigit() and f[1].isdigit():
        line = "\t".join(f[4:])
    return STAMP.sub("", line)
def classify(line):
    m = CLASS_TAIL.search(line)
    if m:
        return m.group(1), line[:m.start()]
    text = body_of(line)
    if re.search(r"(^|— )mail: \d+ new", text) or text.startswith("mail:"):
        return "voice", line
    t = re.match(r"(.+?) to the arm holder: ", text)
    if t and not AGENT.search(t.group(1)):
        return "voice", line
    if "[from the Allfather" in text or re.match(r"(?i)telegram\b", text):
        return "voice", line
    if ASK.search(text):
        return "ask", line
    return "report", line
ID = [re.compile(r"^(?:eindri|seat) (\S+?):? "), re.compile(r"^agent (\S+?) to the arm holder: ")]
def report_id(line):
    text = body_of(line)
    for rx in ID:
        m = rx.search(text)
        if m:
            return m.group(1)
    return ""
lines = [l.rstrip("\n") for l in sys.stdin if l.strip()]
groups = {"voice": [], "ask": [], "report": []}
for l in lines:
    c, shown = classify(l)
    groups[c].append(shown)
mode = os.environ.get("WAKE_ORDER_MODE", "present")
n = {c: len(v) for c, v in groups.items()}
if mode == "classes":
    print("voice=%d ask=%d report=%d" % (n["voice"], n["ask"], n["report"]))
    raise SystemExit(0)
print("S\tvoice %d · ask %d · report %d" % (n["voice"], n["ask"], n["report"]))
for l in groups["voice"] + groups["ask"]:
    print("W\t" + l)
full = os.environ.get("WAKE_ORDER_FULL") == "1"
try:
    at = int(os.environ.get("SAGA_DRAIN_COLLAPSE_AT", "2"))
except ValueError:
    at = 2
# a lone report is shown whole: a collapsed row of one hides more than it saves
if sum(1 for l in groups["report"] if report_id(l)) < at:
    full = True
ids, loose = [], []
for l in groups["report"]:
    rid = "" if full else report_id(l)
    if rid:
        if re.search(r"FAILED|\bfailed\b|DEAD", body_of(l)):
            rid += "(failed)"
        ids.append(rid)
    else:
        loose.append(l)
if ids:
    seen = {}
    for i in ids:
        seen[i] = seen.get(i, 0) + 1
    names = ", ".join(k if v == 1 else "%s×%d" % (k, v) for k, v in seen.items())
    print("R\t%d errand report line(s), collapsed — %s · each stays queued until acked; read one: state/eindri-reports/<id>.md · every line: saga-wake-drain.sh drain --full" % (len(ids), names))
for l in loose:
    print("W\t" + l)
'

# THE HELM OWNS THE ACK (2026-11-11). The home's queue is drained by the session that holds the lock; a
# second session that acks it eats the helm's wakes. True (and prints the owner) when the lease names THIS
# state dir and a live session that is not the caller holds the lock. YMIR_ACK_ANY=1 is the loud override.
# THE HOLDER MAY ACKNOWLEDGE FROM ANY SHELL IT OWNS (2026-11-19): the session is the owner, whichever of
# its children asks.
arm_is_anothers() {
  local lease="$STATE/.arm.lease" owner sess
  [ -z "${YMIR_ACK_ANY:-}" ] && [ -r "$lease" ] && grep -qE "(^| )state=$STATE( |$)" "$lease" 2>/dev/null || return 1
  owner="$(bash "$SCRIPT_DIR/../records/ymir-state.sh" lock owner 2>/dev/null | tr -d '[:space:]')"
  sess="$(bash "$SCRIPT_DIR/../records/ymir-state.sh" lock session-pid 2>/dev/null | tr -d '[:space:]')"
  [ -n "$owner" ] && [ -d "/proc/$owner" ] && [ "${sess:-}" != "$owner" ] \
    && ! bash "$SCRIPT_DIR/../records/ymir-state.sh" lock owned --shell-pid "$$" >/dev/null 2>&1 || return 1
  printf '%s' "$owner"
}

# Remove exactly the lines of <list> from <queue> (a multiset diff), without losing a wake that arrives
# meanwhile (plan 369 item 16). The queue is moved aside first and what stays is APPENDED back, so a writer
# never meets a rewrite of the file it appends to. A move left over from a killed run is returned first.
consume_lines() { # <queue> <list>
  [ -f "$2" ] || return 0
  python3 - "$1" "$2" <<'PY' 2>/dev/null || true
import collections, os, sys
queue, listed = sys.argv[1:3]
aside = queue + ".consuming"
def give_back(lines):
    if lines:
        with open(queue, "a") as out:
            out.write("".join(l + "\n" for l in lines))
if os.path.exists(aside):
    give_back(open(aside).read().splitlines()); os.remove(aside)
want = collections.Counter(open(listed).read().splitlines())
if not want or not os.path.exists(queue):
    raise SystemExit(0)
os.rename(queue, aside)
keep = []
for l in open(aside).read().splitlines():
    if want.get(l, 0) > 0:
        want[l] -= 1
    else:
        keep.append(l)
give_back(keep)
os.remove(aside)
PY
}

case "${1:-drain}" in
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  ack|--ack)
    if ! _owner="$(arm_is_anothers)"; then :; else
      printf 'error: the arm is held by session %s; this queue is its to acknowledge, not yours\nhelp: tell the arm holder over the arm (bin/voice/rodd-arm.sh tell --from <you> "...") — YMIR_ACK_ANY=1 overrides\n' "$_owner" >&2
      exit 3
    fi
    # Consume EXACTLY what the last drain PRESENTED — never a wake that arrived
    # after it. The old full-truncate ate undrained wakes (the ack race) and let
    # the sweep's re-presentation ring with an empty hand — the ghost wakes the
    # Allfather saw. A multiset diff: handled lines leave, newer lines stay.
    consume_lines "$QUEUE" "$STATE/.wake-drained"
    consume_lines "$FMQ" "$STATE/.wake-fmq-drained"
    rm -f "$STATE/.wake-drained" "$STATE/.wake-fmq-drained"
    # The flood-brake hash clears only when both doors are truly empty, so a
    # later terminal wake signals cleanly; preserved newer wakes keep it set.
    if [ ! -s "$QUEUE" ] && { [ ! -f "$FMQ" ] || [ ! -s "$FMQ" ]; }; then
      rm -f "$STATE/.wake-last-hash" 2>/dev/null || true
      printf 'wake queue: acknowledged (0 pending)\n'
    else
      printf 'wake queue: acknowledged handled wakes; newer wakes preserved\n'
    fi
    exit 0
    ;;
  start|--start)
    # THE SESSION START DRAINS (2026-11-19). Measured: 31 wakes sat in the queue from 2026-11-17 to
    # 2026-11-19, because the session start only COUNTED them and the arm drains only at a wake. The
    # helm's session start now runs this: present every owed wake, write each one to the append-only
    # ledger (<state>/wake-ledger.log, so nothing is lost by the ack), acknowledge exactly what was
    # presented, and report what was owed in one line. A session that may not ack (another live
    # session holds the arm) presents and says so; the queue is left for the holder.
    # --full: the ledger and the count hold EVERY line, never the collapsed report row; the
    # order is already people first, so the lines shown below lead with the voices.
    _out="$(bash "$0" drain --full 2>&1)"
    _wakes="$(printf '%s\n' "$_out" | grep '^WAKE ' || true)"
    _n="$(printf '%s' "$_wakes" | grep -c '^WAKE ' || true)"
    if [ "${_n:-0}" = 0 ]; then
      printf 'drain: nothing was owed at session start — wake queue: 0 pending\n'
      exit 0
    fi
    _ledger="$STATE/wake-ledger.log"
    {
      printf '== session start %s · %s wake(s) presented\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_n"
      printf '%s\n' "$_wakes"
    } >>"$_ledger" 2>/dev/null || true
    printf 'drain: %s wake(s) were owed at session start — every one is in %s\n' "$_n" "$_ledger"
    printf '%s\n' "$_out" | grep -m1 '^wake classes: ' || true
    printf '%s\n' "$_wakes" | head -n "${SAGA_DRAIN_SHOW:-8}" | cut -c1-240
    [ "$_n" -gt "${SAGA_DRAIN_SHOW:-8}" ] && printf '… and %s more in the ledger\n' "$((_n - ${SAGA_DRAIN_SHOW:-8}))"
    if _ack="$(bash "$0" ack 2>&1)"; then
      printf 'drain: %s\n' "$_ack"
    else
      printf 'drain: presented, NOT acknowledged — %s\n' "$(printf '%s' "$_ack" | head -1)"
    fi
    _left=0; [ -s "$QUEUE" ] && _left="$(awk 'END{print NR}' "$QUEUE")"
    printf 'wake queue after the drain: %s pending\n' "$_left"
    exit 0
    ;;
  classes|--classes)
    # Read-only: the class counts of what the queue holds now. No snapshot, no drop, no ack.
    [ -s "$QUEUE" ] || { printf 'voice=0 ask=0 report=0\n'; exit 0; }
    WAKE_ORDER_MODE=classes python3 -c "$WAKE_ORDER_PY" <"$QUEUE"
    exit 0
    ;;
  drain|--drain|"")
    case "${2:-}" in --full|full) SAGA_DRAIN_FULL=1 ;; "") ;; *) printf 'error: drain takes --full or nothing, not %s\n' "$2" >&2; exit 2 ;; esac
    ;;
  *) printf 'error: unknown action %s\nhelp: saga-wake-drain.sh [drain [--full]|ack|start|classes]\n' "$1" >&2; exit 2 ;;
esac

# PASS 1 — what is to be presented: the resolved-wake drop (below) decides it, silently, so
# the classes can be counted and named BEFORE a single line is read (plan 328 step 4).
resolved=0
_kept=""
if [ -s "$QUEUE" ]; then
  # Count LINES, not newlines: the door is judged non-empty by `[ -s ]`, so a queue
  # holding one unterminated line must present that line too. `wc -l` said 0 for
  # exactly that file, while the extension read the same door as non-empty and
  # re-presented one week-old wake at every turn boundary (2026-10-24).
  count=$(awk 'END{print NR}' "$QUEUE")
  # A RESOLVED WAKE DROPS ITSELF (plan 275 item 28 §3). A wake is news ONCE: it was
  # presented at the previous drain and its subject's record has since gone terminal, so
  # nothing is owed on it and re-reading it at every turn is noise, not memory. The FIRST
  # notice is never dropped (plan 137): a line absent from the previous presentation is
  # printed even when its subject has already closed.
  _prev="$STATE/.wake-drained"
  _kept="$(mktemp "$STATE/.wake-kept.XXXXXX" 2>/dev/null || printf '%s' "$STATE/.wake-kept.tmp")"
  : >"$_kept" 2>/dev/null || true
  _gone="$_kept.gone"; : >"$_gone" 2>/dev/null || true
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    # A wake is presented until Brokk acks it. The errand's status (done/failed)
    # does NOT make it an echo: a self-finishing worker's terminal wake is the
    # FIRST notice Brokk gets, and dropping it on status makes the worker invisible
    # (plan 137). Echoes from Brokk closing his own errand are still presented once
    # and cleared by `ack` — harmless noise, not a reason to drop the real news.
    _key="$(printf '%s' "$line" | cut -f4)"
    if [ -n "$_key" ] && [ -r "$_prev" ] && grep -qxF -- "$line" "$_prev" 2>/dev/null; then
      _claim="$(tail -n1 "$STATE/$_key.status" 2>/dev/null | tr -d '\r')"
      case "$_claim" in
        done:*|failed:*|needs-decision:*|paused:*)
          resolved=$((resolved + 1)); printf '%s\n' "$line" >>"$_gone"; continue ;;
      esac
    fi
    printf '%s\n' "$line" >>"$_kept" 2>/dev/null || true
  done <"$QUEUE"
  count=$(awk 'END{print NR}' "$_kept")
  _order="$(WAKE_ORDER_MODE=present WAKE_ORDER_FULL="${SAGA_DRAIN_FULL:-0}" python3 -c "$WAKE_ORDER_PY" <"$_kept" 2>/dev/null)"
  # The shape of what waits, before anything else is shown.
  printf 'wake classes: %s\n' "$(printf '%s\n' "$_order" | sed -n 's/^S\t//p' | head -1)"
fi

# THE RECORD IS WHAT WAS SHOWN (plan 369 item 16). It was copied from the queue AFTER the lines were
# printed, so a wake arriving meanwhile was recorded as shown and the ack ate it: the sequence moved and the
# queue was empty. A session that may not ack writes no record, so it cannot replace the holder's.
RECORD=1; arm_is_anothers >/dev/null && RECORD=0
_fmshow="$(mktemp "$STATE/.wake-fmq-show.XXXXXX" 2>/dev/null || printf '%s' "$STATE/.wake-fmq-show.tmp")"
cp "$FMQ" "$_fmshow" 2>/dev/null || : >"$_fmshow"
if [ "$RECORD" = 1 ]; then
  if [ -n "$_kept" ] && [ -s "$_kept" ]; then cp "$_kept" "$STATE/.wake-drained" 2>/dev/null; else rm -f "$STATE/.wake-drained"; fi
  if [ -s "$_fmshow" ]; then cp "$_fmshow" "$STATE/.wake-fmq-drained" 2>/dev/null; else rm -f "$STATE/.wake-fmq-drained"; fi
fi

if [ -s "$_fmshow" ]; then
  printf 'FM wake queue: %s pending (fm-queued wakes below)\n' "$(awk 'END{print NR}' "$_fmshow")"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] && printf 'WAKE %s\n' "$line"
  done <"$_fmshow"
  printf 'FM_ACK_REQUIRED: acknowledge handled fm wakes to drop them from the fm queue\n'
fi

rm -f "$_fmshow" 2>/dev/null
if [ -z "$_kept" ] || { [ ! -s "$_kept" ] && [ "$resolved" = 0 ]; }; then
  printf 'wake queue: 0 pending\n'
else
  printf '%s — wake queue: %s pending\n' "$(sol_line)" "${count:-0}"
  # PASS 2 — people first: voice, then ask, then report; FIFO inside a class.
  if [ -z "$_order" ]; then
    # the ordering could not run (no python): present in arrival order rather than nothing
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] && printf 'WAKE %s\n' "$(sol_stamped "$line")"
    done <"$_kept"
  else
    while IFS= read -r rec || [ -n "$rec" ]; do
      tag="${rec%%$'\t'*}"; text="${rec#*$'\t'}"
      case "$tag" in
        W) printf 'WAKE %s\n' "$(sol_stamped "$text")" ;;
        R) printf 'REPORTS %s\n' "$text" ;;
      esac
    done <<<"$_order"
  fi
  if [ "$resolved" -gt 0 ]; then
    consume_lines "$QUEUE" "$_gone"
    printf 'wake_resolved[1]{dropped,why}:\n  %s,"presented once, and its errand has since closed — a resolved wake is not news"\n' "$resolved"
  fi
  [ "${dropped:-0}" -gt 0 ] && printf 'wake_echo[1]{dropped,why}:\n  %s,"errands already closed — ack clears them, they are not presented as news"\n' "$dropped"
  printf 'WAKE_ACK_REQUIRED: acknowledge handled wakes to drop them from the queue\n'
  # THE OPEN WORK, every wake — not only the morning brief. One line, so a wake says not
  # just "something happened" but "and here is what still stands unmade".
  OW="$SCRIPT_DIR/../records/open-work.sh"
  if [ -x "$OW" ]; then
    ow_json="$("$OW" --json 2>/dev/null)"
    printf '%s' "$ow_json" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
from collections import Counter
items=d.get("items",[])
if not items: raise SystemExit(0)
c=Counter(i.get("state","open") for i in items)
print(f"OPEN WORK: {len(items)} item(s) — " + " · ".join(f"{k} {v}" for k,v in sorted(c.items())) + " · bin/records/open-work.sh --md")' 2>/dev/null
  fi
fi

[ -n "$_kept" ] && rm -f "$_kept" "$_kept.gone" 2>/dev/null

# Open-decision markers (approval gates) left unhandled.
decisions=$(find "$STATE" -maxdepth 1 -name '*.decision' 2>/dev/null | wc -l | tr -d '[:space:]')
printf 'open decisions: %s\n' "${decisions:-0}"
