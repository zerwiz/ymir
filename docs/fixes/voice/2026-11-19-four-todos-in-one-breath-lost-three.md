# Four to-dos in one breath lost three, and the voice said they were saved

**Date:** 2026-11-19 · **Component:** voice (`bin/voice/voice_tools.py`) · **Test:** `bin/voice/tests/test_todo_write.py`

## What was wrong

The voice was asked to put four items on the to-do list in one turn. The model called `todo_add` four times at once.
The toolbox serves each call on its own thread, so four threads did the same read-modify-write of `todo.md` at the
same moment, and all four wrote the same temp file, `todo.md.tmp`.

The activity log shows the result, all in the same second:

- one call failed: `[Errno 2] No such file or directory: '…/todo.md.tmp' -> '…/todo.md'`, because another thread had
  already renamed the shared temp away;
- the other three each wrote the list as it stood before any of them, so each overwrote the last;
- those three reported `Added to his to-do … as ?`, which is a success sentence with no id.

The truth was the inverse of what was said. The one item reported as failed had in fact landed. The three items
reported as added were gone. The operator learned of it only because the voice passed the error to the helm.

The path itself was sound. It had no symlink, no missing mount and no wrong separator; `stat` and `namei -l` showed a
plain file in a plain directory on the home's own filesystem.

## What was done

- **One writer at a time.** Every change to the list (add, tick, reopen, update) now holds a lock for the whole
  read-modify-write. A thread lock covers the toolbox's own threads. An `flock` in the runtime directory covers
  any other process. The lock lives outside the home, so it never shows in the home's `git status`.
- **A real atomic write.** The temp file has a unique name from `mkstemp`, sits in the same directory, is flushed and
  fsynced, takes the target's mode, and is moved with `os.replace`. A temp left by a failure is removed. A missing
  parent directory is created and given its parent's owner.
- **A failure is spoken, never hidden.** A failed write raises `TodoWriteError` with the path and the errno. The tool
  answers *"I could not save that to his to-do — … was NOT written: could not write <path> (Errno N, …)"* and asks for
  a spoken reply.
- **An add is read back.** If the item is not in the file after the write, the add is a failure, never `as ?`.

## How it was proved

`python3 bin/voice/tests/test_todo_write.py` is fenced to a throwaway `YMIR_HOME`. It runs four adds on four threads,
then a tick, then an add into a read-only directory, then an add into a missing directory. It ends with
`PASS: todo write — 0 failure(s)`.

The same test against the code before this change fails every run with the exact error from the log:
`FileNotFoundError: [Errno 2] … todo.md.tmp -> … todo.md`.

## What is owed

`bin/dispatch/dispatch.py` also writes `todo.md` through a fixed `.tmp` name and does not take this lock. It runs on a
clock, not in parallel with itself, so it is not the fault here, but it could meet the voice in the same second.
