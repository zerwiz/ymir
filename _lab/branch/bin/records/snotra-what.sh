#!/usr/bin/env bash
# snotra-what.sh — Snotra's own voice: what the ear is doing, said in one sentence.
#
#   snotra-what.sh now [--brief]     armed or idle · the rule that decided · since when · until when
#   snotra-what.sh last              the last capture: when, how long, who spoke, where the minutes are,
#                                    and whether the pipeline FINISHED or STOPPED AT a step
#   snotra-what.sh plan [<id>]       the ordered steps and the one it is blocked at
#   snotra-what.sh week [--days N]   the counts he reads in a week (default 7 days)
#   snotra-what.sh off --reason "…"  his hand: the ear does not arm; the reason is recorded
#   snotra-what.sh on                his hand lifted
#   snotra-what.sh --json …          machine output for any read verb
#   snotra-what.sh --self-test       prove every verb against a fixture state (no house data touched)
#
# WHY (plan 228 §2 · F1, plan 112's own lesson): *a silent failure is indistinguishable
# from working*. The ear took the microphone for three days and said nothing; the pipeline
# stopped after the transcript and said nothing. This door is the line every one of those
# silences failed to say. It reads the state files the ear ALREADY writes — the watch's
# `.snotra-detect.json`, its decision log, the capture's pid/outfile markers, and the
# meeting folders the ladder finishes — and it keeps no record of its own.
#
# Rule 07: the home and the state dir resolve through bin/vault/hoard-lib.sh; the watch
# unit is named once and overridable; nothing here hardcodes a model or a credential.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
[ -n "${YMIR_HOME:-}" ] || { printf 'snotra-what: the home is unresolved — bin/vault/hoard-lib.sh answered nothing\n' >&2; exit 2; }

STATE="${YMIR_STATE_DIR:-$YMIR_HOME/state}"
DETECT_JSON="$STATE/.snotra-detect.json"
DETECT_LOG="$STATE/.snotra-detect.log"
PID_FILE="$STATE/.snotra-pid"
OUT_FILE="$STATE/.snotra-outfile"
LATEST_FILE="$STATE/.snotra-meetings-latest"
OFF_FILE="$STATE/.snotra-off"
WATCH_UNIT="${SNOTRA_WATCH_UNIT:-snotra-detect.service}"
DOOR="$0"
MEETINGS_DOOR="$ROOT/bin/records/meetings.sh"

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# the hotline, through the ONE door (a hand that lifts the ear is news; a no-op is not)
hotline() {  # <severity> <message> <key>
  [ "${SNOTRA_WHAT_QUIET:-0}" = "1" ] && return 0
  [ -x "$ROOT/bin/notify/send.sh" ] || return 0
  "$ROOT/bin/notify/send.sh" --source snotra --severity "$1" --message "$2" --key "$3" >/dev/null 2>&1 || true
}

CMD="${1:-now}"; shift || true
BRIEF=0; JSON=0; DAYS=7; REASON=""; ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --brief) BRIEF=1; shift ;;
    --json) JSON=1; shift ;;
    --days) DAYS="${2-}"; shift 2 ;;
    --reason) REASON="${2-}"; shift 2 ;;
    -h|--help) usage ;;
    *) [ -z "$ID" ] && ID="$1"; shift ;;
  esac
done
case "$DAYS" in ''|*[!0-9]*) DAYS=7 ;; esac

# ── the watch's liveness, probed, never assumed ─────────────────────────────
watch_state() {  # prints: running | stopped | unknown  (and how it was known)
  if command -v systemctl >/dev/null 2>&1; then
    local s
    s="$(systemctl --user is-active "$WATCH_UNIT" 2>/dev/null | head -1)"
    case "$s" in
      active|activating|reloading) printf 'running\tthe unit %s says %s' "$WATCH_UNIT" "$s"; return 0 ;;
      inactive|failed|deactivating)
        # A unit that is not INSTALLED here reads `inactive` too — a seat with no watch must
        # say so from its own log, never be called stopped because a name is missing (RULES/25).
        if systemctl --user cat "$WATCH_UNIT" >/dev/null 2>&1; then
          printf 'stopped\tthe unit %s says %s' "$WATCH_UNIT" "$s"; return 0
        fi ;;
    esac
  fi
  # no unit (or systemd silent): the log's freshness is the only honest probe
  if [ -r "$DETECT_LOG" ]; then
    local age
    age=$(( $(date +%s) - $(stat -c %Y "$DETECT_LOG" 2>/dev/null || echo 0) ))
    if [ "$age" -lt 120 ]; then printf 'running\tthe decision log was written %ss ago (no unit on this machine)' "$age"
    else printf 'stopped\tthe decision log has not been written for %ss (no unit on this machine)' "$age"; fi
    return 0
  fi
  printf 'unknown\tno unit, no decision log'
}

# ── his hand ────────────────────────────────────────────────────────────────
do_off() {
  local reason="${REASON:-}"
  [ -n "$reason" ] || { printf 'snotra-what: off needs --reason "why" — an off with no reason is a silence again\n' >&2; exit 2; }
  mkdir -p "$STATE" 2>/dev/null || true
  python3 - "$OFF_FILE" "$reason" <<'PY'
import datetime, json, os, sys
path, reason = sys.argv[1], sys.argv[2]
rec = {"off": True, "reason": reason,
       "ts": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
       "by": os.environ.get("USER", "")}
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(rec, fh, indent=2)
os.replace(tmp, path)
PY
  printf 'ear: off — %s\n' "$reason"
  printf '  recorded: %s\n' "$OFF_FILE"
  printf '  the watch reads this file and will not arm; the unit is never edited by hand\n'
  hotline MEDIUM "the ear is off by his hand: $reason" "snotra-off-$(date -u +%Y%m%d)"
}

do_on() {
  if [ -e "$OFF_FILE" ]; then
    local reason; reason="$(python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: d={}
print(d.get("reason",""))' "$OFF_FILE" 2>/dev/null)"
    rm -f "$OFF_FILE"
    printf 'ear: on — the watch may arm again (it was off: %s)\n' "${reason:-no reason recorded}"
  else
    printf 'ear: on — it was never off\n'
  fi
  hotline MEDIUM "the ear is on again — it may arm; nobody's microphone opens by itself" "snotra-on-$(date -u +%Y%m%dT%H%M)"
}

# ── every read verb, from the one record ────────────────────────────────────
read_what() {  # <verb>
  local ws; ws="$(watch_state)"
  printf '%s\n' "$ws" | head -1 >/dev/null
  WHAT_VERB="$1" WHAT_BRIEF="$BRIEF" WHAT_JSON="$JSON" WHAT_DAYS="$DAYS" WHAT_ID="$ID" \
  WHAT_WATCH="$(printf '%s' "$ws" | cut -f1)" WHAT_WATCH_WHY="$(printf '%s' "$ws" | cut -f2-)" \
  S="$STATE" LOG="$DETECT_LOG" JS="$DETECT_JSON" PIDF="$PID_FILE" OUTF="$OUT_FILE" \
  LATESTF="$LATEST_FILE" OFFF="$OFF_FILE" UNIT="$WATCH_UNIT" MEETINGS="$MEETINGS_DOOR" \
  DOOR="$0" ROOTDIR="$ROOT" \
  python3 - <<'PY'
import json, os, re, subprocess, sys, time, datetime

S = os.environ["S"]
LOG = os.environ["LOG"]
JS = os.environ["JS"]
PIDF = os.environ["PIDF"]
OUTF = os.environ["OUTF"]
LATESTF = os.environ["LATESTF"]
OFFF = os.environ["OFFF"]
UNIT = os.environ["UNIT"]
MEETINGS = os.environ["MEETINGS"]
WATCH = os.environ["WHAT_WATCH"]
WATCH_WHY = os.environ["WHAT_WATCH_WHY"]
VERB = os.environ["WHAT_VERB"]
BRIEF = os.environ["WHAT_BRIEF"] == "1"
AS_JSON = os.environ["WHAT_JSON"] == "1"
DAYS = int(os.environ["WHAT_DAYS"] or 7)
WANT_ID = os.environ["WHAT_ID"]
HOME = os.environ.get("YMIR_HOME", "")
NOW = time.time()


def iso(ts):
    try:
        return datetime.datetime.fromtimestamp(float(ts)).astimezone().strftime("%Y-%m-%d %H:%M")
    except Exception:
        return "?"


def hm(ts):
    try:
        return datetime.datetime.fromtimestamp(float(ts)).astimezone().strftime("%H:%M")
    except Exception:
        return "?"


def ago(ts):
    try:
        d = int(NOW - float(ts))
    except Exception:
        return "never"
    if d < 90:
        return "%ds ago" % d
    if d < 5400:
        return "%dm ago" % (d // 60)
    if d < 172800:
        return "%dh ago" % (d // 3600)
    return "%dd ago" % (d // 86400)


def ago_short(seconds):
    seconds = int(seconds)
    if seconds < 60:
        return "%ds" % seconds
    if seconds < 3600:
        return "%dm" % (seconds // 60)
    if seconds < 172800:
        return "%dh" % (seconds // 3600)
    return "%dd" % (seconds // 86400)


def read_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {}


def capture_pid():
    try:
        pid = int(open(PIDF).read().strip())
    except Exception:
        return None
    try:
        os.kill(pid, 0)
        return pid
    except Exception:
        return None


def log_lines():
    try:
        with open(LOG, encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    except Exception:
        return []


def last_decision():
    """The last line the watch wrote that DECIDED something, in the watch's own words."""
    patterns = [
        (re.compile(r"arm REFUSED — the mic is for a LOCAL room only"), "the local-room law — an online meeting is heard by the bot, never by this seat's microphone"),
        (re.compile(r"arm refused — the ear is already listening"), "the one-ear rule — a capture was already listening"),
        (re.compile(r"no call: (.+)"), "no call — {0}"),
        (re.compile(r"START edge — app '([^']*)'"), "an app took the microphone ({0})"),
        (re.compile(r"LEAVE edge \(([^)]*)\)"), "the leave edge ({0})"),
        (re.compile(r"leave: recording (\d+)s is below the (\d+)s meeting floor"), "the meeting floor — {0}s is shorter than {1}s"),
        (re.compile(r"arm FAILED — the capture did not rise"), "the capture did not rise"),
        (re.compile(r"watch started"), "the watch started"),
    ]
    for line in reversed(log_lines()):
        line = line.strip()
        if not line:
            continue
        m = re.match(r"^(\d{4}-\d\d-\d\dT[\d:]+Z)\s+(.*)$", line)
        stamp, rest = (m.group(1), m.group(2)) if m else ("", line)
        for rx, tmpl in patterns:
            mm = rx.search(rest)
            if mm:
                try:
                    text = tmpl.format(*[g for g in mm.groups() if g is not None])
                except Exception:
                    text = rest
                return text, stamp, rest
    return "", "", ""


def cap_seconds():
    """The cap the running capture was given, in seconds (the capture prints it)."""
    for line in reversed(log_lines()):
        m = re.search(r"Duration:\s+(\d+)s max", line)
        if m:
            return int(m.group(1))
    return int(os.environ.get("SNOTRA_MAX_SECONDS", "14400"))


def articles():
    """The meeting index, read through its ONE door — never a second record."""
    if not os.path.exists(MEETINGS):
        return []
    try:
        out = subprocess.run(["bash", MEETINGS, "json"], capture_output=True, text=True, timeout=90).stdout
        rows = json.loads(out or "[]")
        return rows if isinstance(rows, list) else []
    except Exception:
        return []


def newest(rows):
    def key(r):
        return (r.get("when") or "", r.get("id") or "")
    live = [r for r in rows if r.get("when")]
    return sorted(live, key=key)[-1] if live else None


def parse_ts(text):
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            dt = datetime.datetime.strptime(text, fmt)
            if dt.tzinfo is None:
                dt = dt.astimezone()
            return dt.timestamp()
        except Exception:
            continue
    return None


def last_capture_epoch(rows):
    """When the ear last heard something — the newest captured date, or the log's last START."""
    best = None
    for r in rows:
        if r.get("when"):
            for fmt, sl in (("%Y-%m-%d", 0),):
                try:
                    best = max(best or 0, datetime.datetime.strptime(r["when"], fmt).astimezone().timestamp())
                except Exception:
                    pass
    for line in reversed(log_lines()):
        m = re.match(r"^(\d{4}-\d\d-\d\dT[\d:]+Z)\s+START edge", line)
        if m:
            ep = parse_ts(m.group(1))
            if ep:
                best = max(best or 0, ep)
            break
    return best


def signature_block():
    state = read_json(JS)
    off = read_json(OFFF) if os.path.exists(OFFF) else {}
    pid = capture_pid()
    phase = state.get("phase") or ("in-call" if pid else "idle")
    armed = state.get("armed_epoch") or ""
    return state, off, pid, phase, armed


def say_now():
    state, off, pid, phase, armed = signature_block()
    decision, stamp, raw = last_decision()
    rows = articles()
    lasted = last_capture_epoch(rows)
    cap = cap_seconds()
    silent = (WATCH == "running") and (lasted is None or (NOW - lasted) > 86400)
    bits = []
    if off.get("off"):
        when = off.get("ts", "")
        bits.append("off by his hand")
        bits.append("the rule that decided: he said so — %s" % (off.get("reason") or "no reason recorded"))
        if when:
            bits.append("since %s" % when[:16].replace("T", " "))
        bits.append("until he says on")
        head = "off"
    elif phase == "in-call" or pid:
        head = "armed"
        bits.append("in a call (slug %s)" % (state.get("slug") or "impromptu"))
        bits.append("the rule that decided: %s" % (decision or "a capture is running"))
        if armed:
            try:
                since = float(armed)
                bits.append("since %s (%s)" % (hm(since), ago_short(NOW - since)))
                bits.append("the cap ends it at %s" % hm(since + cap))
            except Exception:
                pass
        else:
            bits.append("since just now")
    else:
        head = "armed" if WATCH == "running" else "idle"
        bits.append("watching" if WATCH == "running" else "not watching")
        bits.append("the rule that decided: %s" % (decision or WATCH_WHY))
        if stamp:
            bits.append("since %s" % stamp[:19].replace("T", " "))
        bits.append("until a call begins — nothing is listened to while idle")
    if silent:
        bits.append("no call seen in 24h")
    elif lasted:
        bits.append("last capture %s (%s)" % (iso(lasted), ago(lasted)))
    sentence = "%s — %s" % (head, " · ".join(bits))
    payload = {"state": head, "phase": phase, "watch": WATCH, "watch_why": WATCH_WHY,
               "rule": decision or WATCH_WHY, "since": armed or stamp, "until": (hm(float(armed) + cap) if armed else "a call begins"),
               "silent_24h": silent, "last_capture": iso(lasted) if lasted else "", "off": bool(off.get("off"))}
    if AS_JSON:
        print(json.dumps(payload, ensure_ascii=False, indent=2)); return
    if BRIEF:
        n_cap = len(rows)
        n_min = sum(1 for r in rows if r.get("minutes"))
        n_prom = sum(int(r.get("promises") or 0) for r in rows)
        line = "ear: %d call(s) on the shelf · %d with minutes · %d promises filed · last %s" % (
            n_cap, n_min, n_prom, ago(lasted) if lasted else "never")
        if off.get("off"):
            line += " · OFF by his hand (%s)" % (off.get("reason") or "no reason recorded")
        elif silent:
            line += " · no call seen in 24h"
        print(line)
        return
    print(sentence)


def say_last():
    rows = articles()
    row = newest(rows)
    state, off, pid, phase, armed = signature_block()
    if not row:
        msg = "the ear has captured nothing yet — no meeting folder on the shelf"
        print(json.dumps({"found": False, "message": msg}, indent=2) if AS_JSON else msg)
        return
    folder = row.get("folder") or ""
    for k in ("minutes_file", "transcript_file", "audio", "state", "people"):
        if row.get(k) == "-":
            row[k] = ""
    st = (row.get("state") or "").strip()
    stop = ""
    if st.startswith("stopped at"):
        stop = st
    when = row.get("when") or "?"
    dur = ""
    if armed and phase == "in-call":
        try:
            dur = ago_short(NOW - float(armed))
        except Exception:
            dur = ""
    people = row.get("people") or ""
    payload = {"found": True, "id": row.get("id"), "when": when, "title": row.get("title"),
               "folder": folder, "transcript": row.get("transcript"), "minutes": row.get("minutes"),
               "promises": row.get("promises"), "decisions": row.get("decisions"),
               "state": st or "no state recorded", "stopped_at": stop,
               "finished": bool(row.get("minutes")) and not stop,
               "people": people, "minutes_file": row.get("minutes_file") or ""}
    if AS_JSON:
        print(json.dumps(payload, ensure_ascii=False, indent=2)); return
    out = []
    out.append("last capture: %s — %s" % (when, row.get("title") or "untitled"))
    if dur:
        out.append("  how long:   %s so far (still listening)" % dur)
    elif row.get("duration"):
        out.append("  how long:   %s" % row.get("duration"))
    out.append("  who spoke:  %s" % ((people + " (named from the invitation, not from the audio)") if people
                                     else "nobody named in the record — the transcript carries no names"))
    if row.get("minutes_file"):
        out.append("  minutes:    %s" % row["minutes_file"])
    else:
        out.append("  minutes:    none yet — the ladder has not filed them")
    if stop:
        out.append("  pipeline:   STOPPED — %s" % stop)
    elif row.get("minutes"):
        out.append("  pipeline:   FINISHED — transcript · minutes · %s promise(s) filed as todos" %
                   (row.get("promises") or 0))
    elif row.get("transcript"):
        out.append("  pipeline:   STOPPED at minutes — the transcript is there, the minutes are not")
    else:
        out.append("  pipeline:   STOPPED at transcript — the capture is there, the words are not")
    print("\n".join(out))


STEPS = [
    ("transcript", "the words, beside the recording"),
    ("minutes", "the minutes, composed by the model from the transcript and the people present"),
    ("promises", "every promise the minutes carry, as a list"),
    ("todos", "every promise filed as work on the board in the same act"),
]


def say_plan():
    rows = articles()
    row = None
    if WANT_ID:
        for r in rows:
            if WANT_ID in (r.get("id") or "") or WANT_ID in (r.get("folder") or ""):
                row = r; break
    else:
        row = newest(rows)
    if not row:
        print(json.dumps({"meeting": None, "steps": [s[0] for s in STEPS]}, indent=2) if AS_JSON else
              "no meeting on the shelf — the ladder has nothing to run")
        return
    st = (row.get("state") or "").strip()
    blocked = ""
    if st.startswith("stopped at"):
        blocked = st.split("stopped at", 1)[1].split(":", 1)[0].strip()
    done = set()
    if row.get("transcript"):
        done.add("transcript")
    if row.get("minutes"):
        done.update({"minutes"})
    if int(row.get("promises") or 0) > 0:
        done.update({"promises", "todos"})
    if not blocked:
        for name, _ in STEPS:
            if name not in done:
                blocked = name
                break
    if AS_JSON:
        print(json.dumps({"meeting": row.get("id"), "state": st, "blocked_at": blocked,
                          "steps": [{"step": n, "what": w, "done": n in done} for n, w in STEPS]}, indent=2))
        return
    print("the ladder for %s (%s):" % (row.get("id"), row.get("when")))
    for i, (name, what) in enumerate(STEPS, 1):
        mark = "done" if name in done else ("STUCK" if name == blocked else "waiting")
        print("  %d. %-10s %-7s %s" % (i, name, mark, what))
    if blocked:
        print("  blocked at: %s%s" % (blocked, (" — " + st.split(":", 1)[1].strip()) if ":" in st and st.startswith("stopped") else ""))
    else:
        print("  nothing is blocked: this meeting finished the ladder")


def say_week():
    rows = articles()
    # a DATE window, not a timestamp one: a meeting on the first day of the window is
    # inside it at any hour of that day, and no daylight-saving hour can move the edge.
    cut_day = (datetime.date.today() - datetime.timedelta(days=DAYS)).isoformat()
    rows = [r for r in rows if (r.get("when") or "") >= cut_day]
    cut = datetime.datetime.strptime(cut_day, "%Y-%m-%d").astimezone().timestamp()
    starts = 0
    for line in log_lines():
        m = re.match(r"^(\d{4}-\d\d-\d\dT[\d:]+Z)\s+START edge", line)
        if m:
            ep = parse_ts(m.group(1))
            if ep and ep >= cut:
                starts += 1
    summary = {
        "days": DAYS,
        "captures": starts,
        "meetings": len(rows),
        "transcripts": sum(1 for r in rows if r.get("transcript")),
        "minutes": sum(1 for r in rows if r.get("minutes")),
        "promises": sum(int(r.get("promises") or 0) for r in rows),
        "decisions": sum(int(r.get("decisions") or 0) for r in rows),
        "stopped": sum(1 for r in rows if (r.get("state") or "").startswith("stopped at")),
        "plans": sum(int(r.get("plans") or 0) for r in rows),
    }
    if AS_JSON:
        print(json.dumps(summary, indent=2)); return
    print("the last %d days: %d capture(s) · %d meeting(s) · %d transcript(s) · %d with minutes · %d promise(s) · %d decision(s) · %d stopped · %d plan(s) touched" % (
        summary["days"], summary["captures"], summary["meetings"], summary["transcripts"],
        summary["minutes"], summary["promises"], summary["decisions"], summary["stopped"], summary["plans"]))


{"now": say_now, "last": say_last, "plan": say_plan, "week": say_week}.get(VERB, say_now)()
PY
}

# ── the self-test: fixture state, no house data touched ────────────────────
self_test() {
  local tmp rc=0 fail=0
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/snotra-what-selftest.XXXXXX")" || return 1
  export YMIR_HOME="$tmp/home" YMIR_STATE_DIR="$tmp/state" SNOTRA_WHAT_QUIET=1
  export SNOTRA_WATCH_UNIT="snotra-selftest-no-such-unit.service"   # the log, not this host, decides
  # three days old: inside the week's window, outside the 24h one — the two clocks the door reads
  local WHEN; WHEN="$(python3 -c 'import datetime;print((datetime.date.today()-datetime.timedelta(days=3)).isoformat())')"
  mkdir -p "$YMIR_STATE_DIR" "$YMIR_HOME/hodd/life/meetings/self/$WHEN-self-test"
  local M="$YMIR_HOME/hodd/life/meetings/self/$WHEN-self-test"
  cat >"$M/meeting.json" <<EOF
{"id":"$WHEN-self-test","title":"The self test call","started_at":"${WHEN}T10:00:00",
 "source":"ear","platform":"local","attendees":["Test Person","Second Person"],"state":"captured"}
EOF
  printf '# Transcript\n\nAllfather: we will send the minutes by Friday.\n' >"$M/transcript.md"
  printf '# Minutes\n\n## Decisions\n- the minutes go out on Friday\n\n## Promises\n- [ ] send the minutes · due 2026-01-05\n' >"$M/minutes.md"
  printf 'captured\n' >"$M/.state"
  # the watch state the ear itself writes, plus a decision log
  cat >"$YMIR_STATE_DIR/.snotra-detect.json" <<'EOF'
{"phase":"in-call","slug":"parec","outfile":"/tmp/x.wav","topic":"ping meeting","monitor":"","mic":"","sink":"",
 "armed_epoch":"__ARMED__","triggers":["3"],"baseline":[]}
EOF
  python3 - "$YMIR_STATE_DIR/.snotra-detect.json" <<'PY'
import json, sys, time
p = sys.argv[1]
d = json.load(open(p))
d["armed_epoch"] = str(int(time.time()) - 120)
json.dump(d, open(p, "w"))
PY
  printf '%s\n' \
    "2026-01-02T09:59:00Z watch started (poll 2s, arm 3s, grace 5s, quiet 300s @ -45 dB)" \
    "2026-01-02T10:00:00Z START edge — app 'parec' (pid 123) took the mic; pair mic='m' sink='s'; slug=parec" \
    "  Duration:     14400s max (safety cap)" >"$YMIR_STATE_DIR/.snotra-detect.log"
  local THREE_DAYS_AGO; THREE_DAYS_AGO="$(python3 -c 'import datetime;print((datetime.datetime.now()-datetime.timedelta(days=3)).astimezone().strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  printf '%s\n' "$(date +%s)" >"$YMIR_STATE_DIR/.snotra-pid"

  probe() { # <name> <expected-substring> <verb...>
    local name="$1" want="$2"; shift 2
    local out; out="$(bash "$DOOR" "$@" 2>&1)"; local rc2=$?
    if [ $rc2 -eq 0 ] && printf '%s' "$out" | grep -q -- "$want"; then
      printf '  PASS  %-18s %s\n' "$name" "$(printf '%s' "$out" | head -1 | cut -c1-96)"
    else
      printf '  FAIL  %-18s rc=%s want=%q out=%s\n' "$name" "$rc2" "$want" "$(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-140)"
      rc=1
    fi
  }
  printf 'snotra-what self-test (state: %s)\n' "$YMIR_STATE_DIR"
  probe now-armed     '^armed'                    now
  probe now-rule      'the rule that decided'      now
  probe now-since     'since '                     now
  probe now-until     'the cap ends it at'         now
  probe last-capture  "last capture: $WHEN"         last
  probe last-people   'Test Person'                last
  probe last-minutes  'minutes.md'                 last
  probe plan-steps    '1\. transcript'             plan
  probe week-counts   '1 meeting(s)'               week
  probe brief-line    'ear: 1 call'                now --brief

  # a stopped step is reported; a finished one is not
  printf 'stopped at minutes: the rail did not answer\n' >"$M/.state"
  probe stopped-last  'STOPPED — stopped at minutes: the rail did not answer' last
  probe stopped-plan  'blocked at: minutes'        plan
  if bash "$DOOR" last 2>&1 | grep -q 'FINISHED'; then
    printf '  FAIL  %-18s a stopped pipeline claimed FINISHED\n' "not-finished"; rc=1
  else printf '  PASS  %-18s a stopped pipeline does not claim FINISHED\n' "not-finished"; fi
  printf 'dispatched\n' >"$M/.state"
  probe finished-last 'FINISHED'                   last
  if bash "$DOOR" last 2>&1 | grep -q 'STOPPED'; then
    printf '  FAIL  %-18s a finished pipeline reported STOPPED\n' "not-stopped"; rc=1
  else printf '  PASS  %-18s a finished pipeline reports no stop\n' "not-stopped"; fi

  # the silence line
  python3 - "$YMIR_STATE_DIR/.snotra-detect.json" <<'PY'
import json, sys
p = sys.argv[1]
json.dump({"phase": "idle"}, open(p, "w"))
PY
  # the log as an idle watch leaves it: one armed-and-left capture, three days ago, and silence since
  printf '%s\n' \
    "2026-01-02T09:59:00Z watch started (poll 2s, arm 3s, grace 5s, quiet 300s @ -45 dB)" \
    "2026-01-02T10:00:00Z START edge — app 'parec' (pid 123) took the mic; pair mic='m' sink='s'; slug=parec" \
    "$THREE_DAYS_AGO LEAVE edge (manual leave)" \
    "$THREE_DAYS_AGO no call: no stream carries a call role" >"$YMIR_STATE_DIR/.snotra-detect.log"
  probe silence       'no call seen in 24h'        now
  probe brief-silent  'no call seen in 24h'        now --brief

  # his hand: off records the reason, now says so, the watch will refuse to arm
  probe off           'ear: off'                   off --reason "he was in a room that must not be recorded"
  probe off-recorded  'off by his hand'            now
  probe off-reason    'must not be recorded'       now
  probe on            'ear: on'                    on
  probe on-cleared    'not watching\|watching\|idle\|armed' now

  # a verb it does not know is a refusal, not a silence
  local bad; bad="$(bash "$DOOR" nonsense 2>&1)"; [ $? -ne 0 ] || true
  if [ -e "$YMIR_STATE_DIR/.snotra-off" ]; then rc=1; printf '  FAIL  %-18s off was not lifted\n' "on-cleared"; fi
  if [ $rc -eq 0 ]; then printf 'snotra-what self-test: OK\n'; else printf 'snotra-what self-test: FAILED\n'; fi
  rm -rf "$tmp"
  return $rc
}

case "$CMD" in
  --self-test|selftest) self_test; exit $? ;;
  off) do_off ;;
  on)  do_on ;;
  now|last|plan|week) read_what "$CMD" ;;
  *) usage ;;
esac
