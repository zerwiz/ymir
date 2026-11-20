# every seat can see its own context budget

**2026-11-09 · component: seat**

`context_left` existed in exactly one place: `bin/voice/voice_tools.py`, Rödd's toolbox. A pi seat — the
counsellor, every Eindri, every seat in Sessrúmnir — had nothing, so an agent could not see how much
conversation it was carrying. That is why work ran into the wall without warning: two errands on the same
night ended "25 minutes at the context ceiling".

Measured before the fix, with `grep -rn context_left`: one definition, in the voice module, and two callers
(Rödd's prompt, Skírnir). Nothing else in the tree could ask.

## What was built

**`.pi/extensions/context-left/`** — a shipped pi extension, discovered by pi's own loader in the one home
(RULES/13), so a fresh clone and every update carry it: no separate install step, nothing to remember.

- `index.ts` gathers the harness's own facts — `ctx.getContextUsage()` for the token count,
  `ctx.model.contextWindow` for the window (the catalogue's number, never a literal), and
  `ctx.sessionManager.getEntries()` for the user turns — derives the reading, registers the tool, and
  publishes on every call and every `turn_end`.
- `reading.ts` holds the arithmetic alone (pure, no pi import) so it can be proved without a model.
- The reserve is resolved in pi's own order — project settings, then user settings, then pi's documented
  default — and the answer names which one answered (RULES/07).

**One counter, not two.** The extension publishes to
`<home>/hodd/state/context-left/<session>.json`, one file per session so there is one writer per file. The
voice tool `context_left` was rewritten to repeat that published reading — its host.log token scrape is gone
from that block — and it refuses, naming the reason, when no reading has been published.

**A refusal is a true answer.** An unknown window says *"the context window is unknown for \<model\>"*; a
token count the harness cannot measure yet says so and asks again after the next turn. Neither is rounded
into a number.

Verified: `.agents/tests/context-left.test.sh` drives the real factory with a fake pi object, and proves
the number moves (`remaining` 163,616 → 93,616 as the session spends tokens), that turns-left is derived
from the session's own spending, that both unknowns are refused by name, that the publication carries the
facts and a pid, and that the voice repeats the extension's rendered reading and refuses cleanly when there
is none. `bash .agents/tests/pi-extensions.test.sh` passes in full.

## What this does not claim

A seat pinned to a runtime (`$YMIR_HOME/config/runtime.env` → `YMIR_RUNTIME_DIR`) loads the extensions of
that pinned tree, so a seat sees this tool after its runtime carries it. The tree's own gate
(`bin/seat/valknut-load.sh --check`) reports `shared-copy` for a Yggdrasil worktree that carries its own
`.pi/extensions` — a pre-existing state of this worktree, repaired by its owner with the sparse line the
gate prints.

## CHANGE LOG

- **2026-11-09** — Opened with the fix.
