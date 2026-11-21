#!/usr/bin/env bash
# send.sh — THE HOTLINE: one door a system calls when it has something to say.
#
#   bin/notify/send.sh --source <errand|garmr|snotra|cron|people|trello|ward|engine> \
#       --severity INFO|MEDIUM|HIGH|CRITICAL --message "one line" \
#       [--key <stable-id>] [--record <id>] [--target <kind>:<value>] [--ask] [--dry-run] [--print-line] [--no-telegram] \
#       [--button "<emoji> <label>|<prompt>" …] [--buttons "<CML payload>"]
#
#   bin/notify/send.sh --answered <alert-id> [--on <machine>]       an agent answered: the raw post is not needed
#   bin/notify/send.sh --silence <group> [--hours 24] [--on <machine>]   no line from this group for a while
#   bin/notify/send.sh --flush <alert-id> | --flush-due              post what no agent answered in time
#
# --button / --buttons are the CONTROLS a phone line carries (2026-11-17): a nudge that cannot be acted
# on is a nag, so a line that leaves a decision travels with its buttons. The grammar is NOT restated
# here — bin/notify/telegram-buttons.sh owns it — and `--format reply-markup` renders the same cells as
# the Bot API's own inline_keyboard, because this door posts straight to the Bot API with no session
# behind it. `--buttons` takes a CML matrix the caller already laid into rows (a fence of three per
# draft), so its layout survives instead of being rechunked. A button that could not render is a
# REFUSAL (exit 2), never a message that arrives as prose.
#
# --target is plan 230: every message carries something to OPEN (file: · plan: · pr: · yl:), and
# the desktop leg hands it to bin/notify/open-target.sh, which owns both the toast and the click.
# A message with no target is still allowed — it says `(no link)` in its own title.
#
# Why one door (plan 100): every subsystem used to invent its own spout — a desktop popup,
# a file, or nothing at all — and 16 of 20 events spoke to nobody. This is the one sentence
# they all say.
#
# What it does, in order, and what it does NOT do:
#   Runes      always — the record must not depend on delivery
#   the arm    MEDIUM+ — a wake appended to this machine's .wake-queue, so a live session sees it between turns
#   the owner  HIGH+ — THE OWNER ROAD (2026-11-21): the line is handed to the arm holder that OWNS the source
#              (the machine named in the line, or the home's config/notify-owners.conf) through
#              bin/fleet/arm-send.sh, so it arrives as that agent's TURN. Its arm dead → the heart's arm, and
#              the line says so. The agent answers the operator in the chat; the raw post below waits.
#   desktop    MEDIUM+ — systems/snotra/services/tts-lease/ymir-say.sh (quiet hours apply to MEDIUM only)
#   the pocket HIGH+   — bin/ward/garmr/notify.py, which owns the ladder, budget and quiet hours
#   telegram   HIGH+ or --ask — the Bot API directly, so it works with NO session running. When an agent
#              was handed the line, the raw post is HELD for YMIR_NOTIFY_ANSWER_MIN minutes (default 10)
#              and posted only if no agent answered (--answered) — a silent fleet still pages him.
#
# WHY THE OWNER ROAD (2026-11-21). The Allfather: *"The cron are still not triggering the chat … We must be
# sending in to the chat wrong."* A bot's own post never comes back to any session as a turn — the Bot API does
# not deliver bot messages to bots — so the chat showed the line and no agent was engaged. And the arm leg only
# wrote to THIS machine's queue, so a dev machine's alert woke a dev machine's arm, dead for three hours.
#
# Dedupe and collapse live HERE, once: one line per (source, class, machine) per hour — CRITICAL too — and
# the next line carries the count of the repeats it stood for. The group key never carries a changing number:
# a stamp segment in --key (an hour, a date) and the digits of an auto-keyed message are folded away, because
# a key that changes every hour is not a key (the hound said the same thing 36 times in 9 hours).
#
# Exit: 0 delivered or deliberately suppressed (the report says which) · 1 nothing delivered
# and the Rune could not be written either · 2 usage.
set -u
VERSION="1.1.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }

SOURCE=""; SEVERITY="MEDIUM"; MESSAGE=""; KEY=""; RECORD=""; TARGET=""; ASK=0; DRY=0; NO_TG=0; PRINT_LINE=0
BUTTONS_CML=""; BUTTON_SPECS=()
MODE="send"; MODE_ARG=""; ON=""; HOURS=24
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --severity) SEVERITY="${2:-}"; shift 2 ;;
    --message) MESSAGE="${2:-}"; shift 2 ;;
    --key) KEY="${2:-}"; shift 2 ;;
    --record) RECORD="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --button) BUTTON_SPECS+=("${2:-}"); shift 2 ;;
    --buttons) BUTTONS_CML="${2:-}"; shift 2 ;;
    --ask) ASK=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --print-line) PRINT_LINE=1; shift ;;
    --no-telegram) NO_TG=1; shift ;;
    --answered) MODE=answered; MODE_ARG="${2:-}"; shift 2 ;;
    --silence) MODE=silence; MODE_ARG="${2:-}"; shift 2 ;;
    --flush) MODE=flush; MODE_ARG="${2:-}"; shift 2 ;;
    --flush-due) MODE=flush-due; shift ;;
    --hours) HOURS="${2:-}"; shift 2 ;;
    --on) ON="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

ME="$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')"
STATE_DIR="$HOME_R/state/notify"
APPROVALS="$STATE_DIR/approvals"
STATE_FILE="$STATE_DIR/state.json"
PENDING="$STATE_DIR/pending"
FLEET_REG="${YMIR_FLEET_REGISTRY:-$HOME_R/hodd/data/fleet.json}"
ANSWER_MIN="${YMIR_NOTIFY_ANSWER_MIN:-10}"
mkdir -p "$STATE_DIR" "$PENDING" 2>/dev/null || true

# ── the fleet's own road to another machine (the same registry arm-send.sh reads) ──
fleet_road() {  # <machine> → user@tailnet, or nothing
  python3 - "$FLEET_REG" "$1" <<'PY' 2>/dev/null
import json, sys
h = (json.load(open(sys.argv[1])).get("hosts") or {}).get(sys.argv[2]) or {}
if h.get("user") and h.get("tailnet"): print(f"{h['user']}@{h['tailnet']}")
PY
}
fleet_heart() {
  [ -n "${YMIR_NOTIFY_HEART:-}" ] && { printf '%s' "$YMIR_NOTIFY_HEART"; return; }
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("heart") or "")' "$FLEET_REG" 2>/dev/null
}

# ── the small verbs: answered · silence · flush. --on runs them where the alert was raised. ──
if [ "$MODE" != send ] && [ -n "$ON" ] && [ "$ON" != "$ME" ]; then
  r="$(fleet_road "$ON")"
  [ -n "$r" ] || { printf 'error: no road to %s in %s\n' "$ON" "$FLEET_REG" >&2; exit 2; }
  args=("--$MODE"); [ -n "$MODE_ARG" ] && args+=("$MODE_ARG"); [ "$MODE" = silence ] && args+=(--hours "$HOURS")
  q=""; for a in "${args[@]}"; do q="$q $(printf '%q' "$a")"; done
  exec ssh -o BatchMode=yes -o ConnectTimeout=6 "$r" \
    "bash -lc 'd=\${YMIR_RUNTIME_DIR:-\$HOME/ymir-runtime}; [ -f \$d/bin/notify/send.sh ] || d=\$HOME/ymir; cd \$d && bash bin/notify/send.sh$(printf '%s' "$q" | sed "s/'/'\\\\''/g")'"
fi

# ── telegram, the one place this door posts to the Bot API ──────────────────────
SAID_TG=0
tg_post() {  # <text> <markup-or-empty> <who-label>
  local text="$1" markup="$2"
  if [ "${YMIR_NOTIFY_VAULT:-1}" = 1 ]; then
    eval "$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -E '^export (TELEGRAM|SKIRNIR_TELEGRAM)_(BOT_TOKEN|OWNER_ID|ALERT_CHAT)=')"
  fi
  # the alarm room is NOT the conversation: a dedicated chat if one is configured,
  # posted by the assistant's own bot (the one that is an admin there).
  if [ -n "${TELEGRAM_ALERT_CHAT:-}" ]; then
    TELEGRAM_OWNER_ID="$TELEGRAM_ALERT_CHAT"
    [ -n "${SKIRNIR_TELEGRAM_BOT_TOKEN:-}" ] && TELEGRAM_BOT_TOKEN="$SKIRNIR_TELEGRAM_BOT_TOKEN"
  fi
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_OWNER_ID:-}" ] || return 1
  local margs=()
  [ -n "$markup" ] && margs=(-d "reply_markup=$markup")
  if curl -s -m 10 -o /dev/null -w '%{http_code}' \
      "${TELEGRAM_API_BASE:-https://api.telegram.org}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_OWNER_ID}" \
      --data-urlencode "text=${text}" \
      "${margs[@]}" \
      -d "disable_web_page_preview=true" 2>/dev/null | grep -q '^200$'; then
    SAID_TG=1
    # plan 261: what the house said on Telegram is a row in the communications record
    python3 "$ROOT/bin/records/comms.py" record --channel telegram --direction out \
      --who "$([ -n "${TELEGRAM_ALERT_CHAT:-}" ] && echo 'the alarm room' || echo 'the Allfather')" \
      --thread "$TELEGRAM_OWNER_ID" --project "${3:-notify}" --text "${text}" >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

# A held raw post: posted when its time is up and no agent answered; gone when one did.
flush_one() {  # <alert-id> [force]
  local f="$PENDING/$1.json"
  [ -f "$f" ] || return 0
  if [ "${2:-}" != force ]; then
    python3 -c 'import json,sys,time; sys.exit(0 if float(json.load(open(sys.argv[1])).get("due",0)) <= time.time() else 1)' "$f" 2>/dev/null || return 0
  fi
  local text markup source
  text="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["line"] + " — no agent answered in %s min (%s)" % (d.get("wait_min","?"), d.get("handed","")))' "$f" 2>/dev/null)"
  markup="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("markup",""))' "$f" 2>/dev/null)"
  source="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("source","notify"))' "$f" 2>/dev/null)"
  # Claim it first, so two flushers never post the same line twice.
  mv -f "$f" "$f.posting" 2>/dev/null || return 0
  if tg_post "$text" "$markup" "$source"; then
    rm -f "$f.posting"
    bash "$ROOT/bin/records/runes-append.sh" "$source" notify --message "unanswered after the wait, posted raw: $1" >/dev/null 2>&1 || true
    printf 'flushed\t%s\tposted\n' "$1"
  else
    mv -f "$f.posting" "$f" 2>/dev/null || true
    printf 'flushed\t%s\tFAILED — telegram did not take it; kept for the next flush\n' "$1"
    return 1
  fi
}
flush_due() {
  local f id
  for f in "$PENDING"/*.json; do
    [ -f "$f" ] || continue
    id="$(basename "$f" .json)"
    flush_one "$id" >/dev/null 2>&1 || true
  done
}

case "$MODE" in
  answered)
    [ -n "$MODE_ARG" ] || { printf 'error: --answered needs the alert id\n' >&2; exit 2; }
    if [ -f "$PENDING/$MODE_ARG.json" ]; then
      mkdir -p "$STATE_DIR/answered"; mv -f "$PENDING/$MODE_ARG.json" "$STATE_DIR/answered/$MODE_ARG.json"
      bash "$ROOT/bin/records/runes-append.sh" notify notify --message "answered by an agent: $MODE_ARG" >/dev/null 2>&1 || true
      printf 'answered\t%s\tthe raw post is withdrawn\n' "$MODE_ARG"
    else
      printf 'answered\t%s\tnothing was waiting (already posted, already answered, or another machine)\n' "$MODE_ARG"
    fi
    exit 0 ;;
  silence)
    [ -n "$MODE_ARG" ] || { printf 'error: --silence needs the group the alert named\n' >&2; exit 2; }
    case "$HOURS" in ''|*[!0-9]*) printf 'error: --hours takes a whole number\n' >&2; exit 2 ;; esac
    GROUP="$MODE_ARG" HOURS="$HOURS" STATE_FILE="$STATE_FILE" python3 - <<'PY'
import json, os, time
p = os.environ["STATE_FILE"]
try: s = json.load(open(p))
except Exception: s = {}
until = time.time() + int(os.environ["HOURS"]) * 3600
s.setdefault("silenced", {})[os.environ["GROUP"]] = until
json.dump(s, open(p, "w"))
print("silenced\t%s\tuntil %s" % (os.environ["GROUP"], time.strftime("%Y-%m-%d %H:%M", time.localtime(until))))
PY
    bash "$ROOT/bin/records/runes-append.sh" notify notify --message "silenced for ${HOURS}h: $MODE_ARG" >/dev/null 2>&1 || true
    exit 0 ;;
  flush)
    [ -n "$MODE_ARG" ] || { printf 'error: --flush needs the alert id\n' >&2; exit 2; }
    flush_one "$MODE_ARG"; exit $? ;;
  flush-due)
    flush_due; exit 0 ;;
esac

[ -n "$SOURCE" ] || { printf 'error: --source is required\nhelp: errand | garmr | snotra | cron | people | trello | ward | engine\n' >&2; exit 2; }
[ -n "$MESSAGE" ] || { printf 'error: --message is required\n' >&2; exit 2; }
case "$SEVERITY" in INFO|MEDIUM|HIGH|CRITICAL) ;; *) printf 'error: severity must be INFO|MEDIUM|HIGH|CRITICAL\n' >&2; exit 2 ;; esac

# ── the controls, rendered by the one door that knows the grammar ──────────────
# A button that cannot render must not be sent at all: the Bot API silently accepts a reply_markup it
# cannot show, which is how a wall of prose arrives looking like a decision with no controls.
MARKUP=""
MARKUP_LABELS=()
if [ -n "$BUTTONS_CML" ] || [ ${#BUTTON_SPECS[@]} -gt 0 ]; then
  _btn_args=(emit --format reply-markup --allow-many)
  if [ -n "$BUTTONS_CML" ]; then
    _btn_args+=(--payload "$BUTTONS_CML")
  else
    _btn_args+=(--per-row "${BUTTON_ROW:-3}")
    for _spec in "${BUTTON_SPECS[@]}"; do _btn_args+=(--button "$_spec"); done
  fi
  if ! MARKUP="$(bash "$ROOT/bin/notify/telegram-buttons.sh" "${_btn_args[@]}" 2>&1)"; then
    printf 'error: the buttons were refused — %s\nhelp: each button is "<emoji> <label>|<prompt>"; see bin/notify/telegram-buttons.sh\n' "$MARKUP" >&2
    exit 2
  fi
  while IFS= read -r _lbl; do [ -n "$_lbl" ] && MARKUP_LABELS+=("$_lbl"); done \
    < <(printf '%s' "$MARKUP" | python3 -c 'import json,sys
for row in json.load(sys.stdin).get("inline_keyboard",[]):
    for c in row: print(c.get("text",""))' 2>/dev/null)
fi

# ── WHICH MACHINE SAID IT (2026-11-20) ────────────────────────────────────────
# The Allfather: *"Make alarm lines name the machine they came from — starting with the cron notifier and the
# garmr and skirnir senders — so a dev machine's failure does not read as the heart's."* Measured the same day:
# a dev machine's cron failures (a sweep the heart does not even schedule) arrived in the same chat as the
# heart's, indistinguishable, and the operator read a burst from three machines as one machine failing.
# The tag is the SENDER's machine, resolved once and carried on every line; a relay may name another with
# YMIR_NOTIFY_HOST.
HOST_TAG="${YMIR_NOTIFY_HOST:-$ME}"
[ -n "$HOST_TAG" ] || HOST_TAG="an unnamed machine"
LINE="[${HOST_TAG} · ${SOURCE}/${SEVERITY}] ${MESSAGE}"

# A person, or a test, may ask what the line IS without delivering it: the same construction, printed once.
if [ "$PRINT_LINE" = 1 ]; then printf '%s\n' "$LINE"; exit 0; fi

# THE ARM'S QUEUE IS THE ONE THE ARM READS. It used to be restated here as `state/.wake-queue`
# while the arm and `bin/seat/lock-ask.sh` drain `<home>/state/.wake-queue` — two queues, so every
# notify was delivered "to the arm" into a file nothing reads (measured 2026-11-07: notify wrote 1.3 KB
# at state while the live queue held 6.2 KB of asks and no verdicts). Resolved, never restated.
WAKE_QUEUE=""
if declare -f hoard_state_dir >/dev/null 2>&1; then hoard_state_dir _wq_sd && [ -n "${_wq_sd:-}" ] && WAKE_QUEUE="$_wq_sd/.wake-queue"; fi
[ -n "${WAKE_QUEUE:-}" ] || WAKE_QUEUE="$HOME_R/state/.wake-queue"

# A held raw post whose wait is over goes out now, whoever calls next: a scheduler that died must not
# swallow the page it was holding.
[ "$DRY" = 0 ] && flush_due

# ── dedupe + collapse, decided once ────────────────────────────────────────────
# Prints: verdict <TAB> group <TAB> repeats-since-the-last-line
IFS=$'\t' read -r DECISION GROUP REPEATS < <(SEVERITY="$SEVERITY" SOURCE="$SOURCE" KEY="$KEY" MESSAGE="$MESSAGE" \
  HOST_TAG="$HOST_TAG" STATE_FILE="$STATE_FILE" DRY="$DRY" python3 - <<'PY'
import hashlib, json, os, re, time
state_file = os.environ["STATE_FILE"]
now = time.time()
try:
    state = json.load(open(state_file))
except Exception:
    state = {}
key, source, severity = os.environ["KEY"], os.environ["SOURCE"], os.environ["SEVERITY"]
host, message = os.environ["HOST_TAG"], os.environ["MESSAGE"]
# A VERDICT IS A JUDGEMENT, NOT CHATTER — never collapsed into "more than N events this hour".
# Measured 2026-11-07: the ninth review event of the hour was folded into that line, so a REFUSE
# reached the operator as a count. Keys `report:*` and `review:*` are records and always send whole
# (identical keys are still deduped — the same verdict twice is not news).
is_record = key.startswith("report:") or key.startswith("review:")
# THE GROUP NEVER CARRIES A CHANGING NUMBER (2026-11-21). A stamp segment in an explicit key (an hour
# 2026112019, a date 2026-11-21, an epoch) is folded away; an auto key hashes the message with its
# digits folded, so "heartbeat 25895s old" and "heartbeat 26795s old" are the same alarm.
# Only a REAL stamp shape folds (rework of PR #861): 20YYMMDD with an optional HH, MM, SS; a 10-digit
# epoch; an ISO date or time. A bare run of digits is an identity — garmr keys each alert per process as
# `garmr:{title}:{pid}`, and a 7-digit pid folded as a "stamp" silenced a second process for an hour.
# An ISO stamp carries colons, so it is lifted from the whole key before the key is split on ":".
STAMP = re.compile(r"^(20\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(\d{2}){0,3}|1\d{9})$")
ISO = re.compile(r"\d{4}-\d{2}-\d{2}([T ]\d{2}(:\d{2}){0,2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?)?")
if key:
    group = key if is_record else ":".join(
        s for s in ISO.sub("", key).split(":") if s and not STAMP.match(s))
else:
    folded = re.sub(r"\d+", "#", message)
    group = source + ":" + hashlib.sha256(f"{source}|{folded}".encode()).hexdigest()[:16]
group = f"{host}/{group}"
seen = {k: v for k, v in (state.get("seen") or {}).items() if now - float(v) < 7 * 86400}
counts = {k: [t for t in v if now - float(t) < 3600] for k, v in (state.get("counts") or {}).items()}
repeats = {k: int(v) for k, v in (state.get("repeats") or {}).items() if k in seen}
silenced = {k: v for k, v in (state.get("silenced") or {}).items() if float(v) > now}
verdict = "send"
if group in silenced:
    verdict = "silenced"
elif group in seen and now - float(seen[group]) < 3600:
    # One line per group per hour — CRITICAL included. The hound's CRITICAL used to skip this test
    # entirely, which is how one silent watcher said the same line every 15 minutes for 9 hours.
    verdict = "duplicate"
elif severity != "CRITICAL" and not is_record and len(counts.get(source, [])) >= 8:
    verdict = "collapse"
n = repeats.get(group, 0)
if os.environ.get("DRY") != "1":
    if verdict in ("duplicate", "silenced"):
        repeats[group] = n + 1
    else:
        seen[group] = now
        repeats[group] = 0
        counts.setdefault(source, []).append(now)
    state.update(seen=seen, counts=counts, repeats=repeats, silenced=silenced)
    json.dump(state, open(state_file, "w"))
print(f"{verdict}\t{group}\t{n}")
PY
)
DECISION="${DECISION:-send}"; GROUP="${GROUP:-}"; REPEATS="${REPEATS:-0}"

if [ "$DECISION" = "collapse" ]; then
  MESSAGE="more than 8 ${SOURCE} events this hour — see the record"
  LINE="[${HOST_TAG} · ${SOURCE}/${SEVERITY}] ${MESSAGE}"
  DECISION="send"
fi
# The line that ends an hour of silence carries the count of what it stood for.
if [ "$DECISION" = "send" ] && [ "${REPEATS:-0}" -gt 0 ] 2>/dev/null; then
  LINE="$LINE (repeated ${REPEATS}× since the last line)"
fi

SAID_RUNE=0; SAID_ARM=0; SAID_DESKTOP=0; SAID_PHONE=0; SAID_OWNER=0; OWNER_TO="-"; ALERT_ID="-"; TG_STATE=0

# ── Runes: always, even for a suppressed message (the record is not delivery) ──
if [ "$DRY" = 0 ]; then
  if [ "$DECISION" = "duplicate" ] || [ "$DECISION" = "silenced" ]; then
    bash "$ROOT/bin/records/runes-append.sh" "$SOURCE" notify \
      --message "suppressed ($DECISION ${GROUP}): ${MESSAGE}" >/dev/null 2>&1 && SAID_RUNE=1
  else
    bash "$ROOT/bin/records/runes-append.sh" "$SOURCE" notify \
      --message "$LINE$([ -n "$TARGET" ] && printf ' (opens %s)' "$TARGET")$([ ${#MARKUP_LABELS[@]} -gt 0 ] && printf ' (%d buttons)' "${#MARKUP_LABELS[@]}")" >/dev/null 2>&1 && SAID_RUNE=1
  fi
fi

# ── the owner road: hand the line to the agent that owns it, as a TURN ────────
# Who owns a source: the home's config/notify-owners.conf (`<source> <machine>`; `*` for the rest;
# `self` = the machine in the line; `off` = no owner road for that source), else the machine in the line.
owner_for() {
  local conf="$HOME_R/config/notify-owners.conf" o=""
  if [ -r "$conf" ]; then
    o="$(awk -v s="$SOURCE" '$1 ~ /^#/ || NF < 2 {next} $1 == s {print $2; f=1; exit} $1 == "*" && !d {d=$2} END {if (!f && d) print d}' "$conf")"
  fi
  case "$o" in ""|self) printf '%s' "$HOST_TAG" ;; *) printf '%s' "$o" ;; esac
}
owner_road() {
  local owner heart text tail arm_send rc
  arm_send="${YMIR_NOTIFY_ARM_SEND:-$ROOT/bin/fleet/arm-send.sh}"
  owner="$(owner_for)"
  [ "$owner" = off ] && return 1
  ALERT_ID="$(printf '%s|%s' "$GROUP" "$(date +%s%N)" | sha256sum | cut -c1-10)"
  tail="look into it, then answer the Allfather in ONE telegram_message with what you found and three buttons — 🔎 look (show the evidence) · 🔧 fix (mend it) · 🔕 silence for a day (bin/notify/send.sh --silence '${GROUP}' --on ${HOST_TAG}); then close it: bin/notify/send.sh --answered ${ALERT_ID} --on ${HOST_TAG}. Unanswered in ${ANSWER_MIN} min, the raw line goes to the chat."
  text="ALERT ${ALERT_ID} ${LINE}${RECORD:+ · record $RECORD} — $tail"
  YMIR_NOTIFY_INNER=1 timeout "${YMIR_NOTIFY_ARM_TIMEOUT:-30}" bash "$arm_send" "$owner" "$text" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then OWNER_TO="$owner"; return 0; fi
  heart="$(fleet_heart)"
  if [ -n "$heart" ] && [ "$heart" != "$owner" ]; then
    text="ALERT ${ALERT_ID} (the owner ${owner}'s arm did not answer — handed to the heart) ${LINE}${RECORD:+ · record $RECORD} — $tail"
    YMIR_NOTIFY_INNER=1 timeout "${YMIR_NOTIFY_ARM_TIMEOUT:-30}" bash "$arm_send" "$heart" "$text" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      OWNER_TO="$heart (the heart; ${owner} did not answer)"
      LINE="$LINE (owner ${owner}'s arm did not answer — handed to the heart)"
      return 0
    fi
  fi
  OWNER_TO="nobody (${owner}${heart:+ and the heart $heart} did not answer)"
  return 1
}

# The raw post waits for the agent; a scheduler outside this process posts it if nobody answers.
hold_raw_post() {
  local secs=$(( ANSWER_MIN * 60 ))
  ID="$ALERT_ID" LINE="$LINE${RECORD:+ · record $RECORD}" MARKUP="$MARKUP" SOURCE="$SOURCE" WAIT="$ANSWER_MIN" \
  HANDED="handed to $OWNER_TO" PFILE="$PENDING/$ALERT_ID.json" python3 - <<'PY'
import json, os, time
e = os.environ
json.dump({"id": e["ID"], "line": e["LINE"], "markup": e["MARKUP"], "source": e["SOURCE"],
           "wait_min": e["WAIT"], "handed": e["HANDED"], "created": time.time(),
           "due": time.time() + int(e["WAIT"]) * 60}, open(e["PFILE"], "w"))
PY
  [ "${YMIR_NOTIFY_FLUSH_SCHEDULE:-1}" = 1 ] || return 0
  if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --quiet --collect --on-active="${secs}s" \
       --setenv=YMIR_HOME="$HOME_R" bash "$SELF" --flush "$ALERT_ID" >/dev/null 2>&1; then
    return 0
  fi
  setsid nohup bash -c 'sleep "$1"; bash "$2" --flush "$3"' _ "$secs" "$SELF" "$ALERT_ID" </dev/null >/dev/null 2>&1 &
}

if [ "$DECISION" = "send" ]; then
  HOUR=$(date +%H)
  QUIET=0
  case "$HOUR" in 23|00|01|02|03|04|05|06) QUIET=1 ;; esac

  # ── the owner: HIGH+, as a turn of the agent that can act ───────────────────
  if { [ "$SEVERITY" = "HIGH" ] || [ "$SEVERITY" = "CRITICAL" ]; } && [ "$ASK" = 0 ] && [ "$DRY" = 0 ] \
     && [ "${YMIR_NOTIFY_INNER:-0}" != 1 ] && [ "${YMIR_NOTIFY_OWNER_ROAD:-1}" = 1 ]; then
    owner_road && SAID_OWNER=1
  fi

  # ── the arm: a wake the live session drains ─────────────────────────────────
  # Not twice: when the owner road already handed this line to THIS machine's arm, that was the wake.
  if [ "$SEVERITY" != "INFO" ] && [ "$DRY" = 0 ] && [ "$OWNER_TO" != "$ME" ]; then
    printf '%s notify %s %s %s%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SOURCE" "$SEVERITY" "$MESSAGE" \
      "${RECORD:+ (record $RECORD)}" >> "$WAKE_QUEUE" 2>/dev/null && SAID_ARM=1
  fi

  # ── an approval: the message becomes a question a click can answer ─────────
  APPROVAL_ID=""
  if [ "$ASK" = 1 ] && [ "$DRY" = 0 ]; then
    mkdir -p "$APPROVALS" 2>/dev/null || true
    APPROVAL_ID="$(printf '%s' "$GROUP$(date +%s)" | sha256sum | cut -c1-12)"
    APPROVAL_ID="$APPROVAL_ID" APPROVAL_SRC="$SOURCE" APPROVAL_SEV="$SEVERITY" \
    APPROVAL_Q="$MESSAGE" APPROVAL_REC="$RECORD" APPROVALUES="$APPROVALS" python3 - <<'INNER'
import json, os, time
path = os.path.join(os.environ["APPROVALUES"], os.environ["APPROVAL_ID"] + ".json")
json.dump({"id": os.environ["APPROVAL_ID"], "source": os.environ["APPROVAL_SRC"],
           "severity": os.environ["APPROVAL_SEV"], "question": os.environ["APPROVAL_Q"],
           "record": os.environ["APPROVAL_REC"],
           "asked_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "decision": None}, open(path, "w"))
INNER
  fi

  # ── the desktop: MEDIUM+, but not at 03:00 for a MEDIUM ────────────────────
  if [ "$SEVERITY" != "INFO" ] && [ "$DRY" = 0 ]; then
    if [ "$QUIET" = 1 ] && [ "$SEVERITY" = "MEDIUM" ]; then
      :
    else
      if [ -n "$APPROVAL_ID" ]; then
        bash "$ROOT/systems/snotra/services/tts-lease/ymir-say.sh" "$MESSAGE" --exec "$ROOT/bin/notify/approve.sh $APPROVAL_ID" \
          ${TARGET:+--target "$TARGET"} >/dev/null 2>&1 && SAID_DESKTOP=1
      else
        bash "$ROOT/systems/snotra/services/tts-lease/ymir-say.sh" "$MESSAGE" \
          ${TARGET:+--target "$TARGET"} >/dev/null 2>&1 && SAID_DESKTOP=1
      fi
    fi
  fi

  # ── the pocket: HIGH+ (notify.py owns the ladder and its own quiet hours) ──
  if [ "$SEVERITY" = "HIGH" ] || [ "$SEVERITY" = "CRITICAL" ]; then
    if [ "$DRY" = 0 ]; then
      GARMR_STATE_DIR="$HOME_R/state/garmr" python3 "$ROOT/bin/ward/garmr/notify.py" \
        --severity "$SEVERITY" --line "$MESSAGE" >/dev/null 2>&1 && SAID_PHONE=1
    fi
  fi

  # ── telegram: HIGH+ or --ask, and it works with NO session (Bot API) ───────
  if [ "$NO_TG" = 0 ] && { [ "$SEVERITY" = "HIGH" ] || [ "$SEVERITY" = "CRITICAL" ] || [ "$ASK" = 1 ]; }; then
    if [ "$QUIET" = 1 ] && [ "$SEVERITY" = "MEDIUM" ] && [ "$ASK" = 0 ]; then
      :
    elif [ "$DRY" = 0 ]; then
      if [ "$SAID_OWNER" = 1 ]; then
        # An agent holds it now: its answer is what reaches the chat. The raw line waits as the record.
        hold_raw_post && TG_STATE="held"
      else
        tg_post "${LINE}${RECORD:+ · record $RECORD}" "$MARKUP" "$SOURCE" && TG_STATE=1
      fi
    fi
  fi
fi

printf 'notify[1]{decision,source,severity,rune,arm,desktop,pocket,telegram}:\n'
printf '  "%s","%s","%s","%s","%s","%s","%s","%s"\n' \
  "$DECISION" "$SOURCE" "$SEVERITY" "$SAID_RUNE" "$SAID_ARM" "$SAID_DESKTOP" "$SAID_PHONE" "$TG_STATE"
printf 'owner[1]{alert,handed_to,group,repeats}:\n'
printf '  "%s","%s","%s","%s"\n' "$ALERT_ID" "${OWNER_TO//\"/\'}" "$GROUP" "$REPEATS"
# The controls are part of the answer: the record says how many buttons the line carried.
if [ ${#MARKUP_LABELS[@]} -gt 0 ]; then
  printf 'buttons[%d]{label}:\n' "${#MARKUP_LABELS[@]}"
  for _lbl in "${MARKUP_LABELS[@]}"; do printf '  "%s"\n' "${_lbl//\"/\'}"; done
fi

# A message nobody heard is a failure — except a deliberate duplicate or silence, which is the point.
if [ "$DECISION" = "duplicate" ] || [ "$DECISION" = "silenced" ]; then exit 0; fi
_heard="$SAID_RUNE$SAID_ARM$SAID_DESKTOP$SAID_PHONE$SAID_OWNER"
[ "$TG_STATE" != 0 ] && _heard="${_heard}1"
if [ "$SEVERITY" != "INFO" ] && [ -z "${_heard//0/}" ] && [ "$DRY" = 0 ]; then
  printf 'notify: NOT DELIVERED — no leg answered\nhelp: bin/notify/send.sh --dry-run to see the policy, then check ymir-say.sh and the vault grant\n' >&2
  exit 1
fi
exit 0
