# Your todos, read by the arm holder

## What it is

`bin/voice/todos.sh` reads the two lists the house keeps about what is owed, so the session holding the arm sees them
at session start. They are printed together and never confused:

- **Your list** — `life/personal/me/todo.md`, the one to-do. The file names its own halves (his half, the derived
  half, the house-kept half) and each is counted apart, because they mean different things: his half is your
  judgement, the derived half is what the house measured, the house-kept half is what your messages moved.
- **The voice's ledger** — `state/voice/todos.jsonl`, where a to-do spoken to Rödd lands. It is kept as its own,
  separately named count.

Nothing here writes either list. Reading only.

## What you need

Your list at `$YMIR_HOME/life/personal/me/todo.md`. The voice's ledger may be absent — an empty ledger is a
zero, not an error.

## Do it

```bash
bin/voice/todos.sh                     # every open item: your list first, then the voice ledger
bin/voice/todos.sh --digest            # the session-start block: the counts, then at most 15 open lines
bin/voice/todos.sh --project personal   # only open items whose section or words match "personal"
bin/voice/todos.sh --json              # the voice ledger, everything, open and done
```

The block starts like this:

```
open: 57 — his half 36 · house-kept 21 · voice ledger 0
  …/me/todo.md (house-kept 21 = derived 10 + from his messages 11) · voice ledger …/state/voice/todos.jsonl
- [his · Today] Rödd carries a collaborator's mail — …  (t8495c)
```

The tag on each line says which list and which half it came from — `his`, `derived`, `kept` or `voice` — and the
short id in brackets is the id the to-do tools tick, reopen and reword by.

## Limits

- At most 15 open lines are printed; the rest are counted (`… 42 more`).
- Each item is cut at about 110 characters, with `…` where it was cut. The file holds the whole sentence.
- `--json` is the voice ledger only, by design: it is a machine shape for Rödd's own ledger, not your list.
- A list that cannot be read prints `open: unable — …` with the reason. It never prints `0`, because zero is a claim
  about your day and an unreadable file is not evidence of an empty one.

## If it does not work

- `open: unable — his list … no such file`: your home does not hold `life/personal/me/todo.md`. Check `YMIR_HOME`
  resolves to your home (`bin/vault/hodd.sh path`).
- A number you disagree with: open the file and count the `- [ ]` lines in the half named on the first line. The
  second line names the file it read, so the comparison is exact.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-16** — the door now reads your list first: the halves are counted apart and the voice ledger is its own named count. Before this the digest counted only the voice ledger and the session head printed `todos: 0` while your list held 57 open items. A list that cannot be read prints `unable`, never `0`.
