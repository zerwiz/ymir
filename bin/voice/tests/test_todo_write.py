#!/usr/bin/env python3
"""The voice's to-do writes: parallel adds all land, no temp is left behind, and a failure is spoken back.

Fenced: YMIR_HOME and HOME point at a throwaway directory, so the real list is never touched.
Run: python3 bin/voice/tests/test_todo_write.py
"""
import asyncio
import os
import stat
import sys
import tempfile
import threading
from pathlib import Path

FENCE = tempfile.mkdtemp(prefix="todo-write-test-")
os.environ["YMIR_HOME"] = FENCE
os.environ["HOME"] = FENCE
os.environ["XDG_RUNTIME_DIR"] = FENCE
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import voice_tools as vt  # noqa: E402

ME = Path(FENCE) / "hodd" / "life" / "personal" / "me"
TODO = ME / "todo.md"
fails = 0


def check(ok, what):
    global fails
    print(("ok   " if ok else "FAIL ") + what)
    fails += 0 if ok else 1


def seed():
    ME.mkdir(parents=True, exist_ok=True)
    TODO.write_text("# His half\n\n## Now\n\n- [ ] **an item of his own**\n\n"
                    "# The house-kept half\n\n- [ ] **kept**\n", encoding="utf-8")


def out(r):
    return str(getattr(r, "output", None) if not isinstance(r, dict) else r.get("output"))


def speaks(r):
    return bool(getattr(r, "create_response", None) if not isinstance(r, dict) else r.get("create_response"))


def add(item):
    return asyncio.run(vt._tool_todo_add({"item": item}))


# 1. four adds at once, on four threads — the toolbox's own shape (ThreadingHTTPServer, asyncio.run per call)
seed()
items = [f"parallel item {n}" for n in range(4)]
results = {}
threads = [threading.Thread(target=lambda i=i: results.__setitem__(i, add(i))) for i in items]
for t in threads:
    t.start()
for t in threads:
    t.join()
text = TODO.read_text(encoding="utf-8")
check(all(i in text for i in items), "four parallel adds all land in todo.md")
check(all("Added to his to-do" in out(results[i]) and " as ?" not in out(results[i]) for i in items),
      "each parallel add reports a real id")
check("an item of his own" in text and "kept" in text, "the rest of the file is kept")
check(not [p for p in ME.iterdir() if p.name.endswith(".tmp")], "no .tmp is left behind")
check(oct(TODO.stat().st_mode & 0o777) == oct(0o644), "the file keeps its mode")

# 2. tick and update still work under the lock
_, its = vt._todo_items()
tid = next(t["id"] for t in its if t["item"].startswith("parallel item 0"))
r = asyncio.run(vt._tool_todo_done({"id": tid}))
check("Ticked" in out(r) and "- [x] **parallel item 0**" in TODO.read_text(), "a tick lands")

# 3. a read-only directory: the failure names the path and the errno, and is spoken back
if os.geteuid() != 0:
    os.chmod(ME, stat.S_IRUSR | stat.S_IXUSR)
    try:
        r = add("this one cannot land")
    finally:
        os.chmod(ME, 0o755)
    o = out(r)
    check(o.startswith("I could not save that") and speaks(r), "a failed add is spoken back")
    check(str(ME) in o and "Errno 13" in o, "the failure names the path and the errno")
    check("this one cannot land" not in TODO.read_text(), "nothing half-written")
    check(not [p for p in ME.iterdir() if p.name.endswith(".tmp")], "no .tmp after a failure")

# 4. a missing parent directory is created
import shutil  # noqa: E402
shutil.rmtree(ME)
r = add("into a fresh directory")
check(TODO.is_file() and "into a fresh directory" in TODO.read_text(), "a missing parent is created")

shutil.rmtree(FENCE, ignore_errors=True)
print(f"{'PASS' if not fails else 'FAIL'}: todo write — {fails} failure(s)")
sys.exit(1 if fails else 0)
