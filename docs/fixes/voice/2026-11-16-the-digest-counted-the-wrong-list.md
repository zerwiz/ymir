# The session digest counted the wrong list

**Date:** 2026-11-16 · **Component:** voice (`bin/voice/todos.sh`, `bin/voice/voice_tools.py`) · **Also:** `bin/time/saga-session-start.sh`

## What was wrong

Every session opened with this line in Sága's head:

```
wakes 374 · decisions 0 · questions 0 · todos: 0
```

It was true about the thing it read and false about the thing everyone assumed it read. `bin/voice/todos.sh --digest`
folded the **voice's ledger** — `hodd/state/voice/todos.jsonl`, one event per line, written only when a to-do is
spoken to Rödd — and that file was empty. The Allfather's real list, `hodd/life/personal/me/todo.md`, held **57 open
checkboxes** at the moment the head printed zero: 36 in his half, 10 in the derived half, 11 in the house-kept half.

A count that is confidently zero about the Allfather's day is worse than no count. It reads as *nothing is waiting on
you*, and it is the one line in the head he looks at first.

The split had been known since plan 275 (2026-11-12), when the voice's own tools stopped pointing at the ledger and
started reading `todo.md`; the digest was never taught the same lesson.

## What was done

1. **One parser, and it names the halves.** `_todo_items()` in `bin/voice/voice_tools.py` now returns the **half** each
   item sits in (`his` · `derived` · `kept`), read from the file's own top-level headings — his half is his judgement,
   the derived half is what the house measured, the house-kept half is what his messages moved. No second copy of the
   parser, so the digest and Rödd's tools can never disagree about what an open item is.
2. **The digest reads his list first.** `bin/voice/todos.sh --digest` prints:

   ```
   open: 57 — his half 36 · house-kept 21 · voice ledger 0
     <path>/todo.md (house-kept 21 = derived 10 + from his messages 11) · voice ledger <path>/todos.jsonl
   - [his · Today] Rödd carries a collaborator's mail — …  (t8495c)
   ```

   The halves are counted apart, the voice ledger keeps its own named count, item lines are tagged by half and carry
   the short id the to-do tools tick by, and the 15-line cap is unchanged.
3. **A list that cannot be read says `unable`, never `0`.** The file's own law — *a fact that cannot be read is printed
   as unable, never as zero* — now holds for the count too.
4. **The head keeps the short form.** `head_needs` strips the voice-ledger tail instead of the old `— ledger` tail, so
   the head prints `todos: 57 — his half 36 · house-kept 21`.

## Proof

- `bin/voice/tests/test_todos_digest.sh` — 13 checks against a planted home: **three open checkboxes report three**;
  his half and the house-kept half count apart (3 + 6 = 9) and the house-kept total names its owned split
  (derived 2 + messages 4); a `[x]` line is not open; the voice ledger is its own count (1) and never joins his; an
  absent list prints `unable` and never `open: 0`; and the session head carries the same number, never a bare zero.
- Gate `bin/gates/checks.d/0490-todos-digest.sh` runs it in CI.
- Measured against the real home the same day: `bin/voice/todos.sh --digest` → `open: 57 — his half 36 · house-kept 21
  · voice ledger 0`, and `bash bin/time/saga-session-start.sh --head` → `todos: 57 — his half 36 · house-kept 21`. The list is
  live and kept growing while this was written (69 open — house-kept 33 — an hour later, as the mail triage added rows),
  which is exactly why the door must read the file rather than a ledger that only knows what was spoken to Rödd.
- `bin/time/tests/test_saga_head.sh` — 41 pass, 1 fail, and the failure (`the hook runs the home the session is IN`) is
  pre-existing on `main` at `518213713`, proved by running the same test in the unmodified checkout.
