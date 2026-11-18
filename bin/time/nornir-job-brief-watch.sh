#!/usr/bin/env bash
# nornir-job-brief-watch.sh — if the morning brief failed or is not clean, say why and what to do.
#
# The 07:00 row publishes the brief and THEN exits 1 when a draft has aged past its
# limit, so the scheduler reports "job failed (rc=1)" over a document that exists and
# is complete. Four mornings then read the same way, and two of them read as nothing at
# all: a draft that aged, a drafts door that never shipped, a mailbox the grant refused,
# and a row that never fired. The last one is the worst — silence is what a clean day
# sounds like.
#
# So one row, five minutes later, reads the three facts that decide it and speaks once:
#   · did the 07:00 row fire, and with what exit code   (state/cron.log)
#   · does the brief file exist at all                   (svartalfaheim/<realm>/…/daily/)
#   · what does the brief's own `drafts:` line say       (the brief, where he reads it)
#
# Clean is SILENT: it records the no-op and says nothing. Anything else sends exactly
# ONE line — the reason in plain words and one drafted next act.
#
#   bin/time/nornir-job-brief-watch.sh                     # the 07:05 row
#   bin/time/nornir-job-brief-watch.sh --dry-run           # print the line, send nothing
#   bin/time/nornir-job-brief-watch.sh --now               # judge as if it were 07:05
#
# It never exits non-zero on a not-clean day, on purpose: the scheduler notifies on a
# non-zero row, so exiting 1 after speaking would send a second, dumber line. It exits
# 1 only when it could not deliver — a broken watchdog is the one thing he must hear
# twice.
#
# Exit: 0 clean (silence) or spoken (one line) · 1 could not deliver · 2 usage.
#
# Configuration, never constants (Rule 07):
#   BROKK_BRIEF_DIR              the daily-briefing's own override; same meaning here
#   BROKK_STATE_OVERRIDE         the state dir holding cron.log (the scheduler's own var)
#   BROKK_BRIEF_WATCH_WINDOW     minutes back a run stamp still counts as "this morning" (default 90)
#   BROKK_BRIEF_WATCH_NOTIFY     the notify door (default bin/notify/send.sh)
#   BROKK_BRIEF_WATCH_LAST       where the last verdict is recorded (default state/brief-watch.last)
#   BROKK_BRIEF_WATCH_CMD        the row being watched (default bin/time/nornir-job-daily-briefing.sh)
#   BROKK_BRIEF_WATCH_TODAY      the day being judged (default: today, in the house's zone)
set -u
VERSION="1.0.0"

case "${1-}" in
  -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
# No second default: the resolver above is the only one (Rule 07). A home it cannot find is a
# refusal, not a guess — a job that reads the wrong home reports a clean week it never looked at.
if [ -z "${YMIR_HOME:-}" ]; then
  printf 'error: no YMIR_HOME — the home resolver (bin/vault/hoard-lib.sh) found none\nhelp: set YMIR_HOME, or record the home with bin/vault/hodd.sh\n' >&2
  exit 1
fi

DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --now) : ;;                       # the row's ordinary mode; kept for a readable call
    *) printf 'error: unknown argument %s\nhelp: --dry-run · --now · -h · -v\n' "$a" >&2; exit 2 ;;
  esac
done

STATE="${BROKK_STATE_OVERRIDE:-}"
# A seat does not schedule the house, so a seat's state dir is not where the house's
# record lives — the scheduler refuses one by name (`*/seats/*`) and the watcher reads
# the same record the writer writes. Any other override is honoured as it stands.
case "$STATE" in
  */seats/*|"") STATE="$YMIR_HOME/state" ;;
esac
LOG="${BROKK_CRON_LOG:-$STATE/cron.log}"
WATCHED_CMD="${BROKK_BRIEF_WATCH_CMD:-bin/time/nornir-job-daily-briefing.sh}"
WINDOW="${BROKK_BRIEF_WATCH_WINDOW:-90}"
NOTIFY="${BROKK_BRIEF_WATCH_NOTIFY:-$ROOT/bin/notify/send.sh}"
LAST_RECORD="${BROKK_BRIEF_WATCH_LAST:-$STATE/brief-watch.last}"

REALM="${BROKK_REALM:-}"
if [ -z "$REALM" ] && [ -r "$YMIR_HOME/state/realm.md" ]; then
  REALM=$(head -n 1 "$YMIR_HOME/state/realm.md" 2>/dev/null | tr -d '[:space:]')
fi
if [ -z "$REALM" ] && [ -r "$ROOT/bin/skuld/realm-lib.sh" ]; then
  # shellcheck source=bin/skuld/realm-lib.sh
  . "$ROOT/bin/skuld/realm-lib.sh"
  ymir_active_realm "$ROOT" REALM
fi
REALM="${REALM:-}"

# The day he will read, from the ONE clock door (Rule 07) — never a bare `date`.
TODAY="${BROKK_BRIEF_WATCH_TODAY:-}"
if [ -z "$TODAY" ]; then
  TODAY="$(bash "$ROOT/bin/time/sol.sh" iso --plain 2>/dev/null | cut -c1-10)"
fi
TODAY="${TODAY:-$(date +%Y-%m-%d)}"

BRIEF_DIR="${BROKK_BRIEF_DIR:-$YMIR_HOME/svartalfaheim/$REALM/workspace/memory/daily}"
BRIEF_FILE="$BRIEF_DIR/$TODAY.md"

# ── 1. Did the row fire, and with what verdict? ─────────────────────────────────────
# The scheduler writes `<ts> cron run: <cmd>` before it launches the row and
# `<ts> cron FAIL rc=<n> <cmd> :: <why>` after a non-zero one — the SAME stamp on both,
# so the verdict is matched by stamp, never guessed from proximity in the log. A run
# with no FAIL beside it exited 0.
#
# The window is a distance in minutes, not a calendar date: the log stamps UTC and the
# row fires in local time, and a timezone conversion here would be a second clock. A row
# that missed yesterday's morning lands 23 hours back, which no window confuses.
read -r RUN_KIND RUN_TS RUN_RC RUN_AGE LOGSTATE RUN_WHY <<EOF
$(ROOT_Q="$ROOT" LOG_Q="$LOG" CMD_Q="$WATCHED_CMD" WIN_Q="$WINDOW" python3 - <<'PY'
import datetime, os, re, sys

log_path = os.environ["LOG_Q"]
cmd = os.environ["CMD_Q"]
window = int(os.environ["WIN_Q"])
STAMP = r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)"

if not os.path.exists(log_path):
    print("none - - - absent (the log is not there)")
    sys.exit(0)
try:
    with open(log_path, "r", errors="replace") as fh:
        lines = fh.readlines()
except OSError:
    print("none - - - unreadable (the log could not be read)")
    sys.exit(0)

run_ts = None
run_kind = "none"
run_why = "-"
fail_rc = {}
for line in lines:
    line = line.rstrip("\n")
    m = re.match(r"^" + STAMP + r" cron run: (?P<cmd>\S.*)$", line)
    if m and m.group("cmd").strip() == cmd:
        run_ts, run_kind = m.group(1), "run"
        continue
    m = re.match(r"^" + STAMP + r" cron skip \(busy\): (?P<cmd>\S.*)$", line)
    if m and m.group("cmd").strip() == cmd:
        run_ts, run_kind = m.group(1), "skip"
        continue
    m = re.match(r"^" + STAMP + r" cron FAIL rc=(?P<rc>[0-9]+) (?P<cmd>\S.*?) :: (?P<why>.*)$", line)
    if m and m.group("cmd").strip() == cmd:
        fail_rc[m.group(1)] = (m.group("rc"), m.group("why"))

if run_ts is None:
    print("none - - - ok -")
    sys.exit(0)

def epoch(stamp):
    return datetime.datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(
        tzinfo=datetime.timezone.utc).timestamp()

age = int((datetime.datetime.now(datetime.timezone.utc).timestamp() - epoch(run_ts)) // 60)
rc, why = fail_rc.get(run_ts, ("0", "-"))
print("%s %s %s %d ok %s" % (run_kind, run_ts, rc, age, (why or "-").replace("\n", " ")))
PY
)
EOF
RUN_KIND="${RUN_KIND:-none}"; RUN_TS="${RUN_TS:--}"; RUN_RC="${RUN_RC:-0}"
RUN_AGE="${RUN_AGE:--}"; LOGSTATE="${LOGSTATE:-ok}"; RUN_WHY="${RUN_WHY:--}"

# ── 2. The brief's own three facts ──────────────────────────────────────────────────
BRIEF_THERE=0; [ -r "$BRIEF_FILE" ] && BRIEF_THERE=1
DRAFTS_RAW=""
if [ "$BRIEF_THERE" = 1 ]; then
  DRAFTS_RAW="$(grep -m1 -E '^[[:space:]]*([-*] )?drafts: ' "$BRIEF_FILE" 2>/dev/null | sed -E 's/^[[:space:]]*([-*] )?drafts: //')"
fi

# ── 3. The verdict — a small named table, one row per morning ───────────────────────
VERDICT=""; REASON=""; ACT=""

say() { printf '%s' "$2" | tr '\n' ' ' | cut -c1-"${3:-240}"; }

if [ "$LOGSTATE" != "ok" ]; then
  VERDICT="rc-unknown"
  REASON="cannot tell whether the 07:00 brief ran — $LOGSTATE at $LOG"
  ACT="look at the tail of the cron log by hand, then bin/time/nornir-cron-start.sh --status"
elif [ "$RUN_KIND" = "none" ] || [ "${RUN_AGE:--1}" -gt "$WINDOW" ] 2>/dev/null; then
  VERDICT="row-missing"
  if [ "$RUN_TS" = "-" ]; then
    REASON="the 07:00 brief did not run — no run stamp for it in state/cron.log"
  else
    REASON="the 07:00 brief did not run this morning — its last run stamp is $RUN_TS (${RUN_AGE}m ago)"
  fi
  ACT="check the scheduler: bin/time/nornir-cron-start.sh --status — is the @heart row alive on this seat?"
elif [ "$BRIEF_THERE" = 0 ]; then
  VERDICT="brief-missing"
  REASON="the 07:00 row ${RUN_KIND} (rc=$RUN_RC) but wrote no brief file for $TODAY"
  ACT="read the row's own tail: the lines under its stamp in state/cron.log name the failure"
elif [ -z "$DRAFTS_RAW" ]; then
  VERDICT="no-drafts-line"
  # A brief with no drafts line was written by an OLDER shape of the 07:00 job — measured
  # 2026-11-17: every brief before that day carried none, and today's carries one. At 07:05
  # that can only mean the row ran an older tree, so the pin is the first thing to mend.
  REASON="the brief is there but carries no drafts line, so nothing can say the day is clean"
  ACT="the brief was written by an older shape of the job — the pin is stale: run bin/engine/pin-refresh.sh, then re-run the 07:00 row"
else
  case "$DRAFTS_RAW" in
    none*)
      if [ "$RUN_RC" = "0" ]; then
        VERDICT="clean"
      else
        VERDICT="rc-failed"
        REASON="the 07:00 brief row failed (rc=$RUN_RC): $RUN_WHY"
        ACT="read the row's tail in state/cron.log — the row's own last line is the evidence"
      fi ;;
    UNABLE*)
      VERDICT="unable"
      REASON="the drafts door could not read the mailbox — the grant was refused"
      ACT="re-grant the letters door: bin/mail/draft-age.sh --brief names the endpoint that refused" ;;
    SKIP*)
      case "$DRAFTS_RAW" in
        *missing*)
          VERDICT="door-missing"
          REASON="the brief could not ask the drafts door at all — it is missing, so the day cannot be called clean"
          ACT="the pin is stale — run bin/engine/pin-refresh.sh" ;;
        *)
          VERDICT="no-grant"
          REASON="the drafts door is not granted on this seat, so the brief cannot say the day is clean"
          ACT="grant the letters door: bin/mail/draft-age.sh --brief names the key that is missing" ;;
      esac ;;
    *)
      if printf '%s' "$DRAFTS_RAW" | grep -qE '^[0-9]+ of [0-9]+ older than [0-9]+ days'; then
        AGED_N="$(printf '%s' "$DRAFTS_RAW" | sed -E 's/^([0-9]+) of .*/\1/')"
        AGED_M="$(printf '%s' "$DRAFTS_RAW" | sed -E 's/^[0-9]+ of ([0-9]+) older.*/\1/')"
        AGED_D="$(printf '%s' "$DRAFTS_RAW" | sed -E 's/^[0-9]+ of [0-9]+ older than ([0-9]+) days.*/\1/')"
        VERDICT="drafts-aged"
        REASON="the brief is written, but the day is not clean: $AGED_N of $AGED_M drafts are older than $AGED_D days"
        ACT="send or discard those $AGED_N — bin/mail/draft-age.sh names them, and a draft does not age out on its own"
      elif [ "$RUN_RC" != "0" ]; then
        VERDICT="rc-failed"
        REASON="the 07:00 brief row failed (rc=$RUN_RC): $RUN_WHY"
        ACT="read the row's tail in state/cron.log — the row's own last line is the evidence"
      else
        VERDICT="clean"                # drafts that are unwritten but fresh: the day is clean
      fi ;;
  esac
fi

REASON="$(say r "$REASON" 240)"

# ── 4. Speak once, or record the no-op ──────────────────────────────────────────────
record() {  # <verdict> <what was said or not>
  printf '%s %s — %s\n' "$(bash "$ROOT/bin/time/sol.sh" utc --plain 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" \
    >"$LAST_RECORD" 2>/dev/null || printf 'brief-watch: cannot write %s (non-fatal)\n' "$LAST_RECORD" >&2
}

if [ "$VERDICT" = "clean" ]; then
  record clean "nothing said"
  [ "$DRY" = 1 ] && printf 'brief-watch[1]{verdict,said}: "clean","nothing — the day is clean and the brief is written"\n'
  exit 0
fi

LINE="brief: $REASON — next: $ACT"

if [ "$DRY" = 1 ]; then
  printf 'brief-watch[3]{verdict,line,dry}:\n  "%s","%s","1"\n' "$VERDICT" "$LINE"
  exit 0
fi

TARGET=""
[ "$BRIEF_THERE" = 1 ] && TARGET="file:$BRIEF_FILE"

if [ -x "$NOTIFY" ] || [ -r "$NOTIFY" ]; then
  if bash "$NOTIFY" --source cron --severity HIGH --key "brief-watch:$TODAY" \
       --message "$LINE" ${TARGET:+--target "$TARGET"} >/dev/null 2>&1; then
    record "$VERDICT" "said: $REASON"
    # The ledger keeps the events; the well keeps the lesson (Rule 03 · Rule 20).
    if [ -r "$ROOT/bin/records/runes-append.sh" ]; then
      # shellcheck source=bin/records/runes-append.sh
      . "$ROOT/bin/records/runes-append.sh"
      runes_append "nornir" "brief.watch_spoke" ${REALM:+--realm "$REALM"} \
        --message "$VERDICT — $REASON" >/dev/null 2>&1 || true
    fi
    printf 'brief-watch: %s — one line sent\n' "$VERDICT"
    exit 0
  fi
fi

# The watchdog could not speak. That is the one failure worth exiting non-zero over:
# the scheduler's own notice will carry it, which is exactly right — a watcher that
# cannot talk must not be silent.
record "$VERDICT" "COULD NOT DELIVER: $REASON"
printf 'brief-watch: could not deliver through %s — %s\n' "$NOTIFY" "$LINE" >&2
exit 1
