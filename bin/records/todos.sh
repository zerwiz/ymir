#!/usr/bin/env bash
# todos.sh — THE task board of the house, one writer for one file.
#
# WHY this door exists: a promise made in a meeting is only kept if it becomes a
# piece of work somebody can see. Plan 228 §3 (F2) requires the ladder to file
# every promise as a todo **in the same act** as the minutes — and until now the
# only todo store in the tree was inside `bin/seat/ymir-mcp.py` (the MCP face),
# with no shell door, so no pipeline could file one and no harness could read the
# same board. This is that door; the MCP face calls it, so there is ONE writer.
#
#   todos.sh add "<what>" [--meeting <id>] [--source <s>] [--tag <t>] [--key <stable>]   -> "#<n>"
#   todos.sh list [--open] [--meeting <id>] [--json]                    -> one row per todo
#   todos.sh done <n>                                                  -> status = done
#   todos.sh reopen <n>                                                -> status = pending
#   todos.sh remove <n>
#   todos.sh open                                                      -> the count only
#
# `--key` makes the write IDEMPOTENT: the same key never lands twice (a ladder that
# re-runs a meeting, a retry after a timeout). It prints `exists #<n>` and exits 0, so
# a caller can tell "filed now" from "was already filed" without reading the store.
#
# The board has ONE writer (this door). `bin/seat/ymir-mcp.py` and `bin/mcp/ymir-mcp.py`
# READ the same store in this shape; they never write it.
#
# The store is `$YMIR_HOME/state/todos.json` (Rule 07: resolved, never hardcoded)
# — an array of `{"content": ..., "status": "pending"|"done", ...}`. The optional
# `meeting`, `source` and `added` keys ride along so a todo can be traced back to
# the minute that made it; nothing that reads `content`/`status` is disturbed.
#
# Exit: 0 done · 1 no store/IO · 2 usage · 3 refused (no such todo).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && YMIR_HOARD_LIB_LOADED=1
fi
ymir_home_root HOME_DIR 2>/dev/null || true
[ -n "${HOME_DIR:-}" ] || { printf 'todos: the home is unresolved (bin/vault/hoard-lib.sh)\nhelp: set YMIR_HOME or run the installer\n' >&2; exit 1; }
STATE_DIR="${YMIR_STATE_DIR:-$HOME_DIR/state}"
STORE="$STATE_DIR/todos.json"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
ACTION="${1:-list}"; shift 2>/dev/null || true

case "$ACTION" in
  -h|--help) usage ;;
esac

case "$ACTION" in
  add)
    content="${1-}"; shift 2>/dev/null || true
    meeting=""; source=""; tag=""; key=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --meeting) meeting="${2-}"; shift 2 ;;
        --source) source="${2-}"; shift 2 ;;
        --tag) tag="${2-}"; shift 2 ;;
        --key) key="${2-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$content" ] || { printf 'todos: add needs the text of the task\n' >&2; exit 2; }
    mkdir -p "$STATE_DIR" || { printf 'todos: cannot create %s\n' "$STATE_DIR" >&2; exit 1; }
    python3 - "$STORE" "$content" "$meeting" "$source" "$tag" "$key" <<'PY'
import json, os, sys, datetime
store, content, meeting, source, tag, key = sys.argv[1:7]
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
if not isinstance(items, list):
    items = []
if key:
    for i, t in enumerate(items):
        if t.get("key") == key:
            print("exists #%d %s" % (i, str(t.get("content", ""))[:80]))
            raise SystemExit(0)
entry = {"content": content, "status": "pending"}
for name, value in (("meeting", meeting), ("source", source), ("tag", tag), ("key", key)):
    if value:
        entry[name] = value
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
    only_open=0; as_json=0; meeting=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --open) only_open=1; shift ;;
        --json) as_json=1; shift ;;
        --meeting) meeting="${2-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    if [ "$as_json" = 1 ]; then
      python3 - "$STORE" "$only_open" "$meeting" <<'PY'
import json, os, sys
store, only_open, meeting = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
rows = [dict(t, n=i) for i, t in enumerate(items)]
if only_open:
    rows = [t for t in rows if t.get("status") != "done"]
if meeting:
    rows = [t for t in rows if meeting in str(t.get("meeting", ""))]
print(json.dumps(rows, indent=2))
PY
      exit 0
    fi
    python3 - "$STORE" "$only_open" "$meeting" <<'PY'
import json, os, sys
store, only_open, meeting = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
try:
    items = json.load(open(store)) if os.path.exists(store) else []
except Exception:
    items = []
rows = [(i, t) for i, t in enumerate(items)
        if (not only_open or t.get("status") != "done")
        and (not meeting or meeting in str(t.get("meeting", "")))]
if not rows:
    print("todos[0]{n,status,what}:")
    print("count: 0")
    raise SystemExit(0)
print("todos[%d]{n,status,meeting,what}:" % len(rows))
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
elif action == "reopen":
    items[idx]["status"] = "pending"
    print("#%d reopened: %s" % (idx, items[idx].get("content", "")))
else:
    items[idx]["status"] = "done"
    print("#%d done: %s" % (idx, items[idx].get("content", "")))
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
