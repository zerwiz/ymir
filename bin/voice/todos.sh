#!/usr/bin/env bash
# todos.sh — the Allfather's to-do, READ by anyone who must know it (the arm holder first).
#
# TWO lists, both printed, never one mistaken for the other:
#
#   • HIS LIST — `hodd/life/personal/me/todo.md`, the one to-do (plan 275, 2026-11-12). Every `- [ ]`
#     line in it is an open item; the file names its own halves (his half · the derived half · the
#     house-kept half) and each is counted apart.
#   • THE VOICE LEDGER — `hodd/state/voice/todos.jsonl`, one event per line (add · done · reopen ·
#     update), folded by `_todo_state()` in bin/voice/voice_tools.py. It is kept as its own count.
#
# Until 2026-11-16 this door read only the ledger, so the session digest printed `0 open` while his
# real list held 57. The digest now reads HIS list first, through the one parser (`_todo_items()`),
# and says **unable** when the list cannot be read — never zero, which is a claim.
#
#   todos.sh                 # every open item, his list first, then the voice ledger
#   todos.sh --digest        # the session-start block: counts per half + open lines (capped at 15)
#   todos.sh --json          # the voice ledger, all items, open and done
#   todos.sh --project <p>   # only open items whose section or words match p
#
# Exit: 0 ran (a list that cannot be read is printed as unable) · 2 usage.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-list}"; PROJECT=""
case "$MODE" in
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  list|--digest|--json) ;;
  --project) PROJECT="${2:-}"; [ -n "$PROJECT" ] || { echo "usage: todos.sh --project <name>" >&2; exit 2; }; MODE=list ;;
  *) echo "error: unknown mode $MODE" >&2; exit 2 ;;
esac
python3 - "$SCRIPT_DIR" "$MODE" "$PROJECT" <<'PY'
import json, signal, sys
sys.path.insert(0, sys.argv[1])
# A reader that pipes into `head` closes early; that is not an error to report (the head reads
# `--digest | head -1` on every session start).
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass
mode, project = sys.argv[2], sys.argv[3]
try:
    import voice_tools as vt
    tasks = vt._todo_state()
    ledger = vt._todo_paths()[0]
except Exception as exc:
    print(f"todos: the voice's ledger could not be read ({exc.__class__.__name__})"); sys.exit(0)

# HIS list, read through the one parser. A list that cannot be read is UNable, never zero:
# a zero is a claim about his day, and the file's own law is that an unreadable fact says so.
try:
    md_path = vt._todo_file()
except Exception as exc:
    md_path, md_items, md_why = None, [], f"unreadable ({exc.__class__.__name__})"
else:
    try:
        if md_path.is_file():
            md_items, md_why = vt._todo_items()[1], ""
        else:
            md_items, md_why = [], "no such file"
    except Exception as exc:
        md_items, md_why = [], f"unreadable ({exc.__class__.__name__})"

HALF_WORD = {"his": "his", "derived": "derived", "kept": "kept", "other": "other"}
HALF_NAME = {"his": "his half", "derived": "the derived half", "kept": "the house-kept half", "other": "unheaded"}
prio = {"high": 0, "medium": 1, "low": 2}
want = (project or "").strip().lower()


def matches_md(t):
    return not want or want in t["section"].lower() or want in t["item"].lower()


def matches_ledger(t):
    return not want or want == (t["project"] or "").lower()


md_open = [t for t in md_items if t["status"] == "open" and matches_md(t)]
opened = [t for t in tasks if t["status"] == "open" and matches_ledger(t)]
opened.sort(key=lambda t: (t["project"] != "personal", prio.get(t["priority"], 1), t["due"] or "9999", t["added"]))

if mode == "--json":
    print(json.dumps(tasks, indent=1, ensure_ascii=False)); sys.exit(0)


def md_line(t):
    sec = (t["section"] or "—")
    sec = sec if len(sec) <= 40 else sec[:39].rstrip() + "…"
    words = t["item"]
    words = words if len(words) <= 110 else words[:109].rstrip() + "…"
    return f"- [{HALF_WORD.get(t.get('half'), 'other')} · {sec}] {words}  ({t['id']})"


def ledger_line(t):
    bits = [t["item"]]
    if t["due"]: bits.append(f"due {t['due']}")
    if t["priority"] != "medium": bits.append(t["priority"])
    return f"- [voice · {t['project'] or '-'}] " + " · ".join(bits) + f"  ({t['id']})"


if mode == "--digest":
    per = {"his": 0, "derived": 0, "kept": 0, "other": 0}
    for t in md_open:
        per[t.get("half", "other")] = per.get(t.get("half", "other"), 0) + 1
    house = per["derived"] + per["kept"] + per["other"]
    if md_why:
        print(f"open: unable — his list {md_path} {md_why} · voice ledger {len(opened)}")
    else:
        print(f"open: {len(md_open)} — his half {per['his']} · house-kept {house} · voice ledger {len(opened)}")
        print(f"  {md_path} (house-kept {house} = derived {per['derived']} + from his messages {per['kept']}"
              + (f" + unheaded {per['other']}" if per["other"] else "") + f") · voice ledger {ledger}")
    shown = md_open[:15]
    for t in shown:
        print(md_line(t))
    rest = 15 - len(shown)
    for t in (opened[:rest] if rest > 0 else []):
        print(ledger_line(t))
    total = len(md_open) + len(opened)
    if total > 15:
        print(f"… {total - 15} more: bin/voice/todos.sh")
    sys.exit(0)

if md_why:
    print(f"unable: his list {md_path} {md_why}")
elif not md_open and not opened:
    print("no open items" + (f" about {project}" if project else "")); sys.exit(0)
for t in md_open: print(md_line(t))
for t in opened: print(ledger_line(t))
PY
