# Your todos, read by the arm holder

## What it is
Rödd (the voice) keeps your task list. `bin/voice/todos.sh` reads it so the session holding the arm sees every open
item at session start — personal items first. Rödd stays the only writer; this door only reads.

## What you need
The voice's ledger at `$YMIR_HOME/hodd/state/voice/todos.jsonl` (created the first time you add a todo by voice).

## Do it
```bash
bin/voice/todos.sh                    # every open item
bin/voice/todos.sh --project personal # one project
bin/voice/todos.sh --digest           # what the session digest prints
```

## Limits
Read-only. Add, finish or change a todo through Rödd. The digest shows at most 15 lines.

## If it does not work
`open: 0` with items you expect: check `YMIR_HOME` resolves to your home (`bin/vault/hodd.sh path`).
