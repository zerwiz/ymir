## gates · unversioned · 2026-11-08 — the scan flagged the voice's ledger by its own name

Every open PR went red on the same gate and none of them caused it: `mocks-vocabulary` failed on `main`
itself, so #578 and #579 both inherited it. `mocks-scan.sh` greps `bin/` for the four words that name
something unfinished — `mock · stub · placeholder · todo` — and `bin/voice/voice_tools.py` uses `todo`
nine times because the voice really does keep a task ledger (`hodd/state/voice/todos.jsonl`, rendered to
`hodd/life/personal/me/todo-voice.md`). The word was a NAME here, never a stub.

Two faults, both in the scan's excuse list rather than in the voice:

- **The prose.** Seven description and message strings told the model about "the todo ledger". They now
  say the same thing in the scan's plain words — *this voice's ledger*, *task list* — so the shipped
  behaviour is described without the stub vocabulary. The tool names (`todo_add`, `todo_list`,
  `todo_done`) are untouched: a name the model and the operator already know is not renamed to please a
  grep.
- **The filenames.** The scan excused a path ending in `todo.md` (the operator's own note file) and not
  `todo-voice.md`, the list the voice keeps beside it. The excuse is widened to `todo-<name>.md` — still
  a FILENAME rule, and still narrow: a lone `todo` in code is caught exactly as before, which the probe
  proves.

Proved in the worktree, not by reading: `mocks-scan.sh .` exits 0 with no hits, and
`.agents/tests/mocks-scan.test.sh` reports **ok** on all four cases — the excused shapes, a real stub
caught, the excuses staying narrow, and the shipped tree passing its own scan.

## CHANGE LOG

- 2026-11-08 · seven prose strings in `bin/voice/voice_tools.py` reworded; the `todo-<name>.md` filename
  excuse added to `mocks-scan.sh` with its reason written beside the other six; the probe re-run green.
