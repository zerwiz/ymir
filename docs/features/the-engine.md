# The engine — the runtime core

## What it is

**The engine** (`src/ymir_runtime/`) is Ymir's deep core: one module that owns the
runtime's **four verbs** — `seat · status · send · stop` — behind thin shell doors.
Everything that takes a seat, watches it, talks to it, or stops it reaches the engine;
nothing re‑implements its rules.

## What you need

- Ymir installed. The door picks the interpreter and points `PYTHONPATH` at the tree.

## Do it

```bash
bin/engine/ymir-engine.sh seat   <id> --project <dir> [--harness h] [--model m]
bin/engine/ymir-engine.sh status <id> [--window N] [--toon]
bin/engine/ymir-engine.sh send   <id> "<text>"
bin/engine/ymir-engine.sh stop   <id> [--remove-worktree] [--require-landed] [--force]
bin/engine/ymir-engine.sh dispatch <role|figure> [--task T] [--brief F] [--kind K]
```

- **seat** — take a seat for `id` (a harness + model), creating its worktree as needed.
- **status** — what that seat is doing now.
- **send** — a message into a live seat.
- **stop** — end it, optionally removing the worktree (and refusing unless the work landed).
- **dispatch** — hand a role/figure an errand.

## Notes and limits

- **One implementation.** The Python module is the source of truth; the shell door is a
  pointer. A rule added to a shell door is a second implementation and a bug.
- **The engine owns state**, not the tree: locks, leases, and journals resolve through
  `bin/records/ymir-state.sh` and the hoard (Rule 04/07).
- **`stop` is careful.** `--require-landed` refuses to discard unlanded work; removing a
  worktree is explicit.

## If it does not work

| What you see | What to do |
|---|---|
| `no engine` / import error | The tree's `src/ymir_runtime/` is missing or stale — `ymir groa`. |
| A verb says the seat is busy | Another primary holds the lock; inspect with `bin/records/ymir-state.sh`. |
| `stop` refuses | Unlanded work: land it (a PR) or pass `--force` deliberately. |
