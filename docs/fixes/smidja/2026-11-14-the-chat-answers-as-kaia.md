# smidja · 2026-11-14 — the chat answers as Kaia, and the persona ships with the app

**Component:** smidja · **Branch:** `eindri/smidja-header-chat` (plan 275; helm's word, 2026-11-14)
**Files:** `apps/smidja-factory/apps/visualizer/prompts/kaia.md` (new), `server/chat.ts`,
`server/kaia.test.ts`, `.agents/skills/galdr-ymirsystem/assets/smidja.md`

## Why

The previous change made the chat *answer*; it answered as the seat's counsellor, because the
service's data root is the home and the home holds no Völundr persona, so no
`--append-system-prompt` was passed at all and pi took its identity from the `AGENTS.md` in its
working directory.

The helm's word of 2026-11-14 settles the shape: *"Kaia/Völundr's persona SHIPS with the app as a
generic default in the app's own tree, and the operator's home may override it … the chat must
answer as Kaia, not as the seat."*

## What changed

**A persona ships with the app** — `apps/smidja-factory/apps/visualizer/prompts/kaia.md`, generic
and portable: it says who Kaia is, how she speaks (plain, exact, never a guessed number), what the
smithy's record is, that she never invents a run or a cost, that she takes no identity from the
directory she runs in, and that a run needs a **team** and a **task**.

**The ladder that picks it**, in `kaiaPersonaFile()`:

| Order | Where | Why |
|---|---|---|
| 1 | `KAIA_PERSONA` (an explicit file) | a unit or a wrapper that knows better |
| 2 | `<root>/.agents/skills/smidja/kaia/persona.md` | the operator's own shape, in the home — the root IS the home when the chat's data lives there |
| 3 | `<root>/apps/smidja-factory/apps/visualizer/prompts/kaia.md` | a target repo that carries the smithy itself |
| 4 | the app's own tree, found by walking up from the server module | the shipped default: it answers the same on any machine, in any home |
| 5 | the two legacy paths | a repo shaped differently still finds its own |

**`--no-context-files` is passed to the chat's pi.** Without it the working directory's `AGENTS.md`
outranks the persona — that is exactly how the chat came to introduce itself as the seat's agent.
The consequence is named: the chat no longer inherits a project's context files; its shape is the
persona above.

## Proof

A **brand-new conversation** in the real window (private Electron, DevTools 9444), typed into the
chat's own input, sent through the UI:

```
session: chat-mwfuhbhl
send: clicked
reply after 94s:
  "I am Kaia, the voice of the Smíðja — the one who tells you what the smithy is doing and sets
   it to work — and this window is your own, Allfather Josef: the agent factory of the Ymir house."
errors: []
```

No seat name, no invented run, and the two things a run needs are in the persona.

Four new tests pin the ladder (`bun test`: **18 pass, 0 fail**): an explicit `KAIA_PERSONA` wins; a
stale one is skipped, not trusted; the home override beats the shipped default; with an empty target
repo the app's own default is still found.

## Not done, named

The operator's name still reaches the reply from **pi's own global instruction surface**, not from
the smithy's tree — so the chat can address the operator personally on this machine. That is the
harness's local configuration, not a fact this repo carries, and it is not this errand's to change.

## CHANGE LOG

- 2026-11-14 — generic Kaia persona shipped in the app's tree; home/`KAIA_PERSONA` override;
  `--no-context-files`; ladder pinned by four tests; asset corrected.
