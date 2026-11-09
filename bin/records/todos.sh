#!/usr/bin/env bash
# todos.sh — THE house task board: one door, one writer, one file.
#
# WHY THIS DOOR EXISTS (plan 228 §3 · F2): a promise made in a meeting is only kept if it
# becomes a piece of work somebody can see. The ladder files every promise here IN THE SAME
# ACT as the minutes. Until now the only task store in the tree was inside the harness face
# (`bin/seat/ymir-mcp.py`), with no shell door — so no pipeline could file one. This door
# writes THAT store, so the board every harness shows and the promises a meeting produced are
# the same board, never two.
#
#   todos.sh add "<what>" [--meeting <id>] [--source <s>]   -> "#<n>"   (refused if it exists)
#   todos.sh list [--open]                                  -> one row per task
#   todos.sh done <n>            mark one closed
#   todos.sh reopen <n>          open it again
#   todos.sh remove <n>
#   todos.sh open                the open count, alone
#
# Store: `$YMIR_HOME/state/todos.json` — an array of `{"content","status",…}` (Rule 07: the
# home resolves through bin/vault/hoard-lib.sh, never a hardcoded path). Entries may carry
# `meeting`, `source` and `added`, so a promise can be traced to the minute that made it;
# nothing that reads `content`/`status` is disturbed.
#
# Exit: 0 done · 1 no store/IO · 2 usage · 3 refused (no such task).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && YMIR_HOARD_LIB_LOADED=1
fi
ymir_home_root HOME_DIR 2>/dev/null || true
[ -n "${HOME_DIR:-}" ] || { printf 'todos: the home is unresolved (bin/vault/hoard-lib.sh)\nhelp: set YMIR_HOME or run the installer\n' >&2; exit 1; }
STATE_DIR="${YMIR_STATE_DIR:-$HOME_DIR/state}"
STORE="$STATE_DIR/todos.json"

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
ACTION="${1:-list}"; shift 2>/dev/null || true
case "$ACTION" in -h|--help) usage ;; esac

case "$ACTION" in
  add)
    content="${1-}"; shift 2>/dev/null || true
    meeting=""; source=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --meeting) meeting="${2-}"; shift 2 ;;
        --source) source="${2-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$content" ] || { printf 'todos: add needs the text of the task\n' >&2; exit 2; }
    mkdir -p "$STATE_DIR" || { printf 'todos: cannot create %s\n' "$STATE_DIR" >&2; exit 1; }
    python3 - "$STORE" "$content" "$meeting" "$source" <<'PY'
import datetime, json, os, sys
store, content, meeting, source = sys.argv[1:5]
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
if not isinstance(items, list):
    items = []
# Idempotent by CONTENT and MEETING: a ladder re-run must never file the same promise twice,
# and two meetings may honestly produce the same sentence.
for i, t in enumerate(items):
    if str(t.get("content", "")).strip() == content.strip() and str(t.get("meeting", "")) == meeting:
        print("#%d (already filed)" % i)
        raise SystemExit(0)
entry = {"content": content, "status": "pending"}
if meeting:
    entry["meeting"] = meeting
if source:
    entry["source"] = source
entry["added"] = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
items.append(entry)
tmp = store + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(items, fh, indent=2)
os.replace(tmp, store)
print("#%d" % (len(items) - 1))
PY
    ;;
  list)
    only_open=0
    [ "${1-}" = "--open" ] && only_open=1
    python3 - "$STORE" "$only_open" <<'PY'
import json, os, sys
store, only_open = sys.argv[1], sys.argv[2] == "1"
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
rows = [(i, t) for i, t in enumerate(items) if not only_open or t.get("status") != "done"]
if not rows:
    print("tasks[0]{n,status,meeting,what}:")
    print("count: 0")
    raise SystemExit(0)
print("tasks[%d]{n,status,meeting,what}:" % len(rows))
for i, t in rows:
    what = str(t.get("content", "")).replace('"', "'")
    print('  "%s","%s","%s","%s"' % (i, t.get("status", "pending"), t.get("meeting", ""), what[:110]))
print("count: %d" % len(rows))
PY
    ;;
  done|reopen|remove)
    n="${1-}"
    case "$n" in ''|*[!0-9]*) printf 'todos: %s needs an index (see `todos.sh list`)\n' "$ACTION" >&2; exit 2 ;; esac
    python3 - "$STORE" "$n" "$ACTION" <<'PY'
import json, os, sys
store, idx, action = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
if idx < 0 or idx >= len(items):
    print("todos: no task at index %d" % idx, file=sys.stderr)
    raise SystemExit(3)
if action == "remove":
    gone = items.pop(idx)
    print("removed: %s" % gone.get("content", ""))
else:
    items[idx]["status"] = "done" if action == "done" else "pending"
    print("#%d %s: %s" % (idx, items[idx]["status"], items[idx].get("content", "")))
tmp = store + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(items, fh, indent=2)
os.replace(tmp, store)
PY
    ;;
  open)
    python3 - "$STORE" <<'PY'
import json, os, sys
store = sys.argv[1]
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
print(sum(1 for t in items if t.get("status") != "done"))
PY
    ;;
  *) usage ;;
esac
