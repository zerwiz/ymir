# The brief door never runs its own template

**Date:** 2026-11-19 · **Component:** agents · **Door:** `bin/agents/erindi-brief.sh`

## What was wrong

`bin/agents/erindi-brief.sh e2e-rodd ymir --mode batch` printed shell errors before it wrote a usable brief:

```
line 267: id: No such file or directory
your: No such file or directory
pane:failed: command not found
```

Two paragraphs, "Checkpoint at every boundary" and "TALK INTO THE PANE", had been spliced into the middle of the
terminal-act sentence of the status section. That section is an unquoted heredoc, and the new paragraphs used bare
backticks. So writing a brief executed the template's own examples:

- `` `state/<id>.status` `` became a redirect from a file named `id`;
- `` `bin/agents/eindri-checkpoint.sh save …` `` and `` `bin/agents/eindri-notify.sh --from <your id> …` `` were
  run at scaffold time;
- `` `pane":"failed` `` was run as a command.

The brief also came out with holes where the commands should have been, and the sentence "files the report shelf the
… handoff failsafe sweeps" was cut in two.

## What was forged

- Every backtick in those two paragraphs is escaped, so the template text is written, never executed.
- The two paragraphs moved below the status section's last sentence, so the terminal-act sentence reads whole again.
  No words were removed.
- A scan of every unquoted heredoc in the door finds no bare backtick left.

## Proof (measured, fenced data and state)

Six scaffolds, one line each and no shell error:

```
scaffolded: …/f3.PBua/data/p3-bilskirnir/brief.md (ship, mode=batch; replace {TASK})
scaffolded: …/f3.PBua/data/p3-hvergelmir/brief.md (ship, mode=batch; replace {TASK})
scaffolded: …/f3.PBua/data/p3-odrerir/brief.md (ship, mode=batch; replace {TASK})
scaffolded: …/f3.PBua/data/p3-rodd/brief.md (ship, mode=batch; replace {TASK})
scaffolded: …/f3.PBua/data/p3-sessrumnir/brief.md (ship, mode=batch; replace {TASK})
scaffolded: …/f3.PBua/data/p3-smidja/brief.md (ship, mode=batch; replace {TASK})
```

The written brief carries the checkpoint command as text (`grep -c "eindri-checkpoint.sh save"` → `1`).

## CHANGE LOG

- **2026-11-19** — written with the change it describes.
