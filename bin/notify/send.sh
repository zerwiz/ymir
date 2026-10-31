#!/usr/bin/env bash
# send.sh — THE HOTLINE: one door a system calls when it has something to say.
#
#   bin/notify/send.sh --source <errand|garmr|snotra|cron|people|trello|ward|engine> \
#       --severity INFO|MEDIUM|HIGH|CRITICAL --message "one line" \
#       [--key <stable-id>] [--record <id>] [--ask] [--dry-run] [--no-telegram]
#
# Why one door (plan 100): every subsystem used to invent its own spout — a desktop popup,
# a file, or nothing at all — and 16 of 20 events spoke to nobody. This is the one sentence
# they all say.
#
# What it does, in order, and what it does NOT do:
#   Runes      always — the record must not depend on delivery
#   the arm    MEDIUM+ — a wake appended to .wake-queue, so a live session sees it between turns
#   desktop    MEDIUM+ — systems/snotra/services/tts-lease/ymir-say.sh (quiet hours apply to MEDIUM only)
#   the pocket HIGH+   — bin/ward/garmr/notify.py, which owns the ladder, budget and quiet hours
#   telegram   HIGH+ or --ask — the Bot API directly, so it works with NO session running
#
# Dedupe and collapse live HERE, once: the same --key inside the window is one message, and a
# source louder than the collapse limit becomes one summary line. A channel that cries wolf
# gets muted, and a muted channel is a dead one.
#
# Exit: 0 delivered or deliberately suppressed (the report says which) · 1 nothing delivered
# and the Rune could not be written either · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }

SOURCE=""; SEVERITY="MEDIUM"; MESSAGE=""; KEY=""; RECORD=""; ASK=0; DRY=0; NO_TG=0
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --severity) SEVERITY="${2:-}"; shift 2 ;;
    --message) MESSAGE="${2:-}"; shift 2 ;;
    --key) KEY="${2:-}"; shift 2 ;;
    --record) RECORD="${2:-}"; shift 2 ;;
    --ask) ASK=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --no-telegram) NO_TG=1; shift ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$SOURCE" ] || { printf 'error: --source is required\nhelp: errand | garmr | snotra | cron | people | trello | ward | engine\n' >&2; exit 2; }
[ -n "$MESSAGE" ] || { printf 'error: --message is required\n' >&2; exit 2; }
case "$SEVERITY" in INFO|MEDIUM|HIGH|CRITICAL) ;; *) printf 'error: severity must be INFO|MEDIUM|HIGH|CRITICAL\n' >&2; exit 2 ;; esac

[ -n "$KEY" ] || KEY="$(printf '%s|%s' "$SOURCE" "$MESSAGE" | sha256sum | cut -c1-16)"
STATE_DIR="$HOME_R/hodd/state/notify"
APPROVALS="$STATE_DIR/approvals"
STATE_FILE="$STATE_DIR/state.json"
WAKE_QUEUE="$HOME_R/hodd/state/.wake-queue"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# ── dedupe + collapse, decided once ────────────────────────────────────────────
DECISION="$(SEVERITY="$SEVERITY" SOURCE="$SOURCE" KEY="$KEY" STATE_FILE="$STATE_FILE" python3 - <<'PY'
import json, os, time
state_file = os.environ["STATE_FILE"]
now = time.time()
try:
    state = json.load(open(state_file))
except Exception:
    state = {}
seen = {k: v for k, v in (state.get("seen") or {}).items() if now - float(v) < 7 * 86400}
counts = {k: [t for t in v if now - float(t) < 3600] for k, v in (state.get("counts") or {}).items()}
key, source, severity = os.environ["KEY"], os.environ["SOURCE"], os.environ["SEVERITY"]
verdict = "send"
if severity != "CRITICAL":
    if key in seen and now - float(seen[key]) < 3600:
        verdict = "duplicate"
    elif len(counts.get(source, [])) >= 8:
        verdict = "collapse"
state["seen"] = seen
if verdict == "send":
    state["seen"][key] = now
    counts.setdefault(source, []).append(now)
state["counts"] = counts
json.dump(state, open(state_file, "w"))
print(verdict)
PY
)"

LINE="[${SOURCE}/${SEVERITY}] ${MESSAGE}"
SAID_RUNE=0; SAID_ARM=0; SAID_DESKTOP=0; SAID_PHONE=0; SAID_TG=0

if [ "$DECISION" = "collapse" ] && [ "$SEVERITY" != "CRITICAL" ]; then
  MESSAGE="more than 8 ${SOURCE} events this hour — see the record"
  LINE="[${SOURCE}/${SEVERITY}] ${MESSAGE}"
  DECISION="send"
fi

# ── Runes: always, even for a suppressed message (the record is not delivery) ──
if [ "$DRY" = 0 ]; then
  if [ "$DECISION" = "duplicate" ]; then
    bash "$ROOT/bin/records/runes-append.sh" "$SOURCE" notify \
      --message "suppressed (duplicate ${KEY}): ${MESSAGE}" >/dev/null 2>&1 && SAID_RUNE=1
  else
    bash "$ROOT/bin/records/runes-append.sh" "$SOURCE" notify --message "$LINE" >/dev/null 2>&1 && SAID_RUNE=1
  fi
fi

if [ "$DECISION" = "send" ]; then
  HOUR=$(date +%H)
  QUIET=0
  case "$HOUR" in 23|00|01|02|03|04|05|06) QUIET=1 ;; esac

  # ── the arm: a wake the live session drains ─────────────────────────────────
  if [ "$SEVERITY" != "INFO" ] && [ "$DRY" = 0 ]; then
    printf '%s notify %s %s %s%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SOURCE" "$SEVERITY" "$MESSAGE" \
      "${RECORD:+ (record $RECORD)}" >> "$WAKE_QUEUE" 2>/dev/null && SAID_ARM=1
  fi

  # ── an approval: the message becomes a question a click can answer ─────────
  APPROVAL_ID=""
  if [ "$ASK" = 1 ] && [ "$DRY" = 0 ]; then
    mkdir -p "$APPROVALS" 2>/dev/null || true
    APPROVAL_ID="$(printf '%s' "$KEY$(date +%s)" | sha256sum | cut -c1-12)"
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
        bash "$ROOT/systems/snotra/services/tts-lease/ymir-say.sh" "$MESSAGE" --exec "$ROOT/bin/notify/approve.sh $APPROVAL_ID" >/dev/null 2>&1 && SAID_DESKTOP=1
      else
        bash "$ROOT/systems/snotra/services/tts-lease/ymir-say.sh" "$MESSAGE" >/dev/null 2>&1 && SAID_DESKTOP=1
      fi
    fi
  fi

  # ── the pocket: HIGH+ (notify.py owns the ladder and its own quiet hours) ──
  if [ "$SEVERITY" = "HIGH" ] || [ "$SEVERITY" = "CRITICAL" ]; then
    if [ "$DRY" = 0 ]; then
      GARMR_STATE_DIR="$HOME_R/hodd/state/garmr" python3 "$ROOT/bin/ward/garmr/notify.py" \
        --severity "$SEVERITY" --line "$MESSAGE" >/dev/null 2>&1 && SAID_PHONE=1
    fi
  fi

  # ── telegram: HIGH+ or --ask, and it works with NO session (Bot API) ───────
  if [ "$NO_TG" = 0 ] && { [ "$SEVERITY" = "HIGH" ] || [ "$SEVERITY" = "CRITICAL" ] || [ "$ASK" = 1 ]; }; then
    if [ "$QUIET" = 1 ] && [ "$SEVERITY" = "MEDIUM" ] && [ "$ASK" = 0 ]; then
      :
    elif [ "$DRY" = 0 ]; then
      eval "$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -E '^export (TELEGRAM|SKIRNIR_TELEGRAM)_(BOT_TOKEN|OWNER_ID|ALERT_CHAT)=')"
      # the alarm room is NOT the conversation: a dedicated chat if one is configured,
      # posted by the assistant's own bot (the one that is an admin there).
      if [ -n "${TELEGRAM_ALERT_CHAT:-}" ]; then
        TELEGRAM_OWNER_ID="$TELEGRAM_ALERT_CHAT"
        [ -n "${SKIRNIR_TELEGRAM_BOT_TOKEN:-}" ] && TELEGRAM_BOT_TOKEN="$SKIRNIR_TELEGRAM_BOT_TOKEN"
      fi
      if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_OWNER_ID:-}" ]; then
        if curl -s -m 10 -o /dev/null -w '%{http_code}' \
          "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          --data-urlencode "chat_id=${TELEGRAM_OWNER_ID}" \
          --data-urlencode "text=${LINE}${RECORD:+ · record $RECORD}" \
          -d "disable_web_page_preview=true" 2>/dev/null | grep -q '^200$'; then
          SAID_TG=1
        fi
      fi
    fi
  fi
fi

printf 'notify[1]{decision,source,severity,rune,arm,desktop,pocket,telegram}:\n'
printf '  "%s","%s","%s","%s","%s","%s","%s","%s"\n' \
  "$DECISION" "$SOURCE" "$SEVERITY" "$SAID_RUNE" "$SAID_ARM" "$SAID_DESKTOP" "$SAID_PHONE" "$SAID_TG"

# A message nobody heard is a failure — except a deliberate duplicate, which is the point.
if [ "$DECISION" = "duplicate" ]; then exit 0; fi
if [ "$SEVERITY" != "INFO" ] && [ "$SAID_RUNE$SAID_ARM$SAID_DESKTOP$SAID_PHONE$SAID_TG" = "00000" ] && [ "$DRY" = 0 ]; then
  printf 'notify: NOT DELIVERED — no leg answered\nhelp: bin/notify/send.sh --dry-run to see the policy, then check ymir-say.sh and the vault grant\n' >&2
  exit 1
fi
exit 0
