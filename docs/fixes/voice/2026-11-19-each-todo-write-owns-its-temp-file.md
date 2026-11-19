# Each write of the to-do list owns its temp file

**2026-11-19**, answering a wake from Rödd (plan 325 step 4). Rödd told the arm holder:

> todo_add on heimdall failed writing the list: …/hodd/life/personal/me/todo.md.tmp -> todo.md (Errno 2, no such
> file or directory); the … onboarding line never landed — please fix the atomic write path.

## Why it failed

`_todo_write` in `bin/voice/voice_tools.py` wrote every list to one fixed name, `todo.md.tmp`, and then renamed it
into place. Two writers at once (Rödd's window and another seat of the voice) shared that name. The first renamed
it away, and the second's rename found nothing and raised Errno 2. The folder and the list were both present; only
the shared temp name was at fault.

## What changed

Each write now names its temp file with its pid and a random part. The rename stays a single atomic step, so a
reader never sees half a list. A `finally` removes the temp file if the write fails part-way, so none is left behind.

## Proof

`bin/voice/tests/test_todo_write_race.sh` forks four writers of 200 passes each against a fenced home:

| Door | Errors in 800 writes | Temp files left | Verdict |
|---|---|---|---|
| Before (`3354412b1`) | 491 | 0 | FAIL |
| After | 0 | 0 | ok |

`bin/voice/tests/test_todos_digest.sh` still reports 14 passed, 0 failed.

## What this does not fix

Two writers can still each read the list, add a line, and write it back. The last write then wins and the other
line is lost. That needs a lock across the read and the write, and it is a larger change. The line Rödd reported
did land in the end: it is in the list, stamped 18:03.
