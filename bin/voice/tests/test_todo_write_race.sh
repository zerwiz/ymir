#!/usr/bin/env bash
# test_todo_write_race.sh — two writers of the to-do list no longer collide on one temp file (2026-11-19).
#
# Rödd reported: "todo_add on heimdall failed writing the list: …/todo.md.tmp -> todo.md (Errno 2)". Every
# writer used the same `todo.md.tmp`; the first renamed it away and the second's rename found nothing.
# Fenced: YMIR_HOME and HOME point into a throwaway folder, so the operator's own list is never touched.
set -u
SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOICE="$SELF/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" YMIR_HOME="$tmp/ymirhome"
mkdir -p "$HOME" "$YMIR_HOME/life/personal/me"
printf '# His half\n\n- [ ] seed\n' > "$YMIR_HOME/life/personal/me/todo.md"

python3 - "$VOICE" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import voice_tools as vt

kids = []
for n in range(4):
    pid = os.fork()
    if pid == 0:  # one writer: 200 passes; its exit code is how many failed
        errors = 0
        for i in range(200):
            try:
                vt._todo_write(["# His half", "", f"- [ ] writer {n} pass {i}"])
            except OSError:
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
