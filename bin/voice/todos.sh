#!/usr/bin/env bash
# todos.sh — the Allfather's task ledger, READ by anyone who must know it (the arm holder first).
#
# Rödd (the voice) keeps the ledger: `hodd/state/voice/todos.jsonl`, one event per line
# (add · done · reopen · update), folded by `_todo_state()` in bin/voice/voice_tools.py. Until
# 2026-11-10 only Rödd's own tools read it, so a todo spoken to the voice never reached the session
# that holds the arm — the Allfather's right hand on the machine (his word: "forge so the personal
# todos for the Allfather get read"). This door imports that ONE fold; it does not re-implement it,
# and it never writes the ledger (the voice is its one writer).
#
#   todos.sh                 # every open item, personal first, then by priority and due date
#   todos.sh --digest        # the session-start block: count + every open line (capped at 15)
#   todos.sh --json          # all items, open and done
#   todos.sh --project <p>   # only one project's open items
#
# Exit: 0 ran (an absent ledger is "0 open") · 2 usage.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-list}"; PROJECT=""
case "$MODE" in
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  list|--digest|--json) ;;
  --project) PROJECT="${2:-}"; [ -n "$PROJECT" ] || { echo "usage: todos.sh --project <name>" >&2; exit 2; }; MODE=list ;;
  *) echo "error: unknown mode $MODE" >&2; exit 2 ;;
esac
python3 - "$SCRIPT_DIR" "$MODE" "$PROJECT" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
mode, project = sys.argv[2], sys.argv[3]
try:
    import voice_tools as vt
    tasks = vt._todo_state()
    ledger = vt._todo_paths()[0]
except Exception as exc:
    print(f"todos: the voice's ledger could not be read ({exc.__class__.__name__})"); sys.exit(0)
if mode == "--json":
    print(json.dumps(tasks, indent=1, ensure_ascii=False)); sys.exit(0)
prio = {"high": 0, "medium": 1, "low": 2}
opened = [t for t in tasks if t["status"] == "open" and (not project or t["project"] == project)]
opened.sort(key=lambda t: (t["project"] != "personal", prio.get(t["priority"], 1), t["due"] or "9999", t["added"]))
def line(t):
    bits = [t["item"]]
    if t["due"]: bits.append(f"due {t['due']}")
    if t["priority"] != "medium": bits.append(t["priority"])
    return f"- [{t['project'] or '-'}] " + " · ".join(bits) + f"  ({t['id']})"
if mode == "--digest":
    per = {}
    for t in opened: per[t["project"] or "-"] = per.get(t["project"] or "-", 0) + 1
    split = " · ".join(f"{n} {p}" for p, n in sorted(per.items(), key=lambda kv: (kv[0] != "personal", kv[0])))
    print(f"open: {len(opened)}" + (f" ({split})" if split else "") + f" — ledger {ledger}")
    for t in opened[:15]: print(line(t))
    if len(opened) > 15: print(f"… {len(opened) - 15} more: bin/voice/todos.sh")
    sys.exit(0)
if not opened: print("no open items"); sys.exit(0)
for t in opened: print(line(t))
PY
