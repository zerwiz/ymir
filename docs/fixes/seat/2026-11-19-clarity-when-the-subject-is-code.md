# The voice was hiding instructions — a code answer now says what to do, and a button says what it does

**Date:** 2026-11-19 · **Component:** seat (`AGENTS.md` voice section, `bin/seat/seat-surface.sh`,
`docs/features/telegram-buttons.md`) · **Errand:** `voice-clarity`

## What was wrong

At the operator's word:

> *"when we talking about code it must be clear. i dont understand the buttons. can we update what ymir
> says about voice. so it beeing updated to upsers on insallations and updates. code and answers on
> telegram when talking about code must be clear what do to."*

The contract already said the voice must never enter a path, a command or a number (`voice_bounds`). It
did **not** say what happens when the *subject* is code, which is most of the day: the answer around the
command, and the button label under it.

The evidence was in the answers themselves. A button labelled `🎛 Let the gate hear edits` was shipped the
previous day and stood for "add `edited` to the workflow's `pull_request` types so the checks re-run on a
repaired body". Three facts were inside a metaphor, and the operator had to ask what it meant. A label a
reader cannot act on is a broken control, however well the sentence around it is written.

## What was built

| file | change |
|---|---|
| `AGENTS.md` | a new law in the voice section, **"Clarity outranks the voice whenever the subject is code"**, with five rules: say what to do first · a label is an instruction, not a riddle · one command, one line, copyable · name the file, the line, the error · if it cannot be said plainly, say what is unknown |
| `AGENTS.md` | the Telegram button rule rewritten: a label names **what the tap does, to what, and what comes out**, and a click that changes code names the file, the command and the branch |
| `docs/features/telegram-buttons.md` | the same rule as a page — a table of a good label beside a puzzle, so a reader sees the difference |
| `bin/seat/seat-surface.sh --check` | refuses a seat render that loses either sentence, so install and every update keep the law in front of the agent |

**Why the render is the right place.** The contract reaches a user through `bin/seat/seat-surface.sh`:
the install runs it, Gróa's update runs it, and it writes `~/.pi/agent/AGENTS.seat.md`, which every
harness instruction file points at. A sentence that is only in the repo's `AGENTS.md` still arrives —
but a sentence the renderer *checks for* cannot be dropped by a later edit to the render.

## The proof

A seat render of this tree, into a throwaway home:

```
seat-surface: seat file names forseti ✓
seat-surface: seat file names the operator and the sentence that forbids leaving it off ✓
seat-surface: seat file carries the clarity law — "Clarity outranks the voice whenever the subject is code" ✓
seat-surface: seat file carries the clarity law — "A label is an instruction, not a riddle" ✓
```

With either sentence removed from the contract, the same command reports `seat file LOST the clarity law`
and exits 1 — which is what an install or an update would then fail on, rather than a person discovering it
by reading an answer he could not follow.

## What this does not decide

- **It does not forbid the house voice.** The voice stays in the closing sentence, in the names of things,
  and in the sense of what happened. The law is about the sentence that tells him what to do.
- **`bin/gates/tests/test_new_doors.sh` cannot prove the seat check from a worktree.** Measured: that
  assertion runs `seat-surface.sh --check` against the real `$HOME` and compares it with `$ROOT`, and
  `$ROOT/.hermes.md` is written only in the tree the renderer ran in — so from any `.yggdrasil/` worktree it
  reports `.hermes.md is missing` and exits 1, on `main`'s code as much as on this branch. The check itself
  was proved in a throwaway home and in the real one, which printed both law lines ✓.
- **It cannot be proved by this note, only by the next answers.** A clarity law that is obeyed only when
  someone remembers to obey it is the same hope the heavy lock was before it became a command. The check
  above holds the *sentence*; only the operator can say whether the answer was clear.

## CHANGE LOG

- 2026-11-19 — written at the operator's word, from a button he could not read.
