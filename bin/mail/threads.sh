#!/usr/bin/env bash
# threads.sh — the join: one row per conversation, and the lane that conversation is in.
#
# WHY THIS EXISTS (plan 305 §2.1, phase 1): the store records mail beautifully — 226
# messages, both directions, a thread_key on every row — and answers neither of the two
# questions that matter: "did we answer this?" and "what is this thread waiting on?".
# Nothing joins an inbound message to the outbound one that answered it. This door does
# that join and nothing else, so one command can say, per conversation: which way the
# last message went, when it was, whether an outbound reply came after the last inbound,
# how many days it has gone unanswered, and which of four lanes it sits in.
#
# IT READS. It never writes — not the store, not a state file, not the ledger, not a
# directory. Read state is a snapshot in the labels today (plan 305 §2.1) and derived
# state belongs to the door that OWNS it; a reader that writes is how two records come
# to disagree. The only side effect of this file is text on stdout.
#
#   threads.sh [--lane needs-you|answered|waiting-on-them|closed] [--json]
#              [--store PATH] [--now ISO] [--nudge-days N]
#
#   (no flags)     every thread, one row each, in the six columns plan 305 names
#   --lane L       only that lane (aliases: "needs you", needs_you, you-answered)
#   --json         one JSON object on one line — the face a dispatcher consumes
#   --store PATH   read another store (a fixture); defaults to the home's mail store
#   --now ISO      judge ages against this instant instead of the clock (a fixture)
#   --nudge-days N days a thread we wrote last may sit quiet before it is "waiting on
#                  them" rather than merely "answered" (default 3, plan 305 §5.2)
#
# THE FOUR LANES (plan 305 §2.1). A thread is in exactly one of them.
#
#   closed          he marked it (a handled_at on any message), or the tail is inbound
#                   and owes nothing (the judge's own verdict: archive · record_notice ·
#                   file_invoice — a notice, an invoice, a calendar machine, a bulk
#                   sender), or we answered, they replied, and we answered again.
#   needs-you       inbound tail, and it owes an answer: not auto-submitted, and the
#                   judge did not call it nothing-owed. This is the only lane that speaks.
#   answered        outbound tail, quieter than --nudge-days: we answered; the silence
#                   is the reward, so nothing is listed at him.
#   waiting-on-them outbound tail, quiet for --nudge-days or more: we wrote last and
#                   nothing has come back — the lane a nudge is raised from, once.
#
# "answered" vs "waiting-on-them" is the one reading plan 305 leaves open. §2.1 says
# "we answered and the other side has not written since" and "we wrote last", which are
# the same fact; §2's own flow diagram separates them by time (answered → silence,
# waiting → a nudge after N days). So the split here is AGE, and N defaults to the three
# days §2.4 proposes.
#
# ORDER: lane rank (needs-you · waiting-on-them · answered · closed), then oldest last
# message first — the longest-owed conversation is the first one read.
#
# THE COLUMNS. `last` is the direction of the newest message in the thread. `answered` is
# whether an outbound message came after the last inbound one. `unanswered_days` is how
# long an answer has been OWED, so it is a number only in needs-you and `-` everywhere
# else — a notice nobody must answer is not "unanswered for 21 days", it is closed.
# `--json` carries the rest (the answering message id, the judge's class, the subject,
# the correspondent, the age of the last message) so a dispatcher never has to re-read
# the store to say who and what.
#
# Exit: 0 ok · 1 error (no store, unreadable store) · 2 usage.
set -uo pipefail
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '12,45p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# The home is resolved, never assumed (Rule 07): one place knows where it lives.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$ROOT/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi

LANE=""; JSON=0; STORE=""; NOW=""; NUDGE=3
while [ $# -gt 0 ]; do case "$1" in
  -h|--help|help) usage; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  --lane) LANE="${2-}"; shift 2 ;;
  --json) JSON=1; shift ;;
  --store) STORE="${2-}"; shift 2 ;;
  --now) NOW="${2-}"; shift 2 ;;
  --nudge-days) NUDGE="${2-}"; shift 2 ;;
  *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac; done

case "$NUDGE" in ''|*[!0-9]*) die "--nudge-days wants a whole number of days, not '$NUDGE'" ;; esac

# One store, resolved once: the flag for a fixture, the env for a caller, the home otherwise.
if [ -z "$STORE" ]; then
  STORE="${YMIR_MAIL_STORE:-}"
  if [ -z "$STORE" ]; then
    HOARD="${YMIR_HOARD:-}"
    command -v hoard_root >/dev/null 2>&1 && hoard_root HOARD
    [ -n "$HOARD" ] || die "no mail store: set YMIR_HOME, pass --store PATH, or run bin/vault/hodd.sh path"
    STORE="$HOARD/memory/mail/messages.jsonl"
  fi
fi
[ -e "$STORE" ] || die "no mail store at that path"
[ -r "$STORE" ] || die "the mail store is not readable"

YMIR_THREADS_STORE="$STORE" YMIR_THREADS_LANE="$LANE" YMIR_THREADS_JSON="$JSON" \
YMIR_THREADS_NOW="$NOW" YMIR_THREADS_NUDGE="$NUDGE" python3 - <<'PY'
import json, os, sys
from datetime import datetime, timezone

STORE = os.environ["YMIR_THREADS_STORE"]
LANE  = os.environ.get("YMIR_THREADS_LANE", "").strip()
JSON  = os.environ.get("YMIR_THREADS_JSON", "0") == "1"
NOW   = os.environ.get("YMIR_THREADS_NOW", "").strip()
NUDGE = int(os.environ.get("YMIR_THREADS_NUDGE", "3"))

LANES     = ["needs-you", "answered", "waiting-on-them", "closed"]
LANE_RANK = {l: i for i, l in enumerate(LANES)}
# The plan's own words, and the brief's, are all accepted: one lane, one name.
ALIASES = {
    "needs-you": "needs-you", "needs_you": "needs-you", "needs you": "needs-you",
    "needsyou": "needs-you", "needs": "needs-you",
    "answered": "answered", "you-answered": "answered", "you_answered": "answered",
    "you answered": "answered",
    "waiting-on-them": "waiting-on-them", "waiting_on_them": "waiting-on-them",
    "waiting on them": "waiting-on-them", "waiting": "waiting-on-them",
    "closed": "closed", "done": "closed",
}
# The judge's verdicts that mean "nothing here asks a human" (plan 305 §2.2: the class is
# the evidence). A row with no verdict falls back to the class it was given.
NOTHING_OWED_ACTIONS = {"archive", "record_notice", "file_invoice"}
NOTHING_OWED_CLASSES = {"notice", "invoice"}


def norm_lane(value):
    key = (value or "").strip().lower()
    return ALIASES.get(key)


if LANE:
    wanted = norm_lane(LANE)
    if not wanted:
        sys.stderr.write("error: --lane wants one of %s, not '%s'\n" % (" · ".join(LANES), LANE))
        raise SystemExit(2)
    LANE = wanted


def parse_at(value):
    """An ISO instant, or None. Naive stamps are read as UTC; a broken stamp is None."""
    if not value:
        return None
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        at = datetime.fromisoformat(text)
    except ValueError:
        return None
    return at if at.tzinfo else at.replace(tzinfo=timezone.utc)


if NOW:
    NOW_AT = parse_at(NOW)
    if NOW_AT is None:
        sys.stderr.write("error: --now wants an ISO instant (2026-11-16T12:00:00Z), not '%s'\n" % NOW)
        raise SystemExit(2)
else:
    NOW_AT = datetime.now(timezone.utc)


def nothing_owed(message):
    """Does this message ask nobody for anything? The verdict first, then the class."""
    action = (message.get("proposed_action") or "").strip()
    if action:
        return action in NOTHING_OWED_ACTIONS
    if (message.get("auto_submitted") or "").strip():
        return True
    return (message.get("classification") or "").strip() in NOTHING_OWED_CLASSES


def party(message, which):
    if which == "from":
        who = message.get("from") or {}
    else:
        to = message.get("to") or []
        who = to[0] if to and isinstance(to[0], dict) else {}
    if not isinstance(who, dict):
        return ""
    return (who.get("name") or "").strip() or (who.get("email") or "").strip()


def counterpart(message):
    """The other end of the conversation — ours is the account, theirs is everyone else."""
    account = (message.get("account") or "").strip().lower()
    if (message.get("direction") or "") == "in":
        return party(message, "from")
    for who in (message.get("to") or []):
        if not isinstance(who, dict):
            continue
        email = (who.get("email") or "").strip().lower()
        if email and email != account:
            return (who.get("name") or "").strip() or email
    return ""


def key_of(message, index):
    """The order a conversation is read in: time, then inbound before outbound at a tie,
    then id — so the same store always gives the same join."""
    at = parse_at(message.get("received_at")) or parse_at(message.get("ingested_at"))
    direction = 0 if (message.get("direction") or "") == "in" else 1
    return (at or datetime.min.replace(tzinfo=timezone.utc), direction, str(message.get("id") or ""), index)


rows, broken, broken_at = [], 0, None
with open(STORE, "r", encoding="utf-8", errors="replace") as handle:
    for number, line in enumerate(handle, 1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            broken += 1
            broken_at = broken_at or number
            continue
        if isinstance(row, dict):
            rows.append(row)
        else:
            broken += 1
            broken_at = broken_at or number

threads = {}
for index, row in enumerate(rows):
    threads.setdefault(str(row.get("thread_key") or row.get("id") or ""), []).append((index, row))

joined = []
for thread_key, members in threads.items():
    members.sort(key=lambda pair: key_of(pair[1], pair[0]))
    messages = [row for _, row in members]
    last = messages[-1]
    inbound = [i for i, row in enumerate(messages) if (row.get("direction") or "") == "in"]
    outbound = [i for i, row in enumerate(messages) if (row.get("direction") or "") == "out"]
    last_direction = "in" if (last.get("direction") or "") == "in" else "out"
    last_at = parse_at(last.get("received_at")) or parse_at(last.get("ingested_at"))
    handled = any((row.get("handled_at") or "") for row in messages)
    # We answered and they replied and we answered again: an inbound message strictly
    # between two outbound ones, with the outbound one holding the tail.
    answered_twice = bool(
        last_direction == "out" and len(outbound) >= 2
        and any(outbound[0] < i < outbound[-1] for i in inbound)
    )
    answered = last_direction == "out"
    answering = None
    if answered:
        # The outbound message that answered the last inbound, if there was one to answer.
        answering = last
        for i in reversed(outbound):
            if inbound and i > inbound[-1]:
                answering = messages[i]
                break

    if handled:
        lane, reason = "closed", "handled"
    elif answered_twice:
        lane, reason = "closed", "answered-twice"
    elif last_direction == "in" and nothing_owed(last):
        lane, reason = "closed", "nothing-owed"
    elif last_direction == "in":
        lane, reason = "needs-you", "owed"
    else:
        age = None if last_at is None else int(max(0, (NOW_AT - last_at).total_seconds()) // 86400)
        if age is not None and age < NUDGE:
            lane, reason = "answered", "answered"
        else:
            lane, reason = "waiting-on-them", "quiet"

    # How long an answer has been owed is a fact only where an answer IS owed: needs-you.
    # A notice nobody must answer is not "unanswered for 21 days", it is closed.
    unanswered_days = None
    if lane == "needs-you" and last_at is not None:
        unanswered_days = int(max(0, (NOW_AT - last_at).total_seconds()) // 86400)
    age_days = None if last_at is None else int(max(0, (NOW_AT - last_at).total_seconds()) // 86400)

    joined.append({
        "thread_key": thread_key,
        "lane": lane,
        "lane_reason": reason,
        "last_direction": last_direction,
        "last_at": (last_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z") if last_at else None),
        "answered": answered,
        "answered_by": (str(answering.get("id") or "") if answered and answering is not None else None),
        "answered_at": (
            (parse_at(answering.get("received_at")) or parse_at(answering.get("ingested_at")))
            .astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
            if answered and answering is not None
            and (parse_at(answering.get("received_at")) or parse_at(answering.get("ingested_at")))
            else None
        ),
        "unanswered_days": unanswered_days,
        "age_days": age_days,
        "messages": len(messages),
        "inbound": len(inbound),
        "outbound": len(outbound),
        "unread": any("UNREAD" in (row.get("labels") or []) for row in messages),
        "nothing_owed": nothing_owed(last) if last_direction == "in" else False,
        "classification": (last.get("classification") or ""),
        "subject": (last.get("subject") or ""),
        "correspondent": counterpart(last),
        "last_id": str(last.get("id") or ""),
    })

joined.sort(key=lambda t: (
    LANE_RANK[t["lane"]],
    t["last_at"] or "",
    t["thread_key"],
))

# Under a filter the block holds the lane asked for and no fake zeros: a zero that means
# "not asked for" is the false green this house has paid for twice.
printed = [t for t in joined if not LANE or t["lane"] == LANE]
shown_lanes = [LANE] if LANE else LANES
counts = {lane: 0 for lane in shown_lanes}
for t in printed:
    counts[t["lane"]] += 1


def cell(value):
    """One TOON cell: a quoted string, with the quote characters that would break it."""
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', "'")


if JSON:
    print(json.dumps({
        "store": STORE,
        "now": NOW_AT.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "nudge_days": NUDGE,
        "lane": LANE or "",
        "threads": printed,
        "counts": counts,
        "totals": {
            "threads": len(joined),
            "messages": len(rows),
            "unread_threads": sum(1 for t in joined if t["unread"]),
            "unread_messages": sum(1 for row in rows if "UNREAD" in (row.get("labels") or [])),
            "closed_without_a_reply": sum(1 for t in joined if t["lane"] == "closed" and t["lane_reason"] == "nothing-owed"),
            "unreadable_rows": broken,
        },
    }, ensure_ascii=False))
else:
    print("threads.sh[%d]{thread_key,last,last_at,answered,unanswered_days,lane}:" % len(printed))
    for t in printed:
        print("  %s,%s,%s,%s,%s,%s" % (
            cell(t["thread_key"]),
            cell(t["last_direction"]),
            cell(t["last_at"] or "-"),
            cell("yes" if t["answered"] else "no"),
            cell("-" if t["unanswered_days"] is None else t["unanswered_days"]),
            cell(t["lane"]),
        ))
    print("lanes[%d]{lane,threads}:" % len(shown_lanes))
    for lane in shown_lanes:
        print("  %s,%d" % (cell(lane), counts[lane]))
    owed = sum(1 for t in joined if t["lane"] == "closed" and t["lane_reason"] == "nothing-owed")
    print("mail: %d messages · %d threads · %d closed without a reply (nothing was owed) · "
          "unanswered age counts whole days since the last inbound message"
          % (len(rows), len(joined), owed))

if broken:
    sys.stderr.write("warning: %d unreadable row(s) in the store, first at line %d\n" % (broken, broken_at))
PY
