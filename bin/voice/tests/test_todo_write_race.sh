#!/usr/bin/env bash
# test_todo_write_race.sh — two writers of the to-do list no longer collide on one temp file (2026-11-19).
#
# Rödd reported: "todo_add on heimdall failed writing the list: …/todo.md.tmp -> todo.md (Errno 2)". Every
# writer used the same `todo.md.tmp`; the first renamed it away and the second's rename found nothing.
# 2026-11-19, the gather: the writer is now `bin/records/todo_door.py` (one lock, a mkstemp temp per write), so
# the race is run against the door itself — the same four writers, the same 800 passes.
# Fenced: YMIR_HOME and HOME point into a throwaway folder, so the operator's own list is never touched.
set -u
SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOICE="$SELF/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" YMIR_HOME="$tmp/ymirhome"
mkdir -p "$HOME" "$YMIR_HOME/hodd/life/personal/me"
printf '# His half\n\n- [ ] seed\n' > "$YMIR_HOME/hodd/life/personal/me/todo.md"

python3 - "$VOICE" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
sys.path.insert(0, os.path.join(sys.argv[1], "..", "records"))
import voice_tools as vt
import todo_door

kids = []
for n in range(4):
    pid = os.fork()
    if pid == 0:  # one writer: 200 passes; its exit code is how many failed
        errors = 0
        for i in range(200):
            try:
                p = vt._todo_file()
                with todo_door.locked(p):
                    todo_door.atomic_write(p, "\n".join(["# His half", "", f"- [ ] writer {n} pass {i}"]) + "\n")
            except (OSError, todo_door.DoorError):
                errors += 1
        os._exit(min(errors, 255))
    kids.append(pid)
errs = sum(os.waitstatus_to_exitcode(os.waitpid(k, 0)[1]) for k in kids)
folder = vt._todo_file().parent
left = [p.name for p in folder.iterdir() if p.name.endswith(".tmp")]
text = vt._todo_file().read_text()
whole = text.startswith("# His half\n\n- [ ] writer ")
print(f"writers=4 passes=800 errors={errs} temp_left={len(left)} whole={whole}")
ok = errs == 0 and not left and whole
print("test_todo_write_race: " + ("ok" if ok else "FAIL"))
sys.exit(0 if ok else 1)
PY
