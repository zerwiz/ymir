# The voice asks for a to-do through the door, and his half is enforced

**Date:** 2026-11-19 · **Component:** records (`bin/records/todo_door.py`, `bin/records/comms.py`) · **Also:**
voice (`bin/voice/voice_tools.py`), dispatch (`bin/dispatch/dispatch.py`) · **Test:** `bin/voice/tests/test_todo_write.py`

## What was wrong

The fix before this one (`docs/fixes/voice/2026-11-19-four-todos-in-one-breath-lost-three.md`) mended the lock and
the temp file. It left three faults that made tonight's loss possible.

- **The voice wrote his half.** `todo_add` put spoken items under "## Added in conversation", inside his half of
  `todo.md`. The file's own header says his half "is written by him and never by a machine". Plan 261 refuses
  "writing his own half of the to-do list: a tick is read from it, never made in it". Nothing enforced either.
- **Four roads wrote the list.** The voice, `comms.sh todo-apply`, the dispatch inbox and two dead helpers in the
  voice each had their own write. Only the voice had the new lock; `todo-apply` wrote in place with no temp at all.
- **The view lied by leaving things out.** `todo-voice.md` was last rendered on 2026-11-07. It showed five "Tool test"
  ids that are not in `hodd/state/voice/todos.jsonl`, and none of the nine items the record does hold.

## What was done

### One door for every house writer

`bin/records/todo_door.py` is the only way the house writes the to-do or the voice's record:

| Guarantee | How |
|---|---|
| One writer at a time | `locked(path)`: a thread lock and an `flock` in the runtime directory, reentrant within a thread |
| A write that proves itself | `atomic_write`: same-directory unique temp, fsync, the target's mode, `os.replace`, then a readback |
| His half is his | `write_todo` refuses any write that changes a byte of his half (`HisHalfError`) |
| A failure names itself | every failure is a `DoorError` with the path and the errno |

`comms.sh todo-apply`, the dispatch inbox, and the voice's tick and update now write through it.

### One verb for a spoken to-do

`bin/records/comms.sh todo add "<text>" [--due] [--priority] [--project]` is the verb. The voice's `todo_add` calls
it and nothing else. It does three things in order:

1. it appends the event to `hodd/state/voice/todos.jsonl` and reads it back;
2. it writes a dated line under "## Said to Rödd" in the **house-kept** half of `todo.md`, then reads it back;
3. it re-renders `todo-voice.md` from the record.

If step 2 fails after step 1, the answer says the item is kept in the record but is **not** on his list.

The voice asks for a to-do the way the mail does (plan 261): through `comms.sh`, into the house-kept half.

### His lines are read, never written

A tick of one of his lines is now a dated closing line in the house-kept half, the same shape `todo-apply` writes:
`done: «his words» (section) — said to Rödd 18:03 (item tXXXXX)`. His line is untouched, and it reads as done
in `todo_list`. A reopen unticks that closing line. A change of wording or date becomes a dated `changed:` note.

### A failure speaks

The tool answers *"I could not save that to his to-do — … was NOT written: could not write <path> (Errno 13,
Permission denied)"* and asks for a spoken reply. The activity log keeps `todo.unsaved` with the path and the errno.
Stderr keeps it too, which the voice host writes to `host.log`, because the activity log may sit on the path that
failed.

### The view admits drift

`render_view` compares the old page with the record before writing. When they differ, the new page opens with a
warning naming how many items each side lacked. Ids the old page showed that the record no longer holds are kept
under "Shown by an older view, absent from the record". The record is append-only, so a vanished row is a fault to
find, not a line to forget.

## How it was proved

`python3 bin/voice/tests/test_todo_write.py`, fenced to a throwaway home, ends `PASS: the to-do door — 0 failure(s)`.
It checks that:

- a spoken to-do goes through `execute_tool` and the door, reads back from the record, lands in the house-kept half,
  and leaves his half byte-for-byte unchanged;
- a stale view is named, re-rendered, and keeps what it once showed;
- four adds on four threads all land;
- a tick of his line leaves his half untouched, and a raw write into his half is refused;
- a read-only record directory gives a spoken refusal with the path and `Errno 13`, writes nothing, and leaves no
  `.tmp`;
- a read-only list directory gives a refusal saying the record holds the item, and the log keeps the errno.

`bin/records/tests/test_comms.py` (18 tests), `bin/dispatch/tests/test_dispatch.py` (51 passed) and
`bin/voice/tests/test_todos_digest.sh` (14 passed) still pass. A first try made the dispatch run wait on its own
lock; the lock is now reentrant, and the dispatch suite is the proof.

## What is owed

- The four lines already under "## Added in conversation" in his half were written there by the old road. The door
  will not move them, because moving them edits his half. They stay until he says.
- The running voice serves the release pin. This takes effect only after the batch is merged and the pin flips.
- The live toolbox was not run from this worktree, so the proof stops at `execute_tool`, the function its `POST /tool` calls.
