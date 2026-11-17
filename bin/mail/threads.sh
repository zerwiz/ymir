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
#              [--evidence FILE] [--window DAYS]
#
#   (no flags)     every thread, one row each, in the columns plan 305 names
#   --lane L       only that lane (aliases: "needs you", needs_you, you-answered)
#   --json         one JSON object on one line — the face a dispatcher consumes
#   --store PATH   read another store (a fixture); defaults to the home's mail store
#   --now ISO      judge ages against this instant instead of the clock (a fixture)
#   --nudge-days N days a thread we wrote last may sit quiet before it is "waiting on
#                  them" rather than merely "answered" (default 3, plan 305 §5.2)
#   --evidence FILE what closed a conversation when a letter did not (default: the
#                  home's memory/mail/evidence.yaml, when that file exists; a named
#                  file that is not there is an error, never a silent "no evidence")
#   --window DAYS  how long a letter to the same person about something ELSE counts as
#                  a closure (default 14) — the fifth kind, always marked
#
# THE FOUR LANES (plan 305 §2.1). A thread is in exactly one of them.
#
#   closed          he marked it (a handled_at on any message), or the tail is inbound
#                   and owes nothing (the judge's own verdict: archive · record_notice ·
#                   file_invoice — a notice, an invoice, a calendar machine, a bulk
#                   sender), or we answered, they replied, and we answered again, or
#                   evidence closed it (below).
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
# THE EVIDENCE FILE — four kinds of closure, and every one names its own (2026-11-17, the
# audit of the 49). A reply is not the only way a conversation ends: the mutual NDA was
# signed on 16 October and confirmed on the 19th, and the mail still read open, because
# the lane accepted nothing but a letter. A lane that only accepts a reply marks finished
# work as debt forever. So a conversation also closes by
#
#   document  a signed or delivered artefact in the home — the PATH is named
#   meeting   a meeting record for the day in question — the record is named
#   filing    a notice that needed nothing but reading — the register row, or the reason
#   reply     computed from the store (an outbound letter after their word, answering the
#             same thread) — never declared in the file, because a claim about a letter
#             is checked against the letters
#
# THE FIFTH KIND, ALWAYS MARKED, NEVER COUNTED AS A REPLY: `answered-elsewhere`. We wrote
# to that same person inside --window days but about something else, so the subject is
# still open in substance and the row says so — `answered-elsewhere:<message id>`. It is
# a closure and a mark, never a reply: a letter about another thing does not answer this.
#
# A ROW EXISTS ONLY WHERE SOMEONE LOOKED, AND ONLY SPECIFICALLY. Every row must cite a
# path, a message id or a meeting record a reader can open. A DOCUMENT or a MEETING row
# must also narrow to a subject, a thread or a message id — one contract does not answer
# another. And a sender's DOMAIN is never evidence: a `from_domain:` key, or a bare domain
# written in `from:`, is refused outright and named on stderr. (A `filing` may speak for
# the addresses that only ever send notices; nothing else may.) That is not a style rule:
# a match on the sender's domain alone folded the *unsigned* development agreement
# (chased four times) into the signed NDA and hid it. A sender's domain is not evidence; a
# named contract is.
#
# ORDER: lane rank (needs-you · waiting-on-them · answered · closed), then oldest last
# message first — the longest-owed conversation is the first one read.
#
# THE COLUMNS. `last` is the direction of the newest message in the thread. `answered` is
# whether an outbound message came after the last inbound one. `unanswered_days` is how
# long an answer has been OWED, so it is a number only in needs-you and `-` everywhere
# else — a notice nobody must answer is not "unanswered for 21 days", it is closed.
# `evidence` names what closed it — `document:<path>`, `meeting:<record>`,
# `filing:<record>`, or `answered-elsewhere:<message id>` — and `evidence_id` is the
# message id a row cited. `--json` carries the rest (the answering message id, the
# judge's class, the subject, the correspondent, the age of the last message, the
# evidence row and the day it closed) so a dispatcher never has to re-read the store.
#
# Exit: 0 ok · 1 error (no store, unreadable store, a named evidence file that is not
# there) · 2 usage.
set -uo pipefail
VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '/^#   threads\.sh /,/^# Exit:/p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# The home is resolved, never assumed (Rule 07): one place knows where it lives.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$ROOT/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi

LANE=""; JSON=0; STORE=""; NOW=""; NUDGE=3; EVIDENCE=""; WINDOW=14
while [ $# -gt 0 ]; do case "$1" in
  -h|--help|help) usage; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  --lane) LANE="${2-}"; shift 2 ;;
  --json) JSON=1; shift ;;
  --store) STORE="${2-}"; shift 2 ;;
  --now) NOW="${2-}"; shift 2 ;;
  --nudge-days) NUDGE="${2-}"; shift 2 ;;
  --evidence) EVIDENCE="${2-}"; shift 2 ;;
  --window) WINDOW="${2-}"; shift 2 ;;
  *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac; done

case "$NUDGE" in ''|*[!0-9]*) die "--nudge-days wants a whole number of days, not '$NUDGE'" ;; esac
case "$WINDOW" in ''|*[!0-9]*) die "--window wants a whole number of days, not '$WINDOW'" ;; esac

# The home, resolved once: the store and the evidence file both live in it (Rule 07).
HOARD="${YMIR_HOARD:-}"
command -v hoard_root >/dev/null 2>&1 && hoard_root HOARD

# One store, resolved once: the flag for a fixture, the env for a caller, the home otherwise.
if [ -z "$STORE" ]; then
  STORE="${YMIR_MAIL_STORE:-}"
  if [ -z "$STORE" ]; then
    [ -n "$HOARD" ] || die "no mail store: set YMIR_HOME, pass --store PATH, or run bin/vault/hodd.sh path"
    STORE="$HOARD/memory/mail/messages.jsonl"
  fi
fi
[ -e "$STORE" ] || die "no mail store at that path"
[ -r "$STORE" ] || die "the mail store is not readable"

# The evidence file: named by the flag, else the env, else the home's own file when it is
# there. A file the CALLER named must exist — a typo must not read as "no evidence",
# because an absent file and a file whose every row was refused would otherwise look alike.
NAMED_EVIDENCE=0
if [ -n "$EVIDENCE" ]; then
  NAMED_EVIDENCE=1
elif [ -n "${YMIR_MAIL_EVIDENCE:-}" ]; then
  EVIDENCE="$YMIR_MAIL_EVIDENCE"; NAMED_EVIDENCE=1
fi
if [ -z "$EVIDENCE" ] && [ -n "$HOARD" ] && [ -e "$HOARD/memory/mail/evidence.yaml" ]; then
  EVIDENCE="$HOARD/memory/mail/evidence.yaml"
fi
if [ -n "$EVIDENCE" ]; then
  if [ ! -e "$EVIDENCE" ]; then
    [ "$NAMED_EVIDENCE" = 1 ] && die "no evidence file at that path"
    EVIDENCE=""
  fi
  if [ -n "$EVIDENCE" ] && [ ! -r "$EVIDENCE" ]; then
    die "the evidence file is not readable"
  fi
fi

YMIR_THREADS_STORE="$STORE" YMIR_THREADS_LANE="$LANE" YMIR_THREADS_JSON="$JSON" \
YMIR_THREADS_NOW="$NOW" YMIR_THREADS_NUDGE="$NUDGE" \
YMIR_THREADS_EVIDENCE="$EVIDENCE" YMIR_THREADS_WINDOW="$WINDOW" python3 - <<'PY'
import json, os, sys
from datetime import date, datetime, timezone

STORE = os.environ["YMIR_THREADS_STORE"]
LANE  = os.environ.get("YMIR_THREADS_LANE", "").strip()
JSON  = os.environ.get("YMIR_THREADS_JSON", "0") == "1"
NOW   = os.environ.get("YMIR_THREADS_NOW", "").strip()
NUDGE = int(os.environ.get("YMIR_THREADS_NUDGE", "3"))
EVIDENCE_FILE = os.environ.get("YMIR_THREADS_EVIDENCE", "").strip()
WINDOW = int(os.environ.get("YMIR_THREADS_WINDOW", "14"))

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


# ── the evidence file ─────────────────────────────────────────────────────────────────────
# Four kinds of closure that are not a letter, and a fifth that is only ever a mark. Every
# row is checked before it may close anything: it must NAME its evidence (a path, a message
# id, a meeting record a reader can open) and it must NARROW to a subject, a thread or a
# message. A sender's domain is not evidence.
EVIDENCE_KINDS = ("document", "meeting", "filing")
COMPUTED_KINDS = {
    "reply": "a reply is computed from the store — declaring one here would be a claim the letters must confirm",
    "answered-elsewhere": "answered-elsewhere is computed from the store and --window; it is marked, never declared",
}
DOMAIN_KEYS = {"from_domain", "from_domains", "domain", "domains", "sender_domain", "sender_domains"}
EVIDENCE_ROWS, EVIDENCE_REFUSED, EVIDENCE_NOTE = [], [], ""


def as_list(value):
    """A YAML list or a single scalar, as a list of non-empty strings."""
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [str(item).strip() for item in value if str(item).strip()]
    text = str(value).strip()
    return [text] if text else []


def refuse_evidence(row_id, why):
    EVIDENCE_REFUSED.append((row_id, why))
    sys.stderr.write("warning: evidence row '%s' not applied — %s\n" % (row_id, why))


def load_evidence(path):
    """Read the evidence file, keeping only the rows specific enough to close something.

    A row that cannot name what it knows is refused AND named: an unreadable row and an
    absent row must not look the same, because one of them is a mistake in the record.
    """
    global EVIDENCE_NOTE
    if not path:
        return
    try:
        import yaml
    except ImportError:
        EVIDENCE_NOTE = "PyYAML is absent, so no row was read (bin/engine/prereq-ensure.sh ensures it)"
        sys.stderr.write("warning: the evidence file was not read — %s\n" % EVIDENCE_NOTE)
        return
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            document = yaml.safe_load(handle)
    except OSError:
        EVIDENCE_NOTE = "the file could not be opened"
        sys.stderr.write("warning: the evidence file was not read — %s\n" % EVIDENCE_NOTE)
        return
    except Exception as error:   # a broken file is a finding, never a silent empty one
        EVIDENCE_NOTE = "the file does not parse as YAML (%s)" % error.__class__.__name__
        sys.stderr.write("warning: the evidence file was not read — %s\n" % EVIDENCE_NOTE)
        return
    if not isinstance(document, dict):
        EVIDENCE_NOTE = "the file holds no mapping"
        sys.stderr.write("warning: the evidence file was not read — %s\n" % EVIDENCE_NOTE)
        return
    raw_rows = document.get("closed") or []
    if not isinstance(raw_rows, list):
        EVIDENCE_NOTE = "`closed:` is not a list"
        sys.stderr.write("warning: the evidence file was not read — %s\n" % EVIDENCE_NOTE)
        return
    for number, raw in enumerate(raw_rows, 1):
        if not isinstance(raw, dict):
            refuse_evidence("<row %d>" % number, "it is not a mapping")
            continue
        row_id = str(raw.get("id") or "").strip() or "<row %d>" % number
        kind = str(raw.get("kind") or "").strip().lower()
        if kind in COMPUTED_KINDS:
            refuse_evidence(row_id, COMPUTED_KINDS[kind])
            continue
        if kind not in EVIDENCE_KINDS:
            refuse_evidence(row_id, "kind '%s' is not one of %s" % (kind or "-", " · ".join(EVIDENCE_KINDS)))
            continue
        match = raw.get("match")
        if not isinstance(match, dict):
            refuse_evidence(row_id, "it has no match: block, so what it closes is unknowable")
            continue
        domain_keys = [str(key) for key in match if str(key).strip().lower() in DOMAIN_KEYS]
        if domain_keys:
            refuse_evidence(row_id, "it matches on a sender DOMAIN (%s) — a domain is not evidence; name the message or the subject"
                            % ", ".join(domain_keys))
            continue
        senders = [item.lower() for item in as_list(match.get("from"))]
        subjects = [item.lower() for item in as_list(match.get("subject_any"))]
        thread_keys = as_list(match.get("thread_keys")) + as_list(match.get("thread_key"))
        message_ids = as_list(match.get("message_ids")) + as_list(match.get("message_id"))
        domainish = [sender for sender in senders if "@" not in sender]
        if domainish:
            refuse_evidence(row_id, "`from` names a domain (%s), not an address — a domain is not evidence"
                            % ", ".join(domainish))
            continue
        if not (senders or thread_keys or message_ids):
            refuse_evidence(row_id, "it matches on nothing: no from, no thread, no message id")
            continue
        # A filing may speak for the addresses that only ever send notices; a DOCUMENT or a
        # MEETING may not — one contract does not answer another, which is the whole lesson.
        if kind in ("document", "meeting") and not (subjects or thread_keys or message_ids):
            refuse_evidence(
                row_id,
                "it narrows to the sender alone — a %s row must name a subject, a thread or a "
                "message; a sender-based rule is how an unsigned development agreement was hidden "
                "behind a signed NDA" % kind)
            continue
        citation = str(raw.get("evidence") or "").strip()
        if not citation:
            refuse_evidence(row_id, "it names no evidence — a path, a message id or a meeting record a reader can open")
            continue
        closed_on = None
        stamp = str(raw.get("closed_on") or "").strip()
        if stamp:
            parsed = parse_at(stamp[:10] + "T00:00:00Z")
            closed_on = parsed.date() if parsed else None
        EVIDENCE_ROWS.append({
            "id": row_id,
            "kind": kind,
            "senders": senders,
            "subjects": subjects,
            "thread_keys": thread_keys,
            "message_ids": message_ids,
            "evidence": citation,
            "evidence_message": str(raw.get("evidence_message") or "").strip(),
            "closed_on": closed_on,
            "note": str(raw.get("note") or "").strip(),
        })


load_evidence(EVIDENCE_FILE)


def address_of(who):
    """The address on one party of a message, lowercased — ours and theirs read the same."""
    if not isinstance(who, dict):
        return ""
    return (who.get("email") or "").strip().lower()


def inbound_address(message):
    return address_of(message.get("from")) if (message.get("direction") or "") == "in" else ""


def evidence_for(thread_key, messages, last_at):
    """The strongest evidence row that closes this thread, or None.

    Strongest = the latest `closed_on`; a tie goes to the row written further down the
    file, so the record is read the way a person reads it. An artefact dated BEFORE the
    last inbound message cannot have answered it, so it is not evidence for this thread.
    """
    inbound_senders = {inbound_address(row) for row in messages}
    inbound_senders.discard("")
    subjects = [(row.get("subject") or "").lower() for row in messages]
    ids = {str(row.get("id") or "") for row in messages}
    last_date = last_at.date() if last_at else None
    hits = []
    for order, row in enumerate(EVIDENCE_ROWS):
        if row["thread_keys"] and thread_key not in row["thread_keys"]:
            continue
        if row["message_ids"] and not (ids & set(row["message_ids"])):
            continue
        if row["senders"] and not (inbound_senders & set(row["senders"])):
            continue
        if row["subjects"] and not any(term in subject for term in row["subjects"] for subject in subjects):
            continue
        if row["closed_on"] and last_date and row["closed_on"] < last_date:
            continue
        hits.append((row["closed_on"] or date.min, order, row))
    if not hits:
        return None
    hits.sort(key=lambda triple: (triple[0], triple[1]))
    return hits[-1][2]


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

# Every letter we sent, indexed by the address it went to: the fifth kind reads this, and
# nothing else does. A letter to the same person about another subject is a closure only
# because it is MARKED as one — never because it counts as an answer.
letters_to = {}
for row in rows:
    if (row.get("direction") or "") != "out":
        continue
    sent = parse_at(row.get("received_at")) or parse_at(row.get("ingested_at"))
    if sent is None:
        continue
    account = (row.get("account") or "").strip().lower()
    for who in (row.get("to") or []):
        email = address_of(who)
        if not email or email == account:
            continue
        letters_to.setdefault(email, []).append(
            (sent, str(row.get("id") or ""), str(row.get("thread_key") or row.get("id") or "")))
for letters in letters_to.values():
    letters.sort(key=lambda letter: (letter[0], letter[1]))


def wrote_elsewhere(thread_key, message, window):
    """We wrote to that same person inside `window` days, about something else.

    This is the fifth kind: it closes the row and it is marked `answered-elsewhere`. It is
    never counted as a reply, because a letter about another subject answered another
    subject — saying otherwise is how a lane starts lying to the person reading it.
    """
    email = inbound_address(message)
    at = parse_at(message.get("received_at")) or parse_at(message.get("ingested_at"))
    if not email or at is None:
        return None
    for sent_at, message_id, other_key in letters_to.get(email, []):
        if other_key == thread_key:
            continue
        delta = (sent_at - at).total_seconds()
        if 0 <= delta <= window * 86400:
            return {"id": message_id, "at": sent_at, "email": email}
    return None

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

    # Two more closures, both MARKED: evidence from the file (a document · a meeting · a
    # filing), and — where nothing was filed and this subject was never answered — a letter
    # to the same person about something else inside --window. Neither is ever a reply.
    evidence = None
    if lane in ("needs-you", "waiting-on-them"):
        row_hit = evidence_for(thread_key, messages, last_at)
        if row_hit is not None:
            lane, reason = "closed", row_hit["kind"]
            evidence = {
                "kind": row_hit["kind"],
                "ref": row_hit["evidence"],
                "id": row_hit["evidence_message"] or None,
                "row": row_hit["id"],
                "on": row_hit["closed_on"].isoformat() if row_hit["closed_on"] else None,
                "to": None,
                "note": row_hit["note"] or None,
            }
        elif lane == "needs-you":
            elsewhere = wrote_elsewhere(thread_key, last, WINDOW)
            if elsewhere is not None:
                lane, reason = "closed", "answered-elsewhere"
                evidence = {
                    "kind": "answered-elsewhere",
                    "ref": elsewhere["id"],
                    "id": elsewhere["id"],
                    "row": None,
                    "on": elsewhere["at"].astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
                    "to": elsewhere["email"],
                    "note": None,
                }
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
        "evidence_kind": (evidence or {}).get("kind"),
        "evidence_ref": (evidence or {}).get("ref"),
        "evidence_id": (evidence or {}).get("id"),
        "evidence_row": (evidence or {}).get("row"),
        "evidence_on": (evidence or {}).get("on"),
        "evidence_to": (evidence or {}).get("to"),
        "answered_elsewhere": reason == "answered-elsewhere",
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


def closed_with(reasons):
    return sum(1 for t in joined if t["lane"] == "closed" and t["lane_reason"] in reasons)


evidenced = closed_with(set(EVIDENCE_KINDS))
elsewhere_count = closed_with({"answered-elsewhere"})
replies = sum(1 for t in joined if t["answered"])

if JSON:
    print(json.dumps({
        "store": STORE,
        "now": NOW_AT.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "nudge_days": NUDGE,
        "lane": LANE or "",
        "threads": printed,
        "counts": counts,
        "evidence": {
            "file": EVIDENCE_FILE,
            "window_days": WINDOW,
            "rows": len(EVIDENCE_ROWS),
            "refused": [{"row": row_id, "why": why} for row_id, why in EVIDENCE_REFUSED],
            "not_read": EVIDENCE_NOTE or None,
        },
        "totals": {
            "threads": len(joined),
            "messages": len(rows),
            "unread_threads": sum(1 for t in joined if t["unread"]),
            "unread_messages": sum(1 for row in rows if "UNREAD" in (row.get("labels") or [])),
            "closed_without_a_reply": closed_with({"nothing-owed"}),
            "closed_by_evidence": evidenced,
            "closed_answered_elsewhere": elsewhere_count,
            "answered_threads": replies,
            "unreadable_rows": broken,
            "evidence_rows": len(EVIDENCE_ROWS),
            "evidence_refused": len(EVIDENCE_REFUSED),
            "window_days": WINDOW,
        },
    }, ensure_ascii=False))
else:
    print("threads.sh[%d]{thread_key,last,last_at,answered,unanswered_days,evidence,evidence_id,lane}:"
          % len(printed))
    for t in printed:
        mark = "-" if not t["evidence_kind"] else "%s:%s" % (t["evidence_kind"], t["evidence_ref"] or "-")
        print("  %s,%s,%s,%s,%s,%s,%s,%s" % (
            cell(t["thread_key"]),
            cell(t["last_direction"]),
            cell(t["last_at"] or "-"),
            cell("yes" if t["answered"] else "no"),
            cell("-" if t["unanswered_days"] is None else t["unanswered_days"]),
            cell(mark),
            cell(t["evidence_id"] or "-"),
            cell(t["lane"]),
        ))
    print("lanes[%d]{lane,threads}:" % len(shown_lanes))
    for lane in shown_lanes:
        print("  %s,%d" % (cell(lane), counts[lane]))
    print("mail: %d messages · %d threads · %d closed without a reply (nothing was owed) · "
          "%d closed by evidence (document · meeting · filing) · %d answered elsewhere "
          "(marked, never counted as a reply, within %d days) · unanswered age counts whole "
          "days since the last inbound message"
          % (len(rows), len(joined), closed_with({"nothing-owed"}), evidenced,
             elsewhere_count, WINDOW))
    if not EVIDENCE_FILE:
        print("evidence: none — no evidence file, so a reply is the only closure this run can see")
    elif EVIDENCE_NOTE:
        print("evidence: NOT READ from %s — %s" % (EVIDENCE_FILE, EVIDENCE_NOTE))
    elif EVIDENCE_REFUSED:
        print("evidence: %d row(s) applied from %s · %d refused and named above"
              % (len(EVIDENCE_ROWS), EVIDENCE_FILE, len(EVIDENCE_REFUSED)))
    else:
        print("evidence: %d row(s) applied from %s" % (len(EVIDENCE_ROWS), EVIDENCE_FILE))

if broken:
    sys.stderr.write("warning: %d unreadable row(s) in the store, first at line %d\n" % (broken, broken_at))
PY
