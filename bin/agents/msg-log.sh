#!/usr/bin/env bash
# msg-log.sh — the record of every word sent between agents (2026-11-14, plan 275 item 8).
#
# At the Allfather's word: *"the a2a task stream also should show the herdr communication between agents"*. The
# stream said "no live events" because nothing ever wrote the sends down. Every `bin/agents/eindri-send.sh`
# message now lands here — time, who from, who to, the first line — and Hlidskjalf's A2A panel reads THIS file.
#
#   bin/agents/msg-log.sh record --from "<who>" --to "<agent|pane>" [--pane <id>] "<text>"
#   bin/agents/msg-log.sh json [n]     # a JSON array, oldest first (what the gate serves)
#   bin/agents/msg-log.sh tail [n]     # TOON rows for a human at a terminal
#   bin/agents/msg-log.sh where        # the absolute path of the log
#
# The log is runtime state, so it lives in the hoard's state root ($YMIR_STATE_DIR, else $YMIR_HOME/state),
# never in the checkout (Rule 04): a packaged tree is replaced on upgrade and the record must survive it.
# One line per message, JSON, 0600, appended with O_APPEND so two senders never interleave a row.
#
# It records; it never speaks. A send that fails writes nothing, and a log that cannot be written never
# fails the send — the message matters more than its record, and the caller is told which happened.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
hoard_state_dir YMIR_STATE_DIR
LOG_DIR="${YMIR_MSG_LOG_DIR:-$YMIR_STATE_DIR/fleet}"
LOG="$LOG_DIR/messages.jsonl"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-tail}"; shift || true

usage() { printf 'error: usage: msg-log.sh record --from <who> --to <agent|pane> [--pane <id>] "<text>"\n' >&2; exit 2; }

case "$ACTION" in
  where) printf '%s\n' "$LOG" ;;

  record)
    FROM=""; TO=""; PANE=""; TEXT=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --from) FROM="${2-}"; shift 2 || true ;;
        --to) TO="${2-}"; shift 2 || true ;;
        --pane) PANE="${2-}"; shift 2 || true ;;
        --) shift; break ;;
        *) break ;;
      esac
    done
    TEXT="${*:-}"
    [ -n "$TO" ] && [ -n "$TEXT" ] || usage
    mkdir -p "$LOG_DIR" 2>/dev/null || { printf 'msg-log[1]{state,why}:\n  "unwritten","cannot make %s"\n' "$LOG_DIR" >&2; exit 1; }
    command -v python3 >/dev/null 2>&1 || { printf 'msg-log[1]{state,why}:\n  "unwritten","no python3 to encode the row"\n' >&2; exit 1; }
    python3 - "$LOG" "${FROM:-unknown}" "$TO" "$PANE" "$TEXT" "$(hostname -s 2>/dev/null || uname -n)" <<'PY'
import datetime, json, os, sys
path, frm, to, pane, text, host = sys.argv[1:7]
# One row, one line: the first line of the message, whitespace collapsed, bounded so a
# pasted log can never bloat the record. The full text stays in the pane; this is the index.
body = text.strip().splitlines()[0] if text.strip() else ""
body = " ".join(body.split())
if len(body) > 240:
    body = body[:237] + "…"
row = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "epoch": int(datetime.datetime.now(datetime.timezone.utc).timestamp()),
    "from": frm,
    "to": to,
    "pane": pane,
    "machine": host,
    "text": body,
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
try:
    os.write(fd, (json.dumps(row, ensure_ascii=False) + "\n").encode())
finally:
    os.close(fd)
PY
    ;;

  json|tail)
    N="${1:-40}"
    case "$N" in ''|*[!0-9]*) N=40 ;; esac
    python3 - "$LOG" "$N" "$ACTION" <<'PY'
import json, os, sys
path, n, mode = sys.argv[1], int(sys.argv[2]), sys.argv[3]

rows = []
if os.path.exists(path):
    try:
        with open(path, errors="replace") as fh:
            # A bounded tail, not the whole file: the panel asks for the newest words.
            lines = fh.readlines()[-max(n, 1):]
    except OSError:
        lines = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue

if mode == "json":
    print(json.dumps(rows))
    raise SystemExit(0)

if not rows:
    print("messages: 0 — no agent-to-agent message has been recorded yet")
    raise SystemExit(0)
print("messages[%d]{ts,from,to,text}:" % len(rows))
for r in rows:
    q = lambda s: '"%s"' % str(s or "").replace('"', '\\"')
    print("  %s,%s,%s,%s" % (q(r.get("ts")), q(r.get("from")), q(r.get("to")), q(r.get("text"))))
PY
    ;;

  *) usage ;;
esac
