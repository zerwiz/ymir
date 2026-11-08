#!/usr/bin/env bash
# ledger.sh — the one mail record: what went out, what came in, and when.
#
# WHY THIS EXISTS: the house could say what it had SENT (an approval record) and what it had READ
# (the desk's store), but not, in one place, when a letter went out and to whom. An approval is an
# ACT, not a record of the letter; a message in the store is an ARRIVAL, not a conversation. This
# door keeps the conversation.
#
# It is append-only (Rule 06): a row is never edited, a correction is a new row that names the old
# one. The record lives in the HOME, never in the repo — who we wrote to and what about is private.
#
#   ledger.sh out --to A[,B] --subject S [--gmail ID] [--approval AP] [--attachments N] [--record ID]
#   ledger.sh in  [--limit N]          # fold the desk's store into the same view (read-only)
#   ledger.sh tail [N]                 # both directions, newest first (default 20)
#   ledger.sh digest [--days N]        # counts per day, both directions
#   ledger.sh self-test                # proves append-only, and that a row cannot be rewritten
#
# Exit: 0 ok · 1 error · 2 usage.
set -eu
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# The home is resolved, never assumed (Rule 07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$ROOT/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
HOARD="${YMIR_HOARD:-}"
command -v hoard_root >/dev/null 2>&1 && hoard_root HOARD
[ -n "$HOARD" ] || die "no hoard resolved — set YMIR_HOME, or run bin/vault/hodd.sh path"
MAIL_DIR="${YMIR_MAIL_DIR:-$HOARD/memory/mail}"
LEDGER="${YMIR_MAIL_LEDGER:-$MAIL_DIR/ledger.jsonl}"
STORE="${YMIR_MAIL_STORE:-$MAIL_DIR/messages.jsonl}"
mkdir -p "$MAIL_DIR"

now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
one_line() { printf '%s' "${1-}" | tr '\t\r\n' '   ' | cut -c1-400; }
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;; esac
CMD="${1-}"; shift || true

append_row() {  # append_row <json>  — one write, one newline, never a rewrite
  printf '%s\n' "$1" >> "$LEDGER"
}

cmd_out() {
  local to="" subject="" gid="" approval="" attaches=0 record=""
  while [ $# -gt 0 ]; do case "$1" in
    --to) to=${2-}; shift 2 ;;
    --subject) subject=${2-}; shift 2 ;;
    --gmail) gid=${2-}; shift 2 ;;
    --approval) approval=${2-}; shift 2 ;;
    --attachments) attaches=${2-}; shift 2 ;;
    --record) record=${2-}; shift 2 ;;
    *) die "out: unknown flag $1" ;;
  esac; done
  [ -n "$to" ] || die "out: --to is required"
  [ -n "$subject" ] || die "out: --subject is required"
  local row
  row="$(python3 - "$(now_iso)" "$(one_line "$to")" "$(one_line "$subject")" "$gid" "$approval" "$attaches" "$record" <<'PY'
import json, sys
ts, to, subject, gid, approval, attaches, record = sys.argv[1:8]
print(json.dumps({
    "ts": ts, "direction": "out", "to": to, "from": "house", "subject": subject,
    "gmail_id": gid or None, "approval": approval or None,
    "attachments": int(attaches or 0), "record": record or None,
}, ensure_ascii=False))
PY
)"
  append_row "$row"
  printf 'ledger[2]{direction,rows,at}:\n  "out","%s","%s"\n' "$(wc -l < "$LEDGER" | tr -d ' ')" "$(now_iso)"
}

# The desk's store is the arrival record. This never writes to it; it only reads what Gná kept.
cmd_in() {
  local limit=0
  while [ $# -gt 0 ]; do case "$1" in --limit) limit=${2-}; shift 2 ;; *) die "in: unknown flag $1" ;; esac; done
  [ -f "$STORE" ] || { printf 'ledger[2]{direction,rows,note}:\n  "in","0","no store at %s yet"\n' "$STORE"; return 0; }
  python3 - "$STORE" "$limit" <<'PY'
import json, sys

def who(value):
    """A person, however the store wrote it: a string, a dict, or a list of dicts."""
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return value.get("email") or value.get("name") or ""
    if isinstance(value, list):
        return ", ".join(who(v) for v in value if v)
    return ""

path, limit = sys.argv[1], int(sys.argv[2] or 0)
rows = []
for line in open(path, encoding='utf-8', errors='replace'):
    line = line.strip()
    if not line:
        continue
    try:
        m = json.loads(line)
    except ValueError:
        continue
    rows.append({
        "ts": m.get("received_at") or m.get("ts") or m.get("ingested_at") or "",
        "direction": "in",
        "from": who(m.get("from")),
        "to": who(m.get("to")) or m.get("account") or "",
        "subject": (m.get("subject") or "")[:200],
        "gmail_id": m.get("id") or m.get("message_id"),
    })
if limit:
    rows = rows[-limit:]
print(f'ledger[2]{{direction,rows,store}}:')
print(f'  "in","{len(rows)}","{path}"')
for r in rows[-20:]:
    print(f'  "{r["ts"]}","{r["from"][:40]}","{r["subject"][:60]}"')
PY
}

cmd_tail() {
  local n="${1:-20}"
  python3 - "$LEDGER" "$STORE" "$n" <<'PY'
import json, sys

def who(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return value.get("email") or value.get("name") or ""
    if isinstance(value, list):
        return ", ".join(who(v) for v in value if v)
    return ""

ledger, store, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
rows = []
for path, direction_default in ((ledger, "out"), (store, "in")):
    try:
        handle = open(path, encoding="utf-8", errors="replace")
    except OSError:
        continue
    for line in handle:
        line = line.strip()
        if not line:
            continue
        try:
            m = json.loads(line)
        except ValueError:
            continue
        direction = m.get("direction") or direction_default
        if direction == "out":
            person = who(m.get("to"))
        else:
            person = who(m.get("from"))
        rows.append({
            "ts": m.get("ts") or m.get("received_at") or m.get("ingested_at") or "",
            "dir": direction,
            "who": person,
            "subject": (m.get("subject") or "")[:78],
            "gmail_id": m.get("gmail_id") or m.get("id") or m.get("message_id") or "",
        })
# One message, one row. Both the store and this ledger may name the same letter — the store when the
# importer reads the sent folder, this ledger at the moment of sending. Dedupe on the message id, and
# where there is none, on direction + moment + subject.
seen = set()
unique = []
for r in rows:
    key = (r["dir"], r.get("gmail_id") or "", r["ts"], r["subject"])
    if key in seen:
        continue
    seen.add(key)
    unique.append(r)
rows = unique
rows.sort(key=lambda r: r["ts"])
rows = rows[-n:]
print("mail[3]{when,direction,who,subject}:")
for r in rows:
    print(f'  "{str(r["ts"])[:20]}","{r["dir"]}","{str(r["who"])[:38]}","{r["subject"]}"')
PY
}

cmd_digest() {
  local days=7
  while [ $# -gt 0 ]; do case "$1" in --days) days=${2-}; shift 2 ;; *) die "digest: unknown flag $1" ;; esac; done
  python3 - "$LEDGER" "$STORE" "$days" <<'PY'
import collections, json, sys, datetime
ledger, store, days = sys.argv[1], sys.argv[2], int(sys.argv[3])
counts = collections.Counter()
for path, default in ((ledger, "out"), (store, "in")):
    try:
        handle = open(path, encoding="utf-8", errors="replace")
    except OSError:
        continue
    for line in handle:
        try:
            m = json.loads(line)
        except ValueError:
            continue
        ts = str(m.get("ts") or m.get("received_at") or m.get("ingested_at") or "")[:10]
        if len(ts) != 10:
            continue
        counts[(ts, m.get("direction") or default)] += 1
recent = sorted({d for d, _ in counts})[-days:]
print(f"digest[3]{{day,out,in}}:")
for day in recent:
    print(f'  "{day}","{counts[(day, "out")]}","{counts[(day, "in")]}"')
print(f"totals[2]{{out,in}}:\n  \"{sum(v for (d, k), v in counts.items() if k == 'out')}\",\"{sum(v for (d, k), v in counts.items() if k == 'in')}\"")
PY
}

cmd_self_test() {
  local tmp; tmp="$(mktemp -d)"
  YMIR_MAIL_DIR="$tmp" YMIR_MAIL_LEDGER="$tmp/ledger.jsonl" YMIR_MAIL_STORE="$tmp/none.jsonl" \
    bash "$0" out --to a@example.com --subject "first" >/dev/null
  YMIR_MAIL_DIR="$tmp" YMIR_MAIL_LEDGER="$tmp/ledger.jsonl" YMIR_MAIL_STORE="$tmp/none.jsonl" \
    bash "$0" out --to b@example.com --subject 'a "quoted" subject' >/dev/null
  local rows; rows="$(wc -l < "$tmp/ledger.jsonl" | tr -d ' ')"
  [ "$rows" = 2 ] && printf 'ok   : two rows appended, none rewritten\n' || { printf 'FAIL : %s rows\n' "$rows"; rm -rf "$tmp"; exit 1; }
  python3 - "$tmp/ledger.jsonl" <<'PY' || { rm -rf "$tmp"; exit 1; }
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert rows[1]["subject"] == 'a "quoted" subject', rows[1]
assert all(r["direction"] == "out" for r in rows)
print("ok   : a quote in a subject cannot break a row")
PY
  printf 'ok   : the ledger is append-only by construction (the door has no edit verb)\n'
  rm -rf "$tmp"
  printf 'ledger-self-test: pass\n'
}

case "$CMD" in
  out) cmd_out "$@" ;;
  in) cmd_in "$@" ;;
  tail) cmd_tail "$@" ;;
  digest) cmd_digest "$@" ;;
  self-test|--self-test) cmd_self_test ;;
  *) printf 'error: unknown verb %s\nhelp: ledger.sh [out|in|tail|digest|self-test]\n' "$CMD" >&2; exit 2 ;;
esac
