#!/usr/bin/env python3
"""The to-do door, end to end: a spoken to-do lands, reads back, survives a forged failure with a spoken refusal,
and leaves no temp behind. It goes through the same road Rödd uses: the voice tool `todo_add`, which calls
`bin/records/comms.sh todo add`.

Fenced: YMIR_HOME, HOME and XDG_RUNTIME_DIR point at a throwaway directory, so the real list is never touched.
Run: python3 bin/voice/tests/test_todo_write.py
"""
import asyncio
import json
import os
import shutil
import stat
import sys
import tempfile
import threading
from pathlib import Path

FENCE = tempfile.mkdtemp(prefix="todo-door-test-")
os.environ["YMIR_HOME"] = FENCE
os.environ["HOME"] = FENCE
os.environ["XDG_RUNTIME_DIR"] = FENCE
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import voice_tools as vt  # noqa: E402
import todo_door  # noqa: E402  (voice_tools put bin/records on the path)

H = Path(FENCE) / "hodd"
ME = H / "life" / "personal" / "me"
TODO = ME / "todo.md"
VOICE = H / "state" / "voice"
LEDGER = VOICE / "todos.jsonl"
VIEW = ME / "todo-voice.md"
HIS = ("# His half — what only he can do\n\n## Today\n\n- [ ] **an item of his own**\n\n"
       "## Added in conversation\n\n- [ ] **an older spoken line**\n\n")
fails = 0


def check(ok, what):
    global fails
    print(("ok   " if ok else "FAIL ") + what)
    fails += 0 if ok else 1


def out(r):
    return str(r.get("output") if isinstance(r, dict) else getattr(r, "output", r))


def speaks(r):
    return bool(r.get("create_response") if isinstance(r, dict) else getattr(r, "create_response", False))


def run(coro):
    return asyncio.run(coro)


def temps():
    return [p for d in (ME, VOICE) if d.is_dir() for p in d.iterdir() if p.name.endswith(".tmp")]


def seed():
    ME.mkdir(parents=True, exist_ok=True)
    VOICE.mkdir(parents=True, exist_ok=True)
    TODO.write_text("# The day\n\n**his half** is written by him and never by a machine\n\n" + HIS
                    + "# The derived half — what the house measured\n\n- [ ] derived\n", encoding="utf-8")
    # a stale view: it shows an id the record never held, and lacks what the record holds
    LEDGER.write_text(json.dumps({"ts": "2026-11-08T13:39:09", "action": "add", "id": "t13390986",
                                  "item": "an item the record holds"}) + "\n", encoding="utf-8")
    VIEW.write_text("# old view\n\n## Open (1)\n\n- [ ] Tool test — tick me · `t23504315` · rodd\n", encoding="utf-8")


seed()
his_before = todo_door.his_half(TODO.read_text())

# 1. a spoken to-do lands, through execute_tool (what the toolbox's POST /tool calls) and the one door
r = run(vt.execute_tool("todo_add", {"item": "Reply to Ada about onboarding", "priority": "high"}))
check(out(r).startswith("Saved to his to-do") and speaks(r), "a spoken to-do is saved and said: " + out(r)[:90])
rows = todo_door.read_record(LEDGER)
check(any(x.get("item") == "Reply to Ada about onboarding" and x.get("by") == "voice" for x in rows),
      "it reads back from the record (todos.jsonl)")
text = TODO.read_text()
check("## Said to Rödd" in text and "Reply to Ada about onboarding" in text.split("# The house-kept half")[1],
      "it lands in the house-kept half of todo.md, under 'Said to Rödd'")
check(todo_door.his_half(text) == his_before, "his half is byte-for-byte unchanged")
check(not temps(), "no .tmp is left behind")

# 2. the view admits drift: it is re-rendered and names what the stale page showed
view = VIEW.read_text()
check("drifted" in out(r) and "was stale" in view, "the stale view is named and re-rendered")
check("an item the record holds" in view and "Reply to Ada about onboarding" in view, "the view now holds the record")
check("Tool test — tick me" in view and "absent from the record" in view,
      "what the old view showed is kept under its own heading, not quietly dropped")

# 3. four in one breath, on four threads (the shape that lost three on 2026-11-19)
items = [f"parallel item {n}" for n in range(4)]
res = {}
ts = [threading.Thread(target=lambda i=i: res.__setitem__(i, run(vt._tool_todo_add({"item": i})))) for i in items]
[t.start() for t in ts]
[t.join() for t in ts]
text = TODO.read_text()
check(all(i in text for i in items) and all(out(res[i]).startswith("Saved") for i in items),
      "four parallel adds all land and all say saved")
check(sum(1 for x in todo_door.read_record(LEDGER) if x.get("item", "").startswith("parallel item")) == 4,
      "the record holds all four")
check(not temps(), "no .tmp after the parallel adds")

# 4. his half is his: a tick of his line is a closing line in the house-kept half; a raw write is refused
_, its = vt._todo_items()
mine = next(t for t in its if t["item"] == "an item of his own")
r = run(vt._tool_todo_done({"id": mine["id"]}))
text = TODO.read_text()
check(out(r).startswith("Ticked") and todo_door.his_half(text) == his_before,
      "ticking his line leaves his half untouched")
check(f"done: «an item of his own»" in text and f"(item {mine['id']})" in text, "the closing is a house-kept line")
_, its = vt._todo_items()
check(next(t for t in its if t["id"] == mine["id"])["status"] == "done", "his line now reads as done")
try:
    with todo_door.locked(TODO):
        todo_door.write_todo(TODO, text.replace("an item of his own", "rewritten by a machine"))
    check(False, "a write into his half is refused")
except todo_door.HisHalfError:
    check(True, "a write into his half is refused")

# 5. a forged failure: the record's directory is read-only — the refusal is spoken, with the path and errno
if os.geteuid() != 0:
    before = TODO.read_text()
    os.chmod(VOICE, stat.S_IRUSR | stat.S_IXUSR)
    try:
        r = run(vt._tool_todo_add({"item": "this one cannot land"}))
    finally:
        os.chmod(VOICE, 0o755)
    o = out(r)
    check(o.startswith("I could not save that") and speaks(r), "the failure is spoken: " + o[:80])
    check(str(VOICE) in o and "Errno 13" in o, "the failure names the path and the errno")
    check(TODO.read_text() == before and "this one cannot land" not in LEDGER.read_text(), "nothing half-written")
    check(not temps(), "no .tmp after the failure")

    # a second forged failure, on the list's own directory: the record keeps it, the list refuses, and it is said
    os.chmod(ME, stat.S_IRUSR | stat.S_IXUSR)
    try:
        r = run(vt._tool_todo_add({"item": "the list cannot take this"}))
    finally:
        os.chmod(ME, 0o755)
    o = out(r)
    check(o.startswith("I could not save that") and str(ME) in o and "NOT on his list" in o,
          "a list that refuses is said, and the record is named as holding it")
    check("the list cannot take this" not in TODO.read_text() and not temps(), "the list untouched, no .tmp")
    log = VOICE / f"activity-{__import__('datetime').date.today().isoformat()}.jsonl"
    check(log.is_file() and "todo.unsaved" in log.read_text() and "Errno 13" in log.read_text(),
          "the log keeps the path and the errno")

shutil.rmtree(FENCE, ignore_errors=True)
print(f"{'PASS' if not fails else 'FAIL'}: the to-do door — {fails} failure(s)")
sys.exit(1 if fails else 0)
